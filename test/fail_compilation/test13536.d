/*
TEST_OUTPUT:
---
fail_compilation/test13536.d(20): Error: field U.safeDg cannot be accessed in @safe code because it overlaps with a pointer
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

