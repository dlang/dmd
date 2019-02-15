/*
TEST_OUTPUT:
---
fail_compilation/test_overlap.d(13): Error: overlapping default initialization for field `u` and `i`
fail_compilation/test_overlap.d(13): Error: overlapping default initialization for field `i` and `u`
fail_compilation/test_overlap.d(24): Error: overlapping default initialization for field `u` and `i`
fail_compilation/test_overlap.d(24): Error: overlapping default initialization for field `i` and `u`
fail_compilation/test_overlap.d(31): Error: overlapping default initialization for field `u` and `i`
fail_compilation/test_overlap.d(31): Error: overlapping default initialization for field `i` and `u`
---
*/

class C0
{
    union
    {
        int i = 4;
        uint u = 2;
    }
}

class C1
{
    union U
    {
        int i = 4;
        uint u = 2;
    }
}

union U1
{
    int i = 4;
    uint u = 2;
    ubyte[2] v;
}

