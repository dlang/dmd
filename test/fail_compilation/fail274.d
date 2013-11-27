/*
TEST_OUTPUT:
---
fail_compilation/fail274.d(10): Error: ] expected instead of ';'
---
*/

void main()
{
    asm { inc [; }
}
