// REQUIRED_ARGS: -c -o-
/*
TEST_OUTPUT:
---
fail_compilation/gag4269b.d(12): Error: undefined identifier `Y`
struct X2 { Y y; }
              ^
---
*/

static if(is(typeof(X2.init))) {}
struct X2 { Y y; }
