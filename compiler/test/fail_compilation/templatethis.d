/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(25): Error: cannot use `this` outside an aggregate type
template t(this T)
                ^
fail_compilation/templatethis.d(29): Error: cannot use `this` outside an aggregate type
struct S(this T)
              ^
fail_compilation/templatethis.d(33): Error: cannot use `this` outside an aggregate type
enum e(this T) = 1;
            ^
fail_compilation/templatethis.d(35): Error: cannot use `this` outside an aggregate type
void f(this T)()
            ^
fail_compilation/templatethis.d(41): Error: cannot use `this` outside an aggregate type
	int i(this T) = 1;
            ^
fail_compilation/templatethis.d(44): Error: mixin `templatethis.t2!()` error instantiating
mixin t2;
^
---
*/

template t(this T)
{
}

struct S(this T)
{
}

enum e(this T) = 1;

void f(this T)()
{
}

mixin template t2()
{
	int i(this T) = 1;
}

mixin t2;

class C
{
	mixin t2; // OK
}
