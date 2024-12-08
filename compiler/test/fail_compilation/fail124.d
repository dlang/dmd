/*
TEST_OUTPUT:
---
fail_compilation/fail124.d(23): Error: class `fail124.CC` inherits from duplicate interface `C`
class CC : C, C
^
fail_compilation/fail124.d(37): Error: class `fail124.D` inherits from duplicate interface `T`
class D : T, T, T { }
^
fail_compilation/fail124.d(37): Error: class `fail124.D` inherits from duplicate interface `T`
class D : T, T, T { }
^
---
*/

//import std.stdio;

interface C
{
    void f();
}

class CC : C, C
{
    void f() { /*writefln("hello");*/ }
}

void main()
{
    CC cc = new CC();
    cc.f();
}

// https://issues.dlang.org/show_bug.cgi?id=20830
interface T { }

class D : T, T, T { }
