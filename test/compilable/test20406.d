// https://issues.dlang.org/show_bug.cgi?id=20406
/* TEST_OUTPUT:
---
---
*/

struct S
{
	@disable this();
	this(int) {}
	this(ref S other) {}
}

void foo(S s) {}

void main()
{
    S s = S(3);
    foo(s);
}
