/*
REQUIRED_ARGS: -inline
TEST_OUTPUT:
---
fail_compilation/pragmainline2.d(14): Error: function pragmainline2.foo cannot inline function
fail_compilation/pragmainline2.d(22): Error: function pragmainline2.f1t cannot inline function
fail_compilation/pragmainline2.d(25): Error: function pragmainline2.f2t cannot inline function
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
    while (0) { }
}

pragma(inline, true)   void f1t() { while (0) {} }  // cannot inline
pragma(inline, false)  void f1f() { while (0) {} }
pragma(inline)         void f1d() { while (0) {} }
void f2t() { pragma(inline, true);  while (0) {} }  // cannot inline
void f2f() { pragma(inline, false); while (0) {} }
void f2d() { pragma(inline);        while (0) {} }

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
