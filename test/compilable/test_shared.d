/*
REQUIRED_ARGS:-preview=restrictiveshared
TEST_OUTPUT:
---
---
*/


int f1(shared int x)
{
    auto r = sync(&x, 22);
    return r;

}

int sync(shared int *x, int y)
{
    auto unshared_x = cast()x;

    return *unshared_x = y;
}

