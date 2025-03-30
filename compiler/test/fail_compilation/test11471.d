// REQUIRED_ARGS: -profile
/*
TEST_OUTPUT:
---
fail_compilation/test11471.d(10): Error: `asm` statement is assumed to throw - mark it with `nothrow` if it does not
---
*/

void main() nothrow
{ asm { nop; } } // Error: asm statements are assumed to throw
