/*
TEST_OUTPUT:
---
fail_compilation/fail11751.d(11): Error: missing exponent
fail_compilation/fail11751.d(11): Error: alphanumeric character cannot follow numeric literal `0x1.FFFFFFFFFFFFFp` without whitespace
fail_compilation/fail11751.d(11): Error: semicolon expected following auto declaration, not `ABC`
fail_compilation/fail11751.d(11): Error: no identifier for declarator `ABC`
---
*/

auto x = 0x1.FFFFFFFFFFFFFpABC;
