/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_guard_no_default.d(16): Error: switch expression is not exhaustive; missing pattern `Circle(_)`
---
*/

enum union Shape
{
    case Circle(double),
    case Point(),
}

string missingDefault(Shape s)
{
    return switch (s)
    {
        case Circle(r) if (r > 0.0) => "circle",
        case Point() => "point",
    };
}
