@include once "github:electricimp/Promise/Promise.lib.nut@v4.0.0"
@include once "github:deldrid1/PrettyPrinter/PrettyPrinter.singleton.nut@v1.0.2"    // Enables pretty logging debugging

// =============================================================================
// REST ------------------------------------------------------------------------
// ============================================================================{


REST <- {
    // Debugging
    _debug                = false,  // Debug flag, when true, class will log errors

    /**
    * Normalize the trailing "/" for a URL by ensureing that it is always included
    *
    * @method urlNormalize
    *
    * @param  {string}  url  The URL to normalize
    *
    * @return {string} The normalized URL
    */
    urlNormalize = function(url){
        return url[url.len()-1] == '/' ? url : url + "/"
    }

    /**
    * Normalize the starting "/" for a URL by ensuring that it is never included and that the trailing "/" is included if ensureTrailingSlashIncluded == true
    *
    * @method pathNormalize
    *
    * @param  {string}  path  The path to normalize
    * @param  {boolean} ensureTrailingSlashIncluded  Should the trailing "/" condition be checked and enforced
    *
    * @return {string} The normalized path
    */
    pathNormalize = function(path, ensureTrailingSlashIncluded = false){
        if(ensureTrailingSlashIncluded == true)
            path = urlNormalize(path)

        return path[0] == '/' ? path.slice(1) : path
    }

    /**
    * Creates a validated HTTP request and sends it async, with the response provided back to the calling code as a Promise
    *
    * @method createRequestPromise
    *
    * @param  {string}   method      The HTTP method to execute ["PUT", "POST", "DELETE", "GET", etc...]
    * @param  {string}   url         The url to send to the payload to
    * @param  {string}   headers     The HTTP headers
    * @param  {object}   body        The HTTP body.  This will be encoded with the bodyEncoder before sending the data.
    * @param  {function} bodyEncoder A function which accepts one argument **data** and returns the encoded data as a string.  Defaults to `http.jsonencode`.
    * @param  {function} bodyDecoder A function which accepts one argument **data** and returns the decoded data as a string.  Defaults to `http.jsondecode`.
    *
    * @return {Promise} The promise object
                - .then(parsedResponse) {object} Parsed Response data or full http response table
                - .fail(error) {string}
    */
    createRequestPromise = function(method, url, headers, body = "", returnFullResponse = false, bodyEncoder = http.jsonencode.bindenv(http), bodyDecoder = http.jsondecode.bindenv(http)) {
        return Promise(function (resolve, reject) {
            if(_debug){
                server.log("REST_SENDING >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
                PrettyPrinter.print({
                    "method": method,
                    "url": url,
                    "headers": headers,
                    "body": body
                })
            }

            local request = http.request(method, url, headers, bodyEncoder(body))
            request.setvalidation(VALIDATE_USING_SYSTEM_CA_CERTS);
            request.sendasync(this._createResponseHandler(resolve, reject, bodyDecoder, returnFullResponse).bindenv(this));
        }.bindenv(this));
    }

    /**
    * Private callback function to be executed upon completion of request.sendasync and resolve our `createRequestPromise`
    *
    * @method _createRequestPromise
    *
    * @param  {function} onSuccess             Call to resolve the promise. It has one parameter of its own: value, which receives the http response data
    * @param  {function} onError               Call to reject the promise. It has one parameter of its own: value, which receives the error
    * @param  {function} bodyDecoder           A function which accepts one argument **data** and returns the decoded data as a string.  Defaults to `http.jsondecode`.
    * @param  {boolean}  returnFullResponse    A flag to indicate if the upstream code wants the full response table, or only the decoded data.
    *
    * @return {null}
    */
    _createResponseHandler = function(onSuccess, onError, bodyDecoder, returnFullResponse) {
        return function (res) {
            try {
                if(_debug){
                    server.log("REST_RECEIVED <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<")
                    local resWithoutHeaders = clone(res)
                    delete resWithoutHeaders.headers
                    delete resWithoutHeaders.rawheaders
                    PrettyPrinter.print(resWithoutHeaders)
                }

                if (res.body && res.body.len() > 0) {
                    try {
                        res.body = bodyDecoder(res.body);
                    } catch(ex) {
                        // Unable to decode using our provided bodyDecoder - for now we don't consider this an error and let the upstream code deal with it
                    }
                }

                if (res.statuscode >= 200 && res.statuscode < 300) {
                    return onSuccess(returnFullResponse ? res : res.body);
                } else {
                    return onError(res); //onError, always return raw
                }
            } catch (err) {
                return onError(err);
            }
        }
    }


}
// =============================================================================
// -------------------------------------------------------------- END_Losant_REST
// ============================================================================}

