/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_missing_null_variant.d(14): Error: switch expression is not exhaustive; missing pattern `typeof(null)`
---
*/

enum union Value
{
    case Number(int);
    case typeof(null);
}

int result = switch (Value.Number(1))
{
    case Number(value) => value,
};