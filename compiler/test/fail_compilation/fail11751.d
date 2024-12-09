/*
TEST_OUTPUT:
---
fail_compilation/fail11751.d(14): Error: missing exponent
auto x = 0x1.FFFFFFFFFFFFFpABC;
         ^
fail_compilation/fail11751.d(14): Error: semicolon expected following auto declaration, not `ABC`
auto x = 0x1.FFFFFFFFFFFFFpABC;
                           ^
fail_compilation/fail11751.d(14): Error: no identifier for declarator `ABC`
---
*/

auto x = 0x1.FFFFFFFFFFFFFpABC;
