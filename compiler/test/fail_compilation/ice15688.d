// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/ice15688.d(16): Error: undefined identifier `mappings`
    (mappings, 0)();
     ^
fail_compilation/ice15688.d(16): Error: function expected before `()`, not `0` of type `int`
    (mappings, 0)();
                 ^
---
*/

void main()
{
    (mappings, 0)();
}
