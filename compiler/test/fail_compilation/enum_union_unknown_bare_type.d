/*
TEST_OUTPUT:
---
fail_compilation/enum_union_unknown_bare_type.d(10): Error: unknown type `ExternalStruct`; for a named unit variant, use `case ExternalStruct()`
---
*/

enum union Test
{
    case ExternalStruct,
}