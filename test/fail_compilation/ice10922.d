/*
TEST_OUTPUT:
---
fail_compilation/ice10922.d(11): Error: forward reference to inferred return type of function call self(n - 1u)
fail_compilation/ice10922.d(11): Error: forward reference to inferred return type of function call self(n - 2u)
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
