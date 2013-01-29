// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail243.d(22): Deprecation: class fail243.DepClass is deprecated
fail_compilation/fail243.d(23): Deprecation: struct fail243.DepStruct is deprecated
fail_compilation/fail243.d(24): Deprecation: union fail243.DepUnion is deprecated
fail_compilation/fail243.d(25): Deprecation: enum fail243.DepEnum is deprecated
fail_compilation/fail243.d(26): Deprecation: alias fail243.DepAlias is deprecated
---
*/

deprecated {
    class DepClass {}
    struct DepStruct {}
    union DepUnion {}
    enum DepEnum { A }
    alias int DepAlias;
    //typedef int DepTypedef;   // move to fail243a
}

void func(DepClass obj) {}
void func(DepStruct obj) {}
void func(DepUnion obj) {}
void func(DepEnum obj) {}
void func(DepAlias obj) {}
//void func(DepTypedef obj) {}  // move to fail243a

