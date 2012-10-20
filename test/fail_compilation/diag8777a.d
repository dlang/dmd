/*
TEST_OUTPUT:
---
fail_compilation/diag8777a.d(3): Error: constructor diag8777a.Foo.this missing initializer for immutable field bar
---
*/

#line 1
class Foo {
    immutable int[5] bar;
    this() {}
}
