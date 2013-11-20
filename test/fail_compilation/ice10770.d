/*
TEST_OUTPUT:
---
fail_compilation/ice10770.d(13): Error: enum ice10770.E2 is forward referenced looking for base type
---
*/

enum E1 : int;
static assert(is(E1 e == enum) && is(e == int));

enum E2;
static assert(is(E2   == enum));    // Bugzilla 11554: should not cause error
static assert(is(E2 e == enum));
