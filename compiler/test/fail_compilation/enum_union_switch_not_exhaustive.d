/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_not_exhaustive.d(20): Error: switch expression is not exhaustive; missing pattern `Point`
fail_compilation/enum_union_switch_not_exhaustive.d(29): Error: switch expression is not exhaustive; missing pattern `Circle(_)`
fail_compilation/enum_union_switch_not_exhaustive.d(44): Error: switch expression is not exhaustive; missing pattern `Square(_, _)`
fail_compilation/enum_union_switch_not_exhaustive.d(58): Error: switch expression is not exhaustive; missing pattern `typeof(null)`
---
*/

enum union Shape
{
    case Circle(double);
    case Rectangle(double, double);
    case Point();
}

string testMissingVariant(Shape s)
{
    return switch (s)
    {
        case Circle(r) => "circle",
        case Rectangle(w, h) => "rectangle",
    };
}

string testGuardedShape(Shape s)
{
    return switch (s)
    {
        case Circle(r) if (r > 0.0) => "circle",
        case Rectangle(w, h) => "rectangle",
        case Point() => "point",
    };
}

enum union Rect
{
    case Square(int height, int width);
}

int testGuardedMultiField(Rect r)
{
    return switch (r)
    {
        case Square(height, width) if (height > 0) => 1,
    };
}

enum union Value
{
    case Number(int);
    case typeof(null);
}

int testMissingNullVariant(Value v)
{
    return switch (v)
    {
        case Number(value) => value,
    };
}
