/* TEST_OUTPUT:
---
fail_compilation/fail17491.d(38): Error: cannot modify expression `(S17491).init` because it is not an lvalue
    S17491.init = S17491(42);       // NG
    ^
fail_compilation/fail17491.d(39): Error: cannot take address of expression `S17491(0)` because it is not an lvalue
    *&S17491.init = S17491(42);     // NG
      ^
fail_compilation/fail17491.d(41): Error: cannot modify expression `S17491(0).field` because it is not an lvalue
    S17491.init.field = 42;         // NG
    ^
fail_compilation/fail17491.d(42): Error: cannot take address of expression `S17491(0).field` because it is not an lvalue
    *&S17491.init.field = 42;       // NG
      ^
fail_compilation/fail17491.d(47): Error: cannot modify expression `S17491(0)` because it is not an lvalue
    S17491(0) = S17491(42);         // NG
          ^
fail_compilation/fail17491.d(48): Error: cannot take address of expression `S17491(0)` because it is not an lvalue
    *&S17491(0) = S17491(42);       // NG
            ^
fail_compilation/fail17491.d(50): Error: cannot modify expression `S17491(0).field` because it is not an lvalue
    S17491(0).field = 42;           // NG
          ^
fail_compilation/fail17491.d(51): Error: cannot take address of expression `S17491(0).field` because it is not an lvalue
    *&S17491(0).field = 42;         // NG
            ^
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
    *&S17491.init.field = 42;       // NG

    S17491.init.var = 42;           // OK
    *&S17491.init.var = 42;         // OK

    S17491(0) = S17491(42);         // NG
    *&S17491(0) = S17491(42);       // NG

    S17491(0).field = 42;           // NG
    *&S17491(0).field = 42;         // NG

    S17491(0).var = 42;             // OK
    *&S17491(0).var = 42;           // OK
}
