/*
TEST_OUTPUT:
---
fail_compilation/fail20771.d(23): Error: cannot pass types with postblits or copy constructors as variadic arguments
    variadic(v,
             ^
fail_compilation/fail20771.d(24): Error: cannot pass types with postblits or copy constructors as variadic arguments
             S20771(1));
                   ^
---
*/
extern void variadic(...);

struct S20771
{
    int field;
    this(this) { }
}

void test()
{
    auto v = S20771(0);
    variadic(v,
             S20771(1));
}
