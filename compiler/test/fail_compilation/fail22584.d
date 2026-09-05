// https://github.com/dlang/dmd/issues/22584
/*
TEST_OUTPUT:
---
fail_compilation/fail22584.d(14): Error: variable `x` is shadowing variable `fail22584.main.__foreachbody_L14_C5.x`
fail_compilation/fail22584.d(14):        declared here
---
*/

struct Foo {
    int opApply(scope int delegate(size_t, size_t, ref uint)) => 0;
}
void main() {
    foreach (x, y, x; Foo()) {}
}
