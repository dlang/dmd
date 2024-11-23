// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/diag15411.d(29): Error: function `diag15411.test15411.__funcliteral_L29_C15` cannot access variable `i` in frame of function `diag15411.test15411`
    auto j = (function() { return i; })();
                                  ^
fail_compilation/diag15411.d(28):        `i` declared here
    auto i = 0;
         ^
fail_compilation/diag15411.d(30): Error: function `diag15411.test15411.__funcliteral_L30_C15` cannot access variable `i` in frame of function `diag15411.test15411`
    auto f =  function() { return i; };
                                  ^
fail_compilation/diag15411.d(28):        `i` declared here
    auto i = 0;
         ^
fail_compilation/diag15411.d(38): Error: `static` function `diag15411.testNestedFunction.myFunc2` cannot access function `myFunc1` in frame of function `diag15411.testNestedFunction`
    static void myFunc2 () { myFunc1(); }
                                    ^
fail_compilation/diag15411.d(37):        `myFunc1` declared here
    void myFunc1() { assert(i == 42); }
         ^
---
*/

void test15411()
{
    auto i = 0;
    auto j = (function() { return i; })();
    auto f =  function() { return i; };
}

void testNestedFunction ()
{
    int i = 42;

    void myFunc1() { assert(i == 42); }
    static void myFunc2 () { myFunc1(); }
}
