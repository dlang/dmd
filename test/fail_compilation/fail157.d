// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail157.d(26): Error: overlapping initialization for y
---
*/

typedef int myint = 4;

struct S
{
    int i;
    union
    {
        int x = 2;
        int y;
    }
    int j = 3;
    myint k;
}


void main()
{
    S s = S( 1, 5, 6 );
    assert(s.i == 1);
    assert(s.x == 5);
    assert(s.y == 5);
    assert(s.j == 3);
    assert(s.k == 4);
}
