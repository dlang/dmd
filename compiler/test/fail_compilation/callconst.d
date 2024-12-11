/*
TEST_OUTPUT:
---
fail_compilation/callconst.d(18): Error: function `func` is not callable using argument types `(const(X))`
    func(x);
        ^
fail_compilation/callconst.d(18):        cannot pass argument `x` of type `const(X)` to parameter `ref X`
fail_compilation/callconst.d(21):        `callconst.func(ref X)` declared here
void func(ref X);
     ^
---
*/
struct X {}

void main()
{
    auto x = const X();
    func(x);
}

void func(ref X);
