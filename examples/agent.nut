@include once "./REST.Losant.agent.singleton.nut"

// =============================================================================
// MAIN_APPLICATION_CODE -------------------------------------------------------
// ============================================================================{
server.log(format("Product \"%s\" (ID: %s)", __EI.PRODUCT_NAME, __EI.PRODUCT_ID));
server.log(format("Deployed to Device Group \"%s\" (ID: %s)", __EI.DEVICEGROUP_NAME, __EI.DEVICEGROUP_ID));
server.log(format("Code SHA %s created at %s (ID: %s)", __EI.DEPLOYMENT_SHA, __EI.DEPLOYMENT_CREATED_AT, __EI.DEPLOYMENT_ID));

// =============================================================================
// GLOBAL_VARIABLES ------------------------------------------------------------
// ============================================================================{
/**
 * Our Agent ID wherever it is needed throughout the code.
 */
g_idAgent <- split(http.agenturl(), "/")[2];

/**
 * Our unique device ID to be used throughout the code
 */
g_idDevice <- imp.configparams.deviceid;	//This is such a goofy way to get this, but at least we don't have to wait for the device to send it to us!

/**
 * Dump our shared, persisted agent storage in case we are using it (with the caveats mentioned at https://developer.electricimp.com/api/server/save/?q=api%2Fserver%2Fsave%2F, https://developer.electricimp.com/api/server/load, and https://developer.electricimp.com/resources/permanentstore/)
 */
server.log("server.load() current contents = ")
PrettyPrinter.print(server.load())
// =============================================================================
// -------------------------------------------------------- END_GLOBAL_VARIABLES
// ============================================================================}

// =============================================================================
// LOSANT_EXAMPLE --------------------------------------------------------------
// ============================================================================{

// Builder supplied configuration of our Losant app
const LOSANT_APPLICATION_ID = "@{LOSANT_APPLICATION_ID}";
const LOSANT_API_TOKEN      = "@{LOSANT_API_TOKEN}"

REST.Losant.init(LOSANT_APPLICATION_ID, LOSANT_API_TOKEN)
// REST._debug = true;

function losantCommandHandler(cmd) {
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

function losantCommandStreamError(err, res) {
    server.error("Error occured while listening for commands.");
    server.error(err);
}

REST.Losant.devices.get()
    .then(function(body){
        if(body.count == 0){
            // No devices found, create device
            server.log("Device not found - Creating");
            return REST.Losant.devices.create()
        } else if (body.count == 1){
            local losantDeviceID = body.items[0].deviceId;
            server.log("Device with matching tags found!  Device ID = " + losantDeviceID)
            return losantDeviceID;
        } else {
            // Log results of filtered query
            server.error("Found " + body.count + "devices matching our Agent ID = " + g_idAgent +".");

            // TODO: Delete duplicate devices - Need to come up with a way to determine which device is active (last one to push data?), so data isn't lost

            throw "Found more than 1 device with our Agent ID in Losant"
        }
    }.bindenv(this))
    //TODO: Trade out our API Token for a Device Access Key with limited permissions - this should really happen automatically under the hood...
    // .then(function(deviceID){
    //     // Retreive device scoped key from nonvol
    //     // If it does not exist, ...

    //     REST.Losant.applicationKeys.create()
    //         .then(function(body){
    //             // Store the secret and access key into nonvol
    //             REST.Losant.init(LOSANT_APPLICATION_ID, body.key)
    //         }.bindenv(this))
    // })
    .then(function(deviceID){
         // Make sure the attributes and tags in Losant match the current code.
        local attributes = [
            {
                "name": "accelerometer_settings_doubleTapEnabled",
                "dataType": "boolean"
            },
            {
                "name": "accelerometer_settings_singleTapEnabled",
                "dataType": "boolean"
            },
            {
                "name": "accelerometer_telemetry_numSamples",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_x_avg",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_x_max",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_x_min",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_x",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_y_avg",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_y_max",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_y_min",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_y",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_z_avg",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_z_max",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_z_min",
                "dataType": "number"
            },
            {
                "name": "accelerometer_telemetry_z",
                "dataType": "number"
            },
            {
                "name": "breaker_settings_remoteHandlePosition",
                "dataType": "boolean"
            },
            {
                "name": "breaker_settings_underVoltageReleaseEnabled",
                "dataType": "boolean"
            },
            {
                "name": "buzzer_settings_breakerOpenBehavior",
                "dataType": "string"
            },
            {
                "name": "buzzer_settings_wifiDisconnectedBehavior",
                "dataType": "string"
            },
            {
                "name": "buzzer_settings_wifiSignalHighBehavior",
                "dataType": "string"
            },
            {
                "name": "device_metadata_numWakeReasonColdBoot",
                "dataType": "number"
            },
            {
                "name": "device_metadata_numWakeReasonException",
                "dataType": "number"
            },
            {
                "name": "device_settings_blinkUpEnabled",
                "dataType": "boolean"
            },
            {
                "name": "device_telemetry_agentFreeMemory_avg",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_agentFreeMemory_max",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_agentFreeMemory_min",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_agentFreeMemory",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_deviceFreeMemory_avg",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_deviceFreeMemory_max",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_deviceFreeMemory_min",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_deviceFreeMemory",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_lightLevel_avg",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_lightLevel_max",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_lightLevel_min",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_lightLevel",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_numSamples",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_rssi_avg",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_rssi_max",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_rssi_min",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_rssi",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_supplyVoltage_avg",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_supplyVoltage_max",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_supplyVoltage_min",
                "dataType": "number"
            },
            {
                "name": "device_telemetry_supplyVoltage",
                "dataType": "number"
            },
            {
                "name": "meter_settings_sensor1Phase",
                "dataType": "string"
            },
            {
                "name": "meter_settings_sensor2Phase",
                "dataType": "string"
            },
            {
                "name": "meter_settings_waveformConfiguration_pAOvercurrentDuration",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pAOvercurrentEnabled",
                "dataType": "boolean"
            },
            {
                "name": "meter_settings_waveformConfiguration_pASagDuration",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pASagEnabled",
                "dataType": "boolean"
            },
            {
                "name": "meter_settings_waveformConfiguration_pASwellDuration",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pASwellEnabled",
                "dataType": "boolean"
            },
            {
                "name": "meter_settings_waveformConfiguration_pAmAOvercurrent",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pAmVSag",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pAmVSwell",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBOvercurrentDuration",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBOvercurrentEnabled",
                "dataType": "boolean"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBSagDuration",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBSagEnabled",
                "dataType": "boolean"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBSwellDuration",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBSwellEnabled",
                "dataType": "boolean"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBmAOvercurrent",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBmVSag",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_pBmVSwell",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_samplesAfterTrigger",
                "dataType": "number"
            },
            {
                "name": "meter_settings_waveformConfiguration_samplesAfterTriggerFastRMS",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentA_avg",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentA_max",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentA_min",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentB_avg",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentB_max",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentB_min",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_currentB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energy_delivered",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energy_deliveredWH",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energy_generated",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energy_generatedWH",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energyDelta_delivered",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energyDelta_deliveredWH",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energyDelta_deltaTime",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energyDelta_generated",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_energyDelta_generatedWH",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_frequency_avg",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_frequency_max",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_frequency_min",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_frequency",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_numSamples",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q1mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q1mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q1mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q1mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q2mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q2mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q2mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q2mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q3mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q3mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q3mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q3mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q4mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q4mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q4mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergy_q4mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_deltaTime",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q1mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q1mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q1mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q1mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q2mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q2mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q2mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q2mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q3mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q3mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q3mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q3mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q4mJpA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q4mJpB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q4mVARspA",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_rawEnergyDelta_q4mVARspB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAB_avg",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAB_max",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAB_min",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAB",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAN_avg",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAN_max",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAN_min",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageAN",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageBN_avg",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageBN_max",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageBN_min",
                "dataType": "number"
            },
            {
                "name": "meter_telemetry_voltageBN",
                "dataType": "number"
            },
            {
                "name": "streams_settings_active",
                "dataType": "boolean"
            },
            {
                "name": "thermometer_telemetry_numSamples",
                "dataType": "number"
            },
            {
                "name": "thermometer_telemetry_temperature_avg",
                "dataType": "number"
            },
            {
                "name": "thermometer_telemetry_temperature_max",
                "dataType": "number"
            },
            {
                "name": "thermometer_telemetry_temperature_min",
                "dataType": "number"
            },
            {
                "name": "thermometer_telemetry_temperature",
                "dataType": "number"
            }
        ]

        local tags = [
            {
                "key": "breaker_circuitNumber",
                "value": "number"
            },
            {
                "key": "breaker_interruptingCurrent",
                "value": "number"
            },
            {
                "key": "breaker_lineTerminalStyle",
                "value": "string"
            },
            {
                "key": "breaker_loadManufacturer",
                "value": "string"
            },
            {
                "key": "breaker_loadModelNumber",
                "value": "string"
            },
            {
                "key": "breaker_loadType",
                "value": "string"
            },
            {
                "key": "breaker_numPoles",
                "value": "number"
            },
            {
                "key": "breaker_ratedCurrent",
                "value": "number"
            },
            {
                "key": "breaker_ratedVoltage",
                "value": "number"
            },
            {
                "key": "breaker_totalPoles",
                "value": "number"
            },
            {
                "key": "device_idAgent",
                "value": "string"
            },
            {
                "key": "device_idDevice",
                "value": "string"
            },
            {
                "key": "device_bootRomVersion",
                "value": "string"
            },
            {
                "key": "device_classes",
                "value": "array"
            },
            {
                "key": "device_isConnected",
                "value": "boolean"
            },
            {
                "key": "device_moduleType",
                "value": "string"
            },
            {
                "key": "device_osVersion",
                "value": "string"
            },
            {
                "key": "device_spiFlashChipId",
                "value": "string"
            },
            {
                "key": "device_spiFlashSize",
                "value": "number"
            },
            {
                "key": "device_wifiTerritory",
                "value": "string"
            },
            {
                "key": "meter_firmwareVersion",
                "value": "string"
            }
        ]

        return REST.Losant.device.update({
            "attributes": attributes,
            "tags": REST.Losant.tblAssign(tags, REST.Losant.device.tags)
        });
    }.bindenv(this))
    .then(function(deviceID){
        server.log("Opening streaming listener...");
        return REST.Losant.device.openCommandStream(losantCommandHandler.bindenv(this), losantCommandStreamError.bindenv(this));
    }.bindenv(this))

// =============================================================================
// -------------------------------------------------------------- LOSANT_EXAMPLE
// ============================================================================}
local currentTime = date(time(), 'u');
server.log(format("Agent Booted and Squirrel Initialization Complete - %.4d-%.2d-%.2dT%.2d:%.2d:%.2d (%d). Memory Free=%d, OS Version=%s", currentTime.year, currentTime.month+1, currentTime.day,  currentTime.hour, currentTime.min, currentTime.sec, time(), imp.getmemoryfree(), imp.getsoftwareversion()))
server.log("+++++++++++++Agent URL = " + http.agenturl())
// =============================================================================
// --------------------------------------------------- END_MAIN_APPLICATION_CODE
// ============================================================================}
