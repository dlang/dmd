/*
TEST_OUTPUT:
---
fail_compilation/array_index_init.d(15): Error: incompatible types for `(2) : ("")`: `int` and `string`
---
*/

void main()
{
    auto a = [3, 1:1, 2:2];
    static assert(is(typeof(a) == int[]));
    auto c = [[], [2]];
    static assert(is(typeof(c) == int[][]));

    auto b = [3, 1:2, ""];
}
