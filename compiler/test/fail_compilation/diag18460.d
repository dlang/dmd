/*
TEST_OUTPUT:
---
fail_compilation/diag18460.d(14): Error: no property `opCall` for type `diag18460.Foo`, did you mean `new Foo`?
    auto f = Foo();
             ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=18460

class Foo {}

void main() {
    auto f = Foo();
}
