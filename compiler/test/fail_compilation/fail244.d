// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail244.d(47): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
        obj.value = 666;
        ^
fail_compilation/fail244.d(48): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
        this.value = 666;
        ^
fail_compilation/fail244.d(49): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
        auto n1 = obj.value;
                  ^
fail_compilation/fail244.d(50): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
        auto n2 = this.value;
                  ^
fail_compilation/fail244.d(52): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
        obj.staticValue = 102;
        ^
fail_compilation/fail244.d(53): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
        this.staticValue = 103;
        ^
fail_compilation/fail244.d(54): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
        StructWithDeps.staticValue = 104;
        ^
fail_compilation/fail244.d(55): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
        auto n3 = obj.staticValue;
                  ^
fail_compilation/fail244.d(56): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
        auto n4 = this.staticValue;
                  ^
fail_compilation/fail244.d(57): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
        auto n5 = StructWithDeps.staticValue;
                  ^
---
*/

//import std.stdio;

struct StructWithDeps
{
    deprecated int value;
    deprecated static int staticValue;

    void test(StructWithDeps obj)
    {
        obj.value = 666;
        this.value = 666;
        auto n1 = obj.value;
        auto n2 = this.value;

        obj.staticValue = 102;
        this.staticValue = 103;
        StructWithDeps.staticValue = 104;
        auto n3 = obj.staticValue;
        auto n4 = this.staticValue;
        auto n5 = StructWithDeps.staticValue;
    }
}
