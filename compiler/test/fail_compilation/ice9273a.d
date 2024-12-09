/*
TEST_OUTPUT:
---
fail_compilation/ice9273a.d(23): Error: constructor `ice9273a.C.__ctor!().this` no match for implicit `super()` call in constructor
    this()() {}
    ^
fail_compilation/ice9273a.d(27): Error: template instance `ice9273a.C.__ctor!()` error instantiating
    auto c = new C();
             ^
---
*/

template CtorMixin()
{
    this(T)() {}
}
class B
{
    mixin CtorMixin!();
}
class C : B
{
    this()() {}
}
void main()
{
    auto c = new C();
}
