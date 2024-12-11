/*
TEST_OUTPUT:
---
fail_compilation/fail270.d(18): Error: string slice `[1 .. 0]` is out of bounds
    mixin .Tuple!((TList[1 .. $])) tail;
                        ^
fail_compilation/fail270.d(18): Error: mixin `fail270.Tuple!int.Tuple.Tuple!()` error instantiating
    mixin .Tuple!((TList[1 .. $])) tail;
    ^
fail_compilation/fail270.d(20): Error: mixin `fail270.Tuple!int` error instantiating
mixin Tuple!(int);
^
---
*/

struct Tuple(TList...)
{
    mixin .Tuple!((TList[1 .. $])) tail;
}
mixin Tuple!(int);
