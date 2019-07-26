/* TEST_OUTPUT:
---
fail_compilation/fail17491.d(22): Error: `(S17491).init` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(23): Error: `S17491(0)` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(25): Error: cannot modify constant `S17491(0).field`
fail_compilation/fail17491.d(26): Error: cannot modify constant `*&S17491(0).field`
fail_compilation/fail17491.d(31): Error: `S17491(0)` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(32): Error: `S17491(0)` is not an lvalue and cannot be modified
fail_compilation/fail17491.d(34): Error: cannot modify constant `S17491(0).field`
fail_compilation/fail17491.d(35): Error: cannot modify constant `*&S17491(0).field`
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
