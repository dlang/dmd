/*
PERMUTE_ARGS: -O -inline -mcpu=avx2
 * Test cases from https://github.com/dlang/dmd/issues/24302
 */

import core.bitop;
import core.math : fabs;
import core.simd;

static if (0)
{
long f_24111(ulong a, long b) { return (a & 0xFFFF_FFFF) + (b <= 0); }

void test24111()
{
    assert(f_24111(5, 0) == 6);
}
}

/****************************************************/

// https://github.com/dlang/dmd/issues/24112

uint f_24112(uint x) { return x / 0xFFFF_FFFF; }

void test24112()
{
    assert(f_24112(0xFFFF_FFFF) == 1);
}

/****************************************************/

static if (0)
{
short f_24113()
{
    short x = -1;
    x >>>= 1;
    return x;
}

void test24113()
{
    assert(f_24113() == 0x7FFF);
}
}

/**************************************************/

// https://github.com/dlang/dmd/issues/24304

ushort f_24304(int n)
{
    ushort v = 1;
    for (uint i = 0; i < 1; i++)
        v = cast(ushort)(i & 0x10000);
    v >>>= n;
    return v;
}

void test24304()
{
    assert(f_24304(1) == 0);
}

/**************************************************/

static if (0)
{
int f_24305(int a, int c) { return ((a & 2) ^ c) & 1; }

void test24305()
{
    assert(f_24305(0, 1) == 1);
}

ulong f_24306(byte p)
{
    ulong v = p;
    v = cast(uint)v;
    return v;
}

void test24306()
{
    assert(f_24306(-5) == 0xFFFF_FFFB);
}

short f_24307(int n)
{
    short v = 0;
    for (int i = 0; i < 1; ++i)
        v = -1;
    v >>>= n;
    return v;
}

void test24307()
{
    assert(f_24307(1) == 0x7FFF);
}

long f_24308(int p)
{
    long v = -1;
    v &= cast(uint)(p == 0 ? v : 0);
    return v;
}

void test24308()
{
    assert(f_24308(0) == 0xFFFF_FFFF);
}

__gshared long g_24309a = 1;

int nz_24309a(int x) { return x == 0 ? 1 : x; }

ulong f_24309a(long p)
{
    byte v = 0 > p;
    ulong w = 0 / nz_24309a(v);
    return v ^ w;
}

void test24309a()
{
    assert(f_24309a(g_24309a) == 0);
}

pragma(inline, true) ulong nz_24309b(ulong x) { return x == 0 ? 1 : x; }

ulong f_24309b(int p) { return 1 / nz_24309b(cast(ubyte)(0 < p)); }

void test24309b()
{
    assert(f_24309b(-5) == 1);
}

bool f_24310(ulong z) { return cast(long)(z % 3) > -1; }

void test24310()
{
    assert(f_24310(0));
}

pragma(inline, true) ulong id_24311(ulong x) { return x; }

short f_24311(ulong p)
{
    short v = 0;
    for (long i = 0; i < 1; ++i)
        v = p && (v % id_24311(0 % p));
    return v;
}

void test24311()
{
    assert(f_24311(0) == 0);
}

long f_24312(ulong a, long b)
{
    ubyte x = cast(ubyte)(2 + b);
    int y = cast(int)(a | 1);
    long[8] arr = [-2, 1, 1, -1, 8623284609789202863L, -256L, 0, 1];
    return arr[7];
}

void test24312()
{
    assert(f_24312(0, 0) == 1);
}

long f_24313(ulong a, ulong b)
{
    short v = 0;
    ushort w = 0;
    v |= b;
    w = cast(ubyte)(~a);
    v &= ~a;
    return v;
}

void test24313()
{
    assert(f_24313(0, 0xFFFF_FFFF_FFFF_FFFC) == -4);
}

bool f_24314(int a, int b) { return cast(ubyte)(a & b) != 0; }

void test24314()
{
    assert(!f_24314(0x100, 0x100));
}

bool f_24315(long x) { return x > 0xFFFF_FFFF; }

void test24315()
{
    assert(!f_24315(-1));
}

ulong f_24316(long x) { return (x << 38) + 1; }

void test24316()
{
    assert(f_24316(1) == 0x40_0000_0001);
}

long e19_24317(byte p0, ulong p1, ushort p2) { return (((p1 * 0xaU) - (1)) - p0); }

__gshared ulong[16] inputs_24317 = [0, 0xffffffffffffffefUL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

pragma(inline, false) void check_24317(const char* s, int k, ulong r) { assert(r == -171); }

void test24317()
{
    for (int k = 0; k < 1; k++)
        check_24317("e19_24317 %d %llx\n", k, cast(ulong)e19_24317(cast(byte)inputs_24317[(0) % 1], inputs_24317[(1) % 2], cast(ushort)inputs_24317[(k + 0) % 2]));
}

struct S1_24318 { int[1] m0; }
struct S2_24318 { int m0; short m1; }
struct S3_24318 { short[3] m0; int m1; }
struct S4_24318 { S3_24318 m0; }
extern(C) int d_f4_24318(S4_24318 a1, int a5, long a6, long a7, S1_24318 a8, S2_24318 a9, long a10, long a11, S3_24318 a12, long a13)
{
    ulong h = 31693UL;
    a1.m0.m0[1] = cast(short)(a1.m0.m0[1] + 1);
    a8.m0[0] = (a8.m0[0] + 1);
    a9.m1 = cast(short)(a9.m1 + 1);
    a12.m0[0] = cast(short)(a12.m0[0] + 1);
    h = h * 0x100000001b3UL ^ (a1.m0.m0[0]);
    h = h * 0x100000001b3UL ^ (a1.m0.m0[1]);
    h = h * 0x100000001b3UL ^ (a1.m0.m0[2]);
    h = h * 0x100000001b3UL ^ cast(long)(a1.m0.m1);
    h = h * 0x100000001b3UL ^ cast(long)a5;
    h = h * 0x100000001b3UL ^ a6;
    h = h * 0x100000001b3UL ^ a7;
    h = h * 0x100000001b3UL ^ cast(long)(a8.m0[0]);
    h = h * 0x100000001b3UL ^ cast(long)(a9.m0);
    h = h * 0x100000001b3UL ^ (a9.m1);
    h = h * 0x100000001b3UL ^ a10;
    h = h * 0x100000001b3UL ^ a11;
    h = h * 0x100000001b3UL ^ (a12.m0[0]);
    h = h * 0x100000001b3UL ^ (a12.m0[1]);
    h = h * 0x100000001b3UL ^ (a12.m0[2]);
    h = h * 0x100000001b3UL ^ cast(long)(a12.m1);
    h = h * 0x100000001b3UL ^ a13;
    int res;
    res = cast(int)h;
    h = h * 6364136223846793005UL + 11UL; h ^= h >> 29;
    return res;
}
extern(C) ulong d_hash4_24318(S4_24318 a1, int a5, long a6, long a7, S1_24318 a8, S2_24318 a9, long a10, long a11, S3_24318 a12, long a13)
{
    ulong h = 31693UL;
    return h;
}
__gshared ulong[1] seeds_24318 = [0x7cae167c11fd1e37UL];
void test24318()
{
    foreach (sd; seeds_24318) {
        ulong h = sd ^ 418916UL;
        S4_24318 a1; int a5; long a6; long a7; S1_24318 a8;
        a8.m0[0] = cast(int)h;
        S2_24318 a9; long a10; long a11; S3_24318 a12; long a13;
        int r1 = d_f4_24318(a1, a5, a6, a7, a8, a9, a10, a11, a12, a13);
        ulong h1 = d_hash4_24318(a1, a5, a6, a7, a8, a9, a10, a11, a12, a13);
        assert(r1 == 0xe8702e6a);
    }
}

__gshared uint g_24319 = 0x80;

bool f_24319(uint x) { return ((x >> 30) | (x << 2)) != 0; }

void test24319()
{
    if (g_24319 == 0x80)
        assert(f_24319(g_24319));
}

version (D_SIMD)
{
    __gshared ulong g0_24320 = 1;
    __gshared ulong g1_24320 = 1;

    ulong2 f_24320() { ulong2 v = g1_24320; return v; }

    void test24320()
    {
        assert(f_24320()[0] == 1);
    }
}

uint rol8_24321(uint v) { return (v << 8) | (v >> 24); }

pragma(inline, false) uint f_24321(int p) { return rol8_24321(p >> 8); }

void test24321()
{
    assert(f_24321(-3) == 0xFFFF_FFFF);
}

__gshared byte c_24323 = -6;
__gshared int k_24323 = 1;

long nz_24323(long x) { return x == 0 ? 3 : x; }

pragma(inline, false) long f_24323() { return nz_24323(-1 & (k_24323 ? c_24323 : 0)); }

void test24323()
{
    assert(f_24323() == -6);
}

long f_24309d(uint p1, byte p2) { return (p2 == 7 ? 5L : cast(long)cast(byte)(p1 <= 15)) != 0; }

void test24309d()
{
    assert(f_24309d(100, 0) == 0);
}

__gshared int sink_24325a;

int f_24325a(int n)
{
    int count = 0;
    for (int i = 0; i < n; i += 2)
    {
        sink_24325a = i << 28;
        ++count;
    }
    return count;
}

void test24325a()
{
    assert(f_24325a(15) == 8);
}

byte f_24327()
{
    byte a = 2;
    uint b = 0;
    short c = 0;
    byte r = !(c && b) || a;
    return r;
}

void test24327()
{
    assert(f_24327() == 1);
}

int f_24328(long p)
{
    int v = 0;
    if (0 < p - 1)
        v = 1;
    return v;
}

void test24328()
{
    assert(f_24328(long.min) == 1);
}

int f_24325b()
{
    int n = 0;
    ulong w = 0;
    for (ulong i = 0; i < 9; ++i)
    {
        w += i << 61;
        ++n;
    }
    return n;
}

void test24325b()
{
    assert(f_24325b() == 9);
}

int f_24329()
{
    int n = 0;
    for (int i = 0; n < 4; i += 0x4000_0000)
    {
        ++n;
        if (i < 0)
            return n;
    }
    return 0;
}

void test24329()
{
    assert(f_24329() == 3);
}

long f_24330(long x) { return x / long.min; }

void test24330()
{
    assert(f_24330(0) == 0);
}

byte f_24331a(int a) { return cast(byte)((a & 1) - ((a * -1) != 0)); }

void test24331a()
{
    assert(f_24331a(2) == -1);
}

long f_24332(long g)
{
    g -= int.min;
    return g;
}

void test24332()
{
    assert(f_24332(0) == 0x8000_0000);
}

ulong f_24333(ulong x) { return (x / 0xFFFF_FFFF_FFFF_FFFE) / 0xFFFF_FFFF_0000_0000; }

void test24333()
{
    assert(f_24333(ulong.max - 1) == 0);
}

pragma(inline, true) long nz_24309c(long x) { return x == 0 ? 0 : x; }

byte f_24309c(uint a, long b) { return cast(byte)(b / nz_24309c(cast(byte)(1 <= a))); }

void test24309c()
{
    assert(f_24309c(1, 0) == 0);
}

long f_24325c(byte p)
{
    long v = p;
    for (long i = 0; i < 2; ++i)
        v >>>= (p ^ ((i << 55) << 9)) & 63;
    return v;
}

void test24325c()
{
    assert(f_24325c(-38) == 0xFFF);
}

version (D_SIMD)
{
    void test24334()
    {
        int4 a = cast(int4)cast(float4)1;
        float4 f = 1;
        int4 b = cast(int4)f;
        assert(a[0] == b[0]);
    }
}

version (D_AVX2)
{
    ulong4 f_24335a(ulong4 p)
    {
        ulong4 v = 0 < p;
        p = p < 1;
        return p;
    }

    void test24335a()
    {
        ulong4 a = f_24335a([0, 1, 0, 5]);
        assert(a[2] == ulong.max);
    }
}

version (D_AVX2)
{
    long4 f_24335b(long4 p0, long4 p2) { return p2 > (p2 - (p2 & p0)); }

    void test24335b()
    {
        long4 r = f_24335b([0, 0, 1, 0], [0, 0, 0x7FFF_FFFF, 0]);
        assert(r[2] == -1);
    }
}

struct S_24309e { long f1 : 52; ushort f2 : 1; }

__gshared S_24309e s_24309e;

long dvm_24309e(long a, long b)
{
    if (b == 0 || b == -1)
        return a;
    return a % b;
}

pragma(inline, false) long t_24309e() { return dvm_24309e(1, s_24309e.f2); }

void test24309e()
{
    s_24309e.f2 = 1;
    assert(t_24309e() == 0);
}

double f_24351d(double x, double y) { return (x + 1.0) + y; }

void test24351d()
{
    assert(f_24351d(1e16, -1e16) == 0);
}

float f_24351e(float p) { return 1 + (p + 1); }

void test24351e()
{
    assert(f_24351e(16777217.0f) == 16777216.0f);
}

bool g_24338(short p) { return cast(double)p < cast(double)p - 0; }

__gshared ulong g_24339 = 0;

pragma(inline, true) int one_24339(int x) { return 1; }

byte f_24339(ushort p) { return cast(byte)((p != 0 || 0 / one_24339(p)) ? p : p); }

void test24339()
{
    long r = f_24339(cast(ushort)g_24339);
    assert(r == 0);
}

ulong f_24340(byte p0, int p1, int p2)
{
    short v = 0;
    if (~p1) {
        for (ubyte i = 0; i < 1; i += 2) {
        }
    }
    if (1) {
        v = cast(short)p2;
    }
    for (ubyte i = 0; i < ((v * 13) & 2); ++i) {
        v = 0;
    }
    return v;
}

__gshared ulong[24] inputs_24340 = [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

void test24340()
{
    ulong r = f_24340(cast(byte)inputs_24340[0 % 1], cast(int)inputs_24340[0 % 1], cast(int)inputs_24340[0 % 1]);
    assert(r == 0);
}

struct S_24341 { double a, b; }

ulong f_24341(S_24341 s) { return *cast(ulong*)&s.a; }

void test24341()
{
    assert(f_24341(S_24341(1.0, 2.0)) == 0x3FF0_0000_0000_0000);
}

pragma(inline, true) long nz_long_24331b(long x) { return (x == 0) ? 1 : x; }
ulong f0_24331b(long p8, uint p6, ushort p10)
{
    long v9 = 1;
    ulong v10 = 0;
    long v21 = 0;
    for (int i3 = 0; i3 < 1; i3++) {
        for (int i4 = 0; i4 < 1; i4++) {
            v21 >>= (p6 & 63);
        }
        for (int i5 = 0; i5 < 1; i5++) {
            v10 &= cast(ulong)p10;
            v9 /= nz_long_24331b(p8 / 2147483648L);
        }
        v10 &= 1;
    }
    return v9 ^ v21;
}
void test24331b()
{
    assert(f0_24331b(-4, 0, 0) == 1);
}

pragma(inline, true) int nz_int_24331c(int x) { return (x == 0 || x == -0) ? 2 : x; }
pragma(inline, true) long nz_long_24331c(long x) { return (0) ? 0 : x; }
pragma(inline, false) ubyte h0_24331c(ubyte q0) { return (0); }
ulong f0_24331c(long p0, short p1, ulong p2, long p3, byte p4, short p5, short p6)
{
    short v0 = (1);
    int v2 = (p4);
    for (int i1 = 0; i1 < 1; i1++) {
        p3 |= (1);
    }
    for (int i5 = 0; i5 < 1; i5++) {
        v0 /= nz_int_24331c(cast(int)(p3 / nz_long_24331c(long.min)));
        p1 ^= h0_24331c(cast(ubyte)(v2));
        p1 >>= ((cast(ubyte)(v2)) & 31);
    }
    return (v0 * 1) ^ (0) ^ (0);
}
__gshared ulong[16] inputs_24331c = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
void test24331c()
{
    for (int k = 0; k < 1; k++) {
        ulong r = f0_24331c(inputs_24331c[(0) % 1], cast(short)inputs_24331c[(0) % 1], inputs_24331c[(0) % 1], inputs_24331c[(0) % 1], cast(byte)inputs_24331c[(0) % 1], cast(short)inputs_24331c[(0) % 1], cast(short)inputs_24331c[(0) % 1]);
        assert(r == 0);
    }
}

struct S_24342a { double d; long x; }

void test24342a()
{
    S_24342a a;
    a.x = 0xFFF5_0000_0000_0000;
    S_24342a b = a;
    assert(b.x == 0xFFF5_0000_0000_0000);
}

struct S_24342b { double d; long x; }

extern(C) long f_24342b(long a0, long a1, long a2, long a3, long a4, long a5, S_24342b s) { return s.x; }

__gshared long g_24342b = 0xFFF5_0000_0000_0000;

void test24342b()
{
    S_24342b s;
    s.x = g_24342b;
    assert(f_24342b(0, 0, 0, 0, 0, 0, s) == 0xFFF5_0000_0000_0000);
}

version (D_AVX2)
{
    int8 f_24343a() { return cast(int8)(-cast(ushort16)1) + 1; }

    void test24343a()
    {
        assert(f_24343a()[0] == 0);
    }
}

version (D_SIMD)
{
    __gshared int g_24343b = 0x7FFF;

    ushort8 f_24343b(ushort8 p) { return p + cast(ushort8)(cast(int4)g_24343b + 0xFF); }

    void test24343b()
    {
        ushort8 r = f_24343b([0, 0, 0xFFFF, 0, 0, 0, 0, 0]);
        assert(r[3] == 0);
    }
}

version (D_AVX)
{
    int4 f_24343c(int4 v) { return cast(int4)(cast(short8)v + 1) * 3; }

    void test24343c()
    {
        assert(f_24343c(5)[0] == 0x30012);
    }
}

int g_24345();

bool f_24345() { return g_24345() && bswap(0UL); }

pragma(inline, true) ulong z_24346(double x) { return 0; }

real f_24346()
{
    real d = 0;
    d *= z_24346(0);
    return d;
}

ulong toU_24347(real x) { return 0 ? cast(ulong)x : 0; }

real f_24347()
{
    real d0 = toU_24347(0);
    real d1 = fabs(-0.0);
    return d0 - d1;
}

version (D_SIMD)
{
    float4 f_24348(float4 v) { return cast(float4)(cast(float4)(0 >= v) > v); }
}

version (D_SIMD)
{
    ushort8 f_24349(ushort8 p) { return 0 - (p * 1); }
}

version (D_SIMD)
{
    int4 f_24350(int4 v) { return 1 ^ (v <= v); }
}

double f_24351a(double x) { return 0.0 - x; }

void test24351a()
{
    assert(1 / f_24351a(0.0) > 0);
}

__gshared real r_24351g = 1.0L + 0x1p-60L;

real f_24351g() { return cast(real)cast(double)r_24351g; }

void test24351g()
{
    assert(f_24351g() == 1.0L);
}

double f_24351b(double x) { return (x + 1) * -1.0; }

void test24351b()
{
    assert(1 / f_24351b(-1.0) < 0);
}

double f_24351f(int n)
{
    double x = 0, last = 0;
    for (int i = 0; i < n; ++i)
    {
        last = x * 0.1;
        x += 1.0;
    }
    return last;
}

void test24351f()
{
    assert(f_24351f(1000) == 999 * 0.1);
}

version (D_SIMD)
{
    float4 f_24351c(float4 x) { return -x; }

    void test24351c()
    {
        float4 z = 0;
        assert(1 / f_24351c(z)[0] < 0);
    }
}

__gshared double g_24351h = 0x1.074f8c4d3cd7bp+0;

real f_24351h() { return cast(real)cast(double)cast(float)g_24351h; }

void test24351h()
{
    assert(f_24351h() == 0x1.074f8cp+0L);
}

__gshared real r_24351i = 1.0L + 0x1p-24L + 0x1p-60L;

float f_24351i() { return cast(float)cast(double)r_24351i; }

void test24351i()
{
    assert(f_24351i() == 1.0f);
}

bool f_24351k(double x, double y) { return !(x + y); }

void test24351k()
{
    assert(!f_24351k(double.nan, 1));
}

float f_24353(long p1)
{
    float d0 = 1;
    if (d0 > p1)
        d0 *= 0;
    if ((cast(double)d0 * p1) <= cast(real)(d0 <= d0))
        d0 /= (p1 * d0);
    return d0;
}

ulong f_24354(real p0)
{
    real d0 = p0;
    long n0 = 0;
    if (0)
    {
        if (0)
            d0 += 0;
        else
            d0 = 0;
    }
    else
        n0 ^= 1;
    return n0;
}

int test24354()
{
    return cast(int)f_24354(1.0L) - 1;
}

uint f_24351j(long x)
{
    float r = cast(float)x;
    return *cast(uint*)&r;
}

void test24351j()
{
    assert(f_24351j(0x20_0000_2000_0001) == 0x5A00_0001);
}

int f_24351l(ulong p, double d)
{
    if (p ? cast(real)cast(float)d : 0)
        return 1;
    return 0;
}

void test24351l()
{
    assert(f_24351l(1, double.nan) == 1);
}
}

/**************************************************/

void main()
{
    //test24111();
    test24112();
    //test24113();
    test24304();
/*
    test24305();
    test24306();
    test24307();
    test24308();
    test24309a();
    test24309b();
    test24310();
    test24311();
    test24312();
    test24313();
    test24314();
    test24315();
    test24316();
    test24317();
    test24318();
    test24319();
    version (D_SIMD) test24320();
    test24321();
    test24323();
    test24309d();
    test24325a();
    test24327();
    test24328();
    test24325b();
    test24329();
    test24330();
    test24331a();
    test24332();
    test24333();
    test24309c();
    test24325c();
    version (D_SIMD) test24334();
    version (D_AVX2) test24335a();
    version (D_AVX2) test24335b();
    test24309e();
    test24351d();
    test24351e();
    test24339();
    test24340();
    test24341();
    test24331b();
    test24331c();
    test24342a();
    test24342b();
    version (D_AVX2) test24343a();
    version (D_SIMD) test24343b();
    version (D_AVX) test24343c();
    test24351a();
    test24351g();
    test24351b();
    test24351f();
    version (D_SIMD) test24351c();
    test24351h();
    test24351i();
    test24351k();
    assert(test24354() == 0);
    test24351j();
    test24351l();
*/
}
