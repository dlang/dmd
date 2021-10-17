/*
REQUIRED_ARGS: -verrors=context
TEST_OUTPUT:
---
Deprecation: -verrors=context is redundant, and will be removed in future DMD versions.
fail_compilation/staticforeach4.d(13): Error: index type `byte` cannot cover index range 0..257
fail_compilation/staticforeach4.d(14): Error: index type `byte` cannot cover index range 0..257
---
*/
immutable int[257] data = 1;
int[257] fn() { return data; }

static foreach (byte a, int b; data) { }
static foreach (byte a, int b; fn()) { }
