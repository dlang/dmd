/*
TEST_OUTPUT:
---
fail_compilation/fail39.d(16): Error: function `fail39.main.__funcliteral_L16_C27` cannot access function `foo` in frame of function `D main`
    void function() bar = function void() { foo(); };
                                               ^
fail_compilation/fail39.d(15):        `foo` declared here
    void foo() {}
         ^
---
*/

void main()
{
    void foo() {}
    void function() bar = function void() { foo(); };
}
