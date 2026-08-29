/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_case_name_diff_fields.d(12): Error: duplicate case `StructVariant` in enum union `enum_union_duplicate_case_name_diff_fields.Test2`
---
*/

// Same variant name reused with DIFFERENT record fields must still be
// rejected: without an explicit identifier-uniqueness check, this used to
// silently compile since the synthesized factory functions merely looked
// like two ordinary (differently-signatured) D function overloads.
enum union Test2
{
    case StructVariant { int id; },
    case StructVariant { string s; },
}
