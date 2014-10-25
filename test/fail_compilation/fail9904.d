/*
TEST_OUTPUT:
---
fail_compilation/fail9904.d(22): Error: cannot cast expression null of type typeof(null) to S1
fail_compilation/fail9904.d(23): Error: cannot cast expression null of type typeof(null) to S2
---
*/

struct S1
{
    size_t m;
}

struct S2
{
    size_t m;
    byte b;
}

void main()
{
    auto s1 = cast(S1)null;
    auto s2 = cast(S2)null;
}
