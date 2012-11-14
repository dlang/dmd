/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/depmsg.d(20): Deprecation: struct depmsg.main.Inner.A is deprecated - With message!
fail_compilation/depmsg.d(20): Deprecation: struct depmsg.main.Inner.A is deprecated - With message!
fail_compilation/depmsg.d(21): Deprecation: class depmsg.main.Inner.B is deprecated - With message!
fail_compilation/depmsg.d(21): Deprecation: class depmsg.main.Inner.B is deprecated - With message!
fail_compilation/depmsg.d(22): Deprecation: interface depmsg.main.Inner.C is deprecated - With message!
fail_compilation/depmsg.d(22): Deprecation: interface depmsg.main.Inner.C is deprecated - With message!
fail_compilation/depmsg.d(23): Deprecation: union depmsg.main.Inner.D is deprecated - With message!
fail_compilation/depmsg.d(23): Deprecation: union depmsg.main.Inner.D is deprecated - With message!
fail_compilation/depmsg.d(24): Deprecation: enum depmsg.main.Inner.E is deprecated - With message!
fail_compilation/depmsg.d(24): Deprecation: enum depmsg.main.Inner.E is deprecated - With message!
fail_compilation/depmsg.d(26): Deprecation: alias depmsg.main.Inner.G is deprecated - With message!
fail_compilation/depmsg.d(27): Deprecation: variable depmsg.main.Inner.H is deprecated - With message!
fail_compilation/depmsg.d(28): Deprecation: class depmsg.main.Inner.I!().I is deprecated - With message!
---
*/

#line 1
void main()
{
    class Inner
    {
        deprecated("With message!")
        {
            struct A { }
            class B { }
            interface C { }
            union D { }
            enum E { e };
            //typedef int F;
            alias int G;
            static int H;
            template I() { class I {} }
        }
    }
    with(Inner)
    {
        A a;
        B b;
        C c;
        D d;
        E e;
        //F f;
        G g;
        auto h = H;
        I!() i;
    }
}
