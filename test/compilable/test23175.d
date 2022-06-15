/*
REQUIRED_ARGS: -preview=in -preview=dip1000 -transition=inScope
TEST_OUTPUT:
---
compilable/test23175.d(28): `in` treated as scope without checking for scope violations
---
*/

// -preview=in silently adds possible stack memory escape
// https://issues.dlang.org/show_bug.cgi?id=23175
@nogc:

string fooSyst(in string s) @system
{
    auto t = s;
    return t;
}

string fooSafe(in string s) @safe
{
    return "";
}

void main()
{
    auto sa = fooSafe(['a']); // scope checking, fine
    auto sb = fooSyst("abc"); // string literal, fine
    auto sc = fooSyst(['a']); // memory corruption, error
}
