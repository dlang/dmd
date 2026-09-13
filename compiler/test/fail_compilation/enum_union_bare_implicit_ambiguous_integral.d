/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_implicit_ambiguous_integral.d(19): Error: `enum_union_bare_implicit_ambiguous_integral.Integral.__ctor` called with argument types `(int)` matches multiple overloads after implicit conversions:
fail_compilation/enum_union_bare_implicit_ambiguous_integral.d(11):     `enum_union_bare_implicit_ambiguous_integral.Integral.this(short __enumPayloadParam11)`
and:
fail_compilation/enum_union_bare_implicit_ambiguous_integral.d(11):     `enum_union_bare_implicit_ambiguous_integral.Integral.this(ushort __enumPayloadParam12)`
---
*/

enum union Integral
{
    case short,
    case ushort,
}

void main()
{
    Integral value = 0;
}