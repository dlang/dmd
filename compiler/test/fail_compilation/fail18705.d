/*
TEST_OUTPUT:
---
fail_compilation/fail18705.d(19): Error: function `fail` is not callable using argument types `(string)`
fail_compilation/fail18705.d(19):        cannot pass rvalue argument `val()` of type `string` to parameter `ref string v`
fail_compilation/fail18705.d(15):        `fail18705.fail(ref string v)` declared here
---
*/

// https://github.com/dlang/dmd/issues/18705
// Confirms the "not callable" error explicitly mentions the rvalue/ref
// mismatch instead of only a generic type list.
string val() { return "3"; }

void fail(ref string v) {}

void test18705()
{
    int v = fail(val);
}
