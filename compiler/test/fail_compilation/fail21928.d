/*
TEST_OUTPUT:
---
fail_compilation/fail21928.d(18): Error: array literal `[2LU]` in `@nogc` function `D main` may cause a GC allocation
---
*/

@nogc:


struct Shape
{
    immutable size_t[] dims = [];
}

void main()
{
    auto s = Shape(2 ~ Shape.init.dims);
}
