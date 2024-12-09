/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test15544.d(27): Error: reference to local `this` assigned to non-scope `_del` in @safe code
        _del = &foo;
             ^
fail_compilation/test15544.d(29): Error: reference to local `this` assigned to non-scope `_del` in @safe code
        _del = { assert(x == 42); };
             ^
fail_compilation/test15544.d(46): Error: reference to local `y` assigned to non-scope `dg` in @safe code
    dg = &bar;               // Error
       ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15544

void delegate() @safe _del;

struct S {
    int x = 42;

    @safe void test()
    {
        void foo() { assert(x == 42); }
        _del = &foo;

        _del = { assert(x == 42); };
    }
}

int delegate() dg;

void testClosure1()
{
    int* x;
    int bar() { return *x; }
    dg = &bar;
}

@safe void testClosure2()
{
    scope int* y;
    int bar() { return *y; }
    dg = &bar;               // Error
    auto dg2 = &bar;
}
