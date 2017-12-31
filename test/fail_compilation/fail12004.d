/*
TEST_OUTPUT:
---
fail_compilation/fail12004.d(9): Error: destructor cannot be shared
---
*/

struct S {
    ~this() shared {}
}
