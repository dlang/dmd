/*
TEST_OUTPUT:
---
fail_compilation/diag11769.d(18): Error: diag11769.foo!string.bar called with argument types (string) matches both:
	fail_compilation/diag11769.d(13): bar(immutable(wchar)[] _param_0)
and:
	fail_compilation/diag11769.d(14): bar(immutable(dchar)[] _param_0)
---
*/

template foo(T)
{
    void bar(wstring) {}
    void bar(dstring) {}
}
void main()
{
    foo!string.bar("abc");
}
