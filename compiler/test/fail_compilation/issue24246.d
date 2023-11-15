// https://issues.dlang.org/show_bug.cgi?id=24246

/*
TEST_OUTPUT:
---
fail_compilation/issue24246.d(116): Error: CTFE internal error: literal `int` could not be copied.
---
*/

#line 100

auto f24246()
{
    return 1;
}

auto f24246(int i)
{
    return true ? int : i;
}

struct S24246
{
    int field;
}

enum ice24246 = S24246(f24246.f24246);
