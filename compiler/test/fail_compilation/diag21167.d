/*
TEST_OUTPUT:
---
fail_compilation/diag21167.d(15): Error: function `f` is not callable using argument types `(int, string, int)`
fail_compilation/diag21167.d(17):        cannot pass argument `"foo"` of type `string` to parameter `int __param_1`
fail_compilation/diag21167.d(11):        `diag21167.f(int __param_0, int __param_1, int __param_2)` declared here
---
*/
// https://github.com/dlang/dmd/issues/21167

void f(int, int, int){}

void main()
{
	f(
		1,
		"foo",
		3
	);

}
