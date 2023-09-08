/*
TEST_OUTPUT:
---
fail_compilation/faildottypeinfo.d(12): Error: no property `typeinfo` for `0` of type `int`
fail_compilation/faildottypeinfo.d(13): Error: no property `typeinfo` for type `object.Object`
/home/nick/git/dmd/compiler/test/../../druntime/import/object.d(110):        class `Object` defined here
---
*/

void main()
{
    auto x = 0.typeinfo;
    auto y = Object.typeinfo;
}
