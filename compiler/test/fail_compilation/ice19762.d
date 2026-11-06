// EXTRA_FILES: imports/b19762.d imports/c19762.d
// PERMUTE_ARGS: -g

/*
TEST_OUTPUT:
---
fail_compilation/ice19762.d(14): Error: struct `ice19762.X` had semantic errors when compiling
fail_compilation/ice19762.d(17):        field `err` failed semantic analysis
---
*/

module ice19762;

struct X
{
	import imports.b19762 : Baz;
	Err err;
}
