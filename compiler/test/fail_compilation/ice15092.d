/*
TEST_OUTPUT:
---
fail_compilation/ice15092.d(19): Error: struct `ice15092.A.S` conflicts with struct `ice15092.A.S` at fail_compilation/ice15092.d(18)
    struct S {}
    ^
fail_compilation/ice15092.d(22): Error: class `ice15092.A.C` conflicts with class `ice15092.A.C` at fail_compilation/ice15092.d(21)
    class C {}
    ^
fail_compilation/ice15092.d(25): Error: interface `ice15092.A.I` conflicts with interface `ice15092.A.I` at fail_compilation/ice15092.d(24)
    interface I {}
    ^
---
*/

class A
{
    struct S {}
    struct S {}

    class C {}
    class C {}

    interface I {}
    interface I {}
}
