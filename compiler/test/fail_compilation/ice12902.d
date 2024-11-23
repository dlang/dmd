/*
TEST_OUTPUT:
---
fail_compilation/ice12902.d(24): Error: variable `ice12902.main.__dollar` - type `void` is inferred from initializer `s.opDollar()`, and variables cannot be of type `void`
    s[] = s[$];
            ^
fail_compilation/ice12902.d(24): Error: expression `s.opDollar()` is `void` and has no value
    s[] = s[$];
            ^
---
*/

struct S
{
    void opDollar() { }
    void opIndex() { }
    void opIndexAssign() { }
    void opSliceAssign() { }
}

void main()
{
    S s;
    s[] = s[$];
}
