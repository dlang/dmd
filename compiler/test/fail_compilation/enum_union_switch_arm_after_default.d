/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_arm_after_default.d(19): Error: redundant match arm; pattern is unreachable
---
*/

enum union Shape
{
    case Circle(double);
    case Point();
}

string describe(Shape shape)
{
    return switch (shape)
    {
        default => "other",
        case Circle(radius) => "circle",
    };
}