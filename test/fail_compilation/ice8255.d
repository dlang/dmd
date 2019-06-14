/*
REQUIRED_ARGS: -preview=rvaluerefparam
TEST_OUTPUT:
---
fail_compilation/ice8255.d(12): Error: Cannot pass argument `F().f(((G __rvalue2 = G();) , __rvalue2))` to `pragma msg` because it is `void`
---
*/


struct G {}
struct F(T) { void f(ref T) {} }
pragma(msg, F!G().f(G.init));
