/*
REQUIRED_ARGS: -mcpu=native
PERMUTE_ARGS: -O -inline -release
*/

/***
 * Do coverage testing of cgelem.d
 * Check coverage here:
 * https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/cgelem.d
 */

import core.stdc.stdio;

template tuple(A...) { alias tuple = A; }

/*************************************************/

void test_eladdr()
{
    //  & (*p1 = e) => ((*(t = p1) = e), t)
    int i = 4;
    int* p1 = &i;
    int e = 5;
    auto x = &(*p1 = e);
    assert(i == 5);
    assert(x == p1);
}

/*************************************************/

void test_elneg()
{
    static int i = 3;
    int j = - -i;
    assert(i == j);
}

 /*************************************************/
int shr16(int x) { return (x >> 16) & 0xFFFF; }

void test_elbitwise()
{
    //  (x >> 16) & 0xFFFF => (cast(uint)x >> 16)
    assert(shr16(-1) == 0xFFFF);
    assert(shr16(0x7FFF0000) == 0x7FFF);
}

/*************************************************/

int main()
{
    test_eladdr();
    test_elneg();
    test_elbitwise();

    printf("Success\n");
    return 0;
}
