/*
TEST_OUTPUT:
---
fail_compilation/callconst.d(13): Error: function is not callable using argument types `(const(X))`
fail_compilation/callconst.d(13):               `callconst.func(ref X)`
fail_compilation/callconst.d(13):        cannot pass argument `x` of type `const(X)` to parameter `ref X`
---
*/
struct X {}

void main()
{
    auto x = const X();
    func(x);
}

void func(ref X);
