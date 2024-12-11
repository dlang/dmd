/*
REQUIRED_ARGS: -dw
TEST_OUTPUT:
---
compilable/depmsg.d(65): Deprecation: struct `depmsg.main.Inner.A` is deprecated - With message!
        A a;
          ^
compilable/depmsg.d(65): Deprecation: struct `depmsg.main.Inner.A` is deprecated - With message!
        A a;
          ^
compilable/depmsg.d(66): Deprecation: class `depmsg.main.Inner.B` is deprecated - With message!
        B b;
          ^
compilable/depmsg.d(66): Deprecation: class `depmsg.main.Inner.B` is deprecated - With message!
        B b;
          ^
compilable/depmsg.d(67): Deprecation: interface `depmsg.main.Inner.C` is deprecated - With message!
        C c;
          ^
compilable/depmsg.d(67): Deprecation: interface `depmsg.main.Inner.C` is deprecated - With message!
        C c;
          ^
compilable/depmsg.d(68): Deprecation: union `depmsg.main.Inner.D` is deprecated - With message!
        D d;
          ^
compilable/depmsg.d(68): Deprecation: union `depmsg.main.Inner.D` is deprecated - With message!
        D d;
          ^
compilable/depmsg.d(69): Deprecation: enum `depmsg.main.Inner.E` is deprecated - With message!
        E e;
          ^
compilable/depmsg.d(69): Deprecation: enum `depmsg.main.Inner.E` is deprecated - With message!
        E e;
          ^
compilable/depmsg.d(71): Deprecation: alias `depmsg.main.Inner.G` is deprecated - With message!
        G g;
          ^
compilable/depmsg.d(72): Deprecation: variable `depmsg.main.Inner.H` is deprecated - With message!
        auto h = H;
                 ^
compilable/depmsg.d(73): Deprecation: class `depmsg.main.Inner.I()` is deprecated - With message!
        I!() i;
        ^
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
