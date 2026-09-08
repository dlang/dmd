// TEST_OUTPUT:
// ---
// fail_compilation/enum_union_switch_duplicate_default.d(17): Error: duplicate `default` arm in switch expression
// ---

enum union E
{
    case A,
}

int test(E value)
{
    return switch (value)
    {
        case A => 0,
        default => 1,
        default => 2,
    };
}
