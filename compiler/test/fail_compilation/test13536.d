/*
TEST_OUTPUT:
---
fail_compilation/test13536.d(26): Error: field `U.sysDg` cannot access pointers in `@safe` code that overlap other fields
    u.sysDg = &s.sysMethod;
    ^
fail_compilation/test13536.d(27): Error: field `U.safeDg` cannot access pointers in `@safe` code that overlap other fields
    u.safeDg();
    ^
---
*/


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
