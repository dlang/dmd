// REQUIRED_ARGS:
// PERMUTE_ARGS: -mcpu=native -inline -O

version (D_SIMD)
{

import core.simd;
import core.stdc.stdio;
import core.stdc.string;

alias TypeTuple(T...) = T;

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=16087

static if (__traits(compiles, void8))   static assert(void8.alignof == 8);
static if (__traits(compiles, double1)) static assert(double1.alignof == 8);
static if (__traits(compiles, float2))  static assert(float2.alignof == 8);
static if (__traits(compiles, byte8))   static assert(byte8.alignof == 8);
static if (__traits(compiles, ubyte8))  static assert(ubyte8.alignof == 8);
static if (__traits(compiles, short4))  static assert(short4.alignof == 8);
static if (__traits(compiles, ushort4)) static assert(ushort4.alignof == 8);
static if (__traits(compiles, int2))    static assert(int2.alignof == 8);
static if (__traits(compiles, uint2))   static assert(uint2.alignof == 8);
static if (__traits(compiles, long1))   static assert(long1.alignof == 8);
static if (__traits(compiles, ulong1))  static assert(ulong1.alignof == 8);

static if (__traits(compiles, void8))   static assert(void8.sizeof == 8);
static if (__traits(compiles, double1)) static assert(double1.sizeof == 8);
static if (__traits(compiles, float2))  static assert(float2.sizeof == 8);
static if (__traits(compiles, byte8))   static assert(byte8.sizeof == 8);
static if (__traits(compiles, ubyte8))  static assert(ubyte8.sizeof == 8);
static if (__traits(compiles, short4))  static assert(short4.sizeof == 8);
static if (__traits(compiles, ushort4)) static assert(ushort4.sizeof == 8);
static if (__traits(compiles, int2))    static assert(int2.sizeof == 8);
static if (__traits(compiles, uint2))   static assert(uint2.sizeof == 8);
static if (__traits(compiles, long1))   static assert(long1.sizeof == 8);
static if (__traits(compiles, ulong1))  static assert(ulong1.sizeof == 8);

static if (__traits(compiles, void16))  static assert(void16.alignof == 16);
static if (__traits(compiles, double2)) static assert(double2.alignof == 16);
static if (__traits(compiles, float4))  static assert(float4.alignof == 16);
static if (__traits(compiles, byte16))  static assert(byte16.alignof == 16);
static if (__traits(compiles, ubyte16)) static assert(ubyte16.alignof == 16);
static if (__traits(compiles, short8))  static assert(short8.alignof == 16);
static if (__traits(compiles, ushort8)) static assert(ushort8.alignof == 16);
static if (__traits(compiles, int4))    static assert(int4.alignof == 16);
static if (__traits(compiles, uint4))   static assert(uint4.alignof == 16);
static if (__traits(compiles, long2))   static assert(long2.alignof == 16);
static if (__traits(compiles, ulong2))  static assert(ulong2.alignof == 16);

static if (__traits(compiles, void16))  static assert(void16.sizeof == 16);
static if (__traits(compiles, double2)) static assert(double2.sizeof == 16);
static if (__traits(compiles, float4))  static assert(float4.sizeof == 16);
static if (__traits(compiles, byte16))  static assert(byte16.sizeof == 16);
static if (__traits(compiles, ubyte16)) static assert(ubyte16.sizeof == 16);
static if (__traits(compiles, short8))  static assert(short8.sizeof == 16);
static if (__traits(compiles, ushort8)) static assert(ushort8.sizeof == 16);
static if (__traits(compiles, int4))    static assert(int4.sizeof == 16);
static if (__traits(compiles, uint4))   static assert(uint4.sizeof == 16);
static if (__traits(compiles, long2))   static assert(long2.sizeof == 16);
static if (__traits(compiles, ulong2))  static assert(ulong2.sizeof == 16);

static if (__traits(compiles, void32))   static assert(void32.alignof == 32);
static if (__traits(compiles, double4))  static assert(double4.alignof == 32);
static if (__traits(compiles, float8))   static assert(float8.alignof == 32);
static if (__traits(compiles, byte32))   static assert(byte32.alignof == 32);
static if (__traits(compiles, ubyte32))  static assert(ubyte32.alignof == 32);
static if (__traits(compiles, short16))  static assert(short16.alignof == 32);
static if (__traits(compiles, ushort16)) static assert(ushort16.alignof == 32);
static if (__traits(compiles, int8))     static assert(int8.alignof == 32);
static if (__traits(compiles, uint8))    static assert(uint8.alignof == 32);
static if (__traits(compiles, long4))    static assert(long4.alignof == 32);
static if (__traits(compiles, ulong4))   static assert(ulong4.alignof == 32);

static if (__traits(compiles, void32))   static assert(void32.sizeof == 32);
static if (__traits(compiles, double4))  static assert(double4.sizeof == 32);
static if (__traits(compiles, float8))   static assert(float8.sizeof == 32);
static if (__traits(compiles, byte32))   static assert(byte32.sizeof == 32);
static if (__traits(compiles, ubyte32))  static assert(ubyte32.sizeof == 32);
static if (__traits(compiles, short16))  static assert(short16.sizeof == 32);
static if (__traits(compiles, ushort16)) static assert(ushort16.sizeof == 32);
static if (__traits(compiles, int8))     static assert(int8.sizeof == 32);
static if (__traits(compiles, uint8))    static assert(uint8.sizeof == 32);
static if (__traits(compiles, long4))    static assert(long4.sizeof == 32);
static if (__traits(compiles, ulong4))   static assert(ulong4.sizeof == 32);

static if (__traits(compiles, void64))   static assert(void64.alignof == 64);
static if (__traits(compiles, double8))  static assert(double8.alignof == 64);
static if (__traits(compiles, float16))  static assert(float16.alignof == 64);
static if (__traits(compiles, byte64))   static assert(byte64.alignof == 64);
static if (__traits(compiles, ubyte64))  static assert(ubyte64.alignof == 64);
static if (__traits(compiles, short32))  static assert(short32.alignof == 64);
static if (__traits(compiles, ushort32)) static assert(ushort32.alignof == 64);
static if (__traits(compiles, int16))    static assert(int16.alignof == 64);
static if (__traits(compiles, uint16))   static assert(uint16.alignof == 64);
static if (__traits(compiles, long8))    static assert(long8.alignof == 64);
static if (__traits(compiles, ulong8))   static assert(ulong8.alignof == 64);

static if (__traits(compiles, void64))   static assert(void64.sizeof == 64);
static if (__traits(compiles, double8))  static assert(double8.sizeof == 64);
static if (__traits(compiles, float16))  static assert(float16.sizeof == 64);
static if (__traits(compiles, byte64))   static assert(byte64.sizeof == 64);
static if (__traits(compiles, ubyte64))  static assert(ubyte64.sizeof == 64);
static if (__traits(compiles, short32))  static assert(short32.sizeof == 64);
static if (__traits(compiles, ushort32)) static assert(ushort32.sizeof == 64);
static if (__traits(compiles, int16))    static assert(int16.sizeof == 64);
static if (__traits(compiles, uint16))   static assert(uint16.sizeof == 64);
static if (__traits(compiles, long8))    static assert(long8.sizeof == 64);
static if (__traits(compiles, ulong8))   static assert(ulong8.sizeof == 64);

/*****************************************/

void test1()
{
    void16 v1 = void,v2 = void;
    byte16 b;
    v2 = b;
    v1 = v2;
    static assert(!__traits(compiles, v1 + v2));
    static assert(!__traits(compiles, v1 - v2));
    static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    static assert(!__traits(compiles, v1 & v2));
    static assert(!__traits(compiles, v1 | v2));
    static assert(!__traits(compiles, v1 ^ v2));
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert(!__traits(compiles, v1 == v2));
    static assert(!__traits(compiles, v1 != v2));
    static assert(!__traits(compiles, v1 < v2));
    static assert(!__traits(compiles, v1 > v2));
    static assert(!__traits(compiles, v1 <= v2));
    static assert(!__traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    static assert(!__traits(compiles, ~v1));
    static assert(!__traits(compiles, -v1));
    static assert(!__traits(compiles, +v1));
    static assert(!__traits(compiles, !v1));

    static assert(!__traits(compiles, v1 += v2));
    static assert(!__traits(compiles, v1 -= v2));
    static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    static assert(!__traits(compiles, v1 &= v2));
    static assert(!__traits(compiles, v1 |= v2));
    static assert(!__traits(compiles, v1 ^= v2));
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2()
{
    byte16 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2b()
{
    ubyte16 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2c()
{
    short8 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    v1 = v2 * v3;
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    v1 *= v2;
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));
    v1 = v1 * 3;

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2d()
{
    ushort8 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    v1 = v2 * v3;
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    v1 *= v2;
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2e()
{
    int4 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    static if (__traits(compiles, { v1 = v2 * v3; })) // SSE4.1
        v1 = v2 * v3;
    else
        static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    static if (__traits(compiles, { v1 *= v2; })) // SSE4.1
        v1 *= v2;
    else
        static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2f()
{
    uint4 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    static if (__traits(compiles, { v1 = v2 * v3; })) // SSE4.1
        v1 = v2 * v3;
    else
        static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    static if (__traits(compiles, { v1 *= v2; })) // SSE4.1
        v1 *= v2;
    else
        static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2g()
{
    long2 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static if (__traits(compiles, v1 == v2)) // SSE4.1
    {
        v1 = v2 == v3;
        v1 = v2 != v3;
    }
    else
    {
        static assert(!__traits(compiles, v1 == v2));
        static assert(!__traits(compiles, v1 != v2));
    }
    static if (__traits(compiles, v1 < v2)) // SSE4.2
    {
        v1 = v2 < v3;
        v1 = v2 > v3;
        v1 = v2 <= v3;
        v1 = v2 >= v3;
    }
    else
    {
        static assert(!__traits(compiles, v1 < v2));
        static assert(!__traits(compiles, v1 > v2));
        static assert(!__traits(compiles, v1 <= v2));
        static assert(!__traits(compiles, v1 >= v2));
    }
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2h()
{
    ulong2 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    static assert(!__traits(compiles, v1 * v2));
    static assert(!__traits(compiles, v1 / v2));
    static assert(!__traits(compiles, v1 % v2));
    v1 = v2 & v3;
    v1 = v2 | v3;
    v1 = v2 ^ v3;
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static if (__traits(compiles, v1 == v2)) // SSE4.1
    {
        v1 = v2 == v3;
        v1 = v2 != v3;
    }
    else
    {
        static assert(!__traits(compiles, v1 == v2));
        static assert(!__traits(compiles, v1 != v2));
    }
    static if (__traits(compiles, v1 < v2)) // SSE4.2
    {
        v1 = v2 < v3;
        v1 = v2 > v3;
        v1 = v2 <= v3;
        v1 = v2 >= v3;
    }
    else
    {
        static assert(!__traits(compiles, v1 < v2));
        static assert(!__traits(compiles, v1 > v2));
        static assert(!__traits(compiles, v1 <= v2));
        static assert(!__traits(compiles, v1 >= v2));
    }
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    v1 = ~v2;
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    static assert(!__traits(compiles, v1 *= v2));
    static assert(!__traits(compiles, v1 /= v2));
    static assert(!__traits(compiles, v1 %= v2));
    v1 &= v2;
    v1 |= v2;
    v1 ^= v2;
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2i()
{
    float4 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    v1 = v2 * v3;
    v1 = v2 / v3;
    static assert(!__traits(compiles, v1 % v2));
    static assert(!__traits(compiles, v1 & v2));
    static assert(!__traits(compiles, v1 | v2));
    static assert(!__traits(compiles, v1 ^ v2));
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    static assert(!__traits(compiles, ~v1));
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    v1 *= v2;
    v1 /= v2;
    static assert(!__traits(compiles, v1 %= v2));
    static assert(!__traits(compiles, v1 &= v2));
    static assert(!__traits(compiles, v1 |= v2));
    static assert(!__traits(compiles, v1 ^= v2));
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

void test2j()
{
    double2 v1, v2 = 1, v3 = 1;
    v1 = v2;
    v1 = v2 + v3;
    v1 = v2 - v3;
    v1 = v2 * v3;
    v1 = v2 / v3;
    static assert(!__traits(compiles, v1 % v2));
    static assert(!__traits(compiles, v1 & v2));
    static assert(!__traits(compiles, v1 | v2));
    static assert(!__traits(compiles, v1 ^ v2));
    static assert(!__traits(compiles, v1 ~ v2));
    static assert(!__traits(compiles, v1 ^^ v2));
    static assert(!__traits(compiles, v1 is v2));
    static assert(!__traits(compiles, v1 !is v2));
    static assert( __traits(compiles, v1 == v2));
    static assert( __traits(compiles, v1 != v2));
    static assert( __traits(compiles, v1 < v2));
    static assert( __traits(compiles, v1 > v2));
    static assert( __traits(compiles, v1 <= v2));
    static assert( __traits(compiles, v1 >= v2));
    static assert(!__traits(compiles, v1 << 1));
    static assert(!__traits(compiles, v1 >> 1));
    static assert(!__traits(compiles, v1 >>> 1));
    static assert(!__traits(compiles, v1 && v2));
    static assert(!__traits(compiles, v1 || v2));
    static assert(!__traits(compiles, ~v1));
    v1 = -v2;
    v1 = +v2;
    static assert(!__traits(compiles, !v1));

    v1 += v2;
    v1 -= v2;
    v1 *= v2;
    v1 /= v2;
    static assert(!__traits(compiles, v1 %= v2));
    static assert(!__traits(compiles, v1 &= v2));
    static assert(!__traits(compiles, v1 |= v2));
    static assert(!__traits(compiles, v1 ^= v2));
    static assert(!__traits(compiles, v1 ~= v2));
    static assert(!__traits(compiles, v1 ^^= v2));
    static assert(!__traits(compiles, v1 <<= 1));
    static assert(!__traits(compiles, v1 >>= 1));
    static assert(!__traits(compiles, v1 >>>= 1));

    //  A cast from vector to non-vector is allowed only when the target is same size Tsarray.
    static assert(!__traits(compiles, cast(byte)v1));       // 1byte
    static assert(!__traits(compiles, cast(short)v1));      // 2byte
    static assert(!__traits(compiles, cast(int)v1));        // 4byte
    static assert(!__traits(compiles, cast(long)v1));       // 8byte
    static assert(!__traits(compiles, cast(float)v1));      // 4byte
    static assert(!__traits(compiles, cast(double)v1));     // 8byte
    static assert(!__traits(compiles, cast(int[2])v1));     // 8byte Tsarray
    static assert( __traits(compiles, cast(int[4])v1));     // 16byte Tsarray, OK
    static assert( __traits(compiles, cast(long[2])v1));    // 16byte Tsarray, OK
}

/*****************************************/

float4 test3()
{
    float4 a;
    a = cast(float4)__simd(XMM.PXOR, a, a);
    return a;
}

/*****************************************/

void test4()
{
    int4 c = 7;
    (cast(int[4])c)[3] = 4;
    (cast(int*)&c)[2] = 4;
    c.array[1] = 4;
    c.ptr[3] = 4;
    assert(c.length == 4);
}

/*****************************************/

void BaseTypeOfVector(T : __vector(T[N]), size_t N)(int i)
{
    assert(is(T == int));
    assert(N == 4);
}


void test7411()
{
    BaseTypeOfVector!(__vector(int[4]))(3);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=7951

float[4] test7951()
{
    float4 v1;
    float4 v2;

    return cast(float[4])(v1+v2);
}

/*****************************************/

void test7951_2()
{
    float[4] v1 = [1,2,3,4];
    float[4] v2 = [1,2,3,4];
    float4 f1, f2, f3;
    f1.array = v1;
    f2.array = v2;
    f3 = f1 + f2;
    assert((cast(float[4])f3)[2] == 6);
}

/*****************************************/

void test7949()
{
    int[4] o = [1,2,3,4];
    int4 v1;
    v1.array = o;
    int4 v2;
    v2.array = o;



    auto r = __simd(XMM.ADDPS, v1,v2);

    assert(cast(int[4])r.array == [2, 4, 6, 8]);
}

/*****************************************/

immutable ulong2 gulong2 = 0x8000_0000_0000_0000;
immutable uint4 guint4 = 0x8000_0000;
immutable ushort8 gushort8 = 0x8000;
immutable ubyte16 gubyte16 = 0x80;

immutable long2 glong2 = 0x7000_0000_0000_0000;
immutable int4 gint4 = 0x7000_0000;
immutable short8 gshort8 = 0x7000;
immutable byte16 gbyte16 = 0x70;

immutable float4 gfloat4 = 4.0;
immutable double2 gdouble2 = 8.0;

void test7414()
{
    immutable ulong2 lulong2 = 0x8000_0000_0000_0000;
    assert(memcmp(&lulong2, &gulong2, gulong2.sizeof) == 0);

    immutable uint4 luint4 = 0x8000_0000;
    assert(memcmp(&luint4, &guint4, guint4.sizeof) == 0);

    immutable ushort8 lushort8 = 0x8000;
    assert(memcmp(&lushort8, &gushort8, gushort8.sizeof) == 0);

    immutable ubyte16 lubyte16 = 0x80;
    assert(memcmp(&lubyte16, &gubyte16, gubyte16.sizeof) == 0);


    immutable long2 llong2 = 0x7000_0000_0000_0000;
    assert(memcmp(&llong2, &glong2, glong2.sizeof) == 0);

    immutable int4 lint4 = 0x7000_0000;
    assert(memcmp(&lint4, &gint4, gint4.sizeof) == 0);

    immutable short8 lshort8 = 0x7000;
    assert(memcmp(&lshort8, &gshort8, gshort8.sizeof) == 0);

    immutable byte16 lbyte16 = 0x70;
    assert(memcmp(&lbyte16, &gbyte16, gbyte16.sizeof) == 0);


    immutable float4 lfloat4 = 4.0;
    assert(memcmp(&lfloat4, &gfloat4, gfloat4.sizeof) == 0);

    immutable double2 ldouble2 = 8.0;
    assert(memcmp(&ldouble2, &gdouble2, gdouble2.sizeof) == 0);
}

/*****************************************/

void test7413()
{
    byte16 b = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
    assert(b.array[0] == 1);
    assert(b.array[1] == 2);
    assert(b.array[2] == 3);
    assert(b.array[3] == 4);
    assert(b.array[4] == 5);
    assert(b.array[5] == 6);
    assert(b.array[6] == 7);
    assert(b.array[7] == 8);
    assert(b.array[8] == 9);
    assert(b.array[9] == 10);
    assert(b.array[10] == 11);
    assert(b.array[11] == 12);
    assert(b.array[12] == 13);
    assert(b.array[13] == 14);
    assert(b.array[14] == 15);
    assert(b.array[15] == 16);

    ubyte16 ub = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
    assert(ub.array[0] == 1);
    assert(ub.array[1] == 2);
    assert(ub.array[2] == 3);
    assert(ub.array[3] == 4);
    assert(ub.array[4] == 5);
    assert(ub.array[5] == 6);
    assert(ub.array[6] == 7);
    assert(ub.array[7] == 8);
    assert(ub.array[8] == 9);
    assert(ub.array[9] == 10);
    assert(ub.array[10] == 11);
    assert(ub.array[11] == 12);
    assert(ub.array[12] == 13);
    assert(ub.array[13] == 14);
    assert(ub.array[14] == 15);
    assert(ub.array[15] == 16);

    short8 s = [1,2,3,4,5,6,7,8];
    assert(s.array[0] == 1);
    assert(s.array[1] == 2);
    assert(s.array[2] == 3);
    assert(s.array[3] == 4);
    assert(s.array[4] == 5);
    assert(s.array[5] == 6);
    assert(s.array[6] == 7);
    assert(s.array[7] == 8);

    ushort8 us = [1,2,3,4,5,6,7,8];
    assert(us.array[0] == 1);
    assert(us.array[1] == 2);
    assert(us.array[2] == 3);
    assert(us.array[3] == 4);
    assert(us.array[4] == 5);
    assert(us.array[5] == 6);
    assert(us.array[6] == 7);
    assert(us.array[7] == 8);

    int4 i = [1,2,3,4];
    assert(i.array[0] == 1);
    assert(i.array[1] == 2);
    assert(i.array[2] == 3);
    assert(i.array[3] == 4);

    uint4 ui = [1,2,3,4];
    assert(ui.array[0] == 1);
    assert(ui.array[1] == 2);
    assert(ui.array[2] == 3);
    assert(ui.array[3] == 4);

    long2 l = [1,2];
    assert(l.array[0] == 1);
    assert(l.array[1] == 2);

    ulong2 ul = [1,2];
    assert(ul.array[0] == 1);
    assert(ul.array[1] == 2);

    float4 f = [1,2,3,4];
    assert(f.array[0] == 1);
    assert(f.array[1] == 2);
    assert(f.array[2] == 3);
    assert(f.array[3] == 4);

    double2 d = [1,2];
    assert(d.array[0] == 1);
    assert(d.array[1] == 2);
}

/*****************************************/

byte16 b = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
ubyte16 ub = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
short8 s = [1,2,3,4,5,6,7,8];
ushort8 us = [1,2,3,4,5,6,7,8];
int4 i = [1,2,3,4];
uint4 ui = [1,2,3,4];
long2 l = [1,2];
ulong2 ul = [1,2];
float4 f = [1,2,3,4];
double2 d = [1,2];

void test7413_2()
{
    assert(b.array[0] == 1);
    assert(b.array[1] == 2);
    assert(b.array[2] == 3);
    assert(b.array[3] == 4);
    assert(b.array[4] == 5);
    assert(b.array[5] == 6);
    assert(b.array[6] == 7);
    assert(b.array[7] == 8);
    assert(b.array[8] == 9);
    assert(b.array[9] == 10);
    assert(b.array[10] == 11);
    assert(b.array[11] == 12);
    assert(b.array[12] == 13);
    assert(b.array[13] == 14);
    assert(b.array[14] == 15);
    assert(b.array[15] == 16);

    assert(ub.array[0] == 1);
    assert(ub.array[1] == 2);
    assert(ub.array[2] == 3);
    assert(ub.array[3] == 4);
    assert(ub.array[4] == 5);
    assert(ub.array[5] == 6);
    assert(ub.array[6] == 7);
    assert(ub.array[7] == 8);
    assert(ub.array[8] == 9);
    assert(ub.array[9] == 10);
    assert(ub.array[10] == 11);
    assert(ub.array[11] == 12);
    assert(ub.array[12] == 13);
    assert(ub.array[13] == 14);
    assert(ub.array[14] == 15);
    assert(ub.array[15] == 16);

    assert(s.array[0] == 1);
    assert(s.array[1] == 2);
    assert(s.array[2] == 3);
    assert(s.array[3] == 4);
    assert(s.array[4] == 5);
    assert(s.array[5] == 6);
    assert(s.array[6] == 7);
    assert(s.array[7] == 8);

    assert(us.array[0] == 1);
    assert(us.array[1] == 2);
    assert(us.array[2] == 3);
    assert(us.array[3] == 4);
    assert(us.array[4] == 5);
    assert(us.array[5] == 6);
    assert(us.array[6] == 7);
    assert(us.array[7] == 8);

    assert(i.array[0] == 1);
    assert(i.array[1] == 2);
    assert(i.array[2] == 3);
    assert(i.array[3] == 4);

    assert(ui.array[0] == 1);
    assert(ui.array[1] == 2);
    assert(ui.array[2] == 3);
    assert(ui.array[3] == 4);

    assert(l.array[0] == 1);
    assert(l.array[1] == 2);

    assert(ul.array[0] == 1);
    assert(ul.array[1] == 2);

    assert(f.array[0] == 1);
    assert(f.array[1] == 2);
    assert(f.array[2] == 3);
    assert(f.array[3] == 4);

    assert(d.array[0] == 1);
    assert(d.array[1] == 2);
}

/*****************************************/

float bug8060(float x) {
    int i = *cast(int*)&x;
    ++i;
    return *cast(float*)&i;
}

/*****************************************/

float4 test5(void16 a, void16 b)
{
    a = __simd(XMM.ADDPD, a, b);
    a = __simd(XMM.ADDSS, a, b);
    a = __simd(XMM.ADDSD, a, b);
    a = __simd(XMM.ADDPS, a, b);
    a = __simd(XMM.PADDB, a, b);
    a = __simd(XMM.PADDW, a, b);
    a = __simd(XMM.PADDD, a, b);
    a = __simd(XMM.PADDQ, a, b);

    a = __simd(XMM.SUBPD, a, b);
    a = __simd(XMM.SUBSS, a, b);
    a = __simd(XMM.SUBSD, a, b);
    a = __simd(XMM.SUBPS, a, b);
    a = __simd(XMM.PSUBB, a, b);
    a = __simd(XMM.PSUBW, a, b);
    a = __simd(XMM.PSUBD, a, b);
    a = __simd(XMM.PSUBQ, a, b);

    a = __simd(XMM.MULPD, a, b);
    a = __simd(XMM.MULSS, a, b);
    a = __simd(XMM.MULSD, a, b);
    a = __simd(XMM.MULPS, a, b);
    a = __simd(XMM.PMULLW, a, b);

    a = __simd(XMM.DIVPD, a, b);
    a = __simd(XMM.DIVSS, a, b);
    a = __simd(XMM.DIVSD, a, b);
    a = __simd(XMM.DIVPS, a, b);

    a = __simd(XMM.PAND, a, b);
    a = __simd(XMM.POR, a, b);

    a = __simd(XMM.UCOMISS, a, b);
    a = __simd(XMM.UCOMISD, a, b);

    a = __simd(XMM.XORPS, a, b);
    a = __simd(XMM.XORPD, a, b);

    a = __simd_sto(XMM.STOSS, a, b);
    a = __simd_sto(XMM.STOSD, a, b);
    a = __simd_sto(XMM.STOD, a, b);
    a = __simd_sto(XMM.STOQ, a, b);
    a = __simd_sto(XMM.STOAPS, a, b);
    a = __simd_sto(XMM.STOAPD, a, b);
    a = __simd_sto(XMM.STODQA, a, b);
    a = __simd_sto(XMM.STOUPS, a, b);
    a = __simd_sto(XMM.STOUPD, a, b);
    a = __simd_sto(XMM.STODQU, a, b);
    a = __simd_sto(XMM.STOHPD, a, b);
    a = __simd_sto(XMM.STOHPS, a, b);
    a = __simd_sto(XMM.STOLPD, a, b);
    a = __simd_sto(XMM.STOLPS, a, b);

    a = __simd(XMM.LODSS, a);
    a = __simd(XMM.LODSD, a);
    a = __simd(XMM.LODAPS, a);
    a = __simd(XMM.LODAPD, a);
    a = __simd(XMM.LODDQA, a);
    a = __simd(XMM.LODUPS, a);
    a = __simd(XMM.LODUPD, a);
    a = __simd(XMM.LODDQU, a);
    a = __simd(XMM.LODD, a);
    a = __simd(XMM.LODQ, a);
    a = __simd(XMM.LODHPD, a);
    a = __simd(XMM.LODHPS, a);
    a = __simd(XMM.LODLPD, a);
    a = __simd(XMM.LODLPS, a);

    //MOVDQ2Q  = 0xF20FD6,        // MOVDQ2Q mmx, xmm          F2 0F D6 /r
/+
    LODHPD   = 0x660F16,        // MOVHPD xmm, mem64         66 0F 16 /r
    STOHPD   = 0x660F17,        // MOVHPD mem64, xmm         66 0F 17 /r
    LODHPS   = 0x0F16,          // MOVHPS xmm, mem64         0F 16 /r
    STOHPS   = 0x0F17,          // MOVHPS mem64, xmm         0F 17 /r
    MOVLHPS  = 0x0F16,          // MOVLHPS xmm1, xmm2        0F 16 /r
    LODLPD   = 0x660F12,        // MOVLPD xmm, mem64         66 0F 12 /r
    STOLPD   = 0x660F13,        // MOVLPD mem64, xmm         66 0F 13 /r
    a = __simd(XMM.LODLPS, a, b);
    STOLPS   = 0x0F13,          // MOVLPS mem64, xmm         0F 13 /r
    MOVMSKPD = 0x660F50,        // MOVMSKPD reg32, xmm 66 0F 50 /r
    MOVMSKPS = 0x0F50,          // MOVMSKPS reg32, xmm 0F 50 /r
    MOVNTDQ  = 0x660FE7,        // MOVNTDQ mem128, xmm 66 0F E7 /r
    MOVNTI   = 0x0FC3,          // MOVNTI m32,r32 0F C3 /r
                                // MOVNTI m64,r64 0F C3 /r
    MOVNTPD  = 0x660F2B,        // MOVNTPD mem128, xmm 66 0F 2B /r
    MOVNTPS  = 0x0F2B,          // MOVNTPS mem128, xmm 0F 2B /r
    //MOVNTQ   = 0x0FE7,          // MOVNTQ m64, mmx 0F E7 /r
    //MOVQ2DQ  = 0xF30FD6,        // MOVQ2DQ xmm, mmx F3 0F D6 /r
 +/
    a = __simd(XMM.LODUPD, a, b);
    a = __simd_sto(XMM.STOUPD, a, b);
    a = __simd(XMM.LODUPS, a, b);
    a = __simd_sto(XMM.STOUPS, a, b);

    a = __simd(XMM.PACKSSDW, a, b);
    a = __simd(XMM.PACKSSWB, a, b);
    a = __simd(XMM.PACKUSWB, a, b);
    a = __simd(XMM.PADDSB, a, b);
    a = __simd(XMM.PADDSW, a, b);
    a = __simd(XMM.PADDUSB, a, b);
    a = __simd(XMM.PADDUSW, a, b);
    a = __simd(XMM.PANDN, a, b);
    a = __simd(XMM.PCMPEQB, a, b);
    a = __simd(XMM.PCMPEQD, a, b);
    a = __simd(XMM.PCMPEQW, a, b);
    a = __simd(XMM.PCMPGTB, a, b);
    a = __simd(XMM.PCMPGTD, a, b);
    a = __simd(XMM.PCMPGTW, a, b);
    a = __simd(XMM.PMADDWD, a, b);
    a = __simd(XMM.PSLLW, a, b);
    a = __simd_ib(XMM.PSLLW, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSLLD, a, b);
    a = __simd_ib(XMM.PSLLD, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSLLQ, a, b);
    a = __simd_ib(XMM.PSLLQ, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSRAW, a, b);
    a = __simd_ib(XMM.PSRAW, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSRAD, a, b);
    a = __simd_ib(XMM.PSRAD, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSRLW, a, b);
    a = __simd_ib(XMM.PSRLW, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSRLD, a, b);
    a = __simd_ib(XMM.PSRLD, a, cast(ubyte)0x7A);
    a = __simd(XMM.PSRLQ, a, b);
    a = __simd_ib(XMM.PSRLQ, a, cast(ubyte)0x7A);

    a = __simd(XMM.PSUBSB, a, b);
    a = __simd(XMM.PSUBSW, a, b);
    a = __simd(XMM.PSUBUSB, a, b);
    a = __simd(XMM.PSUBUSW, a, b);

    a = __simd(XMM.PUNPCKHBW, a, b);
    a = __simd(XMM.PUNPCKHDQ, a, b);
    a = __simd(XMM.PUNPCKHWD, a, b);
    a = __simd(XMM.PUNPCKLBW, a, b);
    a = __simd(XMM.PUNPCKLDQ, a, b);
    a = __simd(XMM.PUNPCKLWD, a, b);

    a = __simd(XMM.PXOR, a, b);
    a = __simd(XMM.ANDPD, a, b);
    a = __simd(XMM.ANDPS, a, b);
    a = __simd(XMM.ANDNPD, a, b);
    a = __simd(XMM.ANDNPS, a, b);

    a = __simd(XMM.CMPPD, a, b, 0x7A);
    a = __simd(XMM.CMPSS, a, b, 0x7A);
    a = __simd(XMM.CMPSD, a, b, 0x7A);
    a = __simd(XMM.CMPPS, a, b, 0x7A);

    a = __simd(XMM.CVTDQ2PD, a, b);
    a = __simd(XMM.CVTDQ2PS, a, b);
    a = __simd(XMM.CVTPD2DQ, a, b);
    //a = __simd(XMM.CVTPD2PI, a, b);
    a = __simd(XMM.CVTPD2PS, a, b);
    a = __simd(XMM.CVTPI2PD, a, b);
    a = __simd(XMM.CVTPI2PS, a, b);
    a = __simd(XMM.CVTPS2DQ, a, b);
    a = __simd(XMM.CVTPS2PD, a, b);
    //a = __simd(XMM.CVTPS2PI, a, b);
    //a = __simd(XMM.CVTSD2SI, a, b);
    //a = __simd(XMM.CVTSD2SI, a, b);

    a = __simd(XMM.CVTSD2SS, a, b);
    //a = __simd(XMM.CVTSI2SD, a, b);
    //a = __simd(XMM.CVTSI2SD, a, b);
    //a = __simd(XMM.CVTSI2SS, a, b);
    //a = __simd(XMM.CVTSI2SS, a, b);
    a = __simd(XMM.CVTSS2SD, a, b);
    //a = __simd(XMM.CVTSS2SI, a, b);
    //a = __simd(XMM.CVTSS2SI, a, b);
    //a = __simd(XMM.CVTTPD2PI, a, b);
    a = __simd(XMM.CVTTPD2DQ, a, b);
    a = __simd(XMM.CVTTPS2DQ, a, b);
    //a = __simd(XMM.CVTTPS2PI, a, b);
    //a = __simd(XMM.CVTTSD2SI, a, b);
    //a = __simd(XMM.CVTTSD2SI, a, b);
    //a = __simd(XMM.CVTTSS2SI, a, b);
    //a = __simd(XMM.CVTTSS2SI, a, b);

    a = __simd(XMM.MASKMOVDQU, a, b);
    //a = __simd(XMM.MASKMOVQ, a, b);

    a = __simd(XMM.MAXPD, a, b);
    a = __simd(XMM.MAXPS, a, b);
    a = __simd(XMM.MAXSD, a, b);
    a = __simd(XMM.MAXSS, a, b);

    a = __simd(XMM.MINPD, a, b);
    a = __simd(XMM.MINPS, a, b);
    a = __simd(XMM.MINSD, a, b);
    a = __simd(XMM.MINSS, a, b);

    a = __simd(XMM.ORPD, a, b);
    a = __simd(XMM.ORPS, a, b);
    a = __simd(XMM.PAVGB, a, b);
    a = __simd(XMM.PAVGW, a, b);
    a = __simd(XMM.PMAXSW, a, b);
    //a = __simd(XMM.PINSRW, a, b);
    a = __simd(XMM.PMAXUB, a, b);
    a = __simd(XMM.PMINSB, a, b);
    a = __simd(XMM.PMINUB, a, b);
    //a = __simd(XMM.PMOVMSKB, a, b);
    a = __simd(XMM.PMULHUW, a, b);
    a = __simd(XMM.PMULHW, a, b);
    a = __simd(XMM.PMULUDQ, a, b);
    a = __simd(XMM.PSADBW, a, b);
    a = __simd(XMM.PUNPCKHQDQ, a, b);
    a = __simd(XMM.PUNPCKLQDQ, a, b);
    a = __simd(XMM.RCPPS, a, b);
    a = __simd(XMM.RCPSS, a, b);
    a = __simd(XMM.RSQRTPS, a, b);
    a = __simd(XMM.RSQRTSS, a, b);
    a = __simd(XMM.SQRTPD, a, b);
    a = __simd(XMM.SHUFPD, a, b, 0xA7);
    a = __simd(XMM.SHUFPS, a, b, 0x7A);
    a = __simd(XMM.SQRTPS, a, b);
    a = __simd(XMM.SQRTSD, a, b);
    a = __simd(XMM.SQRTSS, a, b);
    a = __simd(XMM.UNPCKHPD, a, b);
    a = __simd(XMM.UNPCKHPS, a, b);
    a = __simd(XMM.UNPCKLPD, a, b);
    a = __simd(XMM.UNPCKLPS, a, b);

    a = __simd(XMM.PSHUFD, a, b, 0x7A);
    a = __simd(XMM.PSHUFHW, a, b, 0x7A);
    a = __simd(XMM.PSHUFLW, a, b, 0x7A);
    //a = __simd(XMM.PSHUFW, a, b, 0x7A);
    a = __simd_ib(XMM.PSLLDQ, a, cast(ubyte)0x7A);
    a = __simd_ib(XMM.PSRLDQ, a, cast(ubyte)0x7A);

/**/

    a = __simd(XMM.BLENDPD, a, b, 0x7A);
    a = __simd(XMM.BLENDPS, a, b, 0x7A);

    a = __simd(XMM.DPPD, a, b, 0x7A);
    a = __simd(XMM.DPPS, a, b, 0x7A);

    a = __simd(XMM.MPSADBW, a, b, 0x7A);
    a = __simd(XMM.PBLENDW, a, b, 0x7A);

    a = __simd(XMM.ROUNDPD, a, b, 0x7A);
    a = __simd(XMM.ROUNDPS, a, b, 0x7A);
    a = __simd(XMM.ROUNDSD, a, b, 0x7A);
    a = __simd(XMM.ROUNDSS, a, b, 0x7A);

    return cast(float4)a;
}

/*****************************************/
/+
// https://issues.dlang.org/show_bug.cgi?id=9200

void bar9200(double[2] a)
{
    assert(a[0] == 1);
    assert(a[1] == 2);
}

double2 * v9200(double2* a)
{
    return a;
}

void test9200()
{
    double2 a = [1, 2];

    *v9200(&a) = a;

    bar9200(a.array);
}
+/

/*****************************************/

// https://issues.dlang.org/show_bug.cgi?id=9304
// https://issues.dlang.org/show_bug.cgi?id=9322

float4 foo9304(float4 a)
{
    return -a;
}


void test9304()
{
    auto a = foo9304([0, 1, 2, 3]);
    assert(a.array == [0,-1,-2,-3]);
}

/*****************************************/

void test9910()
{
    float4 f = [1, 1, 1, 1];
    auto works = f + 3;
    auto bug = 3 + f;

    assert (works.array == [4,4,4,4]);
    assert (bug.array == [4,4,4,4]);    // no property 'array' for type 'int'
}

/*****************************************/

bool normalize(double[] range, double sum = 1)
{
    double s = 0;
    const length = range.length;
    foreach (e; range)
    {
        s += e;
    }
    if (s == 0)
    {
        return false;
    }
    return true;
}

void test12852()
{
    double[3] range = [0.0, 0.0, 0.0];
    assert(normalize(range[]) == false);
    range[1] = 3.0;
    assert(normalize(range[]) == true);
}

/*****************************************/

void test9449()
{
    ubyte16[1] table;
}

/*****************************************/

void test9449_2()
{
    float[4][2] m = [[2.0, 1, 3, 4], [5.0, 6, 7, 8]];   // segfault

    assert(m[0][0] == 2.0);
    assert(m[0][1] == 1);
    assert(m[0][2] == 3);
    assert(m[0][3] == 4);

    assert(m[1][0] == 5.0);
    assert(m[1][1] == 6);
    assert(m[1][2] == 7);
    assert(m[1][3] == 8);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=13841

void test13841()
{
    alias Vector16s = TypeTuple!(
        void16,  byte16,  short8,  int4,  long2,
                ubyte16, ushort8, uint4, ulong2, float4, double2);
    foreach (V1; Vector16s)
    {
        foreach (V2; Vector16s)
        {
            V1 v1 = void;
            V2 v2 = void;
            static if (is(V1 == V2))
            {
                static assert( is(typeof(true ? v1 : v2) == V1));
            }
            else
            {
                static assert(!is(typeof(true ? v1 : v2)));
            }
        }
    }
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=12776

void test12776()
{
    alias Vector16s = TypeTuple!(
        void16,  byte16,  short8,  int4,  long2,
                ubyte16, ushort8, uint4, ulong2, float4, double2);
    foreach (V; Vector16s)
    {
        static assert(is(typeof(                   V .init) ==                    V ));
        static assert(is(typeof(             const(V).init) ==              const(V)));
        static assert(is(typeof(       inout(      V).init) ==        inout(      V)));
        static assert(is(typeof(       inout(const V).init) ==        inout(const V)));
        static assert(is(typeof(shared(            V).init) == shared(            V)));
        static assert(is(typeof(shared(      const V).init) == shared(      const V)));
        static assert(is(typeof(shared(inout       V).init) == shared(inout       V)));
        static assert(is(typeof(shared(inout const V).init) == shared(inout const V)));
        static assert(is(typeof(         immutable(V).init) ==          immutable(V)));
    }
}

/*****************************************/

void foo13988(double[] arr)
{
    static ulong repr(double d) { return *cast(ulong*)&d; }
    foreach (x; arr)
        assert(repr(arr[0]) == *cast(ulong*)&(arr[0]));
}


void test13988()
{
    double[] arr = [3.0];
    foo13988(arr);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=15123

void test15123()
{
    alias Vector16s = TypeTuple!(
        void16,  byte16,  short8,  int4,  long2,
                ubyte16, ushort8, uint4, ulong2, float4, double2);
    foreach (V; Vector16s)
    {
        auto x = V.init;
    }
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=15144

void test15144()
{
        enum      ubyte16 csXMM1 = ['a','b','c',0,0,0,0,0];
        __gshared ubyte16 csXMM2 = ['a','b','c',0,0,0,0,0];
        immutable ubyte16 csXMM3 = ['a','b','c',0,0,0,0,0];
        version (D_PIC)
        {
        }
        else version (D_PIE)
        {
        }
        else
        {
            asm @nogc nothrow
            {
                movdqa      XMM0, [csXMM1];
                movdqa      XMM0, [csXMM2];
                movdqa      XMM0, [csXMM3];
            }
        }
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=11585

ubyte16 test11585(ubyte16* d)
{
    ubyte16 a;
    if (d is null) return a;

    return cast(ubyte16)__simd(XMM.PCMPEQB, *d, *d);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=13927

void test13927(ulong2 a)
{
    ulong2 b = [long.min, long.min];
    auto tmp = a - b;
}

/*****************************************/

int fooprefetch(byte a)
{
    /* These should be run only if the CPUID PRFCHW
     * bit 0 of cpuid.{EAX = 7, ECX = 0}.ECX
     * Unfortunately, that bit isn't yet set by core.cpuid
     * so disable for the moment.
     */
    version (none)
    {
        prefetch!(false, 0)(&a);
        prefetch!(false, 1)(&a);
        prefetch!(false, 2)(&a);
        prefetch!(false, 3)(&a);
        prefetch!(true, 0)(&a);
        prefetch!(true, 1)(&a);
        prefetch!(true, 2)(&a);
        prefetch!(true, 3)(&a);
    }
    return 3;
}

void testprefetch()
{
    byte b;
    int i = fooprefetch(1);
    assert(i == 3);
}

/*****************************************/

// https://issues.dlang.org/show_bug.cgi?id=16488

void foo_byte16(byte t, byte s)
{
    byte16 f = s;
    auto p = cast(byte*)&f;
    foreach (i; 0 .. 16)
        assert(p[i] == s);
}

void foo_ubyte16(ubyte t, ubyte s)
{
    ubyte16 f = s;
    auto p = cast(ubyte*)&f;
    foreach (i; 0 .. 16)
        assert(p[i] == s);
}


void foo_short8(short t, short s)
{
    short8 f = s;
    auto p = cast(short*)&f;
    foreach (i; 0 .. 8)
        assert(p[i] == s);
}

void foo_ushort8(ushort t, ushort s)
{
    ushort8 f = s;
    auto p = cast(ushort*)&f;
    foreach (i; 0 .. 8)
        assert(p[i] == s);
}


void foo_int4(int t, int s)
{
    int4 f = s;
    auto p = cast(int*)&f;
    foreach (i; 0 .. 4)
        assert(p[i] == s);
}

void foo_uint4(uint t, uint s, uint u)
{
    uint4 f = s;
    auto p = cast(uint*)&f;
    foreach (i; 0 .. 4)
        assert(p[i] == s);
}


void foo_long2(long t, long s, long u)
{
    long2 f = s;
    auto p = cast(long*)&f;
    foreach (i; 0 .. 2)
        assert(p[i] == s);
}

void foo_ulong2(ulong t, ulong s)
{
    ulong2 f = s;
    auto p = cast(ulong*)&f;
    foreach (i; 0 .. 2)
        assert(p[i] == s);
}

void foo_float4(float t, float s)
{
    float4 f = s;
    auto p = cast(float*)&f;
    foreach (i; 0 .. 4)
        assert(p[i] == s);
}

void foo_double2(double t, double s, double u)
{
    double2 f = s;
    auto p = cast(double*)&f;
    foreach (i; 0 .. 2)
        assert(p[i] == s);
}


void test16448()
{
    foo_byte16(5, -10);
    foo_ubyte16(5, 11);

    foo_short8(5, -6);
    foo_short8(5, 7);

    foo_int4(5, -6);
    foo_uint4(5, 0x12345678, 22);

    foo_long2(5, -6, 1);
    foo_ulong2(5, 0x12345678_87654321L);

    foo_float4(5, -6);
    foo_double2(5, -6, 2);
}

/*****************************************/

static if (__traits(compiles, byte32))
{
    void foo_byte32(byte t, byte s)
    {
        byte32 f = s;
        auto p = cast(byte*)&f;
        foreach (i; 0 .. 32)
            assert(p[i] == s);
    }

    void foo_ubyte32(ubyte t, ubyte s)
    {
        ubyte32 f = s;
        auto p = cast(ubyte*)&f;
        foreach (i; 0 .. 32)
            assert(p[i] == s);
    }

    void foo_short16(short t, short s)
    {
        short16 f = s;
        auto p = cast(short*)&f;
        foreach (i; 0 .. 16)
            assert(p[i] == s);
    }

    void foo_ushort16(ushort t, ushort s)
    {
        ushort16 f = s;
        auto p = cast(ushort*)&f;
        foreach (i; 0 .. 16)
            assert(p[i] == s);
    }

    void foo_int8(int t, int s)
    {
        int8 f = s;
        auto p = cast(int*)&f;
        foreach (i; 0 .. 8)
            assert(p[i] == s);
    }

    void foo_uint8(uint t, uint s, uint u)
    {
        uint8 f = s;
        auto p = cast(uint*)&f;
        foreach (i; 0 .. 8)
            assert(p[i] == s);
    }

    void foo_long4(long t, long s, long u)
    {
        long4 f = s;
        auto p = cast(long*)&f;
        foreach (i; 0 .. 4)
            assert(p[i] == s);
    }

    void foo_ulong4(ulong t, ulong s)
    {
        ulong4 f = s;
        auto p = cast(ulong*)&f;
        foreach (i; 0 .. 4)
            assert(p[i] == s);
    }

    void foo_float8(float t, float s)
    {
        float8 f = s;
        auto p = cast(float*)&f;
        foreach (i; 0 .. 8)
            assert(p[i] == s);
    }

    void foo_double4(double t, double s, double u)
    {
        double4 f = s;
        auto p = cast(double*)&f;
        foreach (i; 0 .. 4)
            assert(p[i] == s);
    }

    void test16448_32()
    {
        foo_byte32(5, -10);
        foo_ubyte32(5, 11);

        foo_short16(5, -6);
        foo_short16(5, 7);

        foo_int8(5, -6);
        foo_uint8(5, 0x12345678, 22);

        foo_long4(5, -6, 1);
        foo_ulong4(5, 0x12345678_87654321L);

        foo_float8(5, -6);
        foo_double4(5, -6, 2);
    }
}
else
{
    void test16448_32()
    {
    }
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=16703

float index(float4 f4, size_t i)
{
    return f4[i];
    //return (*cast(float[4]*)&f4)[2];
}

float[4] slice(float4 f4)
{
    return f4[];
}

float slice2(float4 f4, size_t lwr, size_t upr, size_t i)
{
    float[] fa = f4[lwr .. upr];
    return fa[i];
}

void test16703()
{
    float4 f4 = [1,2,3,4];
    assert(index(f4, 0) == 1);
    assert(index(f4, 1) == 2);
    assert(index(f4, 2) == 3);
    assert(index(f4, 3) == 4);

    float[4] fsa = slice(f4);
    assert(fsa == [1.0f,2,3,4]);

    assert(slice2(f4, 1, 3, 0) == 2);
    assert(slice2(f4, 1, 3, 1) == 3);
}

/*****************************************/

struct Sunsto
{
  align (1): // make sure f4 is misaligned
    byte b;
    union
    {
        float4 f4;
        ubyte[16] a;
    }
}

ubyte[16] foounsto()
{
    float4 vf = 6;
    Sunsto s;
    s.f4 = vf * 2;
    vf = s.f4;

    return s.a;
}

void testOPvecunsto()
{
    auto a = foounsto();
    version (LittleEndian)
        assert(a == [0, 0, 64, 65, 0, 0, 64, 65, 0, 0, 64, 65, 0, 0, 64, 65]);
    version (BigEndian)
        assert(a == [65, 64, 0, 0, 65, 64, 0, 0, 65, 64, 0, 0, 65, 64, 0, 0]);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=10447

void test10447()
{
    immutable __vector(double[2]) a = [1.0, 2.0];
    __vector(double[2]) r;
    r += a;
    r = r * a;
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=17237

static if (__traits(compiles, int8))
{
    struct S17237
    {
        bool a;
        struct
        {
            bool b;
            int8 c;
        }
    }

    static assert(S17237.a.offsetof == 0);
    static assert(S17237.b.offsetof == 32);
    static assert(S17237.c.offsetof == 64);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=17344

void test17344()
{
    __vector(int[4]) vec1 = 2, vec2 = vec1++;
    assert(cast(int[4])vec1 == [3, 3, 3, 3]);
    assert(cast(int[4])vec2 == [2, 2, 2, 2]);
}

/*****************************************/

// https://issues.dlang.org/show_bug.cgi?id=17356

void test17356()
{
    float4 a = 13, b = 0;
    __simd_sto(XMM.STOUPS, b, a);
    assert(b.array == [13, 13, 13, 13]);
}

/*****************************************/

// https://issues.dlang.org/show_bug.cgi?id=17695

void test17695(__vector(ubyte[16]) a)
{
    auto b = -a;
}

/*****************************************/

void refIntrinsics()
{
    // never called, but check for link errors
    void16 v;
    void16 a;
    float f = 1;
    double d = 1;

    a = __simd(XMM.ADDPD, a, v);
    a = __simd(XMM.CMPSS, a, v, cast(ubyte)0x7A);

    a = __simd(XMM.LODSS, v);
    a = __simd(XMM.LODSS, f);
    a = __simd(XMM.LODSS, d);

    __simd_sto(XMM.STOUPS, v, a);
    __simd_sto(XMM.STOUPS, f, a);
    __simd_sto(XMM.STOUPS, d, a);

    a = __simd_ib(XMM.PSLLW, a, cast(ubyte)0x7A);

    prefetch!(false, 0)(&a);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=17720

void test17720()
{
    alias Vector16s = TypeTuple!(
        void16,  byte16,  short8,  int4,  long2,
                ubyte16, ushort8, uint4, ulong2, float4, double2);

    // OK: __vector(T) -> __vector(void[]) of same size.
    // NG: __vector(T) -> __vector(void[]) of different size.
    // NG: explicit cast __vector(T) -> __vector(void[]) of different size.
    foreach (V; Vector16s)
    {
        static assert( __traits(compiles, { void16 v = V.init; }));
        static assert(!__traits(compiles, { void32 v = V.init; }));
        static assert(!__traits(compiles, { void32 v = cast(void32)V.init; }));
    }

    // NG: __vector(T) -> __vector(T) of same size.
    // OK: explicit cast __vector(T) -> __vector(T) of same size.
    // NG: __vector(T) -> __vector(T) of different size.
    // NG: explicit cast __vector(T) -> __vector(T) of different size.
    foreach (V; Vector16s)
    {
        static if (is(V == double2))
        {
            static assert(!__traits(compiles, { long2 v = V.init; }));
            static assert( __traits(compiles, { long2 v = cast(long2)V.init; }));
        }
        else
        {
            static assert(!__traits(compiles, { double2 v = V.init; }));
            static assert( __traits(compiles, { double2 v = cast(double2)V.init; }));
        }
        static assert(!__traits(compiles, { double4 v = V.init; }));
        static assert(!__traits(compiles, { double4 v = cast(double4)V.init; }));
    }

    // 32-byte __vector(T) tests.
    static if (__traits(compiles, void32))
    {
        alias Vector32s = TypeTuple!(
            void32,  byte32,  short16,  int8,  long4,
                    ubyte32, ushort16, uint8, ulong4, float8, double4);

        foreach (V; Vector32s)
        {
            static assert( __traits(compiles, { void32 v = V.init; }));
            static assert(!__traits(compiles, { void16 v = V.init; }));
            static assert(!__traits(compiles, { void16 v = cast(void16)V.init; }));
        }

        foreach (V; Vector32s)
        {
            static if (is(V == double4))
            {
                static assert(!__traits(compiles, { long4 v = V.init; }));
                static assert( __traits(compiles, { long4 v = cast(long4)V.init; }));
            }
            else
            {
                static assert(!__traits(compiles, { double4 v = V.init; }));
                static assert( __traits(compiles, { double4 v = cast(double4)V.init; }));
            }
            static assert(!__traits(compiles, { double2 v = V.init; }));
            static assert(!__traits(compiles, { double2 v = cast(double2)V.init; }));
        }
    }
}

/*****************************************/

void test6a()
{
    static if (__traits(compiles, { long4 x; x += 1; }))
    {
        // stack occasionally misaligned
        float f = 0;
        long4 v;
        assert((cast(size_t)&v) % 32 == 0);
        v += 1;
    }
}

void test6b()
{
    static if (__traits(compiles, long4))
    {
        struct S {long4 v;}
        S s;
        assert((cast(size_t)&s) % 32 == 0);
    }
}

void test6()
{
    test6a();
    test6b();
}

/*****************************************/

static if (__traits(compiles, double4))
{
    double4 test7r(double4 v)
    {
        return v;
    }
}

void test7()
{
    static if (__traits(compiles, double4))
    {
        // 32 bytes sliced down to 16 bytes
        double4 v = 1;
        double4 r = test7r(v);
        assert(v[2] == r[2]);
        assert(v[3] == r[3]);
    }
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=18867

ulong2 foo18867(ulong s)
{
    ulong2 v;
    v[0] = s;
    return v;
}

/*****************************************/


auto test20052()
{
    static if (__traits(compiles, long4))
    {
        struct S { long4 v; }
        S s;
        return s;
    }
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=20981

void test20981()
{
    void16 a;
    simd_stox!(XMM.STOUPS)(a, a);
}

void16 simd_stox(XMM opcode)(void16 op1, void16 op2)
{
    return cast(void16) __simd_sto(opcode, op1, op2);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=21469

int4 foo21469(short a)
{
    return cast(int4)(short8(a));
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=20041

immutable(float4) foo20041()
{
    float4 raw = 2.0f;
    raw.array[0] = 1;
    return cast(immutable)raw;
}

void test20041()
{
    static immutable float4 v = foo20041();

    assert(v.array[0] == 1);
    assert(v.array[1] == 2);
    assert(v.array[2] == 2);
    assert(v.array[3] == 2);

//    foreach(d; 0 .. 4)
//      printf("%g ", v[d]);
//    printf("\n");
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=21364

struct X21364
{
    float x0;
    long  x1;
}

version (X86_64)
    static assert(X21364.alignof == 8);

void foo21364(int bar, X21364 x, int i1, int i2, int i3, int i4, int i5, int i6, int i7, int i8, int i9)
{
    assert(i1 == 2);
    assert(bar == 1);
}

void test21364()
{
    X21364 x = X21364();
    foo21364(1, x, 2, 3, 4, 5, 6, 7, 8, 9, 10);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=19632

void test19632()
{
    int4 v = [1, 2, 3, 4];
    int sum = 0;
    foreach (ref e; v)
        sum += (e *= 2);
    assert(v.array[] == [2, 4, 6, 8]);
    assert(sum == 20);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=19443

void test19443()
{
    float4 a = [1.0f, 2.0f, 3.0f, 4.0f];
    float4 b = [5.0f, 6.0f, 7.0f, 8.0f];
    float4 r = cast(float4) __simd(XMM.MOVHLPS, a, b);
    float[4] correct = [7.0f, 8.0f, 3.0f, 4.0f];
    assert(r.array == correct); // FAIL, produces [5, 6, 3, 4] instead
}


/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=22438

struct T22438 { int x; double d; }

T22438 foo22438(int x, double d) { return T22438(x, d); }

struct S22438 { T22438 t; string r; }

void test22438()
{
    S22438 s = S22438(foo22438(10, 3.14), "str");
    assert(s.t.x == 10);
    assert(s.t.d == 3.14);
    assert(s.r == "str");
}

/*****************************************/

__gshared int testsroa_x;

template SROA(T1, T2)
{
    struct FPoint
    {
        T1 x;
        T2 y;
    }

    void sroa(FPoint p1, ref FPoint quad)
    {
        quad = FPoint(p1.x, p1.y);
    }

    void testit()
    {
        FPoint p1 = FPoint(1, 2);

        FPoint quad;
        sroa(p1, quad);

        if (quad != p1)
        {
            printf("failing iteration %d\n", testsroa_x);
            assert(0);
        }
        ++testsroa_x;
    }
}

void testsroa()
{
    SROA!(int,   int  ).testit();
    SROA!(int,   float).testit();
    SROA!(float, float).testit();
    SROA!(float, int  ).testit();

    SROA!(long,   long  ).testit();
    SROA!(long,   double).testit();
    SROA!(double, double).testit();
    SROA!(double, long  ).testit();
}

/*****************************************/

// https://github.com/AuburnSounds/intel-intrinsics/blob/master/source/inteli/pmmintrin.d

alias __m128 = float4;

__m128 _mm_setr_ps (float e3, float e2, float e1, float e0) pure @trusted
{
    float[4] result = [e3, e2, e1, e0];
    return loadUnaligned!(float4)(cast(float4*)result.ptr);
}

__m128 _mm_movehdup_ps (__m128 a) pure @trusted
{
    a.ptr[0] = a.array[1];
    a.ptr[2] = a.array[3];
    return a;
}

void testshdup()
{
    __m128 A = _mm_movehdup_ps(_mm_setr_ps(1, 2, 3, 4));
    float[4] correct = [2.0f, 2, 4, 4 ];
    assert(A.array == correct);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=21673
float4 _mm_move_ss(float4 a, float4 b)
{
    a.ptr[0] = b.array[0];
    return a;
}

void test21673()
{
    float4 A = [1.0f, 2.0f, 3.0f, 4.0f];
    float4 B = [5.0f, 6.0f, 7.0f, 8.0f];
    float4 R = _mm_move_ss(A, B);
    float[4] correct = [5.0f, 2.0f, 3.0f, 4.0f];
    assert(R.array == correct);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=21676
double2 loadUnaligned21676(const(double)* pvec)
{
    double2 result;
    foreach(i; 0..2)
    {
        result[i] = pvec[i];
    }
    return result;
}

double2 _mm_setr_pd(double e1, double e0)
{
    double[2] result = [e1, e0];
    return loadUnaligned21676(result.ptr);
}

double2 fun(double2 a, double2 b)
{
    a[0] = (a[0] < b[0]) ? a[0] : b[0];
    return a;
}

void test21676()
{
    double2 A = _mm_setr_pd(1.0, 2.0);
    double2 B = _mm_setr_pd(4.0, 1.0);
    double2 C = fun(A, B);
    assert(C.array[0] == 1.0);
    assert(C.array[1] == 2.0);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=23009
double2 _mm_loadl_pd(double2 a, const(double)* mem_addr)
{
    a[0] = *mem_addr;
    return a;
}

void test23009()
{
    double A = 7.0;
    double2 B;
    B[0] = 4.0;
    B[1] = -5.0;
    double2 R = _mm_loadl_pd(B, &A);
    double[2] correct = [ 7.0, -5.0 ];
    assert(R.array == correct);
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=23077

float test23077(float x)
{
    short i = *cast(short*)&x;
    ++i;
    return *cast(float*)&i; // this cast is not allowed in @safe code
}

// https://issues.dlang.org/show_bug.cgi?id=23085

float test23085(float x)
{
    byte i = *cast(byte*)&x;
    ++i;
    return *cast(float*)&i; // this cast is not allowed in @safe code
}

// https://issues.dlang.org/show_bug.cgi?id=23084

__vector(int[4]) test23084a(__vector(int[4]) a)
{
    __vector(short[8]) r = cast(short)(a.array[0]);
    return cast(__vector(int[4]))r;
}

__vector(int[4]) test23084b(__vector(int[4]) a)
{
    __vector(byte[16]) r = cast(byte)(a.array[0]);
    return cast(__vector(int[4]))r;
}


/*****************************************/

// https://issues.dlang.org/show_bug.cgi?id=23218

int4 convtest(int[4] a)
{   return cast(int4)a; }

void test23218()
{
    static assert(convtest([1,2,3,4])[0] == 1);
    assert(convtest([1,2,3,4])[0] == 1);
}

/*****************************************/

int main()
{
    test1();
    test2();
    test2b();
    test2c();
    test2d();
    test2e();
    test2f();
    test2g();
    test2h();
    test2i();
    test2j();

    test3();
    test4();
    test7411();

    test7951();
    test7951_2();
    test7949();
    test7414();
    test7413();
    test7413_2();
//    test9200();
    test9304();
    test9910();
    test12852();
    test9449();
    test9449_2();
    test13988();
    testprefetch();
    test16448();
    test16448_32();
    test16703();
    testOPvecunsto();
    test10447();
    test17344();
    test17356();
    test20052();

    test6();
    test7();
    test20981();
    test20041();
    test21364();
    test19632();
    test19443();
    test22438();
    testsroa();
    testshdup();

    test21673();
    test21676();
    test23009();
    test23218();

    return 0;
}

}
else
{

int main() { return 0; }

}
