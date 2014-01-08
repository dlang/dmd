/*
TEST_OUTPUT:
---
fail_compilation/ice10770.d(12): Error: enum ice10770.E2 is forward referenced looking for base type
---
*/

enum E1 : int;
static assert(is(E1 e == enum) && is(e == int));

enum E2;
static assert(is(E2 e == enum));
