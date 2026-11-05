/* TEST_OUTPUT:
---
fail_compilation/typeinfo_size.d(15): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(11):        required by class `object.Object`
fail_compilation/typeinfo_size.d(15):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
---
*/

module object;

class Object {}

class TypeInfo {}

class TypeInfo_Class : TypeInfo
{
    void*[100] x;
}
