/*
TEST_OUTPUT:
---
fail_compilation/ice9273b.d(16): Error: constructor `ice9273b.B.this` no match for implicit `super()` call in constructor
    this() {}
    ^
---
*/

class A
{
    this(T)() {}
}
class B : A
{
    this() {}
}
