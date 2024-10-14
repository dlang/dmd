/*
TEST_OUTPUT:
---
fail_compilation/sarif_test.d(33): Error: undefined identifier `x`
{
  "invocation": {
    "executionSuccessful": false
  },
  "results": [
    {
      "location": {
        "artifactLocation": {
          "uri": "fail_compilation/sarif_test.d"
        },
        "region": {
          "startLine": 33,
          "startColumn": 5
        }
      },
      "message": "undefined identifier `x`",
      "ruleId": "DMD"
    }
  ],
  "tool": {
    "name": "DMD"
  }
}
---
*/
// REQUIRED_ARGS: --sarif

void main() {
    x = 5; // Undefined variable to trigger the error
}
