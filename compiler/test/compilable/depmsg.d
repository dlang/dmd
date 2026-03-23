/*
REQUIRED_ARGS: -verrors=simple -dw
TEST_OUTPUT:
---
compilable/depmsg.d(52): Deprecation: struct `depmsg.main.Inner.A` is deprecated - With message!
compilable/depmsg.d(39):        `A` is declared here
compilable/depmsg.d(52): Deprecation: struct `depmsg.main.Inner.A` is deprecated - With message!
compilable/depmsg.d(39):        `A` is declared here
compilable/depmsg.d(53): Deprecation: class `depmsg.main.Inner.B` is deprecated - With message!
compilable/depmsg.d(40):        `B` is declared here
compilable/depmsg.d(53): Deprecation: class `depmsg.main.Inner.B` is deprecated - With message!
compilable/depmsg.d(40):        `B` is declared here
compilable/depmsg.d(54): Deprecation: interface `depmsg.main.Inner.C` is deprecated - With message!
compilable/depmsg.d(41):        `C` is declared here
compilable/depmsg.d(54): Deprecation: interface `depmsg.main.Inner.C` is deprecated - With message!
compilable/depmsg.d(41):        `C` is declared here
compilable/depmsg.d(55): Deprecation: union `depmsg.main.Inner.D` is deprecated - With message!
compilable/depmsg.d(42):        `D` is declared here
compilable/depmsg.d(55): Deprecation: union `depmsg.main.Inner.D` is deprecated - With message!
compilable/depmsg.d(42):        `D` is declared here
compilable/depmsg.d(56): Deprecation: enum `depmsg.main.Inner.E` is deprecated - With message!
compilable/depmsg.d(43):        `E` is declared here
compilable/depmsg.d(56): Deprecation: enum `depmsg.main.Inner.E` is deprecated - With message!
compilable/depmsg.d(43):        `E` is declared here
compilable/depmsg.d(58): Deprecation: alias `depmsg.main.Inner.G` is deprecated - With message!
compilable/depmsg.d(45):        `G` is declared here
compilable/depmsg.d(59): Deprecation: variable `depmsg.main.Inner.H` is deprecated - With message!
compilable/depmsg.d(46):        `H` is declared here
compilable/depmsg.d(60): Deprecation: class `depmsg.main.Inner.I()` is deprecated - With message!
compilable/depmsg.d(47):        `I()` is declared here
---
*/
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
