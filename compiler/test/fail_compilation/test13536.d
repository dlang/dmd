/*
TEST_OUTPUT:
---
fail_compilation/test13536.d(24): Error: accessing overlapped field `U.sysDg` with pointers is not allowed in a `@safe` function
fail_compilation/test13536.d(24): Error: assigning address of variable `s` to `u` with longer lifetime is not allowed in a `@safe` function
fail_compilation/test13536.d(25): Error: accessing overlapped field `U.safeDg` with pointers is not allowed in a `@safe` function
---
*/

module test13536 2024;

// https://issues.dlang.org/show_bug.cgi?id=13536

struct S {
    void sysMethod() @system {}
}
void fun() @safe {
    union U {
        void delegate() @system sysDg;
        void delegate() @safe safeDg;
    }
    U u;
    S s;
    u.sysDg = &s.sysMethod;
    u.safeDg();
}
