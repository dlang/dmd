// PERMUTE_ARGS:
// REQUIRED_ARGS: -w -transition=in

/*
TEST_OUTPUT:
---
fail_compilation/transition_in.d(14): Warning: `in` is not yet implemented.  Use `const` or `scope const` explicitly instead.
fail_compilation/transition_in.d(14):        `in` is currently defined as `scope const`, but it is implemented as `const`.  Using `in` could cause code to break in the future when it is implemented, so it is recommended to use `const` or `const scope` explicitly until `in` is properly implemented.
fail_compilation/transition_in.d(15): Warning: `in` is not yet implemented.  Use `const` or `scope const` explicitly instead.
fail_compilation/transition_in.d(16): Warning: `in` is not yet implemented.  Use `const` or `scope const` explicitly instead.
---
*/

void test(in void* x) { }
void test1(in void* x) { }
void test2(in void* x) { }
