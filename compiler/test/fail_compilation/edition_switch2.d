/*
REQUIRED_ARGS: -edition=2024
TEST_OUTPUT:
---
fail_compilation/edition_switch2.d(12): Error: pointer subtraction is not allowed in a `@safe` function
---
*/

@safe
size_t test3(char* p, char* q)
{
    return p - q;
}
