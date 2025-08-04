/*
TEST_OUTPUT:
---
fail_compilation/struct_rvalue_assign.d(11): Error: cannot assign to struct rvalue `foo()`
fail_compilation/struct_rvalue_assign.d(12): Error: cannot assign to struct rvalue `foo()`
---
*/

void main ()
{
    foo() = S.init;
    foo() += 5;
}

S foo()
{
    return S.init;
}

struct S
{
    int i;

    void opAssign(S s)
    {
        this.i = s.i;
    }

    void opOpAssign(string op : "+")(int) {}
}
