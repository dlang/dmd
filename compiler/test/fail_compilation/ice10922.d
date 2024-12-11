/*
TEST_OUTPUT:
---
fail_compilation/ice10922.d(15): Error: function `__lambda_L14_C12` is not callable using argument types `()`
    enum self = __traits(parent, {});
                ^
fail_compilation/ice10922.d(15):        too few arguments, expected 1, got 0
fail_compilation/ice10922.d(14):        `ice10922.__lambda_L14_C12(in uint n)` declared here
auto fib = (in uint n) pure nothrow {
           ^
---
*/

auto fib = (in uint n) pure nothrow {
    enum self = __traits(parent, {});
    return (n < 2) ? n : self(n - 1) + self(n - 2);
};

void main()
{
    auto n = fib(39);
}
