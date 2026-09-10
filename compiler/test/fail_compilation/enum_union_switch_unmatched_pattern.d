/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_unmatched_pattern.d(18): Error: switch expression call pattern `Square` does not name a variant of `enum_union_switch_unmatched_pattern.Shape`
---
*/

enum union Shape
{
    case Circle(double),
    case Point(),
}

string describe(Shape s)
{
    return switch (s)
    {
        case Square(r) => "square", // no such variant
        case Point() => "point",
        default => "circle",
    };
}
