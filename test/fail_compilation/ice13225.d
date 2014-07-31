/*
TEST_OUTPUT:
---
fail_compilation/ice13225.d(13): Error: undefined identifier undefined
---
*/

mixin template M(T) {}

struct S
{
    mixin M!((typeof(this)) => 0);
    mixin M!(() => undefined);
}
