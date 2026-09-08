/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_guarded_not_exhaustive.d(15): Error: switch expression is not exhaustive; missing pattern `Square(_, _)`
---
*/

enum union Shape
{
    case Square(int height, int width),
}

int describe(Shape shape)
{
    return switch (shape)
    {
        case Square(height, width) if (height > 0) => 1,
    };
}
