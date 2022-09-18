/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test19812b.d(112): Error: escaping reference to stack allocated value returned by `new I`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19812

#line 100

auto makeI(int m) @safe
{
    static struct S
    {
	int m;
	auto inner() @safe
	{
	    class I
	    {
		int get() @safe { return m; }
	    }
	    return new I;
	}
    }

    auto s = S(m);
    return s.inner();
}
