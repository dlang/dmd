// 128-bit integer (cent/ucent) tests, run on both 32-bit and 64-bit x86.

// Type properties that must hold on every target
static assert(cent.sizeof == 16);
static assert(ucent.sizeof == 16);
static assert(cent.alignof == 8);
static assert(ucent.alignof == 8);
static assert(cent.init == cast(cent)0);
static assert(ucent.init == cast(ucent)0);
static assert(__traits(isIntegral, cent));
static assert(__traits(isIntegral, ucent));
static assert(__traits(isUnsigned, ucent));
static assert(!__traits(isUnsigned, cent));
static assert(is(cent) && is(ucent));

void main()
{
    // ---------------- properties ----------------
    assert(cent.max > 0);
    assert(cent.min < 0);
    assert(cent.init == 0);
    assert(ucent.max > cent.max);
    assert(cent.min == cast(cent)(cast(cent)0x8000000000000000UL << 64));
    assert(cent.max == cast(cent)((cast(cent)0x7FFFFFFFFFFFFFFFUL << 64) | 0xFFFFFFFFFFFFFFFFUL));
    assert(ucent.min == 0);
    assert(ucent.max == ((cast(ucent)0xFFFFFFFFFFFFFFFFUL << 64) | 0xFFFFFFFFFFFFFFFFUL));

    // ---------------- arithmetic ----------------
    cent a = 100;
    cent b = 20;
    assert(a + b == 120);
    assert(a - b == 80);
    assert(a * b == 2000);
    assert(a / b == 5);
    assert(a % b == 0);
    assert(a / 7 == 14);
    assert(a % 7 == 2);
    assert(-a == -100);
    assert(~a == -101);
    assert(a >> 2 == 25);
    assert(a << 2 == 400);
    assert(cast(ucent)a >>> 2 == 25);

    // mixed 64-bit operands
    cent m = 1000L + a;
    assert(m == 1100);
    assert(m - 1000L == a);
    assert(m * 2L == 2200);
    assert(a + 1 == 101);
    assert(a * 3 == 300);

    // 128-bit div/mod with a full 128-bit divisor
    cent big = cast(cent)(cast(cent)0x123456789ABCDEF0UL << 64) | 0x0FEDCBA987654321UL;
    cent divr = cast(cent)0x1000000000000000L;
    assert(big / divr == (cast(cent)0x123456789ABCDEF0UL << 4));
    assert(big % divr == 0x0FEDCBA987654321UL);

    // div/mod by a variable 64-bit divisor
    long dv = 0x1000000000000000L;
    assert(big / dv == (cast(cent)0x123456789ABCDEF0UL << 4));
    assert(big % dv == 0x0FEDCBA987654321UL);

    // unsigned div/mod
    ucent ub = 300;
    assert(ub / 7 == 42);
    assert(ub % 7 == 6);
    ucent ubig = cast(ucent)(cast(ucent)0xFFFFFFFFFFFFFFFFUL << 64) | 0xFFFFFFFFFFFFFFFEUL;
    assert(ubig / 2 == cast(ucent)0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFUL);
    assert(ubig % 2 == 0);

    // overflow wraps mod 2^128
    ucent mx = ucent.max;
    ucent ov = mx + 1;
    assert(ov == 0);

    cent mn = cent.min;
    assert(cast(ucent)(mn - 1) == cast(ucent)cent.max);

    // nested expressions
    cent n = (a + b) * 3;
    assert(n == 360);
    n = (a - b) * (a + b);
    assert(n == 9600);
    n = a + a + a + a;
    assert(n == 400);
    assert((a - b) / (a / b) == 16);

    // variable shift counts
    int sh = 4;
    assert(a << sh == 1600);
    assert(a >> sh == 6);
    cent shl = cast(cent)0x5DEADBEEFCAFEBABUL << 64;
    assert(shl >> 64 == cast(cent)0x5DEADBEEFCAFEBABUL);

    // compound assignment
    cent cc = 10;
    cc += 5;
    assert(cc == 15);
    cc -= 3;
    assert(cc == 12);
    cc *= 3;
    assert(cc == 36);
    cc /= 6;
    assert(cc == 6);
    cc %= 4;
    assert(cc == 2);
    cc <<= 3;
    assert(cc == 16);
    cc >>= 2;
    assert(cc == 4);
    cc &= 6;
    assert(cc == 4);
    cc |= 1;
    assert(cc == 5);
    cc ^= 5;
    assert(cc == 0);
    ++cc;
    assert(cc == 1);
    --cc;
    assert(cc == 0);
    cc = 7;
    cc++;
    assert(cc == 8);
    cc--;
    assert(cc == 7);

    // comparisons
    assert(a > b);
    assert(a >= b);
    assert(b < a);
    assert(b <= a);
    assert(a != b);
    assert(a == 100);
    assert(a == 100L);
    assert(a != 101);
    assert(cent.max > cent.min);
    assert(cent.min < cent.max);
    assert(ucent.max > cent.max);
    assert(cent.max > 0);
    assert(cent.min < 0);

    // bitwise
    cent x = 0x0F0F;
    cent y = 0x00FF;
    assert((x & y) == 0x000F);
    assert((x | y) == 0x0FFF);
    assert((x ^ y) == 0x0FF0);
    assert(cast(ulong)(~x) == 0xFFFFFFFFFFFFF0F0UL);

    // 128-bit values via shifts
    cent hi = cast(cent)0x5DEADBEEFCAFEBABUL << 64;
    assert((hi >> 64) == cast(cent)0x5DEADBEEFCAFEBABUL);
    assert((hi >>> 64) == cast(ucent)0x5DEADBEEFCAFEBABUL);

    // 128-bit literals (> 64 bits)
    cent lc = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    assert(lc == -1);
    ucent luc = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFu;
    assert(luc == ucent.max);
    cent lm = 170141183460469231731687303715884105727;
    assert(lm == cent.max);
    cent lmin = cast(cent)0x80000000000000000000000000000000;
    assert(lmin == cent.min);

    // ---------------- compile-time evaluation (CTFE) ----------------
    enum cent ec = 0x123456789ABCDEF0_0FEDCBA987654321;
    static assert(ec == 0x123456789ABCDEF0_0FEDCBA987654321);
    static assert(ec > 0);
    static assert((ec >> 64) == 0x123456789ABCDEF0);
    enum cent ea = cast(cent)100 / 7;
    static assert(ea == 14);
    enum cent eb = cast(cent)100 % 7;
    static assert(eb == 2);
    enum cent em = cast(cent)0x123456789ABCDEF0_0FEDCBA987654321 * cast(cent)3;
    static assert(em == cast(cent)0x123456789ABCDEF0_0FEDCBA987654321 * 3);
    enum cent en = -ec;
    static assert(en == -0x123456789ABCDEF0_0FEDCBA987654321);
    enum cent eor = ec ^ 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    static assert(eor == ~ec);
    static assert(cast(ulong)(ec >> 64) == 0x123456789ABCDEF0UL);
    static assert(cast(ulong)ec == 0x0FEDCBA987654321UL);
    static assert(cast(long)ec == cast(long)0x0FEDCBA987654321UL);

    // compile-time function on cent
    static cent ctf(cent x)
    {
        return x * 2 + 1;
    }
    enum cent ef = ctf(cast(cent)21);
    static assert(ef == 43);

    // ---------------- basic declaration and assignment ----------------
    cent c;
    c = 5;
    assert(c == 5);
    assert(cast(long)c == 5);

    ucent uc;
    uc = 7;
    assert(uc == 7);
    assert(cast(ulong)uc == 7);

    // negative values
    cent neg = -5;
    assert(neg == -5);
    assert(cast(long)neg == -5);
    assert(neg < 0);
    assert(-neg == 5);

    // cast from 64-bit (sign/zero extension)
    cent se = cast(cent)(-1L);
    assert(se == -1);
    assert(cast(long)se == -1);

    ucent ze = cast(ucent)0xFFFFFFFFFFFFFFFFUL;
    assert(ze == 0xFFFFFFFFFFFFFFFFUL);
    assert(cast(ulong)ze == 0xFFFFFFFFFFFFFFFFUL);

    // cast down (truncation)
    assert(cast(long)(cast(cent)0x123456789ABCDEF0L) == 0x123456789ABCDEF0L);
    assert(cast(ulong)(cast(ucent)0x123456789ABCDEF0UL) == 0x123456789ABCDEF0UL);
    assert(cast(long)(cast(cent)0x123456789ABCDEF0_0FEDCBA987654321L) == 0x0FEDCBA987654321L);
    assert(cast(long)(cast(cent)(-5L)) == -5L);

    // initialization forms
    cent c2 = 42;
    assert(c2 == 42);
    ucent uc2 = 42;
    assert(uc2 == 42);
    cent c3 = cent.max;
    assert(c3 == cent.max);
    cent c4 = cent.min;
    assert(c4 == cent.min);

    // ---------------- structs and arrays containing cent ----------------
    struct S
    {
        cent c;
        long l;
    }
    static assert(S.sizeof == 24);
    static assert(S.alignof == 8);
    S s;
    s.c = 100;
    s.l = 200;
    assert(s.c == 100);
    assert(s.l == 200);

    cent[3] arr;
    arr[0] = 1;
    arr[1] = 2;
    arr[2] = 3;
    assert(arr[0] == 1 && arr[1] == 2 && arr[2] == 3);
    assert(arr.length == 3);

    // ---------------- function params and returns ----------------
    cent ident(cent x) { return x; }
    assert(ident(55) == 55);
    assert(ident(cent.max) == cent.max);
    assert(ident(cent.min) == cent.min);

    ucent uident(ucent x) { return x; }
    assert(uident(77) == 77);
    assert(uident(ucent.max) == ucent.max);

    cent add2(cent a, cent b) { return a + b; }
    assert(add2(30, 12) == 42);

    cent add3(cent a, cent b, cent c) { return a + b + c; }
    assert(add3(1, 2, 3) == 6);

    cent sub2(cent a, cent b) { return a - b; }
    assert(sub2(100, 42) == 58);

    cent mul2(cent a, cent b) { return a * b; }
    assert(mul2(6, 7) == 42);

    cent div2(cent a, cent b) { return a / b; }
    assert(div2(84, 6) == 14);
    assert(div2(big, divr) == (cast(cent)0x123456789ABCDEF0UL << 4));

    cent mixed(cent a, long b) { return a + b; }
    assert(mixed(100, 5) == 105);

    bool cmplt(cent a, cent b) { return a < b; }
    assert(cmplt(1, 2));
    assert(!cmplt(2, 1));

    void setit(ref cent x, long v) { x = cast(cent)v; }
    cent cv = 0;
    setit(cv, 999);
    assert(cv == 999);

    // struct with cent passed by value
    S s2 = S(1000, 2000);
    S idS(S x) { return x; }
    S s3 = idS(s2);
    assert(s3.c == 1000 && s3.l == 2000);

    // ---------------- boolean contexts ----------------
    cent bz = 0;
    assert(!bz);
    if (a)
        assert(a > 0);
    else
        assert(0);
    if (!bz)
        assert(1);
    else
        assert(0);
    while (a > 0)
        break;
    bool truthy = cast(bool)a;
    assert(truthy);
    assert(!cast(bool)bz);
    // short-circuit && and || with 128-bit operands
    assert(a && b);
    assert(a || bz);
    assert(!(bz && a));
    assert(bz || a);
    // conditional expression
    cent chosen = (a > b) ? a : b;
    assert(chosen == a);

    // ---------------- casts to smaller integers ----------------
    cent cbits = cast(cent)0x0123456789ABCDEF_0FEDCBA987654321;
    assert(cast(int)cbits == cast(int)0x87654321);
    assert(cast(uint)cbits == 0x87654321);
    assert(cast(short)cbits == cast(short)0x4321);
    assert(cast(ushort)cbits == 0x4321);
    assert(cast(byte)cbits == cast(byte)0x21);
    assert(cast(ubyte)cbits == 0x21);
    assert(cast(long)cbits == cast(long)0x0FEDCBA987654321UL);
    assert(cast(ulong)cbits == 0x0FEDCBA987654321UL);

    // ---------------- alignment (matches _Alignof(_BitInt(128))) ----------------
    // 16 on AArch64, 4 on i386 System V, 8 elsewhere
    version (AArch64)
        enum centAlign = 16;
    else version (X86)
        version (Posix)
            enum centAlign = 4;
        else
            enum centAlign = 8;
    else
        enum centAlign = 8;
    assert(cent.alignof == centAlign);
    assert(ucent.alignof == centAlign);
    assert(cent.sizeof == 16);
    assert(ucent.sizeof == 16);

    // ---------------- hashing ----------------
    import core.internal.hash : hashOf;
    assert(hashOf(cast(cent)5) == hashOf(cast(cent)5));
    assert(hashOf(cast(ucent)5) == hashOf(cast(ucent)5));
    assert(hashOf(cast(cent)5) != hashOf(cast(cent)6));

    // ---------------- properties ----------------
    assert(cent.max > 0);
    assert(cent.min < 0);
    assert(cent.init == 0);
    assert(ucent.max > cent.max);
}
