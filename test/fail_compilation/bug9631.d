/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(20): Error: cannot implicitly convert expression `F()` of type `bug9631.T1!().F` to `bug9631.T2!().F`
---
*/

template T1()
{
    struct F { }
}

template T2()
{
    struct F { }
}

void main()
{
    T2!().F x = T1!().F();
}
