/*
TEST_OUTPUT:
---
fail_compilation/fail179.d(13): Error: variable `fail179.main.px` cannot be `final`, perhaps you meant `const`?
    final px = &x;
          ^
---
*/

void main()
{
    int x = 3;
    final px = &x;
    *px = 4;
    auto ppx = &px;
    **ppx = 5;
}
