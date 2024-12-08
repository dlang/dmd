// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail243.d(33): Deprecation: class `fail243.DepClass` is deprecated
void func(DepClass obj) {}
     ^
fail_compilation/fail243.d(34): Deprecation: struct `fail243.DepStruct` is deprecated
void func(DepStruct obj) {}
     ^
fail_compilation/fail243.d(35): Deprecation: union `fail243.DepUnion` is deprecated
void func(DepUnion obj) {}
     ^
fail_compilation/fail243.d(36): Deprecation: enum `fail243.DepEnum` is deprecated
void func(DepEnum obj) {}
     ^
fail_compilation/fail243.d(37): Deprecation: alias `fail243.DepAlias` is deprecated
void func(DepAlias obj) {}
     ^
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
