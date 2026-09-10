/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_implicit_ambiguous_integral.d(16): Error: `0` is ambiguous between variants `int` and `long` of enum union `enum_union_bare_implicit_ambiguous_integral.Integral`
---
*/

enum union Integral
{
    case int,
    case long,
}

void main()
{
    Integral value = 0;
}