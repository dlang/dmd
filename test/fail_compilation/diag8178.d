/*
TEST_OUTPUT:
---
fail_compilation/diag8178.d(5): Error: Cannot modify '""'
---
*/

#line 1
struct Foo {
    enum string s = "";
}
void main() {
    Foo.s = "";
}
