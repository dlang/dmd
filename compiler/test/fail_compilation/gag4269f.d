// REQUIRED_ARGS: -c -o-
/*
TEST_OUTPUT:
---
fail_compilation/gag4269f.d(15): Error: undefined identifier `Y9`, did you mean interface `X9`?
interface X9 { Y9 y; }
                  ^
fail_compilation/gag4269f.d(15): Error: field `y` not allowed in interface
interface X9 { Y9 y; }
                  ^
---
*/

static if(is(typeof(X9.init))) {}
interface X9 { Y9 y; }
