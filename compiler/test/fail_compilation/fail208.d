/*
TEST_OUTPUT:
---
fail_compilation/fail208.d(22): Error: `return` expression expected
    return ;
    ^
fail_compilation/fail208.d(25):        called from here: `MakeA()`
static const A aInstance = MakeA();
                                ^
---
*/


// https://issues.dlang.org/show_bug.cgi?id=1593
// ICE compiler crash empty return statement in function
struct A
{
}

A MakeA()
{
    return ;
}

static const A aInstance = MakeA();
