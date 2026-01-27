// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail244.d(37): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
fail_compilation/fail244.d(32):        `value` is declared here
fail_compilation/fail244.d(38): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
fail_compilation/fail244.d(32):        `value` is declared here
fail_compilation/fail244.d(39): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
fail_compilation/fail244.d(32):        `value` is declared here
fail_compilation/fail244.d(40): Deprecation: variable `fail244.StructWithDeps.value` is deprecated
fail_compilation/fail244.d(32):        `value` is declared here
fail_compilation/fail244.d(42): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
fail_compilation/fail244.d(33):        `staticValue` is declared here
fail_compilation/fail244.d(43): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
fail_compilation/fail244.d(33):        `staticValue` is declared here
fail_compilation/fail244.d(44): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
fail_compilation/fail244.d(33):        `staticValue` is declared here
fail_compilation/fail244.d(45): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
fail_compilation/fail244.d(33):        `staticValue` is declared here
fail_compilation/fail244.d(46): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
fail_compilation/fail244.d(33):        `staticValue` is declared here
fail_compilation/fail244.d(47): Deprecation: variable `fail244.StructWithDeps.staticValue` is deprecated
fail_compilation/fail244.d(33):        `staticValue` is declared here
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
