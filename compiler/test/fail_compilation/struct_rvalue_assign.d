/*
TEST_OUTPUT:
---
fail_compilation/struct_rvalue_assign.d(16): Error: cannot assign to struct rvalue `foo()`
fail_compilation/struct_rvalue_assign.d(16):        if the assignment is used for side-effects, call `opAssign` directly
fail_compilation/struct_rvalue_assign.d(17): Error: cannot modify struct rvalue `foo()`
fail_compilation/struct_rvalue_assign.d(17):        if the assignment is used for side-effects, call `opOpAssign` directly
fail_compilation/struct_rvalue_assign.d(18): Error: cannot modify struct rvalue `foo()`
fail_compilation/struct_rvalue_assign.d(18):        if the assignment is used for side-effects, call `opUnary` directly
---
*/
module sra 2024;

void main()
{
    foo() = S.init;
    foo() += 5;
    ++foo();
    cast(void) ~foo(); // other unary ops are OK
}

S foo() => S.init;

struct S
{
    int i;

    void opAssign(S s) {}
    void opOpAssign(string op : "+")(int) {}
    void opUnary(string op)() {}
}
