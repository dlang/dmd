/*
TEST_OUTPUT:
---
fail_compilation/fail10346.d(11): Error: undefined identifier `T`
void bar(T x, T)(Foo!T) {}
         ^
---
*/

struct Foo(T) {}
void bar(T x, T)(Foo!T) {}
void main()
{
    Foo!int spam;
    bar!10(spam);
}
