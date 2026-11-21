/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_positional_arity.d(19): Error: pattern for variant `Pair` has 1 argument(s), expected 2
fail_compilation/enum_union_switch_positional_arity.d(28): Error: pattern for variant `Pair` has 3 argument(s), expected 2
---
*/

enum union E
{
    case Pair(int, int);
    case Done();
}

int testFew(E value)
{
    return switch (value)
    {
        case Pair(1) => 0,
        default => 0,
    };
}

int testExtra(E value)
{
    return switch (value)
    {
        case Pair(left, right, extra) => left + right,
        default => 0,
    };
}
