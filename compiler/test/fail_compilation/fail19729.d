/*
TEST_OUTPUT:
---
fail_compilation/fail19729.d(39): Error: `fail19729.C.__ctor` called with argument types `(string)` matches both:
fail_compilation/fail19729.d(22):     `fail19729.C.Templ!string.this(string t)`
and:
fail_compilation/fail19729.d(22):     `fail19729.C.Templ!string.this(string t)`
    new C("conflict");
    ^
fail_compilation/fail19729.d(40): Error: `fail19729.D.__ctor` called with argument types `(string)` matches both:
fail_compilation/fail19729.d(22):     `fail19729.D.Templ!(const(char)[]).this(const(char)[] t)`
and:
fail_compilation/fail19729.d(22):     `fail19729.D.Templ!(const(char)*).this(const(char)* t)`
    new D("conflict");
    ^
---
*/
module fail19729;

mixin template Templ(T)
{
    this(T t) { }
}

class C
{
    mixin Templ!string;
    mixin Templ!string;
}

class D
{
    mixin Templ!(const(char)*);
    mixin Templ!(const(char)[]);
}

void main()
{
    new C("conflict");
    new D("conflict");
}
