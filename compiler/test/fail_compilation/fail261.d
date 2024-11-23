/*
TEST_OUTPUT:
---
fail_compilation/fail261.d(22): Error: invalid `foreach` aggregate `range` of type `MyRange`
    foreach (r; range)
    ^
fail_compilation/fail261.d(22):        `foreach` works with input ranges (implementing `front` and `popFront`), aggregates implementing `opApply`, or the result of an aggregate's `.tupleof` property
fail_compilation/fail261.d(22):        https://dlang.org/phobos/std_range_primitives.html#isInputRange
---
*/

//import std.stdio;

struct MyRange
{
}

void main()
{
    MyRange range;

    foreach (r; range)
    {
        //writefln("%s", r.toString());
    }
}
