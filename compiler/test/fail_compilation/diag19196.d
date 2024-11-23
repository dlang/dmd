/*
TEST_OUTPUT:
---
fail_compilation/diag19196.d(15): Error: unable to determine fields of `B` because of forward references
    alias F = typeof(T.tupleof);
                     ^
fail_compilation/diag19196.d(19): Error: template instance `diag19196.Foo!(B)` error instantiating
    Foo!B b;
    ^
---
*/
module diag19196;
struct Foo(T)
{
    alias F = typeof(T.tupleof);
}
struct B
{
    Foo!B b;
}
