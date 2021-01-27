// https://issues.dlang.org/show_bug.cgi?id=21538
/*
TEST_OUTPUT:
---
fail_compilation/fail21538.d(17): Error: function `const @safe void fail21538.C.f(const(void delegate() @safe) dg)` does not override any function, did you mean to override `const @safe void fail21538.I.f(const(void delegate()) dg)`?
---
*/

interface I
{
    void f(const void delegate() dg) const @safe;
}

class C : I
{
    // this overrride should not be legal
    override void f(const void delegate() @safe dg) const @safe { }
}

void main() @safe
{
    const void delegate() @system dg = { };
    C c = new C;
    // c.f(dg); // error, expected
    (cast(I) c).f(dg); // no error
}
