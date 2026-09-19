/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_non_union.d(12): Error: switch expression patterns require an enum union condition
---
*/

int test()
{
    return switch (1)
    {
        case value => 0,
        default => 1,
    };
}
