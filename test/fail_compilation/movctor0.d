// REQUIRED_ARGS: -preview=rvaluetype
/*
TEST_OUTPUT:
---
fail_compilation/movctor0.d(44): Error: struct `movctor0.SErr` is not copyable because it is annotated with `@disable`
---
*/

struct S1
{
    this(@rvalue ref S1) {}
    this(this) {}
}

void test1()
{
    S1 a;
    S1 b = cast(@rvalue) a; // ok
    S1 c = a; // ok
}

struct S2
{
    this(@rvalue ref S2) {}
    this(ref S2) {}
}

void test2()
{
    S2 a;
    S2 b = cast(@rvalue) a; // ok
    S2 c = a; // ok
}

struct SErr
{
    this(@rvalue ref SErr) {}
}

void test3()
{
    SErr a;
    SErr b = cast(@rvalue) a; // ok
    SErr c = a; // error
}
