/*
EXTRA_FILES: imports/dip22a.d
TEST_OUTPUT:
---
fail_compilation/dip22a.d(32): Error: no property `bar` for `new Klass` of type `imports.dip22a.Klass`
    new Klass().bar();
               ^
fail_compilation/imports/dip22a.d(3):        class `Klass` defined here
class Klass
^
fail_compilation/dip22a.d(33): Error: no property `bar` for `Struct()` of type `imports.dip22a.Struct`
    Struct().bar();
            ^
fail_compilation/imports/dip22a.d(8):        struct `Struct` defined here
struct Struct
^
fail_compilation/dip22a.d(34): Error: undefined identifier `bar` in module `imports.dip22a`
    imports.dip22a.bar();
                  ^
fail_compilation/dip22a.d(35): Error: no property `bar` for `Template!int` of type `void`
    Template!int.bar();
                ^
fail_compilation/dip22a.d(36): Error: no property `bar` for `12` of type `int`
    12.bar();
      ^
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
