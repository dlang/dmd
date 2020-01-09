// REQUIRED_ARGS: -profile
/*
TEST_OUTPUT:
---
compilable/test11471.d(10): Deprecation: `asm` statement is assumed to throw - mark it with `nothrow` if it does not
---
*/

void main() nothrow
{ asm { nop; } } // Error: asm statements are assumed to throw
