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
// https://issues.dlang.org/show_bug.cgi?id=23461

int4 and(int a) { return a && true; }
int4 or(int a) { return a || false; }

void test23461()
{
    int4 x = and(3);
    assert(x.array == [1,1,1,1]);
    x = and(0);
    assert(x.array == [0,0,0,0]);

    x = or(3);
    assert(x.array == [1,1,1,1]);
    x = or(0);
    assert(x.array == [0,0,0,0]);
}

/*****************************************/

version (none)//(D_AVX2)
{
long2 testlt2(long2 x, long2 y) { return x < y; }
long2 testgt2(long2 x, long2 y) { return x > y; }
long2 testge2(long2 x, long2 y) { return x >= y; }
long2 testle2(long2 x, long2 y) { return x <= y; }

void testcmp2()
{
    auto x = testgt2([5L,6L], [4L,6L]);
    assert(x.array == [-1L,0L]);
    x = testlt2([5L,6L], [4L,6L]);
    assert(x.array == [0L,0L]);
    x = testle2([5L,6L], [4L,6L]);
    assert(x.array == [0L,-1L]);
    x = testge2([5L,6L], [4L,6L]);
    assert(x.array == [-1L,-1L]);
}
}
else
{
void testcmp2() { }
}

/*****************************************/

int4 testlt(int4 x, int4 y) { return x < y; }
int4 testgt(int4 x, int4 y) { return x > y; }
int4 testge(int4 x, int4 y) { return x >= y; }
int4 testle(int4 x, int4 y) { return x <= y; }

void testcmp4()
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

short8 testlt(short8 x, short8 y) { return x < y; }
short8 testgt(short8 x, short8 y) { return x > y; }
short8 testge(short8 x, short8 y) { return x >= y; }
short8 testle(short8 x, short8 y) { return x <= y; }

void testcmp8()
{
    auto x = testgt([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [-1,0,0,0, -1,0,0,0]);
    x = testlt([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [0,0,-1,-1, 0,0,-1,-1]);
    x = testle([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [0,-1,-1,-1, 0,-1,-1,-1]);
    x = testge([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [-1,-1,0,0, -1,-1,0,0]);
}

/*****************************************/

byte16 testlt16(byte16 x, byte16 y) { return x < y; }
byte16 testgt16(byte16 x, byte16 y) { return x > y; }
byte16 testge16(byte16 x, byte16 y) { return x >= y; }
byte16 testle16(byte16 x, byte16 y) { return x <= y; }

void testcmp16()
{
    auto x = testgt16([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [-1,0,0,0, -1,0,0,0, 0,0,0,0, 0,0,0,0]);
    x = testlt16([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [0,0,-1,-1, 0,0,-1,-1, 0,0,0,0, 0,0,0,0]);
    x = testle16([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [0,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1]);
    x = testge16([5,6,5,6,5,6,5,6], [4,6,8,7,4,6,7,8]);
    assert(x.array == [-1,-1,0,0, -1,-1,0,0, -1,-1,-1,-1, -1,-1,-1,-1]);
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
// https://issues.dlang.org/show_bug.cgi?id=23462

int4 notMask(int4 a) { return a == 0; }

void test23462()
{
    int4 x = [1,2,3,4];
    x = notMask(x);
    assert(x.array == [0,0,0,0]);
    x = notMask(x);
    assert(x.array == [~0,~0,~0,~0]);
}

/*****************************************/

void testunscmp()
{
    uint4 x = [uint.max,1, 0, uint.max];
    uint4 y = [0,1,1,6];
    uint4 z = x > y;
    assert(z.array == [-1,0,0,-1]);
}

/*****************************************/

uint4 testlt(float4 x, float4 y) { return x < y; }
uint4 testgt(float4 x, float4 y) { return x > y; }
uint4 testge(float4 x, float4 y) { return x >= y; }
uint4 testle(float4 x, float4 y) { return x <= y; }

void testflt()
{
    auto x = testgt([5,6,5,6], [4,6,8,7]);
    assert((cast(int4)x).array == [-1,0,0,0]);
    x = testlt([5,6,5,6], [4,6,8,7]);
    assert((cast(int4)x).array == [0,0,-1,-1]);
    x = testle([5,6,5,6], [4,6,8,7]);
    assert((cast(int4)x).array == [0,-1,-1,-1]);
    x = testge([5,6,5,6], [4,6,8,7]);
    assert((cast(int4)x).array == [-1,-1,0,0]);
}

ulong2 testlt(double2 x, double2 y) { return x < y; }
ulong2 testgt(double2 x, double2 y) { return x > y; }
ulong2 testge(double2 x, double2 y) { return x >= y; }
ulong2 testle(double2 x, double2 y) { return x <= y; }

void testdbl()
{
    auto x = testgt([5.0,6.0], [4.0,6.0]);
    assert((cast(long2)x).array == [-1L,0]);
    x = testlt([5.0,6.0], [4.0,6.0]);
    assert((cast(long2)x).array == [0L,0]);
    x = testle([5.0,6.0], [4.0,6.0]);
    assert((cast(long2)x).array == [0L,-1]);
    x = testge([5.0,6.0], [4.0,6.0]);
    assert((cast(long2)x).array == [-1L,-1]);
}

/*****************************************/

int main()
{
    test21474();
    test23461();
    testcmp2();
    testcmp4();
    testcmp8();
    testcmp16();
    testside();
    testeqne();
    testz4();
    test2();
    test3();
    test23462();
    testunscmp();
    testflt();
    testdbl();

    return 0;
}

}
else
{

int main() { return 0; }

}
