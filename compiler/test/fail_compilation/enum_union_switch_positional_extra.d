/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_positional_extra.d(18): Error: pattern for variant `Pair` has 3 argument(s), expected 2
---
*/

enum union E
{
    case Pair(int, int),
    case Done(),
}

int test(E value)
{
    return switch (value)
    {
        case Pair(left, right, extra) => left + right,
        case Done() => 0,
    };
}
