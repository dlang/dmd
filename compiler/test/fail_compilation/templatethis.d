/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(10): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(14): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(18): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(20): Error: cannot use `this` outside an aggregate type
---
*/
#line 9

template t(this T)
{
}

struct S(this T)
{
} // check still get errors after aggregate type ends

enum e(this T) = 1;

void f(this T)()
{
}

mixin template t2()
{
	int i(this T) = 1; // OK
}
