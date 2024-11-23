/*
TEST_OUTPUT:
---
fail_compilation/fail155.d(22): Error: overlapping initialization for field `x` and `y`
S s = S( 1, 2, 3, 4 );
            ^
fail_compilation/fail155.d(22):        `struct` initializers that contain anonymous unions must initialize only the first member of a `union`. All subsequent non-overlapping fields are default initialized
---
*/

struct S
{
    int i;
    union
    {
        int x;
        int y;
    }
    int j;
}

S s = S( 1, 2, 3, 4 );
