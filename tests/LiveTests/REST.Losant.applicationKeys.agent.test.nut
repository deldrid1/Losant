@include once "./../../REST.Losant.agent.singleton.nut"
@include once "./REST.Losant.LiveTestConfigVariables.agent.nut"

REST.Losant.init(LOSANT_APPLICATION_ID, LOSANT_API_TOKEN)
REST.Losant.device.id = LOSANT_TEST_DEVICE_ID
// REST._debug = true;

class LosantApplicationKeysTest extends ImpTestCase {

    function testApplicationKeyCreate(){
        return REST.Losant.applicationKeys.create()
    }

}
