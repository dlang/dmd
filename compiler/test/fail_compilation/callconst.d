/*
TEST_OUTPUT:
---
fail_compilation/callconst.d(19): Error: function `func` is not callable using argument types `(const(X))`
fail_compilation/callconst.d(19):        cannot pass argument `x` of type `const(X)` to parameter `ref X`
fail_compilation/callconst.d(22):        `callconst.func(ref X)` declared here
---
*/
struct X {}

void main()
{
    auto x = const X();
    func(x);
}

void func(ref X);
