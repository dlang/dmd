/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_redundant.d(22): Error: redundant match arm; pattern is unreachable
fail_compilation/enum_union_switch_redundant.d(31): Error: redundant match arm; pattern is unreachable
fail_compilation/enum_union_switch_redundant.d(42): Error: redundant match arm; pattern is unreachable
fail_compilation/enum_union_switch_redundant.d(52): Error: redundant match arm; pattern is unreachable
---
*/

enum union Shape
{
    case Circle(double);
    case Point();
}

string testArmAfterDefault(Shape shape)
{
    return switch (shape)
    {
        default => "other",
        case Circle(radius) => "circle",
    };
}

int testConstrainedAfterUnconstrained(Shape shape)
{
    return switch (shape)
    {
        case Circle(radius) => 1,
        case Circle(radius) if (radius > 10) => 2,
        default => 0,
    };
}

string testDuplicateArm(Shape shape)
{
    return switch (shape)
    {
        case Circle(r) => "circle",
        case Point() => "point",
        case Point() => "point again",
    };
}

string testDefaultAfterExhaustive(Shape shape)
{
    return switch (shape)
    {
        case Circle(radius) => "circle",
        case Point() => "point",
        default => "unreachable",
    };
}
