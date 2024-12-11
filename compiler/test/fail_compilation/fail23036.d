// https://issues.dlang.org/show_bug.cgi?id=23036

/*
TEST_OUTPUT:
---
fail_compilation/fail23036.d(18): Error: `struct S` may not define both a rvalue constructor and a copy constructor
struct S
^
fail_compilation/fail23036.d(21):        rvalue constructor defined here
    this(S, int a = 2) {}
    ^
fail_compilation/fail23036.d(20):        copy constructor defined here
    this(ref S) {}
    ^
---
*/

struct S
{
    this(ref S) {}
    this(S, int a = 2) {}
}

void main()
{
    S a;
    S b = a;
}
