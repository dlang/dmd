/*
TEST_OUTPUT:
---
fail_compilation/fail21928b.d(20): Error: array literal in `@nogc` function `D main` may cause a GC allocation
    auto s = Shape(Shape.init.dims ~ 2);
                   ^
---
*/

@nogc:


struct Shape
{
    immutable size_t[] dims = [];
}

void main()
{
    auto s = Shape(Shape.init.dims ~ 2);
}
