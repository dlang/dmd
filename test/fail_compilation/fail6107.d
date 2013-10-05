/*
TEST_OUTPUT:
---
fail_compilation/fail6107.d(8): Error: struct fail6107.Foo variable __ctor is not a constructor; identifiers starting with __ are reserved for the implementation
fail_compilation/fail6107.d(11): Error: class fail6107.Bar variable __ctor is not a constructor; identifiers starting with __ are reserved for the implementation
---
*/
struct Foo {
    enum __ctor = 4;
}
class Bar {
    int __ctor = 4;
}

