@include once __ROOT__ + "/REST.Losant.agent.singleton.nut"

// =============================================================================
// REST_LOSANT_DEVICES ---------------------------------------------------------
// ============================================================================{

REST.Losant.device <- {
    id = null           // The Losant generated Device ID
    attributes = [],    // The Losant Attributes as returned in get or set in update or devices.create
    tags = [            // The Losant tags as returned in get or set in update or devices.create
        {
            "key"   : "idAgent",
            "value" : split(http.agenturl(), "/")[2]
        },
        {
            "key"   : "idDevice",
            "value" : imp.configparams.deviceid
        },
    ],

    applicationKeyId = null,    //TODO: Not sure if this is necessary beyond deleting the key?
    applicationKey = null,
    applicationKeySecret = null,

    _applicationKeyToken = null,
    _applicationKeyTokenRefreshTimer = null,

    _path = "/devices/%s",
    //TODO: Trade out our API Token for a Device Access Key with limited permissions and use it throughout this API

    _connectionWatchdog = null,
    _connectionWatchdogCheckInterval = 1.0,
    _connectionLastStatus = null,

    _commandStreamDeviceID = null,
    _commandStreamSSErequest = null,
    _commandStreamSSEwatchdog = null,
    _commandStreamKeepAliveTimeout = null,

    _stateStreamDeviceID = null,
    _stateStreamSSErequest = null,
    _stateStreamSSEwatchdog = null,
    _stateStreamKeepAliveTimeout = null,

    /**
    * Deletes a device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Organization, all.User, device.*, or device.delete.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - If device was successfully deleted (https://api.losant.com/#/definitions/success)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    destroy = function(params = {}){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("DELETE", format(this._path + "?%s", deviceID, http.urlencode(params)), "", this._getAuthHeaders())
                    .then(function(body){
                        // Unset our device ID if we've just destroyed it
                        if(deviceID == this.id){
                            this.stopConnectionStatusWatchdog()
                            this.id = null;
                        }
                        return body;
                    }.bindenv(this))

    }

    /**
    * Retrieves information on a device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.get.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {string} excludeConnectionInfo - If set, do not return connection info
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Device information (https://api.losant.com/#/definitions/device)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    get = function(params = {}){
        local validParams = [
            "excludeConnectionInfo",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("GET", format(this._path + "?%s", deviceID, http.urlencode(params)), "", this._getAuthHeaders())
                    .then(function(body){
                        if(deviceID == this.id){
                            // set the device ID, tags, and attributes that are returned in our device class for future use so that outside code doesn't have to remember to do this!
                            this.id = body.deviceId;
                            this.tags = body.tags;
                            this.attributes = body.attributes;

                            this.startConnectionStatusWatchdog()
                        }

                        return body
                    }.bindenv(this))
    }

    /**
    * Retrieve the last known commands(s) sent to the device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.getCommand.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {string} limit - Max command entries to return (ordered by time descending)
    *  {string} since - Look for command entries since this time (ms since epoch)
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Recent device commands (https://api.losant.com/#/definitions/deviceCommands)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    getCommand = function(params = {}){
        local validParams = [
            "limit",
            "since",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("GET", format(this._path + "/command?%s", deviceID, http.urlencode(params)), "", this._getAuthHeaders())
    }

    /**
    * Retrieve the composite last complete state of the device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.getCompositeState.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {string} start - Start of time range to look at to build composite state
    *  {string} end - End of time range to look at to build composite state
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Composite last state of the device (https://api.losant.com/#/definitions/compositeDeviceState)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    getCompositeState = function(params = {}){
        local validParams = [
            "start",
            "end",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("GET", format(this._path + "/compositeState?%s", deviceID, http.urlencode(params)), "", this._getAuthHeaders())
    }

    /**
    * Retrieve the recent log entries about the device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.getLogEntries.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {string} limit - Max log entries to return (ordered by time descending)
    *  {string} since - Look for log entries since this time (ms since epoch)
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Recent log entries (https://api.losant.com/#/definitions/deviceLog)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    getLogEntries  = function(params = {}){
        local validParams = [
            "limit",
            "since",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("GET", format(this._path + "/logs?%s", deviceID, http.urlencode(params)), "", this._getAuthHeaders())
    }

    /**
    * Retrieve the last known state(s) of the device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.getState.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {string} limit - Max state entries to return (ordered by time descending)
    *  {string} since - Look for state entries since this time (ms since epoch)
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Recent device states (https://api.losant.com/#/definitions/deviceStates)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    getState  = function(params = {}){
        local validParams = [
            "limit",
            "since",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("GET", format(this._path + "/state?%s", deviceID, http.urlencode(params)), "", this._getAuthHeaders())
    }

    /**
    * Updates information about a device - note this is an overwrite, not a merge!
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Organization, all.User, device.*, or device.patch.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {table} device - Object containing new properties of the device (https://api.losant.com/#/definitions/devicePatch)
    *       - {string} name
    *       - {string} description
    *       - {string} deviceClass
    *       - {array}  attributes
    *       - {array}  tags
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Updated device information (https://api.losant.com/#/definitions/device)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    update = function(params = {}){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Setup the device body parameter, overwriting anything that is there
        local body = {}
        body.name               <- "name"           in params ? params.name             : split(http.agenturl(), "/").top()
        body.description        <- "description"    in params ? params.description      : "Electric Imp Device"
        body.deviceClass        <- "deviceClass"    in params ? params.deviceClass      : "standalone"
        body.attributes         <- "attributes"     in params ? params.attributes       : (this.id == deviceID ? this.attributes : [])
        body.tags               <- "tags"           in params ? params.tags             : this.tags

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("PATCH", format(this._path + "?%s", deviceID, http.urlencode(params)), body, this._getAuthHeaders())
                    .then(function(body){
                        if(deviceID == this.id){
                            // set the device ID, tags, and attributes that are returned in our device class for future use so that outside code doesn't have to remember to do this!
                            this.id = body.deviceId;
                            this.tags = body.tags;
                            this.attributes = body.attributes;

                            this.startConnectionStatusWatchdog()
                        }

                        return body
                    }.bindenv(this))
    }

    /**
    * Send a command to a device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Device, all.Organization, all.User, device.*, or device.sendCommand.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  deviceCommand - Command to send to the device (https://api.losant.com/#/definitions/deviceCommand)
    *       - {string} time
    *       - {string} name
    *       - {object} payload
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - If command was successfully sent (https://api.losant.com/#/definitions/success)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    sendCommand = function(params = {}, bodyEncoder = http.jsonencode.bindenv(http), bodyDecoder = http.jsondecode.bindenv(http)){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Setup the device body parameter, overwriting anything that is there
        local body = {
            "name" : params.name
        }
        body.time               <- "time"           in params ? params.time             : this.createIsoTimeStamp()
        body.payload            <- "payload"        in params ? params.payload          : {}


        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "/command?%s", deviceID, http.urlencode(params)), body, this._getAuthHeaders(), false, bodyEncoder, bodyDecoder)
    }

    /**
    * Send the current state of the device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Device, all.Organization, all.User, device.*, or device.sendState.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {object} deviceState - A single device state object, or an array of device state objects (https://api.losant.com/#/definitions/deviceStateOrStates)
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - If state was successfully received (https://api.losant.com/#/definitions/success)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    sendState = function(params = {}, bodyEncoder = http.jsonencode.bindenv(http), bodyDecoder = http.jsondecode.bindenv(http)){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Setup the deviceState body parameter, overwriting anything that is there
        local body = params.deviceState

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "/state?%s", deviceID, http.urlencode(params)), body, this._getAuthHeaders(), false, bodyEncoder, bodyDecoder)
    }

    /**
    * Set the current connection status of the device
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Device, all.Organization, all.User, device.*, or device.setConnectionStatus.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  connectionStatus - The current connection status of the device (https://api.losant.com/#/definitions/deviceConnectionStatus)
    *       - {string} status ["connected", "disconnected"]
    *       - {string} connectedAt
    *       - {string} disconnectedAt
    *       - {string} disconnectReason
    *       - {integer} messagesFromClient
    *       - {integer} messagesToClient

    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - If connection status was successfully applied (https://api.losant.com/#/definitions/success)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    setConnectionStatus = function(params = {}){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        local deviceID = "deviceId"           in params ? params.deviceId : this.id

        if(typeof deviceID != "string")
            throw "Device ID has not been set"

        // Setup the device body parameter, overwriting anything that is there
        local body = {
            "status" : params.status
        }

        if("connectedAt" in params){
            body.connectedAt <- params.connectedAt
        } else if (body.status == "connected"){
            body.connectedAt <- this.createIsoTimeStamp()
        }

        if("disconnectedAt" in params){
            body.disconnectedAt <- params.disconnectedAt
        } else if (body.status == "disconnected"){
            body.disconnectedAt <- this.createIsoTimeStamp()
        }

        if("disconnectReason" in params){
            body.disconnectReason <- params.disconnectReason
        }
        if("messagesFromClient" in params){
            body.messagesFromClient <- params.messagesFromClient
        }
        if("messagesToClient" in params){
            body.messagesToClient <- params.messagesToClient
        }

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "/setConnectionStatus?%s", deviceID, http.urlencode(params)), body, this._getAuthHeaders())
    }

    /**
    * Attach to a real time stream of command messages to this device using Server Sent Events (SSE)
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.commandStream.
    *
    * Parameters:
    *  {function} onData - Callback function called when data is received
    *  {function} onError - Callback function called when error is encountered
    *  {string} deviceId - ID associated with the device
    *  {string} keepAliveInterval - Number of seconds between keepalive messages (between 2 & 60)
    *
    * Returns a Promise for (or calls the provided callback with)
    * an EventSource instance, which will be an
    * SSE stream of new command messages for this device
    *
    * It will have the following message event types:
    *  deviceCommand - An SSE event representing a single device command (https://api.losant.com/#/definitions/deviceCommand)
    *
    * See https://developer.mozilla.org/en-US/docs/Web/API/EventSource
    * for more information about EventSource instances.
    *
    * Possible Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    openCommandStream = function(onData, onError, params = {}){
        local validParams = [
            "keepAliveInterval",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        this._commandStreamDeviceID = "deviceId"           in params ? params.deviceId : this.id

        // Establish our keep alive timer value

        if(typeof this._commandStreamDeviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params.keepAliveInterval <- "keepAliveInterval"  in params ?  params.keepAliveInterval : 30
        params._actions          <- "_actions"           in params ?  params._actions          : false
        params._links            <- "_links"             in params ?  params._links            : false
        params._embedded         <- "_embedded"          in params ?  params._embedded         : false

        params = validateAndSanitizeParams(params, validParams);

        // Don't allow more than one stream open at a time
        this.closeCommandStream();

        // Start streaming watchdog
        this._commandStreamKeepAliveTimeout = params.keepAliveInterval*1.05;    // Increase our watchdog by 5% over the keepalive interval
        this._startCommandStreamKeepAliveTimer(onData, onError);

        // Open the streaming request
        this._commandStreamSSErequest = http.get(format("%s" + _path + "/commandStream?%s", this._baseURL, this._commandStreamDeviceID, http.urlencode(params)), this._headers);
        this._commandStreamSSErequest.sendasync(this._commandStreamRespFactory(onData, onError), this._commandStreamOnDataFactory(onData, onError));
    }

    // isCommandStreamOpen - Returns whether stream is currently open
    // Returns: boolean, if a stream is currently open
    // Parameters: none
    function isCommandStreamOpen() {
        return (_commandStreamSSErequest != null);
    }

    // closeCommandStream - Closes a listener for commands directed at this device
    // Returns: null
    function closeCommandStream() {
        if (this._commandStreamSSErequest != null) {
            this._commandStreamSSErequest.cancel();
            this._commandStreamSSErequest = null;
        }

        if (this._commandStreamSSEwatchdog) {
            imp.cancelwakeup(_commandStreamSSEwatchdog);
            this._commandStreamSSEwatchdog = null;
        }
    }

    // _commandStreamRespFactory - Creates function that reopen stream if it closes for known reason,
    //                   otherwise calls onError callback.
    // Returns: function
    // Parameters:
    //      losDevId (required) : string - Losant device id (this is NOT the imp device id)
    //      onData (required): function - Callback function called when data is received
    //      onError (required) : function - Callback function called when error is
    //                                      encountered
    function _commandStreamRespFactory(onData, onError) {
        return function (resp) {
            if (resp.statuscode == 28 || resp.statuscode == 200) {
                // Reopen listener  //TODO: Probably need to implement some kind of backoff strategy
                imp.wakeup(0, function() {
                    this.openCommandStream(onData, onError);
                }.bindenv(this));
            } else {
                // Make sure the stream is closed, call the error callback
                this.closeCommandStream();
                imp.wakeup(1.0, function() {
                    // Start a Reconnection attempt  //TODO: Probably need to implement some kind of backoff strategy
                    this.openCommandStream(onData, onError);

                    onError("ERROR: Command stream closed, received error. Status code: " + resp.statuscode, resp);
                }.bindenv(this))
            }
            // Reset request variable
            this._commandStreamSSErequest = null;
        }.bindenv(this)
    }

    // _commandStreamOnDataFactory - Creates function that parses incomming data message or calls OnError callback if parsing fails.
    // Returns: function
    // Parameters:
    //      losDevId (required) : string - Losant device id (this is NOT the imp device id)
    //      onData (required): function - Callback function called when data is received
    //      onError (required) : function - Callback function called when error is
    //                                      encountered
    function _commandStreamOnDataFactory(onData, onError) {
        return function(content) {
            // Restart keep alive timer
            this._startCommandStreamKeepAliveTimer(onData, onError);
            // Process all data that is not a keepalive ping
            if (content != ":keepalive\n\n") {
                try {
                    // Parse content to get to data table
                    // Data is formatted according to SSE (server-sent-event) spec
                    // https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
                    local arr = split(content, "\n");
                    if (arr[1].find("data:") != null) {
                        // chop "data: " off the top of string, so
                        // table can be decoded
                        local data = arr[1].slice(6);
                        data = http.jsondecode(data);
                        // Pass command to callback
                        imp.wakeup(0, function() {
                            onData(data);
                        }.bindenv(this))
                    }
                } catch(e) {
                    // Parser failed, pass payload to user
                    onError("ERROR: Parsing command streaming data failed " + e, content);
                }
            }
        }.bindenv(this)
    }

    // _startCommandStreamKeepAliveTimer - Cancels keep alive timer if it is running and restarts a keep alive timer. If timer
    //                        is not reset stream will be closed and streaming error handler will be called.
    // Returns : nothing
    // Parameters : none
    function _startCommandStreamKeepAliveTimer(onData, onError) {
        if (this._commandStreamSSEwatchdog) {
            imp.cancelwakeup(_commandStreamSSEwatchdog);
            this._commandStreamSSEwatchdog = null;
        }
        this._commandStreamSSEwatchdog = imp.wakeup(_commandStreamKeepAliveTimeout, function() {
            this.closeCommandStream();
            // Start a Reconnection attempt  //TODO: Probably need to implement some kind of backoff strategy
            this.openCommandStream(onData, onError);

            onError("ERROR: Command stream restarting. No response from server in " + _commandStreamKeepAliveTimeout + " seconds", null);
        }.bindenv(this));
    }

    /**
    * Attach to a real time stream of state messages from this device using Server Sent Events (SSE)
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, device.*, or device.stateStream.
    *
    * Parameters:
    *  {string} deviceId - ID associated with the device
    *  {string} keepAliveInterval - Number of seconds between keepalive messages
    *
    * Returns a Promise for (or calls the provided callback with)
    * an EventSource instance, which will be an
    * SSE stream of new state messages for this device
    *
    * It will have the following message event types:
    *  deviceState - An SSE event representing a single device state (https://api.losant.com/#/definitions/deviceState)
    *
    * See https://developer.mozilla.org/en-US/docs/Web/API/EventSource
    * for more information about EventSource instances.
    *
    * Possible Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if device was not found (https://api.losant.com/#/definitions/error)
    */
    openStateStream = function(onData, onError, params = {}){
        local validParams = [
            "keepAliveInterval",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Extract the device ID from the params or use the one that we have set
        this._stateStreamDeviceID = "deviceId"           in params ? params.deviceId : this.id

        // Establish our keep alive timer value

        if(typeof this._stateStreamDeviceID != "string")
            throw "Device ID has not been set"

        // Override any missing default values
        params.keepAliveInterval <- "keepAliveInterval"  in params ?  params.keepAliveInterval : 30
        params._actions          <- "_actions"           in params ?  params._actions          : false
        params._links            <- "_links"             in params ?  params._links            : false
        params._embedded         <- "_embedded"          in params ?  params._embedded         : false

        params = validateAndSanitizeParams(params, validParams);

        // Don't allow more than one stream open at a time
        this.closeStateStream();

        // Start streaming watchdog
        this._stateStreamKeepAliveTimeout = params.keepAliveInterval*1.05;    // Increase our watchdog by 5% over the keepalive interval
        this._startStateStreamKeepAliveTimer(onData, onError);

        // Open the streaming request
        this._stateStreamSSErequest = http.get(format("%s" + _path + "/stateStream?%s", this._baseURL, this._stateStreamDeviceID, http.urlencode(params)), this._headers);
        this._stateStreamSSErequest.sendasync(this._stateStreamRespFactory(onData, onError), this._stateStreamOnDataFactory(onData, onError));
    }

    // isStateStreamOpen - Returns whether stream is currently open
    // Returns: boolean, if a stream is currently open
    // Parameters: none
    function isStateStreamOpen() {
        return (_stateStreamSSErequest != null);
    }

    // closeStateStream - Closes a listener for commands directed at this device
    // Returns: null
    function closeStateStream() {
        if (this._stateStreamSSErequest != null) {
            this._stateStreamSSErequest.cancel();
            this._stateStreamSSErequest = null;
        }

        if (this._stateStreamSSEwatchdog) {
            imp.cancelwakeup(_stateStreamSSEwatchdog);
            this._stateStreamSSEwatchdog = null;
        }
    }

    // _stateStreamRespFactory - Creates function that reopen stream if it closes for known reason,
    //                   otherwise calls onError callback.
    // Returns: function
    // Parameters:
    //      losDevId (required) : string - Losant device id (this is NOT the imp device id)
    //      onData (required): function - Callback function called when data is received
    //      onError (required) : function - Callback function called when error is
    //                                      encountered
    function _stateStreamRespFactory(onData, onError) {
        return function (resp) {
            if (resp.statuscode == 28 || resp.statuscode == 200) {
                // Reopen listener  //TODO: Probably need to implement some kind of backoff strategy
                imp.wakeup(0, function() {
                    this.openStateStream(onData, onError);
                }.bindenv(this));
            } else {
                // Make sure the stream is closed, call the error callback
                this.closeStateStream();
                imp.wakeup(1.0, function() {
                    // Start a Reconnection attempt  //TODO: Probably need to implement some kind of backoff strategy
                    this.openStateStream(onData, onError);

                    onError("ERROR: Command stream closed, received error. Status code: " + resp.statuscode, resp);
                }.bindenv(this))
            }
            // Reset request variable
            this._stateStreamSSErequest = null;
        }.bindenv(this)
    }

    // _stateStreamOnDataFactory - Creates function that parses incomming data message or calls OnError callback if parsing fails.
    // Returns: function
    // Parameters:
    //      losDevId (required) : string - Losant device id (this is NOT the imp device id)
    //      onData (required): function - Callback function called when data is received
    //      onError (required) : function - Callback function called when error is
    //                                      encountered
    function _stateStreamOnDataFactory(onData, onError) {
        return function(content) {
            // Restart keep alive timer
            this._startStateStreamKeepAliveTimer(onData, onError);
            // Process all data that is not a keepalive ping
            if (content != ":keepalive\n\n") {
                try {
                    // Parse content to get to data table
                    // Data is formatted according to SSE (server-sent-event) spec
                    // https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
                    local arr = split(content, "\n");
                    if (arr[1].find("data:") != null) {
                        // chop "data: " off the top of string, so
                        // table can be decoded
                        local data = arr[1].slice(6);
                        data = http.jsondecode(data);
                        // Pass command to callback
                        imp.wakeup(0, function() {
                            onData(data);
                        }.bindenv(this))
                    }
                } catch(e) {
                    // Parser failed, pass payload to user
                    onError("ERROR: Parsing command streaming data failed " + e, content);
                }
            }
        }.bindenv(this)
    }

    // _startStateStreamKeepAliveTimer - Cancels keep alive timer if it is running and restarts a keep alive timer. If timer
    //                        is not reset stream will be closed and streaming error handler will be called.
    // Returns : nothing
    // Parameters : none
    function _startStateStreamKeepAliveTimer(onData, onError) {
        if (this._stateStreamSSEwatchdog) {
            imp.cancelwakeup(_stateStreamSSEwatchdog);
            this._stateStreamSSEwatchdog = null;
        }
        this._stateStreamSSEwatchdog = imp.wakeup(_stateStreamKeepAliveTimeout, function() {
            this.closeStateStream();
            // Start a Reconnection attempt  //TODO: Probably need to implement some kind of backoff strategy
            this.openStateStream(onData, onError);

            onError("ERROR: Command stream restarting. No response from server in " + _stateStreamKeepAliveTimeout + " seconds", null);
        }.bindenv(this));
    }

    function startConnectionStatusWatchdog(interval = 1.0){
        if(this._connectionWatchdog){
            return;
        }

        this._connectionWatchdogCheckInterval = interval;
        return _checkConnectionStatus()
    }

    function stopConnectionStatusWatchdog(){
        if(this._connectionWatchdog){
            imp.cancelwakeup(this._connectionWatchdog)
            this._connectionWatchdog = null;
        }
    }

    function _checkConnectionStatus(){
        // setup our timer
        this._connectionWatchdog = imp.wakeup(this._connectionWatchdogCheckInterval, this._checkConnectionStatus.bindenv(this))

        local status = ::device.isconnected() ? "connected" : "disconnected"

        if(status != this._connectionLastStatus){
            return this.setConnectionStatus({
                        "status": status
                    })
                    .then(function(data){
                        this._connectionLastStatus = status
                    }.bindenv(this))
        }

        return Promise.resolve(status)
    }

    function _getAuthHeaders(){
        local headers = {}
        if(this._applicationKeyToken)
            headers["Authorization"] <- format("Bearer %s", this._applicationKeyToken)
        return headers
    }
}

// Setup table delegates so that all of the scoping flowdowns ("this") is appropriate for how we are scaffolding the class
REST.Losant.device.setdelegate(REST.Losant)

// =============================================================================
// ----------------------------------------------------- END_REST_LOSANT_DEVICES
// ============================================================================}

