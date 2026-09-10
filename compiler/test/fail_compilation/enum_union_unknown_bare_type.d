/*
TEST_OUTPUT:
---
fail_compilation/enum_union_unknown_bare_type.d(10): Error: undefined identifier `ExternalStruct`
---
*/

enum union Test
{
    case ExternalStruct,
}