/*
TEST_OUTPUT:
---
fail_compilation/diag12777.d(14): Error: cannot modify const expression this.v
fail_compilation/diag12777.d(15): Error: cannot modify immutable expression this.v
fail_compilation/diag12777.d(21): Error: cannot modify const expression this.v
fail_compilation/diag12777.d(22): Error: cannot modify immutable expression this.v
---
*/

struct S
{
    int v;
    void fun() const     { v++; }
    void gun() immutable { v++; }
}

class C
{
    int v;
    void fun() const     { v++; }
    void gun() immutable { v++; }
}
