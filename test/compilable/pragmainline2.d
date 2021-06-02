/*
REQUIRED_ARGS: -inline -wi
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
