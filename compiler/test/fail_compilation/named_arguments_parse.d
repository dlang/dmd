/**
TEST_OUTPUT:
---
fail_compilation/named_arguments_parse.d(17): Error: named arguments not allowed here
	mixin(thecode: "{}");
       ^
fail_compilation/named_arguments_parse.d(18): Error: named arguments not allowed here
	pragma(msg, themsg: "hello");
             ^
---
*/


// @(attribute: 3) Currently gives an ugly parse error, will be better when named template arguments are implemented
void main()
{
	mixin(thecode: "{}");
	pragma(msg, themsg: "hello");
}
