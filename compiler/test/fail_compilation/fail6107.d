/*
TEST_OUTPUT:
---
fail_compilation/fail6107.d(14): Error: variable `fail6107.Foo.__ctor` is not a constructor; identifiers starting with `__` are reserved for the implementation
    enum __ctor = 4;
         ^
fail_compilation/fail6107.d(18): Error: variable `fail6107.Bar.__ctor` is not a constructor; identifiers starting with `__` are reserved for the implementation
    int __ctor = 4;
        ^
---
*/
struct Foo
{
    enum __ctor = 4;
}
class Bar
{
    int __ctor = 4;
}
