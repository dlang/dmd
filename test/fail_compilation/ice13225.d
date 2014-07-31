/*
TEST_OUTPUT:
---
fail_compilation/ice13225.d(13): Error: undefined identifier undefined
fail_compilation/ice13225.d(13): Error: mixin ice13225.S.M!(__error) does not match template declaration M(T)
---
*/
mixin template M(T) {}

struct S
{
    mixin M!((typeof(this)) => 0);
    mixin M!(() => undefined);
}
