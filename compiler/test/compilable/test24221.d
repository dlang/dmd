// https://github.com/dlang/dmd/issues/24221

/*
TEST_OUTPUT:
---
cast(E)5
---
*/

enum E
{
    a = 1,
    b = f(),
}

int f()
{
    pragma(msg, cast(E)5);
    return 2;
}
