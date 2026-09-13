/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_bare_type.d(8): Error: duplicate case `double` in enum union `enum_union_duplicate_bare_type.LatLong`
---
*/

enum union LatLong
{
    case double,
    case double,
}
