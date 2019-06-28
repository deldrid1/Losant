@include once __ROOT__ + "/REST.Losant.agent.singleton.nut"

// =============================================================================
// REST_LOSANT_DEVICES ---------------------------------------------------------
// ============================================================================{

REST.Losant.events <- {
    _path = "/events",

    /**
    * Create a new event for an application
    *
    * Authentication:
    * The client must be configured with a valid api
    * access token to call this action. The token
    * must include at least one of the following scopes:
    * all.Application, all.Organization, all.User, events.*, or events.post.
    *
    * Parameters:
    *  {string} applicationId - ID associated with the application
    *  event - New event information (https://api.losant.com/#/definitions/eventPost)
    *       - {string} level      - one of ["info", "warning", "error", "critical"]
    *       - {string} state      - one of ["new","acknowledged","resolved"]
    *       - {string} subject    - name of the event
    *       - {string} message    - description of the event
    *       - {object} data       -
    *       - {string} deviceId   - Losant Device ID of the event
    *       - {array}  eventTags  -
    *  {string} losantdomain - Domain scope of request (rarely needed)
    *  {boolean} _actions - Return resource actions in response
    *  {boolean} _links - Return resource link in response
    *  {boolean} _embedded - Return embedded resources in response
    *
    * Responses:
    *  201 - Successfully created event (https://api.losant.com/#/definitions/event)
    *
    * Errors:
    *  400 - Error if malformed request (https://api.losant.com/#/definitions/error)
    *  404 - Error if application was not found (https://api.losant.com/#/definitions/error)
    *  429 - Error if event creation rate limit exceeded (https://api.losant.com/#/definitions/error)
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
            "level" : "level" in params ? params.level : "info",
            "state" : "state" in params ? params.state : "new"
            "subject" : params.subject
        }

        if(deviceID)    // Pass in null, if you don't want a default device ID set
            body.deviceId = deviceID

        body.message     <- "message"   in params ? params.message   : null
        body.data        <- "data"      in params ? params.data      : null
        body.eventTags   <- "eventTags" in params ? params.eventTags : null

        if(body.message == null)    delete body.message;
        if(body.data == null)       delete body.data;
        if(body.eventTags == null)  delete body.eventTags;

        // Override any missing default values
        params._actions         <- "_actions"      in params ?  params._actions         : false
        params._links           <- "_links"        in params ?  params._links           : false
        params._embedded        <- "_embedded"     in params ?  params._embedded        : false

        params = validateAndSanitizeParams(params, validParams);

        return this.send("POST", format(this._path + "?%s", http.urlencode(params)), body)
    }
}

// Setup table delegates so that all of the scoping flowdowns ("this") is appropriate for how we are scaffolding the class
REST.Losant.events.setdelegate(REST.Losant)

// =============================================================================
// ----------------------------------------------------- END_REST_LOSANT_DEVICES
// ============================================================================}

