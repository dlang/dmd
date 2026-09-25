/*
TEST_OUTPUT:
---
fail_compilation/enum_union_tuple_pattern_arity.d(23): Error: incompatible number of components for unpack declaration (`3` vs. `2`)
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
        case Wrapped((first, second, third)) => first + second + third,
        default => 0,
    };
}