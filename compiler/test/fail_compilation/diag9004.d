/*
TEST_OUTPUT:
---
fail_compilation/diag9004.d(25): Error: template `bar` is not callable using argument types `!()(Foo!int, int)`
    bar(foo, 1);
       ^
fail_compilation/diag9004.d(18):        Candidate is: `bar(FooT)(FooT foo, FooT.T x)`
void bar(FooT)(FooT foo, FooT.T x)
     ^
---
*/

struct Foo(_T)
{
    alias _T T;
}

void bar(FooT)(FooT foo, FooT.T x)
{
}

void main()
{
    Foo!int foo;
    bar(foo, 1);
}
