/*
TEST_OUTPUT:
---
fail_compilation/fail20775.d(23): Error: cannot pass types that need destruction as variadic arguments
    variadic(v,
             ^
fail_compilation/fail20775.d(24): Error: cannot pass types that need destruction as variadic arguments
             S20775(1));
                   ^
---
*/
extern void variadic(...);

struct S20775
{
    int field;
    ~this() { }
}

void test()
{
    auto v = S20775(0);
    variadic(v,
             S20775(1));
}
