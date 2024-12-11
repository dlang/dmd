/*
TEST_OUTPUT:
---
fail_compilation/ccast.d(20): Error: C style cast illegal, use `cast(byte)i`
byte b = (byte)i;
         ^
fail_compilation/ccast.d(33): Error: C style cast illegal, use `cast(foo)5`
    (foo)5;
    ^
fail_compilation/ccast.d(35): Error: C style cast illegal, use `cast(void*)5`
    (void*)5;
    ^
fail_compilation/ccast.d(38): Error: C style cast illegal, use `cast(void*)5`
    (void*)
    ^
---
*/

int i;
byte b = (byte)i;

void bar(int x);

void main()
{
    (&bar)(5); // ok
    auto foo = &bar;
    (foo = foo)(5); // ok
    (*foo)(5); // ok

    (foo)(5); // ok
    (bar)(5); // ok
    (foo)5;

    (void*)5;
    (void*)(5); // semantic implicit cast error

    (void*)
        5;
}
