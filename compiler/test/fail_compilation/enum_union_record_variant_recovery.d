/*
TEST_OUTPUT:
---
fail_compilation/enum_union_record_variant_recovery.d(11): Error: semicolon needed to end declaration of `List` instead of `!`
fail_compilation/enum_union_record_variant_recovery.d(11): Error: declaration expected, not `!`
---
*/

enum union List(T)
{
    case Cons { T value, List!T* tail };
    case typeof(null);
}

void main() {}
