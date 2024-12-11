/*
TEST_OUTPUT:
---
fail_compilation/ice12539.d(17): Error: sequence index `[0]` is outside bounds `[0 .. 0]`
    auto a = map[Foo[0]];
                    ^
---
*/

alias TypeTuple(E...) = E;

void main ()
{
    int[string] map;

    alias Foo = TypeTuple!();
    auto a = map[Foo[0]];
}
