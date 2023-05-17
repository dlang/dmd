// EXTRA_FILES: imports/b19762.d imports/c19762.d
// PERMUTE_ARGS: -g

/*
TEST_OUTPUT:
---
fail_compilation/ice19762.d(16): Error: undefined identifier `Err`, did you mean variable `err`?
---
*/

module ice19762;

struct X
{
	import imports.b19762 : Baz;
	Err err;
}
