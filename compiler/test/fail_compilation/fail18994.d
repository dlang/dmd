/*
TEST_OUTPUT:
---
fail_compilation/fail18994.d(21): Error: struct `fail18994.Type1` is not copyable because it has a disabled postblit
    foreach(b; Type2()) {}
    ^
---
*/
struct Type2
{
    int opApply(int delegate(ref Type1)) { return 0; }
}

struct Type1
{
    @disable this(this);
}

void test()
{
    foreach(b; Type2()) {}
}
