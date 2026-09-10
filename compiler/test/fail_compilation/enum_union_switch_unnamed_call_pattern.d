/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_unnamed_call_pattern.d(17): Error: switch expression call pattern requires a named variant callee
---
*/

enum union Value
{
    case int,
}

int classify(Value value)
{
    return switch (value)
    {
        case (0)(1) => 0,
        case int => 1,
    };
}