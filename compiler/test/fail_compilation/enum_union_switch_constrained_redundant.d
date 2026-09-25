/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_constrained_redundant.d(18): Error: redundant match arm; pattern is unreachable
---
*/

enum union Shape
{
    case Square(int height, int width);
}

int describe(Shape shape)
{
    return switch (shape)
    {
        case Square(height, width) => 1,
        case Square(height, width) if (height == 10 && width == 5) => 2,
    };
}
