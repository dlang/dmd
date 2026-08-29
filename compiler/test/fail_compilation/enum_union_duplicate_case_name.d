/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_case_name.d(10): Error: duplicate case `StructVariant` in enum union `enum_union_duplicate_case_name.Test1`
---
*/

// Two record variants sharing the same name are rejected, even though their
// bodies are identical (or, as tested separately, different).
enum union Test1
{
    case StructVariant {},
    case StructVariant {},
}
