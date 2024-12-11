/*
TEST_OUTPUT:
---
fail_compilation/fail61.d(39): Error: no property `B` for type `fail61.A.B`
    int n2 = A.B.B.C;       // Line22
             ^
fail_compilation/fail61.d(30):        class `B` defined here
    class B : A
    ^
fail_compilation/fail61.d(40): Error: no property `B` for type `fail61.A.B`
    int n3 = A.B.B.B.C;     // Line23
             ^
fail_compilation/fail61.d(30):        class `B` defined here
    class B : A
    ^
fail_compilation/fail61.d(49): Error: no property `A2` for type `fail61.B2`
        B2.A2.foo();        // Line32
        ^
fail_compilation/fail61.d(44):        class `B2` defined here
class B2 : A2 { override void foo(){} }
^
fail_compilation/fail61.d(58): Error: calling non-static function `foo` requires an instance of type `B3`
        B3.foo();           // Line41
              ^
---
*/

class A
{
    class B : A
    {
        static const int C = 5;
    }
}

void main()
{
    int n1 = A.B.C;
    int n2 = A.B.B.C;       // Line22
    int n3 = A.B.B.B.C;     // Line23
}

class A2 { void foo(){ assert(0);} }
class B2 : A2 { override void foo(){} }
class C2 : B2
{
    void bar()
    {
        B2.A2.foo();        // Line32
    }
}

class B3 { void foo(){ assert(0); } }
class C3
{
    void bar()
    {
        B3.foo();           // Line41
    }
}
