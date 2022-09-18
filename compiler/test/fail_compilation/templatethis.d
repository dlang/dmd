/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(11): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(15): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(19): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(21): Error: cannot use `this` outside an aggregate type
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

/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(34): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(37): Error: mixin `templatethis.t2!()` error instantiating
---
*/
mixin template t2()
{
	int i(this T) = 1;
}

mixin t2;

/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(51): Error: template instance `templatethis.C.f!int` argument for template this parameter must be a class or struct
fail_compilation/templatethis.d(51): Error: template instance `templatethis.C.f!int` error instantiating
---
*/
class C
{
	static void f(this T)() {}
}

alias a = C.f!int;
alias b = C.f!C; // OK
