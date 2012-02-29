// REQUIRED_ARGS:

version (D_SIMD)
{

import core.simd;

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

    return 0;
}

}
else
{

int main() { return 0; }

}

