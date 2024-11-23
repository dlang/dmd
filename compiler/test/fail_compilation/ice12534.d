/*
TEST_OUTPUT:
---
fail_compilation/ice12534.d(16): Error: static assert:  `is(exprs[0 .. 0])` is false
    static assert(is(exprs[0..0]));
    ^
---
*/

alias TypeTuple(T...) = T;

void main()
{
    int x, y;
    alias exprs = TypeTuple!(x, y);
    static assert(is(exprs[0..0]));
}
