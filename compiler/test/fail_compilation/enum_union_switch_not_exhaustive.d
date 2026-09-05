/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_not_exhaustive.d(17): Error: switch expression is not exhaustive; missing variant(s) `Point`
---
*/

enum union Shape
{
    case Circle(double),
    case Rectangle(double, double),
    case Point,
}

string describe(Shape s)
{
    return switch (s)
    {
        case Circle(r) => "circle",
        case Rectangle(w, h) => "rectangle",
        // Point is missing, and there's no `default`.
    };
}
