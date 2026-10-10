/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_expression_payload_pattern.d(21): Error: value tests in patterns are not supported; bind the value and use an `if` guard
fail_compilation/enum_union_switch_expression_payload_pattern.d(31): Error: value tests in patterns are not supported; bind the value and use an `if` guard
---
*/

enum union Value
{
    case Number(int);
    case Point { int x; int y; };
}

int nextValue();

int inspectNumber(Value value)
{
    return switch (value)
    {
        case Number(nextValue()) => 1,
        default => 0,
    };
}

int inspectPoint(Value value)
{
    int expected;
    return switch (value)
    {
        case Point { x: expected + 1, y } => y,
        default => 0,
    };
}
