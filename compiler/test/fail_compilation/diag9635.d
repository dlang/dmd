// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag9635.d(21): Error: accessing non-static variable `i` requires an instance of `Foo`
        i = 4;
        ^
fail_compilation/diag9635.d(22): Error: calling non-static function `foo` requires an instance of type `Foo`
        foo();
           ^
---
*/

struct Foo
{
    int i;
    void foo()() { }

    static void bar()
    {
        i = 4;
        foo();
    }
}
