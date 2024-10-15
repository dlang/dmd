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
          "uri": "file:///home/royalpinto007/d-build-source/dmd/compiler/test/fail_compilation/sarif_test.d"
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
    "version": "v2.110.0-beta.1-324-gab8582b70f-dirty"
  }
}
---
*/
// REQUIRED_ARGS: --sarif

void main() {
    x = 5; // Undefined identifier 'x' to trigger an error
}
