/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23145.d(117): Error: `scope` allocation of `c` requires that constructor be annotated with `scope`
fail_compilation/test23145.d(111):        is the location of the constructor
fail_compilation/test23145.d(124): Error: `scope` allocation of `c` requires that constructor be annotated with `scope`
fail_compilation/test23145.d(111):        is the location of the constructor
fail_compilation/test23145.d(125): Error: `@safe` function `test23145.bax` cannot call `@system` function `test23145.inferred`
fail_compilation/test23145.d(131):        which wasn't inferred `@safe` because of:
fail_compilation/test23145.d(131):        `scope` allocation of `c` requires that constructor be annotated with `scope`
fail_compilation/test23145.d(129):        `test23145.inferred` is declared here
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23145

#line 100

class D
{
    C c;
}

class C
{
    D d;
    int x=3;
    this(int i) scope @safe @nogc;
    this(D d) @safe @nogc;
}

C foo(D d) @nogc @safe
{
    scope e = new C(1);  // ok
    scope c = new C(d);  // error
    return c.d.c;
}

C bax(D d) @safe
{
    scope e = new C(1);  // ok
    scope c = new C(d);  // error
    inferred(d);
    return c.d.c;
}

auto inferred(D d)
{
    scope c = new C(d);  // infer system
}
