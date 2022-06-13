/*
TEST_OUTPUT:
---
fail_compilation/numliteral.c(10): Error: binary constants not allowed
fail_compilation/numliteral.c(11): Error: embedded `_` not allowed
---
*/

// Test C-specific errors
int x = 0b00;
int y = 0_1;

// https://issues.dlang.org/show_bug.cgi?id=22549
int z = 078.0 + 008. + 009e1;
