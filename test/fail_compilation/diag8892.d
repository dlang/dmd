// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag8892.d(15): Error: cannot implicitly convert expression (['A']) of type char[] to char[2u]
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
