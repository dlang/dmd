/* TEST_OUTPUT:
---
fail_compilation/interface_size.d(22): Error: `object.Interface` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/interface_size.d(30):        required by class `object.C`
fail_compilation/interface_size.d(22):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
---
*/

module object;

alias size_t = typeof(int.sizeof);

class Object {}
class TypeInfo {}
class TypeInfo_Const : TypeInfo {}

class TypeInfo_Class : TypeInfo
{
    void*[size_t.sizeof == 8 ? 17 : 19] x;
}

struct Interface
{
    void* classinfo;
    void*[2] vtbl;
    size_t offset;
}

interface I {}
class C : I {}
