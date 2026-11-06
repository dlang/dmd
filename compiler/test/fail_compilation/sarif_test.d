// REQUIRED_ARGS: -verror-style=sarif
// DISABLED: win32 win64
// Disabled on Windows: while the test runner transforms linux paths to Windows paths in test output,
// it's not aware that inside JSON strings that \ gets escaped as "\\" so it fails with diff:
// - "uri": "fail_compilation\sarif_test.d"
// + "uri": "fail_compilation\\sarif_test.d"

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
							"startLine": 69,
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
							"startLine": 71,
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
