/*
EXTRA_FILES: imports/fail347a.d
TEST_OUTPUT:
---
fail_compilation/fail347.d(24): Error: undefined identifier `bbr`, did you mean variable `bar`?
fail_compilation/fail347.d(25): Error: no property `ofo` for type `S`, did you mean `fail347.S.foo`?
fail_compilation/fail347.d(27): Error: no property `fool` for `sp` of type `fail347.S*`
fail_compilation/fail347.d(27):        did you mean variable `foo`?
fail_compilation/fail347.d(28): Error: undefined identifier `strlenx`, did you mean function `strlen`?
---
*/

//import core.stdc.string;
import imports.fail347a;

struct S
{
    int foo;
}

void main()
{
    S bar;
    bbr.foo = 3;
    bar.ofo = 4;
    auto sp = &bar;
    sp.fool = 5;
    auto s = strlenx("hello");
}
