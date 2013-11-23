/*
TEST_OUTPUT:
---
fail_compilation/fail9537.d(17): Error: escaping reference to local variable tup
fail_compilation/fail9537.d(22): Error: escaping reference to local variable sa
---
*/

struct Tuple(T...)
{
    T field;
    alias field this;
}

ref foo(Tuple!(int, int) tup)
{
    return tup[0];
}

ref foo(int[3] sa)
{
    return sa[0];
}
