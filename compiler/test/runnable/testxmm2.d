// REQUIRED_ARGS:
// PERMUTE_ARGS: -mcpu=native -inline -O

version (D_SIMD)
{

import core.simd;
import core.stdc.string;

alias TypeTuple(T...) = T;

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=21474

struct along
{
    long[1] arr;
}

int4 to_m128i(along a)
{
    long2 r;
    r[0] = a.arr[0];
    return cast(int4)r;
}

void test21474()
{
    along a;
    a.arr[0] = 0x1234_5678_9ABC_DEF0;
    int4 i4 = to_m128i(a);
    assert(i4[0] == 0x9ABC_DEF0);
    assert(i4[1] == 0x1234_5678);
    assert(i4[2] == 0);
    assert(i4[3] == 0);
}

int4 cmpss_repro(float4 a)
{
    int4 result;
    result.ptr[0] = (1 > a.array[0]) ? -1 : 0;
    return result;
}

/*****************************************/

void testeqne()
{
    static int4 testeq(int4 x, int4 y)
    {
        return x == y;
    }

    static int4 testne(int4 x, int4 y)
    {
        return x != y;
    }

    int4 x = [1,2,3,4];
    int4 y = [4,3,2,1];
    int4 t = [-1, -1, -1, -1];
    int4 f = [0,0,0,0];
    int4 z = testeq(x, x);
    assert(x[] == x[]);
    assert(z[] == t[]);
    z = testne(x, x);
    assert(z[] == f[]);
    z = testeq(x, y);
    assert(z[] == f[]);
    z = testne(x, y);
    assert(z[] == t[]);
}

/*****************************************/

int main()
{
    test21474();
    testeqne();

    return 0;
}

}
else
{

int main() { return 0; }

}
