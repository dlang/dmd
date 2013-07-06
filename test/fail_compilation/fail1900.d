/*
TEST_OUTPUT:
---
fail_compilation/fail1900.d(26): Error: template fail1900.Mix1!().Foo matches more than one template declaration:
	fail_compilation/fail1900.d(13):Foo(ubyte x)
and
	fail_compilation/fail1900.d(14):Foo(byte x)
---
*/

template Mix1()
{
    template Foo(ubyte x) {}
    template Foo(byte x) {}
}
template Mix2()
{
    template Foo(int x) {}
}

mixin Mix1;
mixin Mix2;

void test1900a()
{
    alias x = Foo!1;
}
