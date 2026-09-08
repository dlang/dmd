/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_redundant_default.d(20): Error: redundant match arm; pattern is unreachable
---
*/

enum union Shape
{
    case Circle(double),
    case Point,
}

string describe(Shape shape)
{
    return switch (shape)
    {
        case Circle(radius) => "circle",
        case Point => "point",
        default => "unreachable",
    };
}