// REQUIRED_ARGS: -verror-style=sarif
/*
TEST_OUTPUT:
---
{
	"version": "2.1.0",
	"$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json",
	"runs": [{
		"tool": {
			"driver": {
				"name": "Digital Mars D",
				"version": "$r:\d+\.\d+\.\d+$",
				"informationUri": "https://dlang.org/dmd.html"
			}
		},
		"invocations": [{
			"executionSuccessful": false
		}],
		"results": [
			{
				"ruleId": "DMD-error",
				"message": {
					"text": "undefined identifier `x`"
				},
				"level": "error",
				"locations": [{
					"physicalLocation": {
						"artifactLocation": {
							"uri": "fail_compilation/sarif_test.d"
						},
						"region": {
							"startLine": 63,
							"startColumn": 5
						}
					}
				}]
			},
			{
				"ruleId": "DMD-error",
				"message": {
					"text": "static assert:  \"needs \"escaping\": back\\slash, tab\there, new\nline\""
				},
				"level": "error",
				"locations": [{
					"physicalLocation": {
						"artifactLocation": {
							"uri": "fail_compilation/sarif_test.d"
						},
						"region": {
							"startLine": 65,
							"startColumn": 5
						}
					}
				}]
			}
		]
	}]
}
---
*/

void main() {
    x = 5; // Undefined variable to trigger the error

    static assert(0, "needs \"escaping\": back\\slash, tab\there, new\nline");
}
