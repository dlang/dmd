// https://issues.dlang.org/show_bug.cgi?id=22133
/*
TEST_OUTPUT:
---
fail_compilation/fail22133.d(20): Error: `s.popFront()()` has no effect
    s.popFront;
    ^
fail_compilation/fail22133.d(21): Error: template `s.popFront()()` has no type
    return s.popFront;
           ^
---
*/
struct Slice
{
    void popFront()() {}
}

auto fail22133(const Slice s)
{
    s.popFront;
    return s.popFront;
}

auto ok22133(Slice s)
{
    s.popFront;
    return s.popFront;
}
