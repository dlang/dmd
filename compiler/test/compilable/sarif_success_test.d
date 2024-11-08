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
			"executionSuccessful": true
		}],
		"results": [
		]
	}]
}
---
*/

void main() {
    int x = 5;
}
