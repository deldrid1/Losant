// Builder supplied configuration of our Losant app
// Make sure these variables are set in `.impt.project.builder` or your environment variables if you want the tests to pass!

const LOSANT_APPLICATION_ID = "@{LOSANT_APPLICATION_ID}";
const LOSANT_API_TOKEN      = "@{LOSANT_API_TOKEN}";
const LOSANT_TEST_DEVICE_ID = "@{LOSANT_DEVICE_ID}";

if(LOSANT_APPLICATION_ID == "")
    throw "LOSANT_APPLICATION_ID Builder variable must be set!"

if(LOSANT_API_TOKEN == "")
    throw "LOSANT_API_TOKEN Builder variable must be set!"

if(LOSANT_TEST_DEVICE_ID == "")
    throw "LOSANT_TEST_DEVICE_ID Builder variable must be set!"
