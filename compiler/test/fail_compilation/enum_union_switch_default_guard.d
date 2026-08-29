/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_default_guard.d(19): Error: `default` arm cannot have an `if` guard
---
*/

enum union Shape
{
    case Circle(double),
    case Point,
}

string guardedDefault(Shape s)
{
    return switch (s)
    {
        case Circle(r) => "circle",
        default if (true) => "point",
    };
}
