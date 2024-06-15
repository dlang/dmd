/* REQUIRED_ARGS: -preview=fixImmutableConv
TEST_OUTPUT:
---
fail_compilation/test15660.d(26): Error: cannot implicitly convert expression `f(v)` of type `int[]` to `immutable(int[])`
fail_compilation/test15660.d(34): Error: cannot copy `const(void)[]` to `void[]`
fail_compilation/test15660.d(34):        Source data may contain pointers to incompatibly qualified data
fail_compilation/test15660.d(34):        Use `cast(void[])` if immutable data is not written to
fail_compilation/test15660.d(36): Error: cannot copy `const(int*)[]` to `void[]` in `@safe` code
fail_compilation/test15660.d(36):        Source data may contain pointers to incompatibly qualified data
fail_compilation/test15660.d(36):        Use `cast(void[])` if immutable data is not written to
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15660

int[] f(ref void[] m) pure
{
    auto result = new int[5];
    m = result;
    return result;
}

void main()
{
    void[] v;
    immutable x = f(v);
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
