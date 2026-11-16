/* Test cases from https://github.com/dlang/dmd/issues/24302
 */

#include <assert.h>

/***************************************************/

struct S_24303 { unsigned f : 19; } s_24303;

int test24303(void)
{
    s_24303.f = 10;
    assert(s_24303.f - 20 < 0);
    return 0;
}

/***************************************************/

#if 0

struct S_24322 { unsigned f : 6; unsigned g : 10; } arr_24322[4];

void t_24322(struct S_24322 *p, int i) { p[i].f |= -1; }

int test24322(void)
{
    t_24322(arr_24322, 2);
    assert(arr_24322[2].f == 63);
    return 0;
}


struct S_24324 { unsigned f : 1; } s_24324;

long long f_24324(long long k) { return (0 - k) | (s_24324.f != 0); }

int test24324(void)
{
    assert(f_24324(0) == 0);
    return 0;
}


struct S_24326 { short f : 7; } s_24326;

void add_24326(int k) { s_24326.f += k; }

int test24326(void)
{
    s_24326.f = 5;
    add_24326(3);
    assert(s_24326.f == 8);
    return 0;
}


long long f_24336(long long x, int y, int z) { return -((x || y) || z); }

int test24336(void)
{
    assert(f_24336(1, 0, 0) == -1);
    return 0;
}


int x_24337;

int test24337(void)
{
    assert(0 - (x_24337 || 1) == -1);
    return 0;
}


struct S_24344 { short a : 1; unsigned char b : 8; short c : 14; } s_24344;

int test24344(void)
{
    s_24344.c = -6;
    assert(s_24344.c == -6);
    return 0;
}


struct S_24352 { int a : 3; } s_24352;

int inc_24352(void) { return s_24352.a++; }

int test24352(void)
{
    s_24352.a = 3;
    assert(inc_24352() == 3);
    return 0;
}

#endif

/***************************************************/

int main(void)
{
    test24303();
/*
    test24322();
    test24324();
    test24326();
    test24336();
    test24337();
    test24344();
    test24352();
*/
    return 0;
}
