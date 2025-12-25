// https://github.com/dlang/dmd/issues/22254
/*
TEST_OUTPUT:
---
fail_compilation/ice22254.d(10): Error: Assert condition must evaluate to bool enum
---
*/

void foo() {
	assert(assert(0, ""), "");
}
