@include once "./../../REST.Losant.agent.singleton.nut"
@include once "./REST.Losant.LiveTestConfigVariables.agent.nut"

REST._debug = true;

REST.Losant.init(LOSANT_APPLICATION_ID, LOSANT_API_TOKEN)
REST.Losant.device.id = LOSANT_TEST_DEVICE_ID

// This is connected to a LIVE Losant backend - please use with caution!
// The best thing to do is to do is to focus your test case to one method at a time using the -t flag:
// impt test run -t "tests/LiveTests/*::testDeviceGet"
class LosantDeviceTest extends ImpTestCase {

    function testDeviceGet(){
        return REST.Losant.device.get()
    }

    // function testDeviceUpdate(){
    //     REST.Losant.device.id = LOSANT_TEST_DEVICE_ID
    //     return REST.Losant.device.update({"name": imp.configparams.deviceid})
    // }

    // function testDeviceDelete(){
    //     return REST.Losant.device.destroy()
    // }

    function testDeviceCreate(){
        return REST.Losant.devices.create()
    }

    function repeatSendCommand(counter=0, maxCount=5, delay=0.5){
        imp.wakeup(delay, function(){
            server.log("Sending Device Command")
            REST.Losant.device.sendCommand({
                "name": "fulfill"
                "payload": {
                    "my": "fun"
                    "data": true
                    "counter": counter++
                }
            })

            if(counter <= maxCount) repeatSendCommand(counter, maxCount, delay);
        }.bindenv(this))
    }

    function testCommandStream(){
        return Promise(function(fulfill, reject){
            local function _commandHandler(cmd) {
                // Keys: "name", "time", "payload"
                // server.log(http.jsonencode(cmd));
                switch(cmd.name) {
                    case "fulfill":
                        if(cmd.payload.counter >= 5){
                            REST.Losant.device.closeCommandStream();
                            return fulfill(cmd);
                        }
                        server.log("Received command: " + cmd.name);
                        server.log(http.jsonencode(cmd.payload));
                        break;
                    case "reject":
                        REST.Losant.device.closeCommandStream();
                        return reject(cmd);
                    default:
                        server.log("Received command: " + cmd.name);
                        server.log(cmd.payload);
                }
            }

            local function _onStreamError(err, res) {
                server.error("Error occured while listening for commands.");
                server.error(err);
            }

            server.log("Opening streaming listener...");
            REST.Losant.device.openCommandStream(_commandHandler.bindenv(this), _onStreamError.bindenv(this));

            // Make sure all of our SSE reconnection logic is working by sending multiple commands
            repeatSendCommand()

        }.bindenv(this))
    }

    function repeatSendState(counter=0, maxCount=5, delay=1.0){
        server.log(counter + " / " + maxCount + ", delay=" + delay)
        imp.wakeup(delay, function(){
            REST.Losant.device.sendState({
                "deviceState": REST.Losant.createPayload({
                    "counter": counter++
                })
            })

            if(counter <= maxCount){
                repeatSendState(counter, maxCount, delay);
            }
        }.bindenv(this))
    }

    function testStateStream(){
        // Variable to store our current config in
        local info
        local p = Promise(function(fulfill, reject){
            local function _stateHandler(state) {
                // Keys: time", "data", "meta"?
                // server.log(http.jsonencode(state));
                if(state.data.counter >= 5){
                    REST.Losant.device.closeStateStream();
                    return fulfill(state);
                }
                server.log("Received state: ");
                server.log(http.jsonencode(state));
            }

            local function _onStreamError(err, res) {
                server.error("Error occured while listening for states.");
                server.error(err);
            }

            return REST.Losant.device.get({"excludeConnectionInfo": true})
                .then(function(deviceInfo){
                    PrettyPrinter.print(deviceInfo)
                    info = deviceInfo

                    // Update the device config to make sure our test will run and the data will be plubmed through
                    return REST.Losant.device.update({
                        "attributes": [
                            {
                                "name": "counter"
                                "dataType" : "number"
                            }
                        ]
                    })
                }.bindenv(this))
                .then(function(dummy){

                    server.log("Opening streaming listener...");
                    // Turns out the order for this is important - if we connect to our stream before we have our config updated, we won't get any data
                    REST.Losant.device.openStateStream(_stateHandler.bindenv(this), _onStreamError.bindenv(this));


                    this.repeatSendState()
                }.bindenv(this))

            // Make sure all of our SSE reconnection logic is working by sending multiple commands

        }.bindenv(this))

        return p.then(function(data){
            // Reset the device config to clean up after ourselves
            return REST.Losant.device.update(info)
                    .then(function(dummy){
                        return data
                    })
        })
        .fail(function(err){
            throw err
        })
    }
}
