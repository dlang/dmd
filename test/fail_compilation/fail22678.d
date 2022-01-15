// https://issues.dlang.org/show_bug.cgi?id=22678
// REQUIRED_ARGS: -verrors=context -vcolumns
/* TEST_OUTPUT:
---
fail_compilation/fail22678.d(12,13): Error: cannot implicitly convert expression `1` of type `int` to `string`
	string a = 1;
	           ^
---
*/
void fail22678()
{
	string a = 1;
}
