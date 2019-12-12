
/* TEST_OUTPUT:
---
fail_compilation/mixintype2.d(9): Error: alias `mixintype2.Foo.T` recursive alias declaration
---
*/

struct Foo {
    alias T = mixin("T2");
}
alias T1 = mixin("Foo.T");
alias T2 = mixin("T1");
void func (T2 p) {}
