/*
TEST_OUTPUT:
---
fail_compilation/fail13116.d(18): Error: cannot `ref` return expression `this` because it is not an lvalue
    ref C evil() { return this; } // this should be rejected
                          ^
fail_compilation/fail13116.d(27): Error: cannot `ref` return expression `super` because it is not an lvalue
    ref Base evil() { return super; } // should be rejected
                             ^
---
*/
struct S
{
    ref S notEvil() return { return this; } // this should be accepted
}
class C
{
    ref C evil() { return this; } // this should be rejected
}
void main()
{
}

class Base { }
class Derived : Base
{
    ref Base evil() { return super; } // should be rejected
}
