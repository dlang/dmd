/*
TEST_OUTPUT:
---
fail_compilation/diag13082.d(28): Error: constructor `diag13082.C.this(int a)` is not callable using argument types `(string)`
    auto c = new C(b);
             ^
fail_compilation/diag13082.d(28):        cannot pass argument `b` of type `string` to parameter `int a`
fail_compilation/diag13082.d(29): Error: constructor `diag13082.S.this(int a)` is not callable using argument types `(string)`
    auto s = new S(b);
             ^
fail_compilation/diag13082.d(29):        cannot pass argument `b` of type `string` to parameter `int a`
---
*/

class C
{
    this(int a) {}
}

struct S
{
    this(int a) {}
}

void main()
{
    string b;
    auto c = new C(b);
    auto s = new S(b);
}
