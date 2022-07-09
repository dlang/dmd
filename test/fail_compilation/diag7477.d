/*
TEST_OUTPUT:
---
fail_compilation/diag7477.d(15): Deprecation: Enum `diag7477.Bar` has base type `Foo` with non-zero .init; initialize the enum member explicitly
fail_compilation/diag7477.d(15): Error: integral constant must be scalar type, not `Foo`
fail_compilation/diag7477.d(20): Error: no property `max` for type `string`
fail_compilation/diag7477.d(23): Error: incompatible types for `(null) + (1)`: `Baz` and `int`
---
*/

struct Foo { int x; }

enum Bar : Foo
{
    a,
    b,
    c
}

enum Baz : string
{
    a,
    b,
}
