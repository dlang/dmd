/*
TEST_OUTPUT:
---
fail_compilation/test9176.d(12): Error: forward reference to get
---
*/

void foo(int x) {}
static assert(!is(typeof(foo(S()))));

struct S {
    auto get() { return get(); }
    alias get this;
}
void main(){}
