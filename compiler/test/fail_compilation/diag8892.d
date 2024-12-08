/*
TEST_OUTPUT:
---
fail_compilation/diag8892.d(16): Error: cannot implicitly convert expression `['A']` of type `char[]` to `char[2]`
    auto f = Foo(['A']);
                 ^
---
*/
struct Foo
{
    char[2] data;
}

void main()
{
    auto f = Foo(['A']);
}
