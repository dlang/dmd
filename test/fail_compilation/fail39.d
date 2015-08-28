/*
TEST_OUTPUT:
---
fail_compilation/fail39.d(11): Error: function fail39.main.foo is a nested function and cannot be accessed from fail39.main.__funcliteral2
---
*/

void main()
{
    void foo() {}
    void function() bar = function void() { foo(); };
}
