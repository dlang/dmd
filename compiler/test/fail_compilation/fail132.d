/*
TEST_OUTPUT:
---
fail_compilation/fail132.d(21): Error: cannot construct nested class `B` because no implicit `this` reference to outer class `A` is available
    A.B c = new A.B;
            ^
---
*/

//import std.stdio;

class A
{
    class B
    {
    }
}

void main()
{
    A.B c = new A.B;
}
