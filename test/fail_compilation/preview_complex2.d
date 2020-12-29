/*
REQUIRED_ARGS: -preview=complex
TEST_OUTPUT:
---
fail_compilation/preview_complex2.d(3): Error: semicolon expected following auto declaration, not `i`
fail_compilation/preview_complex2.d(4): Error: semicolon expected following auto declaration, not `i`
---
 */

#line 1
void main()
{
    auto cv = 1.0+0.0i;
    auto iv = 1.0i;
}
