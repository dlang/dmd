/*
TEST_OUTPUT:
---
fail_compilation/fail11714.d(16): Error: variable `fail11714.c` is a thread-local class and cannot have a static initializer
fail_compilation/fail11714.d(16):        use `static this()` to initialize instead
fail_compilation/fail11714.d(23): Error: variable `fail11714.s` is a thread-local pointer to struct and cannot have a static initializer
fail_compilation/fail11714.d(23):        use `static this()` to initialize instead
---
*/

class C11714
{
    int data;
};

C11714 c = new C11714;  // mutable class reference.

struct S11714
{
    int data;
};

S11714* s = new S11714; // mutable pointer to struct.
