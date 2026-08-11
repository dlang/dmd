/**
 * Misc symbols required for WASM
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module rt.wasm.extra;

private extern (C) noreturn _wasm_trap(int code) @nogc nothrow;

/// The libc assert handler, the D `assert` throws an AssertError instead
extern (C) noreturn __assert(const(char)* file, int line, const(char)* msg) @nogc nothrow
{
    import core.stdc.stdio : fprintf, stderr;
    fprintf(stderr, "%s(%d): Assertion `%s` failed\n", file, line, msg);
    _wasm_trap(1);
}

/// wasi-libc exposes errno as a plain global, druntime expects an accessor
private extern (C) extern __gshared int errno;
extern (C) ref int __errno_location() @nogc nothrow
{
    return errno;
}

private extern (C) void* gc_calloc(size_t sz, uint ba = 0, const scope TypeInfo ti = null) @nogc nothrow;

// Only for &alloca, the wasm backend lowers direct alloca() calls to a dynamic
// shadow-stack bump
extern (C) void* alloca(size_t size) nothrow
{
    return gc_calloc(size);
}

import core.attribute : wasmImportModule;

@wasmImportModule("wasi_snapshot_preview1")
private extern (C) int clock_time_get(uint clockId, ulong precision, ulong* timestamp) @nogc nothrow;

extern (C) long clock() @nogc nothrow
{
    ulong t;
    if (clock_time_get(2, 1, &t) != 0 && clock_time_get(1, 1, &t) != 0)
        return -1;
    return cast(long) t;
}

// wasi-libc emits these for 128 bit multiply (strtod/scanf long double paths)
extern (C) void __multi3(ulong* res, ulong alo, ulong ahi, ulong blo, ulong bhi)
{
    const ulong a0 = alo & 0xFFFF_FFFF, a1 = alo >> 32;
    const ulong b0 = blo & 0xFFFF_FFFF, b1 = blo >> 32;
    const ulong p00 = a0 * b0;
    const ulong mid = a0 * b1 + (p00 >> 32);
    const ulong mid2 = a1 * b0 + (mid & 0xFFFF_FFFF);
    res[0] = (mid2 << 32) | (p00 & 0xFFFF_FFFF);
    res[1] = a1 * b1 + (mid >> 32) + (mid2 >> 32) + alo * bhi + ahi * blo;
}

extern (C) void __muloti4(ulong* res, ulong alo, ulong ahi, ulong blo, ulong bhi, int* overflow)
{
    __multi3(res, alo, ahi, blo, bhi);

    static void mul64(ulong a, ulong b, out ulong lo, out ulong hi)
    {
        const ulong a0 = a & 0xFFFF_FFFF, a1 = a >> 32;
        const ulong b0 = b & 0xFFFF_FFFF, b1 = b >> 32;
        const ulong p00 = a0 * b0;
        const ulong mid = a0 * b1 + (p00 >> 32);
        const ulong mid2 = a1 * b0 + (mid & 0xFFFF_FFFF);
        lo = (mid2 << 32) | (p00 & 0xFFFF_FFFF);
        hi = a1 * b1 + (mid >> 32) + (mid2 >> 32);
    }
    static void neg128(ref ulong lo, ref ulong hi)
    {
        hi = ~hi + (lo == 0 ? 1 : 0);
        lo = 0 - lo;
    }

    const bool negA = (ahi >> 63) != 0;
    const bool negB = (bhi >> 63) != 0;
    if (negA)
        neg128(alo, ahi);
    if (negB)
        neg128(blo, bhi);

    ulong p0lo, p0hi, qlo, qhi, rlo, rhi;
    mul64(alo, blo, p0lo, p0hi);
    mul64(alo, bhi, qlo, qhi);
    mul64(ahi, blo, rlo, rhi);
    const bool anyTop = (ahi && bhi) || qhi || rhi;

    ulong mid = p0hi + qlo;
    bool carry = mid < p0hi;
    const ulong mid2 = mid + rlo;
    carry = carry || (mid2 < mid);

    const bool negResult = negA != negB;
    bool ovf = anyTop || carry;
    if (!ovf && (mid2 >> 63))
        ovf = !negResult || mid2 != 0x8000_0000_0000_0000UL || p0lo != 0;
    *overflow = ovf ? 1 : 0;
}
