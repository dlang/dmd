/**
Test language editions (currently experimental)

TEST_OUTPUT:
---
fail_compilation/editions.d(21): Error: scope parameter `x` may not be returned
fail_compilation/editions.d(29): Error: cannot copy `const(void)[]` to `void[]`
fail_compilation/editions.d(29):        Source data may contain pointers to incompatibly qualified data
fail_compilation/editions.d(29):        Use `cast(void[])` to ignore
fail_compilation/editions.d(31): Error: cannot copy `const(int*)[]` to `void[]` in `@safe` code
fail_compilation/editions.d(31):        Source data may contain pointers to incompatibly qualified data
fail_compilation/editions.d(31):        Use `cast(void[])` to ignore
---
*/
@__edition_latest_do_not_use
module editions;

@safe:
int* f(scope int* x)
{
    return x;
}

// https://issues.dlang.org/show_bug.cgi?id=17148
void f(int*[] a, const int*[] b) @system
{
	void[] a1 = a;
	const(void)[] b1 = b;
	a1[] = b1[];
	*a[0] = 0; //modify const data
	a1[] = new const(int*)[2];
}
