// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/ice15317.d(13): Error: undefined identifier `fun`
    alias f = fun;
              ^
---
*/

void main()
{
    alias f = fun;
    auto x1 = &f;
}
