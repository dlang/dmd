/*
TEST_OUTPUT:
---
fail_compilation/faildottypeinfo.d(18): Error: no property `typeinfo` for `0` of type `int`
    auto x = 0.typeinfo;
              ^
fail_compilation/faildottypeinfo.d(19): Error: no property `typeinfo` for type `object.Object`
    auto y = Object.typeinfo;
             ^
$p:druntime/import/object.d$($n$):        class `Object` defined here
class Object
^
---
*/

void main()
{
    auto x = 0.typeinfo;
    auto y = Object.typeinfo;
}
