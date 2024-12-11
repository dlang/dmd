/*
TEST_OUTPUT:
---
fail_compilation/fail13498.d(15): Error: cannot implicitly convert expression `"foo"` of type `string` to `int`
    return "foo"; // should fail as well
           ^
fail_compilation/fail13498.d(20): Error: template instance `fail13498.foo!()` error instantiating
    foo();
       ^
---
*/

int foo()()
{
    return "foo"; // should fail as well
}

void main()
{
    foo();
}
