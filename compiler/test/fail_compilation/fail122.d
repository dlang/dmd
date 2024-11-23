/*
TEST_OUTPUT:
---
fail_compilation/fail122.d(14): Error: undefined identifier `y`
    y = 2;
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=228
// Crash on inferring function literal return type after prior errors
void main()
{
    y = 2;
    auto x = function(){};
}
