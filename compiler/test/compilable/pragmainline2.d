/*
REQUIRED_ARGS: -verrors=simple -inline -wi
TEST_OUTPUT:
---
compilable/pragmainline2.d(14): Warning: cannot inline function `pragmainline2.foo`
compilable/pragmainline2.d(22): Warning: cannot inline function `pragmainline2.f1t`
compilable/pragmainline2.d(25): Warning: cannot inline function `pragmainline2.f2t`
---
*/

pragma(inline, true):
pragma(inline, false):
pragma(inline)
void foo()
{
    pragma(inline, false);
    pragma(inline);
    pragma(inline, true);   // this last one will affect to the 'foo'
    asm { nop; }
}

pragma(inline, true)   void f1t() { asm { nop; } }  // cannot inline
pragma(inline, false)  void f1f() { asm { nop; } }
pragma(inline)         void f1d() { asm { nop; } }
void f2t() { pragma(inline, true);  asm { nop; } }  // cannot inline
void f2f() { pragma(inline, false); asm { nop; } }
void f2d() { pragma(inline);        asm { nop; } }

void main()
{
    foo();

    f1t();
    f1f();
    f1d();
    f2t();
    f2f();
    f2d();
}

/*
TEST_OUTPUT:
---
compilable/pragmainline2.d(50): Warning: cannot inline function `pragmainline2.jazz`
compilable/pragmainline2.d(63): Warning: cannot inline function `pragmainline2.metal`
---
*/

pragma(inline, true)
auto jazz()
{
    static struct U
    {
        int a = 42;
        float b;
        ~this(){} // __dtor: inline not allowed
    }
    U u;
    return u.a;
}

pragma(inline, true)
auto metal()
{
    class U   // class : inline not allowed
    {
        int a = 42;
        float b;
    }
    return (new U).a;
}

void music()
{
    auto f = jazz();
    auto b = metal();
}

// test inlining in core.internal.convert for hash generation
bool test_toUByte()
{
    import core.internal.convert;

    const(ubyte)[] ubarr;
    int[] iarr = [1, 2, 3];
    ubarr = toUbyte(iarr);
    char[] carr = [1, 2, 3];
    ubarr = toUbyte(carr);
    long lng = 42;
    ubarr = toUbyte(lng);
    char ch = 42;
    ubarr = toUbyte(ch);
    static if(is(__vector(int[4])))
    {
        __vector(int[4]) vint = [1, 2, 3, 4];
        ubarr = toUbyte(vint);
    }
    enum E { E1, E2, E3 }
    E eval = E.E1;
    ubarr = toUbyte(eval);
    void delegate() dg;
    ubarr = toUbyte(dg);
    struct S { int x; }
    S sval;
    ubarr = toUbyte(sval);
	return true;
}
static assert(test_toUByte());

void test_newaa()
{
    // inlining of newaa.pure_keyEqual, newaa.compat_key, newaa.pure_hashOf
    // must be disabled for nested structs
    struct UnsafeElement
    {
        int i;
        static bool b;
        ~this(){
            int[] arr;
            void* p = arr.ptr + 1; // unsafe
        }
    }
    UnsafeElement[int] aa1;
    int[UnsafeElement] aa2;
    aa1[1] = UnsafeElement();
    assert(0 !in aa1);
    assert(aa1 == aa1);
    assert(UnsafeElement() !in aa2);
    aa2[UnsafeElement()] = 1;

    // test inlining of hashOf(Interface)
    static interface Iface
    {
        void foo();
    }
    Iface[int] aa3;
    int[Iface] aa4;
}
