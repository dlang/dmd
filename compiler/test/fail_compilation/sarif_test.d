/*
TEST_OUTPUT:
---
{
	"version": "2.1.0",
	"$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json",
	"runs": [{
		"tool": {
		"driver": {
		"name": "Digital Mars D","version": "2.110.0","informationUri": "https://dlang.org/dmd.html"
		}
		},
		"invocations": [{
		"executionSuccessful": false
		}],
		"results": [{
		"ruleId": "DMD",
		"message": { "text": "undefined identifier `x`" },"locations": [{
		"physicalLocation": {
		"artifactLocation": {
		"uri": "fail_compilation/sarif_test.d"},
		"region": {
		"startLine": 34,"startColumn": 5}
		}
		}]
		}]
	}]
}
---
*/
// REQUIRED_ARGS: -verror-style=sarif

void main() {
    x = 5; // Undefined variable to trigger the error
}
