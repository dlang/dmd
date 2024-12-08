/*
TEST_OUTPUT:
---
fail_compilation/diag11769.d(20): Error: `diag11769.foo!string.bar` called with argument types `(string)` matches both:
fail_compilation/diag11769.d(15):     `diag11769.foo!string.bar(wstring __param_0)`
and:
fail_compilation/diag11769.d(16):     `diag11769.foo!string.bar(dstring __param_0)`
    foo!string.bar("abc");
                  ^
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
