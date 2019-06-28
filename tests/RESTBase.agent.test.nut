@include once "/REST.Losant.agent.singleton.nut"
@include once "/tests/LiveTests/REST.Losant.LiveTestConfigVariables.agent.nut"

class RESTtest extends ImpTestCase {

    function testURLNormalize(){
        local url = "https://www.google.com"

        this.assertEqual(REST.urlNormalize(url),       url + "/", "Ensure it adds a trailing slash when one isn't present")
        this.assertEqual(REST.urlNormalize(url + "/"), url + "/", "Ensure it leaves the trailing slash alone one is present")
    }

    function testPathNormalize(){
        local path = "someURLPath/to/a/place"

        this.assertEqual(REST.pathNormalize(path),       path, "Ensure it leaves the leading slash alone when one isn't present")
        this.assertEqual(REST.pathNormalize("/" + path), path, "Ensure it removes the leading slash when one is present")
    }
}
