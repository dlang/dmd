/*
TEST_OUTPUT:
---
fail_compilation/diag11727.d(10): Error: type n has no value
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

/*
TEST_OUTPUT:
---
fail_compilation/diag11727.d(26): Error: type void has no value
---
*/
auto returnVoid()
{
    alias v = void;
    return v;
}

/*
TEST_OUTPUT:
---
fail_compilation/diag11727.d(38): Error: template t() has no value
---
*/
auto returnTemplate()
{
    template t() {}
    return t;
}
