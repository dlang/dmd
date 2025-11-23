/* This D file is implicitly imported by all ImportC source files.
 * It provides definitions for C compiler builtin functions and declarations.
 * The purpose is to make it unnecessary to hardwire them into the compiler.
 * As the leading double underscore suggests, this is for internal use only.
 *
 * Copyright: Copyright D Language Foundation 2022-2025
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC __importc_builtins.di)
 */


module __builtins;

import core.stdc.config : c_long, c_ulong;
import core.checkedint : adds, subs, muls;

/* gcc relies on internal __builtin_xxxx functions and templates to
 * accomplish <stdarg.h>. D does the same thing with templates in core.stdc.stdarg.
 * Here, we redirect the gcc builtin declarations to the equivalent
 * ones in core.stdc.stdarg, thereby avoiding having to hardwire them
 * into the D compiler.
 */

alias va_list = imported!"core.stdc.stdarg".va_list;

version (Posix)
{
    version (X86_64)
        alias __va_list_tag = imported!"core.stdc.stdarg".__va_list_tag;
}

alias __builtin_va_start = imported!"core.stdc.stdarg".va_start;

alias __builtin_va_end = imported!"core.stdc.stdarg".va_end;

alias __builtin_va_copy = imported!"core.stdc.stdarg".va_copy;

/* dmd's ImportC rewrites __builtin_va_arg into an instantiation of va_arg
 */
alias va_arg = imported!"core.stdc.stdarg".va_arg;

version (CRuntime_Microsoft)
{
    //https://docs.microsoft.com/en-us/cpp/cpp/int8-int16-int32-int64?view=msvc-170
    alias __int8 = byte;
    alias __int16 = short;
    alias __int32 = int;
    alias __int64 = long;
}

/*********** floating point *************/

/* https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html
 */

version (DigitalMars)
{
    immutable float __nan = float.nan;

    float __builtin_nanf()(char*)  { return float.nan; }

    double __builtin_inf()()  { return double.infinity; }
    float  __builtin_inff()() { return float.infinity; }
    real   __builtin_infl()() { return real.infinity; }

    alias __builtin_huge_val  = __builtin_inf;
    alias __builtin_huge_valf = __builtin_inff;
    alias __builtin_huge_vall = __builtin_infl;

    alias __builtin_fabs  = imported!"core.stdc.math".fabs;
    alias __builtin_fabsf = imported!"core.stdc.math".fabsf;
    alias __builtin_fabsl = imported!"core.stdc.math".fabsl;

    ushort __builtin_bswap16()(ushort value)
    {
        return cast(ushort) (((value >> 8) & 0xFF) | ((value << 8) & 0xFF00U));
    }

    uint __builtin_bswap32()(uint value)
    {
        import core.bitop;
        return core.bitop.bswap(value);
    }

    ulong  __builtin_bswap64()(ulong value)
    {
        import core.bitop;
        return core.bitop.bswap(value);
    }

    uint  __builtin__popcount()(ulong value)
    {
        import core.bitop;
        return core.bitop._popcnt(value);
    }

    // Lazily imported on first use
    private alias c_long = imported!"core.stdc.config".c_long;

    // Stub these out to no-ops
    int    __builtin_constant_p(T)(T exp) { return 0; } // should be something like __traits(compiles, enum X = expr)
    c_long __builtin_expect()(c_long exp, c_long c) { return exp; }
    void*  __builtin_assume_aligned()(const void* p, size_t align_, ...) { return cast(void*)p; }

    // https://releases.llvm.org/13.0.0/tools/clang/docs/LanguageExtensions.html#builtin-assume
    void __builtin_assume(T)(lazy T arg) { }

    /* Header on macOS for arm64 references this.
     * Don't need to implement it, it just needs to compile
     */
    align (16) struct __uint128_t
    {
        ulong a, b;
    }
}

version (CRuntime_Glibc) version (AArch64)
{
    // math.h needs these
    alias __Float32x4_t = __vector(float[4]);
    alias __Float64x2_t = __vector(double[2]);
}

// https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

private bool overflowOp(alias op, T1, T2, T3)(T1 a, T2 b, ref T3 res)
{
    bool overflow = false;
    res = op(a, b, overflow);
    return overflow;
}

private T builtin_opc(alias op, T)(T a, T b, T carry_in, ref T carry_out)
{
    carry_out = op(a, b, a) | op(a, carry_in, a);
    return a;
}

pragma(inline, true)
{
    bool __builtin_add_overflow(T1, T2, T3)(T1 a, T2 b, T3* res) => overflowOp!(adds, T1, T2, T3)(a, b, *res);
    bool __builtin_sub_overflow(T1, T2, T3)(T1 a, T2 b, T3* res) => overflowOp!(subs, T1, T2, T3)(a, b, *res);
    bool __builtin_mul_overflow(T1, T2, T3)(T1 a, T2 b, T3* res) => overflowOp!(muls, T1, T2, T3)(a, b, *res);
    bool __builtin_add_overflow_p(T1, T2, T3)(T1 a, T2 b, T3 c)  => overflowOp!(adds, T1, T2, T3)(a, b, res);
    bool __builtin_sub_overflow_p(T1, T2, T3)(T1 a, T2 b, T3 c)  => overflowOp!(subs, T1, T2, T3)(a, b, res);
    bool __builtin_mul_overflow_p(T1, T2, T3)(T1 a, T2 b, T3 c)  => overflowOp!(muls, T1, T2, T3)(a, b, res);
    bool __builtin_sadd_overflow  ()(int     a, int     b, int*     res) => overflowOp!(adds, int    , int    , int    )(a, b, *res);
    bool __builtin_saddl_overflow ()(c_long  a, c_long  b, c_long*  res) => overflowOp!(adds, c_long , c_long , c_long )(a, b, *res);
    bool __builtin_saddll_overflow()(long    a, long    b, long*    res) => overflowOp!(adds, long   , long   , long   )(a, b, *res);
    bool __builtin_uadd_overflow  ()(uint    a, uint    b, uint*    res) => overflowOp!(adds, uint   , uint   , uint   )(a, b, *res);
    bool __builtin_uaddl_overflow ()(c_ulong a, c_ulong b, c_ulong* res) => overflowOp!(adds, c_ulong, c_ulong, c_ulong)(a, b, *res);
    bool __builtin_uaddll_overflow()(ulong   a, ulong   b, ulong*   res) => overflowOp!(adds, ulong  , ulong  , ulong  )(a, b, *res);
    bool __builtin_ssub_overflow  ()(int     a, int     b, int*     res) => overflowOp!(subs, int    , int    , int    )(a, b, *res);
    bool __builtin_ssubl_overflow ()(c_long  a, c_long  b, c_long*  res) => overflowOp!(subs, c_long , c_long , c_long )(a, b, *res);
    bool __builtin_ssubll_overflow()(long    a, long    b, long*    res) => overflowOp!(subs, long   , long   , long   )(a, b, *res);
    bool __builtin_usub_overflow  ()(uint    a, uint    b, uint*    res) => overflowOp!(subs, uint   , uint   , uint   )(a, b, *res);
    bool __builtin_usubl_overflow ()(c_ulong a, c_ulong b, c_ulong* res) => overflowOp!(subs, c_ulong, c_ulong, c_ulong)(a, b, *res);
    bool __builtin_usubll_overflow()(ulong   a, ulong   b, ulong*   res) => overflowOp!(subs, ulong  , ulong  , ulong  )(a, b, *res);
    bool __builtin_smul_overflow  ()(int     a, int     b, int*     res) => overflowOp!(muls, int    , int    , int    )(a, b, *res);
    bool __builtin_smull_overflow ()(c_long  a, c_long  b, c_long*  res) => overflowOp!(muls, c_long , c_long , c_long )(a, b, *res);
    bool __builtin_smulll_overflow()(long    a, long    b, long*    res) => overflowOp!(muls, long   , long   , long   )(a, b, *res);
    bool __builtin_umul_overflow  ()(uint    a, uint    b, uint*    res) => overflowOp!(muls, uint   , uint   , uint   )(a, b, *res);
    bool __builtin_umull_overflow ()(c_ulong a, c_ulong b, c_ulong* res) => overflowOp!(muls, c_ulong, c_ulong, c_ulong)(a, b, *res);
    bool __builtin_umulll_overflow()(ulong   a, ulong   b, ulong*   res) => overflowOp!(muls, ulong  , ulong  , ulong  )(a, b, *res);

    uint  __builtin_addc  ()(uint  a, uint  b, uint  carry_in, uint*  carry_out) => builtin_opc!(adds, uint )(a, b, carry_in, *carry_out);
    ulong __builtin_addcl ()(ulong a, ulong b, uint  carry_in, ulong* carry_out) => builtin_opc!(adds, ulong)(a, b, carry_in, *carry_out);
    ulong __builtin_addcll()(ulong a, ulong b, ulong carry_in, ulong* carry_out) => builtin_opc!(adds, ulong)(a, b, carry_in, *carry_out);
    uint  __builtin_subc  ()(uint  a, uint  b, uint  carry_in, uint*  carry_out) => builtin_opc!(subs, uint )(a, b, carry_in, *carry_out);
    ulong __builtin_subcl ()(ulong a, ulong b, uint  carry_in, ulong* carry_out) => builtin_opc!(subs, ulong)(a, b, carry_in, *carry_out);
    ulong __builtin_subcll()(ulong a, ulong b, ulong carry_in, ulong* carry_out) => builtin_opc!(subs, ulong)(a, b, carry_in, *carry_out);
}

unittest {
    int r1;
    assert(__builtin_sadd_overflow(2147483647, 1, &r1) == true);
    assert(__builtin_sadd_overflow(1, 1, &r1) == false);

    assert(__builtin_ssub_overflow(-2147483648, 1, &r1) == true);
    assert(__builtin_ssub_overflow(5, 3, &r1) == false);

    assert(__builtin_smul_overflow(2000000000, 2, &r1) == true);
    assert(__builtin_smul_overflow(10, 20, &r1) == false);

    uint ur;
    assert(__builtin_uadd_overflow(0xFFFFFFFFu, 1u, &ur) == true);
    assert(__builtin_uadd_overflow(10u, 20u, &ur) == false);

    assert(__builtin_usub_overflow(0u, 1u, &ur) == true);
    assert(__builtin_usub_overflow(20u, 10u, &ur) == false);

    assert(__builtin_umul_overflow(0xFFFFFFFFu, 2u, &ur) == true);
    assert(__builtin_umul_overflow(10u, 20u, &ur) == false);

    uint carry;
    uint rr = __builtin_addc(1u, 1u, 0u, &carry);
    assert(rr == 2);
    assert(carry == 0);

    rr = __builtin_addc(0xFFFFFFFFu, 1u, 0u, &carry);
    assert(carry == 1);

    rr = __builtin_subc(1u, 1u, 0u, &carry);
    assert(rr == 0);
    assert(carry == 0);

    rr = __builtin_subc(0u, 1u, 0u, &carry);
    assert(carry == 1);
}

private U signbit(T, U)(T x)
{
    T arg = x;
    return cast(U)arg >> (T.sizeof * 8 - 1);
}

pragma(inline, true)
{
    // https://gcc.gnu.org/onlinedocs/gcc/Bit-Operation-Builtins.html
    import core.bitop : popcnt, bsr, bsf, rol, ror;
    private int clz(T)(T x) => bsr(x) ^ ((int.sizeof * 8)-1);

    int __builtin_clz()(uint x)          => clz!uint(x);
    int __builtin_clzl()(c_ulong x)      => clz!c_ulong(x);
    int __builtin_clzll()(ulong x)       => clz!ulong(x);
    int __builtin_clzg(T)(T arg)         => clz(arg);

    int __builtin_ctz()(uint x)          => bsf(x);
    int __builtin_ctzl()(c_ulong x)      => bsf(x);
    int __builtin_ctzll()(ulong x)       => bsf(x);
    int __builtin_ctzg(T)(T arg)         => bsf(arg);

    int __builtin_clrsb()(int x)         => signbit!(int, uint)(x) ? clz!uint(~x) - 1 : clz!uint(x) -1;
    int __builtin_clrsbl()(c_long x)     => signbit!(c_long, c_ulong)(x) ? clz!c_ulong(~x) - 1 : clz!c_ulong(x) -1;
    int __builtin_clrsbll()(long x)      => signbit!(long, ulong)(x) ? clz!ulong(~x) - 1 : clz!ulong(x) -1;
    int __builtin_clrsbg(T, U)(T arg)    => signbit!(T, U)(arg) ? clz!U(~x) - 1 : clz!U(x) -1;

    int __builtin_ffs()(int x)           => x ? bsf(x) + 1 : 0;
    int __builtin_ffsl()(c_long x)       => x ? bsf(x) + 1 : 0;
    int __builtin_ffsll()(long x)        => x ? bsf(x) + 1 : 0;
    int __builtin_ffsg(T)(T arg)         => arg ? bsf(arg) + 1 : 0;

    int __builtin_popcount()(uint x)     => popcnt(x);
    int __builtin_popcountl()(c_ulong x) => popcnt(x);
    int __builtin_popcountll()(ulong x)  => popcnt(x);
    int __builtin_popcountg(T)(T arg)    => popcnt(arg);

    int __builtin_parity()(uint x)      => popcnt(x) % 2;
    int __builtin_parityl()(c_ulong)    => popcnt(x) % 2;
    int __builtin_parityll()(ulong)     => popcnt(x) % 2;
    int __builtin_parityg(T)(T arg)     => popcnt(arg) % 2;

    T __builtin_stdc_bit_ceil(T)(T arg)  => arg <= 1 ? T(1) : T(2) << (T.sizeof * 8 - 1 - clz(arg - 1));
    T __builtin_stdc_bit_floor(T)(T arg) => arg == 0 ? T(0) : T(1) << (T.sizeof * 8 - 1 - clz(arg));
    uint __builtin_stdc_bit_width(T)(T arg) => T.sizeof * 8 - clz(arg);
    uint __builtin_stdc_count_ones (T)(T arg) => popcnt(arg);
    uint __builtin_stdc_count_zeros(T)(T arg) => popcnt(cast(T) ~arg);
    uint __builtin_stdc_first_leading_one  (T)(T arg) => clz( arg) + 1U;
    uint __builtin_stdc_first_leading_zero (T)(T arg) => clz(~arg) + 1U;
    uint __builtin_stdc_first_trailing_one (T)(T arg) => ctz( arg) + 1U;
    uint __builtin_stdc_first_trailing_zero(T)(T arg) => ctz(~arg) + 1U;
    uint __builtin_stdc_has_single_bit(T)(T arg) => popcnt(arg) == 1;
    T1 __builtin_stdc_rotate_left (T1, T2)(T1 arg1, T2 arg2) => roL(arg1, arg2);
    T1 __builtin_stdc_rotate_right(T1, T2)(T1 arg1, T2 arg2) => ror(arg1, arg2);
}

unittest
{
    assert((__builtin_ffs(1)) == 1);
    assert((__builtin_ffs(2)) == 2);
    assert((__builtin_ffsl(8L)) == 4);
    assert((__builtin_ffsll(16L)) == 5);

    assert((__builtin_clz(1u)) >= 0);
    assert((__builtin_clzl(1UL)) >= 0);
    assert((__builtin_clzll(1UL)) >= 0);

    assert((__builtin_ctz(4u)) == 2);
    assert((__builtin_ctzl(4UL)) == 2);
    assert((__builtin_ctzll(8UL)) == 3);

    assert((__builtin_clrsb(1)) >= 0);
    assert((__builtin_clrsbl(1L)) >= 0);
    assert((__builtin_clrsbll(1L)) >= 0);

    assert((__builtin_popcount(3u)) == 2);
    assert((__builtin_popcountl(3UL)) == 2);
    assert((__builtin_popcountll(3UL)) == 2);

    assert((__builtin_parity(3u)) == 0);
    assert((__builtin_parityl(3UL)) == 0);
    assert((__builtin_parityll(3UL)) == 0);

    assert((__builtin_stdc_rotate_right(2u, 1)) >= 1);
}

// https://gcc.gnu.org/onlinedocs/gcc/CRC-Builtins.html

/* processes from LSB */
C rev_crc_data(C, D, P)(C crc, D data, P poly)
{
    foreach (_; 0 .. D.sizeof * 8) {
        bool mix = (crc ^ data) & 0x01;
        crc >>= 1;
        if (mix)
            crc ^= poly;
        data >>= 1;
    }
    return crc;
}

/* processes from MSB */
C crc_data(C, D, P)(C crc, D data, P poly)
{
    enum dbit_width = D.sizeof * 8;
    foreach (_; 0 .. dbit_width) {
        C top_bit = cast(C)1 << (C.sizeof * 8 - 1);
        bool data_bit = ((data & (cast(D)1 << (dbit_width - 1))) != 0);
        bool mix = ((crc & top_bit) != 0) ^ data_bit;
        crc <<= 1;
        if (mix)
            crc ^= poly;
        data <<= 1;
    }
    return crc;
}


pragma(inline, true)
{
    ubyte __builtin_rev_crc8_data8()(ubyte crc, ubyte data, ubyte poly) => rev_crc_data!(ubyte, ubyte, ubyte)(crc, data, poly);
    ushort __builtin_rev_crc16_data16()(ushort crc, ushort data, ushort poly) => rev_crc_data!(ushort, ushort, ushort)(crc, data, poly);
    ushort __builtin_rev_crc16_data8()(ushort crc, ubyte data, ushort poly) => rev_crc_data!(ushort, ubyte, ushort)(crc, data, poly);
    uint __builtin_rev_crc32_data32()(uint crc, uint data, uint poly) => rev_crc_data!(uint, uint, uint)(crc, data, poly);
    uint __builtin_rev_crc32_data8()(uint crc, ubyte data, uint poly) => rev_crc_data!(uint, ubyte, uint)(crc, data, poly);
    uint __builtin_rev_crc32_data16()(uint crc, ushort data, uint poly) => rev_crc_data!(uint, ushort, uint)(crc, data, poly);
    ulong __builtin_rev_crc64_data64()(ulong crc, ulong data, ulong poly) => rev_crc_data!(ulong, ulong, ulong)(crc, data, poly);
    ulong __builtin_rev_crc64_data8()(ulong crc, ubyte data, ulong poly) => rev_crc_data!(ulong, ubyte, ulong)(crc, data, poly);
    ulong __builtin_rev_crc64_data16()(ulong crc, ushort data, ulong poly) => rev_crc_data!(ulong, ushort, ulong)(crc, data, poly);
    ulong __builtin_rev_crc64_data32()(ulong crc, uint data, ulong poly) => rev_crc_data!(ulong, uint, ulong)(crc, data, poly);

    ubyte __builtin_crc8_data8()(ubyte crc, ubyte data, ubyte poly) => crc_data!(ubyte, ubyte, ubyte)(crc, data, poly);
    ushort __builtin_crc16_data16()(ushort crc, ushort data, ushort poly) => crc_data!(ushort, ushort, ushort)(crc, data, poly);
    ushort __builtin_crc16_data8()(ushort crc, ubyte data, ushort poly) => crc_data!(ushort, ubyte, ushort)(crc, data, poly);
    uint __builtin_crc32_data32()(uint crc, uint data, uint poly) => crc_data!(uint, uint, uint)(crc, data, poly);
    uint __builtin_crc32_data8()(uint crc, ubyte data, uint poly) => crc_data!(uint, ubyte, uint)(crc, data, poly);
    uint __builtin_crc32_data16()(uint crc, ushort data, uint poly) => crc_data!(uint, ushort, uint)(crc, data, poly);
    ulong __builtin_crc64_data64()(ulong crc, ulong data, ulong poly) => crc_data!(ulong, ulong, ulong)(crc, data, poly);
    ulong __builtin_crc64_data8()(ulong crc, ubyte data, ulong poly) => crc_data!(ulong, ubyte, ulong)(crc, data, poly);
    ulong __builtin_crc64_data16()(ulong crc, ushort data, ulong poly) => crc_data!(ulong, ushort, ulong)(crc, data, poly);
    ulong __builtin_crc64_data32()(ulong crc, uint data, ulong poly) => crc_data!(ulong, uint, ulong)(crc, data, poly);
}
