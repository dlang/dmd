/* TEST_OUTPUT:
---
fail_compilation/fail17491.d(20): Error: `(S17491).init` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(21): Error: `S17491(0)` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(23): Error: cannot modify constant expression `S17491(0).field`
fail_compilation/fail17491.d(29): Error: `S17491(0)` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(30): Error: `S17491(0)` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(32): Error: cannot modify constant expression `S17491(0).field`
---
*/
// https://issues.dlang.org/show_bug.cgi?id=17491
struct S17491
{
    int field;
    static int var;
}

void test17491()
{
    S17491.init = S17491(42);       // NG
    *&S17491.init = S17491(42);     // NG

    S17491.init.field = 42;         // NG
    *&S17491.init.field = 42;       // Should be NG

    S17491.init.var = 42;           // OK
    *&S17491.init.var = 42;         // OK

    S17491(0) = S17491(42);         // NG
    *&S17491(0) = S17491(42);       // NG

    S17491(0).field = 42;           // NG
    *&S17491(0).field = 42;         // Should be NG

    S17491(0).var = 42;             // OK
    *&S17491(0).var = 42;           // OK
}
