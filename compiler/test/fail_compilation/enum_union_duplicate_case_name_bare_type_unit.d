/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_case_name_bare_type_unit.d(10): Error: duplicate case `ExternalStruct` in enum union `enum_union_duplicate_case_name_bare_type_unit.Test`
---
*/

struct ExternalStruct {}

enum union Test
{
    case ExternalStruct,
    case ExternalStruct(),
}