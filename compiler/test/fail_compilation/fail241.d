/*
TEST_OUTPUT:
---
fail_compilation/fail241.d(20): Error: mutable method `f` is not callable using a `const` object
fail_compilation/fail241.d(15):        `fail241.Foo.f()` declared here
fail_compilation/fail241.d(15):        Consider adding `const` or `inout`
fail_compilation/fail241.d(21): Error: mutable method `g` is not callable using a `const` object
fail_compilation/fail241.d(16):        `fail241.Foo.g()` declared here
fail_compilation/fail241.d(16):        Consider adding `const` or `inout`
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
