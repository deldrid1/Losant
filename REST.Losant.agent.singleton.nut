@include once "./REST.agent.singleton.nut"

// =============================================================================
// REST_LOSANT -----------------------------------------------------------------
// ============================================================================{
const REST_LOSANT_BASEURL = "https://api.losant.com"


REST.Losant <- {

    _baseURL              = null,   // Base URL we will communicate with - defaults to `${REST_LOSANT_BASEURL}/`
    _basePath             = null,   // Base path we will communicate with -`applications/${idApplication}/`
    _idApplication        = null,   // Losant Application ID
    _headers              = null,   // Base HTTP Headers for use in the client

    /**
    * Initializes the LosantREST class for use.  This method should be called before any other methods are used
    *
    * @method init
    *
    * @param  {string}  idApplication  The Losant Application ID that the REST API instance will interact with
    * @param  {string}  apiToken       The Losant API Bearer Token that the REST API will use for Authentication
    * @param  {string}  (baseURL)      Optional URL endpoint to interact with.  Defaults to REST_LOSANT_BASEURL
    *
    * @return {object} The LosantREST object
    */
    init = function(idApplication, apiToken, baseURL = REST_LOSANT_BASEURL){
        this._idApplication = idApplication
        this._baseURL = urlNormalize(baseURL)
        this._basePath = pathNormalize("applications/" + idApplication + "/")

        this._headers = {
            "Content-Type":   "application/json"
            "Accept":        "application/json"
            "Authorization": format("Bearer %s", apiToken)
        }

        return this
    }

    /**
    * Creates a validated HTTP request and sends it async, with the response provided back to the calling code as a Promise
    *
    * @method createRequestPromise
    *
    * @param  {string}   method      The HTTP method to execute ["PUT", "POST", "DELETE", "GET", etc...]
    * @param  {string}   path        The path to append to the _baseURL to send the payload to
    * @param  {string}   headers     Any HTTP header overrides.  This will be "tblAssign"ed into this._headers to create the full set
    * @param  {object}   body        The HTTP body.  This will be encoded with the bodyEncoder before sending the data.
    * @param  {function} bodyEncoder A function which accepts one argument **data** and returns the encoded data as a string.  Defaults to `http.jsonencode`.
    * @param  {function} bodyDecoder A function which accepts one argument **data** and returns the decoded data as a string.  Defaults to `http.jsondecode`.
    *
    * @return {Promise} The promise object
                - .then(parsedResponse) {object} Parsed Response data or full http response table
                - .fail(error) {string}
    */
    send = function(method, path, body = "", headers = {}, returnFullResponse = false, bodyEncoder = http.jsonencode.bindenv(http), bodyDecoder = http.jsondecode.bindenv(http)){
        return this.createRequestPromise(method, this._baseURL + this._basePath + this.pathNormalize(path), this.tblAssign(clone(this._headers), headers), body, returnFullResponse, bodyEncoder, bodyDecoder)
                    .fail(function(err){

                        // Check if error is an HTTP Response object
                        if(typeof err == "table" && "body" in err){
                            // if (resp.statuscode == 307 && "location" in resp.headers) {  // Deal with redirects
                            //     local location = resp.headers["location"];
                            //     local splitURL = split(this._baseURL, ".")
                            //     local p = location.find(splitURL[splitURL.len()-2] + "." + splitURL[splitURL.len()-1]);
                            //     p = location.find("/", p);
                            //     endpoint = location.slice(0, p);
                            //     return;
                            // } else if (res.statuscode == 28 ||r es.statuscode == 429 ) { Too Many Requests / Rate Limited - implement exponential backoff and retry as required
                            //     throw err;
                            // } else if (res.statuscode == 400) { // Bad Request
                            //     throw err;
                            // } else if (res.statuscode == 401) { // Unauthorized
                            //     throw err;
                            // } else if (res.statuscode == 404) { // Not found
                            //     throw err;
                            // } else if (res.statuscode == 413) { // Payload Too Large
                            //     throw err;
                            // } else if (res.statuscode == 503) { // Bad Request
                            //     throw err;
                            // }
                        }

                        // If we haven't handled it yet, we need to throw so that the next fail can deal with it...
                        throw err;

                    }.bindenv(this))
    }

    /**
    * Validates that a table of key/value pairs only contains valid keys.  `params` is both modified in place and returned to only contain the `validParams`
    *
    * @method validateAndSanitizeParams
    *
    * @param  {table} params        Flat table of key/value parameters
    * @param  {array} validParams   Array of strings (that will be parsed as regexp2's) of valid Parameters that should remain in the params table
    *
    * @return {table} the in place modified/sanitized version of params
    **/
    function validateAndSanitizeParams(params, validParams){
        local invalidParams = []
        foreach(param, value in params){
            local found = false
            foreach(idx, validParam in validParams){
                local regex = regexp2(validParam)

                // if(param.len() >= validParam.len() && param.slice(0, validParam.len()) == validParam){   // "Begins with support only"
                if(regex.match(param)){
                    found = true;
                    continue;  // break out of the inner for loop
                }
            }

            if(found == false){
                // server.error("Removing Invalid parameter " + param + " found in validateAndSanitizeParams.  Valid Parameters = " + http.jsonencode(validParams))
                invalidParams.push(param)
            }
        }

        foreach(idx, param in invalidParams){
            delete params[param]
        }

        return params
    }

    /**
    * Formats tag array into Losant Query parameter format
    *
    * @method createIsoTimeStamp
    *
    * @param  {ts} integer Optional epoch time in seconds as returned by time()
    *
    * @return {string} time formatted as "2015-12-03T00:54:51.000Z"
    **/
    function createIsoTimeStamp(ts = null) {
        local d = ts ? date(ts) : date();
        return format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", d.year, d.month+1, d.day, d.hour, d.min, d.sec, d.usec / 1000);
    }

    /**
    * Formats tag array into Losant Query parameter format
    *
    * @method createTagOptionalParams
    *
    * @param  {array}   tags      array of tables - this should be formatted the same as tags are formatted, however not all key(s) or value(s) are required
    *                             // [{"key" : "agentId", "value" : agentId}, {"key" : "impDevId", "value" :  impDeviceId}]
    * @param  {string}  fType     Filter Type - a type value as required by the Losant API

    *
    * @return {table} the query parameters in a table that can be passed to http.urlencode to get Losant's format (the uglified version of the string below with lots of %5B, etc.):
    *                  // { "tagFilter[0][key]": "agentId", "tagFilter[1][value]": "3000", "tagFilter[1][key]": "impDevId", "tagFilter[0][value]": "12346543" } //JSON Encoded
    *                  // tagFilter%5B0%5D%5Bkey%5D=agentId&tagFilter%5B1%5D%5Bvalue%5D=3000&tagFilter%5B1%5D%5Bkey%5D=impDevId&tagFilter%5B0%5D%5Bvalue%5D=12346543 //URL encoded
    **/
    function createTagOptionalParams(tags, fType = "tagFilter") {
        local params = {};
        foreach(idx, tag in tags) {
            local prefix = format("%s[%i]", fType, idx);
            if ("key" in tag) {
                params[format("%s[key]", prefix)] <- format("%s", tag.key.tostring());
            }
            if ("value" in tag) {
                params[format("%s[value]", prefix)] <- format("%s", tag.value.tostring());
            }
        }
        return params
    }

    function createPayload(data, ts = null){
        return {
            "time": createIsoTimeStamp(ts)
            "data": data
        }
    }

    // Takes all the keys in source, and puts them into target (overwritting target as needed)
    function tblAssign(target, source){
        foreach(k,v in source){
            target[k] = v
        }
        return target
    }
}

// Setup table delegates so that all of the scoping flowdowns ("this") is appropriate for how we are scaffolding the class
REST.Losant.setdelegate(REST)

// Now include all of our implementation!
@include once "./lib/applicationKeys.agent.singleton.nut"
@include once "./lib/auth.agent.singleton.nut"
@include once "./lib/device.agent.singleton.nut"
@include once "./lib/devices.agent.singleton.nut"
@include once "./lib/events.agent.singleton.nut"

// =============================================================================
// ------------------------------------------------------------- END_REST_LOSANT
// ============================================================================}

