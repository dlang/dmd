/*
TEST_OUTPUT:
---
fail_compilation/fail241.d(26): Error: mutable method `fail241.Foo.f` is not callable using a `const` object
        f();  // error, cannot call public member function from invariant
         ^
fail_compilation/fail241.d(21):        Consider adding `const` or `inout` here
    public void f() { }
                ^
fail_compilation/fail241.d(27): Error: mutable method `fail241.Foo.g` is not callable using a `const` object
        g();  // ok, g() is not public
         ^
fail_compilation/fail241.d(22):        Consider adding `const` or `inout` here
    private void g() { }
                 ^
---
*/

class Foo
{
    public void f() { }
    private void g() { }

    invariant()
    {
        f();  // error, cannot call public member function from invariant
        g();  // ok, g() is not public
    }
}
