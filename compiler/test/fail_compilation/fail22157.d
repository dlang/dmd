// https://issues.dlang.org/show_bug.cgi?id=22157

/*
TEST_OUTPUT:
---
fail_compilation/fail22157.d(36): Error: `fail22157.S!true.S.foo` called with argument types `()` matches both:
fail_compilation/fail22157.d(25):     `fail22157.S!true.S.foo()`
and:
fail_compilation/fail22157.d(26):     `fail22157.S!true.S.foo()`
    S!true.foo;
    ^
fail_compilation/fail22157.d(37): Error: `fail22157.S!false.S.foo` called with argument types `()` matches both:
fail_compilation/fail22157.d(30):     `fail22157.S!false.S.foo()`
and:
fail_compilation/fail22157.d(31):     `fail22157.S!false.S.foo()`
    S!false.foo;
    ^
---
*/

struct S(bool b)
{
    static if(b)
    {
        void foo() {}
        static void foo() {}
    }
    else
    {
        static void foo() {}
        void foo() {}
    }
}

void main() {
    S!true.foo;
    S!false.foo;
}
