/*
TEST_OUTPUT:
---
fail_compilation/diag9047.d(17): Error: must import std.math to use ^^ operator
fail_compilation/diag9047.d(22): Error: must import std.math to use ^^ operator
fail_compilation/diag9047.d(28): Error: must import std.math to use ^^ operator
fail_compilation/diag9047.d(32): Error: must import std.math to use ^^ operator
fail_compilation/diag9047.d(39): Error: must import std.math to use ^^ operator
---
*/

// sentinel: should not be picked up
struct std { struct math { @disable static void pow(T...)(T t) { } } }

void f1()
{
    auto f = (double a, double b) => a ^^ b;
}

void f2()
{
    auto f2 = (double a, double b) => a ^^ b;
    import std.math;
}

void f3()
{
    auto f1 = (double a, double b) => a ^^ b;
    {
        import std.math;
    }
    auto f2 = (double a, double b) => a ^^ b;
}

void f4()
{
    // sentinel: should not be picked up
    struct std { struct math { @disable static void pow(T...)(T t) { } } }
    auto f = (double a, double b) => a ^^ b;
}
