/*
TEST_OUTPUT:
---
fail_compilation/fail248.d(11): Error: type `int` is not an expression
typeof(foo) a; // ok
       ^
---
*/

alias int foo;
typeof(foo) a; // ok
