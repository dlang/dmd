/*
REQUIRED_ARGS: -v
---
fail_compilation/fail15616b.d(44): Error: none of the overloads of `foo` are callable using argument types `(double)`, candidates are:
fail_compilation/fail15616b.d(17):        `fail15616b.foo(int a)`
fail_compilation/fail15616b.d(20):        `fail15616b.foo(int a, int b)`
fail_compilation/fail15616b.d(29):        `fail15616b.foo(int a, int b, int c)`
fail_compilation/fail15616b.d(32):        `fail15616b.foo(string a)`
fail_compilation/fail15616b.d(35):        `fail15616b.foo(string a, string b)`
fail_compilation/fail15616b.d(38):        `fail15616b.foo(string a, string b, string c)`
fail_compilation/fail15616b.d(23):        `fail15616b.foo(T)(T a) if (is(T == float))`
fail_compilation/fail15616b.d(26):        `fail15616b.foo(T)(T a) if (is(T == char))`
---
*/

void foo(int a)
{}

void foo(int a, int b)
{}

void foo(T)(T a) if (is(T == float))
{}

void foo(T)(T a) if (is(T == char))
{}

void foo(int a, int b, int c)
{}

void foo(string a)
{}

void foo(string a, string b)
{}

void foo(string a, string b, string c)
{}


void main()
{
    foo(3.14);
}
