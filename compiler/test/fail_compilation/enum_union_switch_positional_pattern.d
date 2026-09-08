// TEST_OUTPUT:
// ---
// fail_compilation/enum_union_switch_positional_pattern.d(16): Error: pattern for variant `Pair` has 1 argument(s), expected 2
// ---

enum union E
{
    case Pair(int, int),
    case Done,
}

int test(E value)
{
    return switch (value)
    {
        case Pair(1) => 0,
        case Pair(left, right) => left + right,
        case Done => 0,
    };
}
