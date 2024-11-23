/*
TEST_OUTPUT:
---
fail_compilation/ice15332.d(20): Error: calling non-static function `fun` requires an instance of type `C`
        int a1 = function() { return fun; }();
                                     ^
fail_compilation/ice15332.d(21): Error: accessing non-static variable `var` requires an instance of `C`
        int a2 = function() { return var; }();
                                     ^
---
*/

class C
{
    int fun() { return 5; }
    int var;

    void test()
    {
        int a1 = function() { return fun; }();
        int a2 = function() { return var; }();
    }
}
