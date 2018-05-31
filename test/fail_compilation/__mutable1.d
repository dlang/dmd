/*
TEST_OUTPUT:
---
fail_compilation/__mutable1.d(13): Error: variable `__mutable1.S.mc` cannot be both `__mutable` and `const`
fail_compilation/__mutable1.d(14): Error: variable `__mutable1.S.imc` cannot be both `__mutable` and `immutable`
fail_compilation/__mutable1.d(15): Error: variable `__mutable1.S.pm` `__mutable` fields must be `private`
fail_compilation/__mutable1.d(18): Error: variable `__mutable1.x` only fields can be `__mutable`
---
*/

struct S
{
    private __mutable const int* mc; // error: cannot be both __mutable and const
    private __mutable immutable int* imc; // error: cannot be both __mutable and immutable
    __mutable int* pm; // error: `__mutable` fields must be `private`
}

__mutable int x = 2; // error: only fields can be `__mutable`
