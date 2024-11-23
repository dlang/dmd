
/* TEST_OUTPUT:
---
fail_compilation/testscopestatic.d(23): Error: variable `testscopestatic.foo.p` cannot be `scope` and `static`
    static scope int* p;
                      ^
fail_compilation/testscopestatic.d(24): Error: variable `testscopestatic.foo.b` cannot be `scope` and `extern`
    extern scope int b;
                     ^
fail_compilation/testscopestatic.d(25): Error: variable `testscopestatic.foo.c` cannot be `scope` and `__gshared`
    scope __gshared int c;
                        ^
fail_compilation/testscopestatic.d(29): Error: field `x` cannot be `scope`
        scope int x;
                  ^
---
*/


void foo()
{
    scope int a;
    static scope int* p;
    extern scope int b;
    scope __gshared int c;

    struct S
    {
        scope int x;
    }
}
