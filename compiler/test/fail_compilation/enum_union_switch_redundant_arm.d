/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_redundant_arm.d(20): Error: redundant match arm; pattern is unreachable
---
*/

enum union Shape
{
    case Circle(double),
    case Point,
}

string describe(Shape s)
{
    return switch (s)
    {
        case Circle(r) => "circle",
        case Point => "point",
        case Point => "point again", // already covered by the earlier arm
    };
}
