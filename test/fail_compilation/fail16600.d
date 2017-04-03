/*
TEST_OUTPUT:
---
fail_compilation/fail16600.d(19): Error: fail16600.S.__ctor called with argument types (string) const matches both:
fail_compilation/fail16600.d(13):     fail16600.S.this(string)
and:
fail_compilation/fail16600.d(14):     fail16600.S.this(string) immutable
---
*/

struct S
{
    this(string);
    this(string) immutable;
}

void main()
{
    auto a = const(S)("abc");
}

