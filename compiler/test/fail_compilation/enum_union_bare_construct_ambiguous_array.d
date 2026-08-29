/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_construct_ambiguous_array.d(16): Error: `[]` is ambiguous between variants `int[]` and `void[]` of enum union `enum_union_bare_construct_ambiguous_array.Arrs`
---
*/

enum union Arrs
{
    case int[],
    case void[],
}

void test()
{
    Arrs arrs = []; // [] implicitly converts to both int[] and void[]
}
