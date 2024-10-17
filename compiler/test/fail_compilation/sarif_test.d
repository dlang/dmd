/*
TEST_OUTPUT:
---
fail_compilation/sarif_test.d(34): Error: undefined identifier `x`
{
  "invocation": {
    "executionSuccessful": false
  },
  "results": [
    {
      "location": {
        "artifactLocation": {
          "uri": "$p:(.*[\\\\/])?sarif_test\\.d$"
        },
        "region": {
          "startLine": 34,
          "startColumn": 5
        }
      },
      "message": "undefined identifier `x`",
      "ruleId": "DMD"
    }
  ],
  "tool": {
    "name": "DMD",
    "version": "$r:v2\\..*\\s?"
  }
}
---
*/
// REQUIRED_ARGS: --sarif

void main() {
    x = 5; // Undefined variable to trigger the error
}
