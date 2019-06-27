@include once "./REST.Losant.agent.singleton.nut"

// =============================================================================
// REST_LOSANT_DEVICES ---------------------------------------------------------
// ============================================================================{

REST.Losant.auth <- {
    _path = "/auth",

    /**
    * Authenticates a device using the provided credentials.
    *
    * If the request is for the Losant device ID stored in REST.Losant.device.id, the function will store
    * the REST.Losant.device._applicationKeyToken and setup token refresh using REST.Losant.device._applicationKeyTokenRefreshTimer

    * Authentication:
    * No api access token is required to call this action.
    *
    * Parameters:
    *  credentials - Device authentication credentials (https://api.losant.com/#/definitions/deviceCredentials)
    *       - {string} deviceId         - Losant Device ID
    *       - {string} key              - Losant Application Key
    *       - {string} secret           - Losant Application Key Secret
    *       - {integer} tokenTTL        - Optional Requested Time to Live of the token
    *       - {array} requestedScopes   - Optional array containing 1-All of the following list: ["all.Device", "all.Device.read", "data.export", "data.timeSeriesQuery", "data.lastValueQuery", "device.commandStream", "device.get", "device.getCompositeState", "device.getState", "device.stateStream", "device.getLogEntries", "device.getCommand", "device.debug", "device.sendState", "device.sendCommand", "device.setConnectionStatus", "devices.get", "devices.sendCommand"]
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  200 - Successful authentication. The included api access token by default has the scope 'all.Device'. (https://api.losant.com/#/definitions/authedDevice)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  401 - Unauthorized error if authentication fails (https://api.losant.com/#/definitions/error)
    */
    device = function(params = {}){
        local headers = {
            "Content-Type":   "application/json",
            "Accept":        "application/json"
        }

        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        local deviceID = "deviceId"           in params ? params.deviceId : REST.Losant.device.id

        // Setup the device body parameter, overwriting anything that is there
        local body = {
            "deviceId"          : deviceID,
            "key"               : "key"                 in params ? params.key              : REST.Losant.device.applicationKey,
            "secret"            : "secret"              in params ? params.secret           : REST.Losant.device.applicationKeySecret,
            "tokenTTL"          : "tokenTTL"            in params ? params.tokenTTL         : 3600,
            "requestedScopes"   : "requestedScopes"     in params ? params.requestedScopes  : null,
        }

        if(body.tokenTTL == null)        delete body.tokenTTL
        if(body.requestedScopes == null) delete body.requestedScopes

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        local sendParams = validateAndSanitizeParams(clone(params), validParams);

        return this.createRequestPromise("POST", format("%s%s?%s", this._baseURL, this.pathNormalize(this._path + "/device"), http.urlencode(sendParams)), headers, body)
                    .then(function(resBody){
                        if(deviceID == REST.Losant.device.id){
                            // server.log("Retrieved REST.Losant.device._applicationKeyToken = " + resBody.token)
                            REST.Losant.device._applicationKeyToken = resBody.token;

                            // Make sure that if we have auth'd multiple times, that we are only setting timers to reauth for our latest token
                            if(REST.Losant.device._applicationKeyTokenRefreshTimer != null){
                                imp.cancelwakeup(REST.Losant.device._applicationKeyTokenRefreshTimer)
                                REST.Losant.device._applicationKeyTokenRefreshTimer = null;
                            }

                            // If our token has an expiration time, lets make sure we reset it!
                            if("tokenTTL" in body){
                                // server.log("Setting timer for " + (body.tokenTTL-5) + " Seconds")
                                REST.Losant.device._applicationKeyTokenRefreshTimer = imp.wakeup(body.tokenTTL-5, function(){
                                    // server.log("Attempting to refresh REST.Losant.device._applicationKeyToken")
                                    this.device(params)
                                }.bindenv(this))
                            }
                        }

                        return body
                    }.bindenv(this))
                    .fail(function(err){
                        server.error("UNABLE TO GET REST.Losant.auth.device token!!!")
                        server.error(err)
                        throw err
                    })
    }
}

// Setup table delegates so that all of the scoping flowdowns ("this") is appropriate for how we are scaffolding the class
REST.Losant.auth.setdelegate(REST.Losant)

// =============================================================================
// ----------------------------------------------------- END_REST_LOSANT_DEVICES
// ============================================================================}

