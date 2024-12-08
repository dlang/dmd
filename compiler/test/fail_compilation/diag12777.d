/*
TEST_OUTPUT:
---
fail_compilation/diag12777.d(22): Error: cannot modify `this.v` in `const` function
    void fun() const     { v++; }
                           ^
fail_compilation/diag12777.d(23): Error: cannot modify `this.v` in `immutable` function
    void gun() immutable { v++; }
                           ^
fail_compilation/diag12777.d(29): Error: cannot modify `this.v` in `const` function
    void fun() const     { v++; }
                           ^
fail_compilation/diag12777.d(30): Error: cannot modify `this.v` in `immutable` function
    void gun() immutable { v++; }
                           ^
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
