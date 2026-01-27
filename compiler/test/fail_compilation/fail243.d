// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail243.d(28): Deprecation: class `fail243.DepClass` is deprecated
fail_compilation/fail243.d(20):        `DepClass` is declared here
fail_compilation/fail243.d(29): Deprecation: struct `fail243.DepStruct` is deprecated
fail_compilation/fail243.d(21):        `DepStruct` is declared here
fail_compilation/fail243.d(30): Deprecation: union `fail243.DepUnion` is deprecated
fail_compilation/fail243.d(22):        `DepUnion` is declared here
fail_compilation/fail243.d(31): Deprecation: enum `fail243.DepEnum` is deprecated
fail_compilation/fail243.d(23):        `DepEnum` is declared here
fail_compilation/fail243.d(32): Deprecation: alias `fail243.DepAlias` is deprecated
fail_compilation/fail243.d(24):        `DepAlias` is declared here
---
*/

deprecated
{
    class DepClass {}
    struct DepStruct {}
    union DepUnion {}
    enum DepEnum { A }
    alias int DepAlias;
    //typedef int DepTypedef;
}

void func(DepClass obj) {}
void func(DepStruct obj) {}
void func(DepUnion obj) {}
void func(DepEnum obj) {}
void func(DepAlias obj) {}
//void func(DepTypedef obj) {}
