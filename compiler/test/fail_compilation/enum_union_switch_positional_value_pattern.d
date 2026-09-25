/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_positional_value_pattern.d(18): Error: value tests in patterns are not supported; bind the value and use an `if` guard
---
*/

enum union Value
{
    case Number(int);
    case Empty();
}

int inspect(Value value)
{
    return switch (value)
    {
        case Number(42) => 1,
        case Number(number) => number,
        case Empty() => 0,
    };
}