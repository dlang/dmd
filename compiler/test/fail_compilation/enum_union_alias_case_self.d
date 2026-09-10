/*
TEST_OUTPUT:
---
fail_compilation/enum_union_alias_case_self.d(12): Error: `case C1 = C1` cannot alias itself, use a qualified name
---
*/

class C1 {}

enum union Pointers
{
    case C1 = C1,
}