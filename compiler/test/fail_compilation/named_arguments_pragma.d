/**
TEST_OUTPUT:
---
fail_compilation/named_arguments_pragma.d(12): Error: cannot use named argument `thecode: "{}"` in `mixin` or `pragma`
fail_compilation/named_arguments_pragma.d(13): Error: cannot use named argument `themsg: "hello"` in `mixin` or `pragma`
fail_compilation/named_arguments_pragma.d(13):        while evaluating `pragma(msg, themsg: "hello")`
---
*/

void main()
{
	mixin(thecode: "{}");
	pragma(msg, themsg: "hello");
}
