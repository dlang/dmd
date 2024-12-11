/*
TEST_OUTPUT:
---
fail_compilation/diag11727.d(18): Error: type `n` is not an expression
    return n;
           ^
fail_compilation/diag11727.d(28): Error: type `void` is not an expression
    return v;
           ^
fail_compilation/diag11727.d(34): Error: template `t()` has no type
    return t;
           ^
---
*/
auto returnEnum()
{
    enum n;
    return n;
}
void main()
{
    assert(returnEnum() == 0);
}

auto returnVoid()
{
    alias v = void;
    return v;
}

auto returnTemplate()
{
    template t() {}
    return t;
}
