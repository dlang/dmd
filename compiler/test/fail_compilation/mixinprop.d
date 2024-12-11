/* TEST_OUTPUT:
---
fail_compilation/mixinprop.d(14): Error: no property `x` for `mixin Foo!() F;
` of type `void`
    F.x;
     ^
---
*/
mixin template Foo() { }

void main()
{
    mixin Foo F;
    F.x;
}
