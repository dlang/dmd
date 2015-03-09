/*
TEST_OUTPUT:
---
fail_compilation/fail13116.d(14): Deprecation: this is not an lvalue
fail_compilation/fail13116.d(14): Error: escaping reference to local variable this
---
*/
struct S
{
    ref S notEvil() { return this; } // this should be accepted
}
class C
{
    ref C evil() { return this; } // this should be rejected
}
void main()
{
}

/*
TEST_OUTPUT:
---
fail_compilation/fail13116.d(30): Deprecation: super is not an lvalue
fail_compilation/fail13116.d(30): Error: escaping reference to local variable this
---
*/
class Base { }
class Derived : Base
{
    ref Base evil() { return super; } // should be rejected
}
