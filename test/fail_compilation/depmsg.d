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
fail_compilation/depmsg.d(58): Deprecation: function depmsg.main.Foo.bar1 is deprecated - [C] Use Foo.bar42 instead
fail_compilation/depmsg.d(59): Deprecation: function depmsg.main.Foo.bar2 is deprecated - [E] Use Foo.bar42 instead
fail_compilation/depmsg.d(60): Deprecation: function depmsg.main.Foo.bar3 is deprecated - [S] Use Foo.bar42 instead
fail_compilation/depmsg.d(61): Deprecation: function depmsg.main.Foo.bar4 is deprecated - [F] Use Foo.bar42 instead
fail_compilation/depmsg.d(62): Deprecation: variable depmsg.main.Foo.v2 is deprecated - Forward reference
fail_compilation/depmsg.d(68): Deprecation: class depmsg.main.Obsolete is deprecated
fail_compilation/depmsg.d(68): Deprecation: function depmsg.main.Obsolete.obs is deprecated - Function is obsolete
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

    struct Foo {
        enum DeprecatedReasonEnum = "[E] Use Foo.bar42 instead";
        static const DeprecatedReasonStatic = "[S] Use Foo.bar42 instead";
        static immutable DeprecatedReasonFunc = reason("Foo.bar42");

        static string reason (string name)
        {
            return "[F] Use " ~ name ~ " instead";
        }

        deprecated("[C] Use " ~ `Foo.bar42 instead`)
        void bar1 () {}

        deprecated(DeprecatedReasonEnum)
        void bar2 () {}

        deprecated(DeprecatedReasonStatic)
        void bar3 () {}

        deprecated(DeprecatedReasonFunc)
        void bar4 () {}

        deprecated(Forward ~ Reference) int v2 = 2;
        enum Forward = "Forward ", Reference = "reference";
    }

    Foo f;
    f.bar1;
    f.bar2;
    f.bar3;
    f.bar4;
    assert(f.v2 == 2);

    deprecated class Obsolete {
        deprecated("Function is obsolete") void obs() {}
    }

    (new Obsolete).obs();
}
