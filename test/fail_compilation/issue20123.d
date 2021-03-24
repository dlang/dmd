/* TEST_OUTPUT:
---
fail_compilation/issue20123.d(39): Error: can only `@disable` opUnaryRight
fail_compilation/issue20123.d(39): Error: can only `@disable` opUnaryRight
fail_compilation/issue20123.d(40): Error: cannot be used because it is annotated with `@disable`
fail_compilation/issue20123.d(40): Error: cannot be used because it is annotated with `@disable`
fail_compilation/issue20123.d(30): Error: function `issue20123.C.opUnaryRight` isn't a template
fail_compilation/issue20123.d(30): Error: function `issue20123.C.opUnaryRight` isn't a template
fail_compilation/issue20123.d(35): Error: variable `issue20123.D.opUnaryRight().opUnaryRight` isn't a function
fail_compilation/issue20123.d(35): Error: variable `issue20123.D.opUnaryRight().opUnaryRight` isn't a function
---
*/
// https://issues.dlang.org/show_bug.cgi?id=20123

struct A
{
    void opUnary(string s)(){}
    void opUnaryRight(string s)(){}
}

struct B
{
    void opUnary(string s)(){}
    void opUnaryRight(string s)() @disable {}
}

struct C
{
    void opUnary(string s)(){}
    void opUnaryRight() @disable {}
}
struct D
{
    void opUnary(string s)(){}
    template opUnaryRight(){ int opUnaryRight; }
}
void test()
{
    A a; a++; a--;
    B b; b++; b--;
    C c; c++; c--;
    D d; d++; d--;
}

