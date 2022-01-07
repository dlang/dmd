/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/tuplecast.d(106): Deprecation: casting from `(int, int)` to `long` is deprecated
---
*/

#line 100

alias TypeTuple(T...) = T;

void weiredCast()
{
    TypeTuple!(int, int) values;
    auto values2 = cast(long)values;
}
