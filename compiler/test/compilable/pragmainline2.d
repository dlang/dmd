/*
REQUIRED_ARGS: -inline -wi
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
