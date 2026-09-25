/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_pattern_binding.d(18): Error: duplicate pattern binding `item`
---
*/

enum union Value
{
    case Pair(int, int);
    case None();
}

int inspect(Value value)
{
    return switch (value)
    {
        case Pair(item, item) => item,
        case None() => 0,
    };
}
