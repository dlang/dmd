/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_implicit_ambiguous_null.d(19): Error: `enum_union_bare_implicit_ambiguous_null.Pointers.__ctor` called with argument types `(typeof(null))` matches multiple overloads after qualifier conversion:
fail_compilation/enum_union_bare_implicit_ambiguous_null.d(11):     `enum_union_bare_implicit_ambiguous_null.Pointers.this(int* __enumPayloadParam11)`
and:
fail_compilation/enum_union_bare_implicit_ambiguous_null.d(11):     `enum_union_bare_implicit_ambiguous_null.Pointers.this(bool* __enumPayloadParam12)`
---
*/

enum union Pointers
{
    case int*,
    case bool*,
}

void main()
{
    Pointers pointers = null;
}