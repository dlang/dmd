/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(18): Error: `this` is not in a class or struct scope
fail_compilation/templatethis.d(18): Error: `this` is only defined in non-static member functions, not `templatethis`
fail_compilation/templatethis.d(22): Error: `this` is not in a class or struct scope
fail_compilation/templatethis.d(22): Error: `this` is only defined in non-static member functions, not `templatethis`
fail_compilation/templatethis.d(26): Error: `this` is not in a class or struct scope
fail_compilation/templatethis.d(26): Error: `this` is only defined in non-static member functions, not `templatethis`
fail_compilation/templatethis.d(28): Error: `this` is not in a class or struct scope
fail_compilation/templatethis.d(28): Error: `this` is only defined in non-static member functions, not `templatethis`
fail_compilation/templatethis.d(34): Error: `this` is not in a class or struct scope
fail_compilation/templatethis.d(34): Error: `this` is only defined in non-static member functions, not `t2!()`
fail_compilation/templatethis.d(37): Error: mixin `templatethis.t2!()` error instantiating
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

/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(50): Error: template instance `f!int` does not match template declaration `f(this T : C)()`
---
*/
class C
{
	static void f(this T)() {}
}

alias a = C.f!int;
