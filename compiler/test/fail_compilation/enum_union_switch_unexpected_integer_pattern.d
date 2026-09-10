/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_unexpected_integer_pattern.d(18): Error: switch expression value and expression patterns are not supported; use a named variant or type pattern
---
*/

enum union Value
{
    case int,
    case string,
}

string classify(Value value)
{
    return switch (value)
    {
        case 0 => "zero",
        case int => "integer",
        case string => "string",
    };
}