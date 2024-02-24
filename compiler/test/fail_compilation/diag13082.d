/*
TEST_OUTPUT:
---
fail_compilation/diag13082.d(26): Error: constructor `this` is not callable using argument types `(string)`
fail_compilation/diag13082.d(26):        cannot pass argument `b` of type `string` to parameter `int a`
fail_compilation/diag13082.d(15):        `diag13082.C.this(int a)` declared here
fail_compilation/diag13082.d(27): Error: constructor `this` is not callable using argument types `(string)`
fail_compilation/diag13082.d(27):        cannot pass argument `b` of type `string` to parameter `int a`
fail_compilation/diag13082.d(20):        `diag13082.S.this(int a)` declared here
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
