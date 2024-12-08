/*
https://issues.dlang.org/show_bug.cgi?id=18385

TEST_OUTPUT:
---
fail_compilation/fail2789.d(38): Error: function `fail2789.A2789.m()` conflicts with previous declaration at fail_compilation/fail2789.d(33)
    float m()       // conflict
          ^
fail_compilation/fail2789.d(63): Error: function `fail2789.f4()` conflicts with previous declaration at fail_compilation/fail2789.d(62)
void f4() {}    // conflict
     ^
fail_compilation/fail2789.d(69): Error: function `fail2789.f6()` conflicts with previous declaration at fail_compilation/fail2789.d(68)
auto f6() { return ""; }    // string(), conflict
     ^
fail_compilation/fail2789.d(72): Error: function `fail2789.f_ExternC1()` conflicts with previous declaration at fail_compilation/fail2789.d(71)
extern(C) void f_ExternC1() {}      // conflict
               ^
fail_compilation/fail2789.d(75): Error: function `fail2789.f_ExternC2` cannot overload `extern(C)` function at fail_compilation/fail2789.d(74)
extern(C) void f_ExternC2(int) {}   // conflict
               ^
fail_compilation/fail2789.d(78): Error: function `fail2789.f_ExternC3` cannot overload `extern(C)` function at fail_compilation/fail2789.d(77)
extern(C) void f_ExternC3() {}      // conflict
               ^
fail_compilation/fail2789.d(102): Error: function `fail2789.mul14147(const(int[]) left, const(int[]) right)` conflicts with previous declaration at fail_compilation/fail2789.d(98)
pure auto mul14147(const int[] left, const int[] right)
          ^
---
*/
// Line 7 starts here

class A2789
{
    int m()
    {
        return 1;
    }

    float m()       // conflict
    {
        return 2.0;
    }

    float m() const // doen't conflict
    {
        return 3.0;
    }

    static void m() // no conflict
    {
    }
}

void f1();
void f1() {}    // ok

void f2() {}
void f2();      // ok

void f3();
void f3();      // ok

void f4() {}
void f4() {}    // conflict

void f5() @safe {}
void f5() @system {}    // no conflict because of attribute based overloading in in extern(D)

auto f6() { return 10; }    // int()
auto f6() { return ""; }    // string(), conflict

extern(C) void f_ExternC1() {}
extern(C) void f_ExternC1() {}      // conflict

extern(C) void f_ExternC2() {}
extern(C) void f_ExternC2(int) {}   // conflict

extern(C) void f_ExternC3(int) {}
extern(C) void f_ExternC3() {}      // conflict

extern (D) void f_MixExtern1() {}
extern (C) void f_MixExtern1() {}   // no conflict because of different mangling

extern (D) void f_MixExtern2(int) {}
extern (C) void f_MixExtern2() {}   // no error

extern (C) void f_ExternC4(int sig);
extern (C) void f_ExternC4(int sig) @nogc;      // no error

extern (C) void f_ExternC5(int sig) {}
extern (C) void f_ExternC5(int sig) @nogc;      // no error

extern (C) void f_ExternC6(int sig);
extern (C) void f_ExternC6(int sig) @nogc {}    // no error

struct S14147(alias func)
{
}
pure auto mul14147(const int[] left, const int[] right)
{
    S14147!(a => a) s;
}
pure auto mul14147(const int[] left, const int[] right)
{
    S14147!(a => a) s;
}
