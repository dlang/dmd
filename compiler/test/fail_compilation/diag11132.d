/*
TEST_OUTPUT:
---
fail_compilation/diag11132.d(25): Error: overlapping initialization for field `a` and `b`
    S s = { 1, 2, 3 };
               ^
fail_compilation/diag11132.d(25):        `struct` initializers that contain anonymous unions must initialize only the first member of a `union`. All subsequent non-overlapping fields are default initialized
---
*/

struct S
{
    int x;
    union
    {
        int a;
        int b;
    }

    int z;
}

void main()
{
    S s = { 1, 2, 3 };
}
