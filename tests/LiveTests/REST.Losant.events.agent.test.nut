@include once __ROOT__ + "/REST.Losant.agent.singleton.nut"
@include once __ROOT__ + "/tests/LiveTests/REST.Losant.LiveTestConfigVariables.agent.nut"


REST.Losant.init(LOSANT_APPLICATION_ID, LOSANT_API_TOKEN)
REST._debug = true;

class LosantEventsTest extends ImpTestCase {

    function testEventCreate(){
        return REST.Losant.events.create({
            "subject": "Test Event",
            "message": "test Message for the event is here",
            "level": "critical",
            "data": {
                "some": "event Data",
                "in": "Here",
                "with a number": 4
            }
        })
    }
}
