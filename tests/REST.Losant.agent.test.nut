@include once "./../REST.Losant.agent.singleton.nut"

class LosantBaseTest extends ImpTestCase {

    function testvalidateAndSanitizeParams(){
        local testParamsTemplate = {
            "sortField" : math.rand(),
            "sortDirection" : math.rand(),
            "page" : math.rand(),
            "perPage" : math.rand(),
            "filterField" : math.rand(),
            "filter" : math.rand(),
            "deviceClass" : math.rand(),
            "tagFilter" : math.rand(),
            "excludeConnectionInfo" : math.rand(),
            "losantdomain" : math.rand(),
            "_actions" : math.rand(),
            "_links" : math.rand(),
            "_embedded" : math.rand()
        }

        local validParams = [
            "sortField",
            "sortDirection",
            "page",
            "perPage",
            "filterField",
            "filter",
            "deviceClass",
            "tagFilter",
            "excludeConnectionInfo",
            "losantdomain",
            "_actions",
            "_links",
            "_embedded"
        ]

        //validateAndSanitizeParams modified our existing parameters in place, so lots of clones required for valid testing

        local testParams = clone(testParamsTemplate)
        this.assertDeepEqual(REST.Losant.validateAndSanitizeParams(clone(testParams), validParams), testParamsTemplate, "Matching keys should match")

        this.assertDeepEqual(REST.Losant.validateAndSanitizeParams({}, validParams), {}, "Empty params")

        this.assertDeepEqual(REST.Losant.validateAndSanitizeParams(clone(testParamsTemplate), []), {}, "Empty validParams")

        local testParams = clone(testParamsTemplate)
        delete testParams.sortField
        this.assertDeepEqual(REST.Losant.validateAndSanitizeParams(clone(testParams), validParams), testParams, "Removing a single key should not create a difference")

        local testParams = clone(testParamsTemplate)
        testParams.badParam <- true;
        this.assertDeepEqual(REST.Losant.validateAndSanitizeParams(clone(testParams), validParams), testParamsTemplate, "Bad Parameters should be removed")


        // Test with a simple "begins with" regex
        validParams[7] = "tagFilter(.*)"
        local testParams = clone(testParamsTemplate)
        testParams["tagFilter[0][key]"] <- "test"

        this.assertDeepEqual(REST.Losant.validateAndSanitizeParams(clone(testParams), validParams), testParams, "Begins with Regex")

    }
}
