/*
TEST_OUTPUT:
---
fail_compilation/fail248.d(9): Error: argument int to typeof is not an expression
---
*/

alias int foo;
typeof(foo) a; // ok
