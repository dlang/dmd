// https://github.com/dlang/dmd/issues/23551
// EXTRA_CPP_SOURCES: test23551.cpp
// EXTRA_FILES: test23551.h

extern(C++)
class Base
{
    int i;
    this();
    int f();
}

extern(C++) interface Interface
{
    int g();
}

extern(C++) class C : Base, Interface
{
    this();
    int g();
}

class D : C
{
    this(){}
    override extern(C++) int g()
    {
        return 4000 + i;
    }
}

extern(C++) interface Interface2
{
    int g2();
    int g3();
}

extern(C++) interface Interface3
{
    int g4();
    int g5();
}

extern(C++) class E : C, Interface2, Interface3
{
    this();
    int g2();
    int g3();
    int g4();
    int g5();
}

class F : E
{
    this(){}
    override extern(C++) int g()
    {
        return 6100 + i;
    }
    override extern(C++) int g2()
    {
        return 6200 + i;
    }
    override extern(C++) int g5()
    {
        return 6500 + i;
    }
}

void main()
{
    {
        auto o = new C();
        o.i = 1;
        assert(o.f() == 1001);
        assert(o.g() == 3001);
        Interface x = o;
        assert(x.g() == 3001);
    }
    {
        auto o = new D();
        o.i = 2;
        assert(o.f() == 1002);
        assert(o.g() == 4002);
        Interface x = o;
        assert(x.g() == 4002);
    }
    {
        auto o = new E();
        o.i = 3;
        assert(o.f() == 1003);
        assert(o.g() == 3003);
        assert(o.g2() == 5203);
        assert(o.g3() == 5303);
        assert(o.g4() == 5403);
        assert(o.g5() == 5503);
        Interface x = o;
        assert(x.g() == 3003);
        Interface2 x2 = o;
        assert(x2.g2() == 5203);
        assert(x2.g3() == 5303);
        Interface3 x3 = o;
        assert(x3.g4() == 5403);
        assert(x3.g5() == 5503);
    }
    {
        auto o = new F();
        o.i = 4;
        assert(o.f() == 1004);
        assert(o.g() == 6104);
        assert(o.g2() == 6204);
        assert(o.g3() == 5304);
        assert(o.g4() == 5404);
        assert(o.g5() == 6504);
        Interface x = o;
        assert(x.g() == 6104);
        Interface2 x2 = o;
        assert(x2.g2() == 6204);
        assert(x2.g3() == 5304);
        Interface3 x3 = o;
        assert(x3.g4() == 5404);
        assert(x3.g5() == 6504);
    }
}
