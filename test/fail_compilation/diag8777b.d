/*
TEST_OUTPUT:
---
fail_compilation/diag8777b.d(3): Error: constructor diag8777b.Foo.this missing initializer for const field bar
---
*/

#line 1
class Foo {
    const int[5] bar;
    this() {}
}
