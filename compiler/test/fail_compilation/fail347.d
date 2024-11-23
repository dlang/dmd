/*
EXTRA_FILES: imports/fail347a.d
TEST_OUTPUT:
---
fail_compilation/fail347.d(36): Error: undefined identifier `bbr`, did you mean variable `bar`?
    bbr.foo = 3;
    ^
fail_compilation/fail347.d(37): Error: no property `ofo` for type `S`, did you mean `fail347.S.foo`?
    bar.ofo = 4;
       ^
fail_compilation/fail347.d(39): Error: no property `fool` for `sp` of type `fail347.S*`
    sp.fool = 5;
      ^
fail_compilation/fail347.d(39):        did you mean variable `foo`?
fail_compilation/fail347.d(40): Error: undefined identifier `strlenx`, did you mean function `strlen`?
    auto s = strlenx("hello");
             ^
fail_compilation/fail347.d(41): Error: no property `strlenx` for `"hello"` of type `string`
    auto q = "hello".strlenx();
                    ^
fail_compilation/fail347.d(41):        did you mean function `strlen`?
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
    auto q = "hello".strlenx();
}
