/*
TEST_OUTPUT:
---
fail_compilation/enum_union_tuple_pattern_value.d(23): Error: value tests in tuple patterns are not supported; bind the value and use an `if` guard
---
*/

struct Tuple(T...)
{
    T expand;
    alias expand this;
}

enum union Value
{
    case Wrapped(Tuple!(int, int));
}

int inspect(Value value)
{
    return switch (value)
    {
        case Wrapped((1, right)) => right,
        default => 0,
    };
}