/*
TEST_OUTPUT:
---
fail_compilation/numliteral.c(11): Error: embedded `_` not allowed
---
*/

int x = 0b00; // https://issues.dlang.org/show_bug.cgi?id=23410

// Test C-specific errors
int y = 0_1;

// https://issues.dlang.org/show_bug.cgi?id=22549
int z = 078.0 + 008. + 009e1;
