/*
TEST_OUTPUT:
---
fail_compilation/fail19931.d(16): Error: `struct S` may not define both a rvalue constructor and a copy constructor
struct S
^
fail_compilation/fail19931.d(18):        rvalue constructor defined here
    this(S s) {}
    ^
fail_compilation/fail19931.d(19):        copy constructor defined here
    this(ref S s) {}
    ^
---
*/

struct S
{
    this(S s) {}
    this(ref S s) {}
    this(this) {}
}
