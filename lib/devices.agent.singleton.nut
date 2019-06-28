@include once "/REST.Losant.agent.singleton.nut"

// =============================================================================
// REST_LOSANT_DEVICES ---------------------------------------------------------
// ============================================================================{

REST.Losant.devices <- {
    _path = "/devices",

    /**
    * Create a new device for an application.  Upon success it also sets REST.Losant.device.id to the returned Losant Device ID
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Organization, all.User, devices.*, or devices.post.
    *
    * Parameters:
    *  {string} applicationId - ID associated with the application
    *  device - New device information (https://api.losant.com/#/definitions/devicePost)
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
    *  201 - Successfully created device (https://api.losant.com/#/definitions/device)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if application was not found (https://api.losant.com/#/definitions/error)
    *
    * returns a promise with the losant device ID as its value
    */
    create = function(params = {}){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        // Setup the device body parameter, overwriting anything that is there
        local body = {}
        body.name               <- "name"           in params ? params.name             : split(http.agenturl(), "/").top()
        body.description        <- "description"    in params ? params.description      : "Electric Imp Device"
        body.deviceClass        <- "deviceClass"    in params ? params.deviceClass      : "standalone"
        body.attributes         <- "attributes"     in params ? params.attributes       : []
        body.tags               <- "tags"           in params ? params.tags             : [
                                                                                            {
                                                                                                "key"   : "idAgent",
                                                                                                "value" : split(http.agenturl(), "/").top()
                                                                                            },
                                                                                            {
                                                                                                "key"   : "idDevice",
                                                                                                "value" : imp.configparams.deviceid
                                                                                            },
                                                                                        ];

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "?%s", http.urlencode(params)), body)
                    .then(function(body){
                        // set the device ID, tags, and attributes that are returned in our device class for future use so that outside code doesn't have to remember to do this!
                        REST.Losant.device.id = body.deviceId;
                        REST.Losant.device.tags = body.tags;
                        REST.Losant.device.attributes = body.attributes;

                        REST.Losant.device.startConnectionStatusWatchdog();

                        return body.deviceId
                    }.bindenv(this))
    }

    /**
    * Returns the devices for an application.  If no tagFilters are specified, the current agent ID is used as the default.
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Application.read, all.Device, all.Device.read, all.Organization, all.Organization.read, all.User, all.User.read, devices.*, or devices.get.
    *
    * Parameters:
    *  {string} sortField - Field to sort the results by. Accepted values are: name, id, creationDate, lastUpdated
    *  {string} sortDirection - Direction to sort the results by. Accepted values are: asc, desc
    *  {string} page - Which page of results to return
    *  {string} perPage - How many items to return per page
    *  {string} filterField - Field to filter the results by. Blank or not provided means no filtering. Accepted values are: name
    *  {string} filter - Filter to apply against the filtered field. Supports globbing. Blank or not provided means no filtering.
    *  {string} deviceClass - Filter the devices by the given device class. Accepted values are: standalone, gateway, peripheral, floating, edgeCompute
    *  {table}  tagFilter(.*) - Tag Optional pairs to filter by. REST.Losant.createTagOptionalParams is your friend :) (https://api.losant.com/#/definitions/deviceTagFilter)
    *  {string} excludeConnectionInfo - If set, do not return connection info
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Collection of devices (https://api.losant.com/#/definitions/devices)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if application was not found (https://api.losant.com/#/definitions/error)
    */
    get = function(params = {}){
        local validParams = [
            "sortField",
            "sortDirection",
            "page",
            "perPage",
            "filterField",
            "filter",
            "deviceClass",
            "tagFilter(.*)",    // Keys just need to begin with "tagFilter" - we could make this more intelligent to only look for [%d][key/value] if we want better checking
            "excludeConnectionInfo",
            "_actions",
            "_links",
            "_embedded"
        ]

        // Override any missing default values
        params["tagFilter[0][key]"]     <- "tagFilter[0][key]"      in params ?  params["tagFilter[0][key]"]   : "idAgent"
        params["tagFilter[0][value]"]   <- "tagFilter[0][value]"    in params ?  params["tagFilter[0][value]"]   : split(http.agenturl(), "/").top()

        params._actions     <- "_actions"      in params ?  params._actions    : false
        params._links       <- "_links"        in params ?  params._links      : false
        params._embedded    <- "_embedded"     in params ?  params._embedded   : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("GET", format(this._path + "?%s", http.urlencode(params)))
                    .then(function(body){
                        foreach(k,v in body.items){
                            // set the tags, and attributes that are returned in our device class for future use so that outside code doesn't have to remember to do this!
                            if(v.deviceId == REST.Losant.device.id){
                                REST.Losant.device.tags = v.tags;
                                REST.Losant.device.attributes = v.attributes;
                            } else if(body.items.len() == 1 && REST.Losant.device.id == null) {
                                REST.Losant.device.id = v.deviceId
                                REST.Losant.device.tags = v.tags;
                                REST.Losant.device.attributes = v.attributes;

                                REST.Losant.device.startConnectionStatusWatchdog();
                            }
                        }
                        return body
                    }.bindenv(this))
    }

    /**
    * Send a command to multiple devices
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Device, all.Organization, all.User, devices.*, or devices.sendCommand.
    *
    * Parameters:
    *  multiDeviceCommand - Command to send to the device (https://api.losant.com/#/definitions/multiDeviceCommand)
    *       - {string} time
    *       - {string} name
    *       - {object} payload
    *       - {array} deviceTags
    *       - {array} deviceIds
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - If command was successfully sent (https://api.losant.com/#/definitions/success)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if application was not found (https://api.losant.com/#/definitions/error)
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
        body.deviceTags         <- "deviceTags"     in params ? params.deviceTags       : []
        body.deviceIds          <- "deviceIds"      in params ? params.deviceIds        : []

        if(body.deviceTags.len() == 0) delete body.deviceTags
        if(body.deviceIds.len() == 0) delete body.deviceIds

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "/command?%s", deviceID, http.urlencode(params)), body, {}, false, bodyEncoder, bodyDecoder)
    }
}

// Setup table delegates so that all of the scoping flowdowns ("this") is appropriate for how we are scaffolding the class
REST.Losant.devices.setdelegate(REST.Losant)

// =============================================================================
// ----------------------------------------------------- END_REST_LOSANT_DEVICES
// ============================================================================}

