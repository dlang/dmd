/*
TEST_OUTPUT:
---
compilable/specialkeywords.d
test.compilable.specialkeywords
test.compilable.specialkeywords.foo
int test.compilable.specialkeywords.foo(string[] args)
_D4test10compilable15specialkeywords3fooFAAyaZi
---
*/

module test.compilable.specialkeywords;

pragma(msg, __FILE__);
pragma(msg, __MODULE__);

int foo(string[] args)
{
	pragma(msg, __FUNCTION__);
	pragma(msg, __PRETTY_FUNCTION__);
	pragma(msg, __MANGLED_FUNCTION__);

	return 0;
}
