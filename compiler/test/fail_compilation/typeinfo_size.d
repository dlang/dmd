/* TEST_OUTPUT:
---
fail_compilation/typeinfo_size.d(34): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(28):        required by class `object.Object`
fail_compilation/typeinfo_size.d(34):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
fail_compilation/typeinfo_size.d(34): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(32):        required by class `object.TypeInfo`
fail_compilation/typeinfo_size.d(34):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
fail_compilation/typeinfo_size.d(34): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(33):        required by class `object.TypeInfo_Const`
fail_compilation/typeinfo_size.d(34):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
fail_compilation/typeinfo_size.d(34): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(34):        required by class `object.TypeInfo_Class`
fail_compilation/typeinfo_size.d(34):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
fail_compilation/typeinfo_size.d(34): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(43):        required by interface `object.I`
fail_compilation/typeinfo_size.d(34):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
fail_compilation/typeinfo_size.d(34): Error: `object.TypeInfo_Class` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(45):        required by class `object.C`
fail_compilation/typeinfo_size.d(34):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
fail_compilation/typeinfo_size.d(36): Error: `object.Interface` is declared with size $n$ bytes, but the compiler expects $n$ bytes
fail_compilation/typeinfo_size.d(45):        required by class `object.C`
fail_compilation/typeinfo_size.d(36):        object.d does not match this compiler version, check installation and import paths with `-v` compiler switch
---
*/
module object;

class Object {}

alias size_t = typeof(int.sizeof);

class TypeInfo {}
class TypeInfo_Const : TypeInfo {}
class TypeInfo_Class : TypeInfo {}

struct Interface
{
    void* classinfo;
    void*[2] vtbl;
    size_t offset;
}

interface I {}

class C : I {}
