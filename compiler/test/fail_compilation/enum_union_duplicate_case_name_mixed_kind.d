/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_case_name_mixed_kind.d(10): Error: duplicate case `Variant1` in enum union `enum_union_duplicate_case_name_mixed_kind.Test5`
---
*/

// The same name reused across DIFFERENT variant kinds (record vs positional)
// is also rejected.
enum union Test5
{
    case Variant1 { int id; },
    case Variant1(int),
}
