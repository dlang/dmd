/*
TEST_OUTPUT:
---
fail_compilation/enum_union_base_type.d(8): Error: enum union declarations cannot have a base type
---
*/

enum union Value : int
{
    case None();
}
