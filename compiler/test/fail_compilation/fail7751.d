/*
TEST_OUTPUT:
---
fail_compilation/fail7751.d(19): Error: no constructor for `Foo`
    return new Foo!T(x, y);
           ^
fail_compilation/fail7751.d(27): Error: template instance `fail7751.foo!int` error instantiating
    bar(foo(0));
           ^
---
*/
class Foo(T)
{
    T x;
    Foo y;
}
auto foo(T)(T x, Foo!T y=null)
{
    return new Foo!T(x, y);
}
void bar(U)(U foo, U[] spam=[])
{
    spam ~= [];
}
void main()
{
    bar(foo(0));
}
