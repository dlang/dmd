/*
TEST_OUTPUT:
---
fail_compilation/ice10770.d(9): Error: enum ice10770.E1 is forward referenced looking for base type
---
*/

enum E1;
static assert(is(E1 e == enum));

enum E2 : int;
static assert(is(E2 e == enum) && is(e == int));
