/**
TEST_OUTPUT:
---
fail_compilation/named_arguments.d(21): Error: named arguments (`mx: 10`) are not supported yet
fail_compilation/named_arguments.d(22): Error: named arguments (`x: 20`) are not supported yet
fail_compilation/named_arguments.d(22): Error: named arguments (`y: 30`) are not supported yet
fail_compilation/named_arguments.d(23): Error: named arguments (`T: int`) are not supported yet
fail_compilation/named_arguments.d(23): Error: template instance `tt!(T: int)` does not match template declaration `tt(T)`
fail_compilation/named_arguments.d(24): Error: cannot use named argument `thecode: "{}"` in `mixin` or `pragma`
fail_compilation/named_arguments.d(25): Error: cannot use named argument `themsg: "hello"` in `mixin` or `pragma`
fail_compilation/named_arguments.d(25):        while evaluating `pragma(msg, themsg: "hello")`
---
*/

void f(int x, int y);
struct S { int mx; }
alias tt(T) = T;

void main()
{
	auto s = new S(mx: 10);
	f(x: 20, y: 30,);
	tt!(T: int);
	mixin(thecode: "{}");
	pragma(msg, themsg: "hello");
}
