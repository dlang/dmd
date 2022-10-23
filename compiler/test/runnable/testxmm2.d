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

int4 testlt(int4 x, int4 y) { return x < y; }
int4 testgt(int4 x, int4 y) { return x > y; }
int4 testge(int4 x, int4 y) { return x >= y; }
int4 testle(int4 x, int4 y) { return x <= y; }

void testcmp()
{
    auto x = testgt([5,6,5,6], [4,6,8,7]);
    assert(x.array == [-1,0,0,0]);
    x = testlt([5,6,5,6], [4,6,8,7]);
    assert(x.array == [0,0,-1,-1]);
    x = testle([5,6,5,6], [4,6,8,7]);
    assert(x.array == [0,-1,-1,-1]);
    x = testge([5,6,5,6], [4,6,8,7]);
    assert(x.array == [-1,-1,0,0]);
}

/*****************************************/

void testside()
{
    int i;
    int4 e1()
    {
        ++i;
        return [5,6,5,6];
    }
    int4 e2()
    {
        i *= 10;
        return [4,6,7,8];
    }
    assert((e1() < e2()).array == [0,0,-1,-1]);
    assert(i == 10);
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

int4 testz4() { return [0,0,0,0]; }
int4 testn4() { return [~0,~0,~0,~0]; }

void test2()
{
    assert(testz4().array == [0,0,0,0]);
    assert(testn4().array == [~0,~0,~0,~0]);
}

/*****************************************/

version (D_AVX2)
{
int8 testz8() { return [0,0,0,0,0,0,0,0]; }
int8 testn8() { return [~0,~0,~0,~0,~0,~0,~0,~0]; }

void test3()
{
    assert(testz8().array == [0,0,0,0,0,0,0,0]);
    assert(testn8().array == [~0,~0,~0,~0,~0,~0,~0,~0]);
}
}
else
{
void test3() { }
}

/*****************************************/

int main()
{
    test21474();
    testcmp();
    testside();
    testeqne();
    testz4();
    test2();
    test3();

    return 0;
}

}
else
{

int main() { return 0; }

}
