@include once __ROOT__ + "/REST.Losant.agent.singleton.nut"
// =============================================================================
// REST_LOSANT_DEVICES ---------------------------------------------------------
// ============================================================================{

REST.Losant.applicationKeys <- {
    _path = "/keys",

    /**
    * Create a new applicationKey for an application
    *
    * If the application Key is for the Losant device ID stored in REST.Losant.device.id, the function will store
    * the returned key/secret in REST.Losant.device.applicationKey and REST.Losant.device.applicationKeySecret
    * and automatically kick off a REST.Losant.auth.device() (which will store the REST.Losant.device._applicationKeyToken and setup token refresh)
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Organization, all.User, applicationKeys.*, or applicationKeys.post.
    *
    * Parameters:
    *  applicationKey - ApplicationKey information (https://api.losant.com/#/definitions/applicationKeyPost)
    *       - {string} description - Optional description of the key
    *       - {array} deviceIds   - Optional Array of Losant Device IDs
    *       - {array} deviceTags  - Optional Array of Losant Device Tags
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  201 - Successfully created applicationKey (https://api.losant.com/#/definitions/applicationKeyPostResponse)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if application was not found (https://api.losant.com/#/definitions/error)
    */
    create = function(params = {}){
        local validParams = [
            "_actions",
            "_links",
            "_embedded"
        ]

        local deviceID = "deviceId"           in params ? params.deviceId : REST.Losant.device.id

        // Setup the device body parameter, overwriting anything that is there
        local body = {
            "deviceIds"   : "deviceIds"   in params ? params.deviceIds   : [deviceID]
            "description" : "description" in params ? params.description : "Electric Imp Agent generated Key",
            "deviceTags"  : "deviceTags"  in params ? params.deviceTags  : null
        }

        if(body.deviceIds == null || body.deviceIds.len() == 1 && deviceID == null) delete body.deviceIds   // Allow applicationKeys to be scoped for all devices

        if(body.description == null) delete body.description
        if(body.deviceTags == null)  delete body.deviceTags

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "?%s", http.urlencode(params)), body)
                    .then(function(body){
                        if(("deviceIds" in body && body.deviceIds.find(REST.Losant.device.id) != null) ||  !("deviceIds" in body)){
                            // This key / secret pair should be used by the device class for all future requests - lets store it!
                            REST.Losant.device.applicationKeyId     = body.applicationKeyId
                            REST.Losant.device.applicationKey       = body.key
                            REST.Losant.device.applicationKeySecret = body.secret

                            // Kick off a device Auth to fetch our token
                            return REST.Losant.auth.device()
                                        .then(function(data){
                                            return body;    // Return the original request body
                                        }.bindenv(this))
                        }

                        return body;
                    }.bindenv(this))
    }
}

// Setup table delegates so that all of the scoping flowdowns ("this") is appropriate for how we are scaffolding the class
REST.Losant.applicationKeys.setdelegate(REST.Losant)

// =============================================================================
// ----------------------------------------------------- END_REST_LOSANT_DEVICES
// ============================================================================}

