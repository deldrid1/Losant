@include once "/REST.Losant.agent.singleton.nut"
@include once "/tests/LiveTests/REST.Losant.LiveTestConfigVariables.agent.nut"

REST.Losant.init(LOSANT_APPLICATION_ID, LOSANT_API_TOKEN)
REST._debug = true;

class LosantDevicesTest extends ImpTestCase {

    function testGetDevices200(){
        local params = {
            perPage = 1
        }

        return REST.Losant.devices.get(params)
    }

    function testGetDevicesUnauthorized(){
        REST.Losant.init(LOSANT_APPLICATION_ID, "GARBAGE_TOKEN")

        local p = REST.Losant.devices.get()
                    .then(function(data){
                        throw "How did I get here???"
                    })
                    .fail(function(err){
                        if(err.statuscode == 401 && err.body["type"] == "Unauthorized"){    //&& err.body.message == "Invalid access token"
                            return err //Success - we got expected behavior!
                        }

                        throw err
                    }.bindenv(this))

        // Clean up after ourselves
        REST.Losant.init(LOSANT_APPLICATION_ID, LOSANT_APPLICATION_ID)

        // Return the promise for the test case
        return p
    }

    // function testDevicesCreate(){
    //     return REST.Losant.devices.create()
    // }
}
