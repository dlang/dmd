/*
TEST_OUTPUT:
---
fail_compilation/fail208.d(18): Error: `return` expression expected
fail_compilation/fail208.d(21):        called from here: `MakeA()`
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
