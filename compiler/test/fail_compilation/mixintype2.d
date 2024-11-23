
/* TEST_OUTPUT:
---
fail_compilation/mixintype2.d(21): Error: alias `mixintype2.Foo.T` recursive alias declaration
    alias T = mixin("T2");
    ^
fail_compilation/mixintype2.d(27): Error: `mixin(0)` does not give a valid type
enum mixin(0) a = 0;
     ^
fail_compilation/mixintype2.d(28): Error: unexpected token `{` after type `int()`
mixin("int() {}") f;
                  ^
fail_compilation/mixintype2.d(28):        while parsing string mixin type `int() {}`
fail_compilation/mixintype2.d(28): Error: `mixin(_error_)` does not give a valid type
mixin("int() {}") f;
^
---
*/

struct Foo {
    alias T = mixin("T2");
}
alias T1 = mixin("Foo.T");
alias T2 = mixin("T1");
void func (T2 p) {}

enum mixin(0) a = 0;
mixin("int() {}") f;
