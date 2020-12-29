/*
REQUIRED_ARGS: -edition=2024
TEST_OUTPUT:
---
fail_compilation/edition_complex2.d(11): Error: semicolon expected following auto declaration, not `i`
fail_compilation/edition_complex2.d(12): Error: semicolon expected following auto declaration, not `i`
---
 */
void main()
{
    auto cv = 1.0+0.0i;
    auto iv = 1.0i;
}
