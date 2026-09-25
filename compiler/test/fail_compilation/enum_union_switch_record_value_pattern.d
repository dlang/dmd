/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_record_value_pattern.d(18): Error: value tests in patterns are not supported; bind the value and use an `if` guard
---
*/

enum union Value
{
    case Point { int x; int y; };
    case Empty();
}

int inspect(Value value)
{
    return switch (value)
    {
        case Point { x: 42, y } => y,
        case Point { x, y } => x + y,
        case Empty() => 0,
    };
}
