/*
TEST_OUTPUT:
---
fail_compilation/diag10770.d(9): Error: enum diag10770.E is forward referenced looking for base type
---
*/

enum E;
static assert(is(E e == enum));

enum F : int;
static assert(is(F e == enum));
