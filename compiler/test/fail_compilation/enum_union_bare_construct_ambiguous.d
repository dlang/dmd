/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_construct_ambiguous.d(47): Error: `[]` is ambiguous between variants `int[]` and `void[]` of enum union `enum_union_bare_construct_ambiguous.Arrs`
fail_compilation/enum_union_bare_construct_ambiguous.d(48): Error: `() { }` is ambiguous between variants `void function()` and `void delegate()` of enum union `enum_union_bare_construct_ambiguous.Funs`
fail_compilation/enum_union_bare_construct_ambiguous.d(49): Error: `enum_union_bare_construct_ambiguous.Pointers.__ctor` called with argument types `(typeof(null))` matches multiple overloads after qualifier conversion:
fail_compilation/enum_union_bare_construct_ambiguous.d(33):     `enum_union_bare_construct_ambiguous.Pointers.this(int* __enumPayloadParam33)`
and:
fail_compilation/enum_union_bare_construct_ambiguous.d(33):     `enum_union_bare_construct_ambiguous.Pointers.this(bool* __enumPayloadParam34)`
fail_compilation/enum_union_bare_construct_ambiguous.d(50): Error: `enum_union_bare_construct_ambiguous.Integral.__ctor` called with argument types `(int)` matches multiple overloads after implicit conversions:
fail_compilation/enum_union_bare_construct_ambiguous.d(39):     `enum_union_bare_construct_ambiguous.Integral.this(short __enumPayloadParam41)`
and:
fail_compilation/enum_union_bare_construct_ambiguous.d(39):     `enum_union_bare_construct_ambiguous.Integral.this(ushort __enumPayloadParam42)`
fail_compilation/enum_union_bare_construct_ambiguous.d(51): Error: `enum_union_bare_construct_ambiguous.Pointers.__ctor` called with argument types `(typeof(null))` matches multiple overloads after qualifier conversion:
fail_compilation/enum_union_bare_construct_ambiguous.d(33):     `enum_union_bare_construct_ambiguous.Pointers.this(int* __enumPayloadParam33)`
and:
fail_compilation/enum_union_bare_construct_ambiguous.d(33):     `enum_union_bare_construct_ambiguous.Pointers.this(bool* __enumPayloadParam34)`
---
*/

enum union Arrs
{
    case int[];
    case void[];
}

enum union Funs
{
    case void function();
    case void delegate();
}

enum union Pointers
{
    case int*;
    case bool*;
}

enum union Integral
{
    case short;
    case ushort;
}

void main()
{
    Arrs arrs = [];
    Funs f = (){};
    Pointers p1 = Pointers(null);
    Integral i = 0;
    Pointers p2 = null;
}
