// REQUIRED_ARGS:

version (D_SIMD)
{

import core.simd;
import core.stdc.string;
import std.stdio;

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
}

/*****************************************/

void test2()
{
    byte16 v1,v2,v3;
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
}

/*****************************************/

void test2b()
{
    ubyte16 v1,v2,v3;
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
}

/*****************************************/

void test2c()
{
    short8 v1,v2,v3;
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
}

/*****************************************/

void test2d()
{
    ushort8 v1,v2,v3;
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
}

/*****************************************/

void test2e()
{
    int4 v1,v2,v3;
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
}

/*****************************************/

void test2f()
{
    uint4 v1,v2,v3;
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
}

/*****************************************/

void test2g()
{
    long2 v1,v2,v3;
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
}

/*****************************************/

void test2h()
{
    ulong2 v1,v2,v3;
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
}

/*****************************************/

void test2i()
{
    float4 v1,v2,v3;
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
}

/*****************************************/

void test2j()
{
    double2 v1,v2,v3;
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
}

/*****************************************/

float4 test3()
{
    float4 a;
    a = __simd(XMM.PXOR, a, a);
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
// 7951

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

    writeln(r.array);
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

    return 0;
}

}
else
{

int main() { return 0; }

}

