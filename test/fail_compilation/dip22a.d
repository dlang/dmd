/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dip22a.d(19): Error: no property `bar` for type `imports.dip22a.Klass`, did you mean non-visible function `bar`?
fail_compilation/dip22a.d(20): Error: `imports.dip22a.Struct.bar` is not visible from module `dip22a`
fail_compilation/dip22a.d(20): Error: no property `bar` for type `Struct`, did you mean non-visible function `bar`?
fail_compilation/dip22a.d(21): Error: `imports.dip22a.bar` is not visible from module `dip22a`
fail_compilation/dip22a.d(21): Error: undefined identifier `bar` in module `imports.dip22a`, did you mean non-visible function `bar`?
fail_compilation/dip22a.d(22): Error: `imports.dip22a.Template!int.bar` is not visible from module `dip22a`
fail_compilation/dip22a.d(22): Error: no property `bar` for type `void`
fail_compilation/dip22a.d(23): Error: no property `bar` for type `int`
---
*/
import imports.dip22a;

void test()
{
    new Klass().bar();
    Struct().bar();
    imports.dip22a.bar();
    Template!int.bar();
    12.bar();
}
