/**
 * This module contains a collection of bit-level operations.
 *
 * Copyright: Copyright Don Clugston 2005 - 2013.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Don Clugston, Sean Kelly, Walter Bright, Alex Rønne Petersen, Thomas Stuart Bockman
 * Source:    $(DRUNTIMESRC core/_bitop.d)
 */

module core.bitop;

nothrow:
@safe:
@nogc:

version( D_InlineAsm_X86_64 )
    version = AsmX86;
else version( D_InlineAsm_X86 )
    version = AsmX86;

version (X86_64)
    version = AnyX86;
else version (X86)
    version = AnyX86;

// Use to implement 64-bit bitops on 32-bit arch.
private union Split64
{
    ulong u64;
    struct
    {
        version(LittleEndian)
        {
            uint lo;
            uint hi;
        }
        else
        {
            uint hi;
            uint lo;
        }
    }

    pragma(inline, true)
    this(ulong u64) @safe pure nothrow @nogc
    {
        if (__ctfe)
        {
            lo = cast(uint) u64;
            hi = cast(uint) (u64 >>> 32);
        }
        else
            this.u64 = u64;
    }
}

unittest
{
    const rt = Split64(1);
    assert((rt.lo == 1) && (rt.hi == 0));

    enum ct = Split64(1);
    assert((ct.lo == rt.lo) && (ct.hi == rt.hi));
}

/**
 * Scans the bits in v starting with bit 0, looking
 * for the first set bit.
 * Returns:
 *      The bit number of the first bit set.
 *      The return value is undefined if v is zero.
 */
int bsf(size_t v) pure;

/// ditto
int bsf(ulong v) pure
{
    static if (size_t.sizeof == ulong.sizeof)
        return bsf(cast(size_t) v);
    else static if (size_t.sizeof == uint.sizeof)
    {
        const sv = Split64(v);
        return (sv.lo == 0)?
            bsf(sv.hi) + 32 :
            bsf(sv.lo);
    }
    else
        static assert(false);
}

///
unittest
{
    assert(bsf(0x21) == 0);
    assert(bsf(ulong.max << 39) == 39);
}

unittest
{
    // Make sure bsf() is available at CTFE
    enum test_ctfe = bsf(ulong.max);
    assert(test_ctfe == 0);
}

/**
 * Scans the bits in v from the most significant bit
 * to the least significant bit, looking
 * for the first set bit.
 * Returns:
 *      The bit number of the first bit set.
 *      The return value is undefined if v is zero.
 */
int bsr(size_t v) pure;

/// ditto
int bsr(ulong v) pure
{
    static if (size_t.sizeof == ulong.sizeof)
        return bsr(cast(size_t) v);
    else static if (size_t.sizeof == uint.sizeof)
    {
        const sv = Split64(v);
        return (sv.hi == 0)?
            bsr(sv.lo) :
            bsr(sv.hi) + 32;
    }
    else
        static assert(false);
}

///
unittest
{
    assert(bsr(0x21) == 5);
    assert(bsr((ulong.max >> 15) - 1) == 48);
}

unittest
{
    // Make sure bsr() is available at CTFE
    enum test_ctfe = bsr(ulong.max);
    assert(test_ctfe == 63);
}

/**
 * Tests the bit.
 * (No longer an intrisic - the compiler recognizes the patterns
 * in the body.)
 */
int bt(in size_t* p, size_t bitnum) pure @system
{
    static if (size_t.sizeof == 8)
        return ((p[bitnum >> 6] & (1L << (bitnum & 63)))) != 0;
    else static if (size_t.sizeof == 4)
        return ((p[bitnum >> 5] & (1  << (bitnum & 31)))) != 0;
    else
        static assert(0);
}
///
@system pure unittest
{
    size_t[2] array;

    array[0] = 2;
    array[1] = 0x100;

    assert(bt(array.ptr, 1));
    assert(array[0] == 2);
    assert(array[1] == 0x100);
}

/**
 * Tests and complements the bit.
 */
int btc(size_t* p, size_t bitnum) pure @system;


/**
 * Tests and resets (sets to 0) the bit.
 */
int btr(size_t* p, size_t bitnum) pure @system;


/**
 * Tests and sets the bit.
 * Params:
 * p = a non-NULL pointer to an array of size_ts.
 * bitnum = a bit number, starting with bit 0 of p[0],
 * and progressing. It addresses bits like the expression:
---
p[index / (size_t.sizeof*8)] & (1 << (index & ((size_t.sizeof*8) - 1)))
---
 * Returns:
 *      A non-zero value if the bit was set, and a zero
 *      if it was clear.
 */
int bts(size_t* p, size_t bitnum) pure @system;

///
@system pure unittest
{
    size_t[2] array;

    array[0] = 2;
    array[1] = 0x100;

    assert(btc(array.ptr, 35) == 0);
    if (size_t.sizeof == 8)
    {
        assert(array[0] == 0x8_0000_0002);
        assert(array[1] == 0x100);
    }
    else
    {
        assert(array[0] == 2);
        assert(array[1] == 0x108);
    }

    assert(btc(array.ptr, 35));
    assert(array[0] == 2);
    assert(array[1] == 0x100);

    assert(bts(array.ptr, 35) == 0);
    if (size_t.sizeof == 8)
    {
        assert(array[0] == 0x8_0000_0002);
        assert(array[1] == 0x100);
    }
    else
    {
        assert(array[0] == 2);
        assert(array[1] == 0x108);
    }

    assert(btr(array.ptr, 35));
    assert(array[0] == 2);
    assert(array[1] == 0x100);
}

/**
 * Swaps bytes in a 4 byte uint end-to-end, i.e. byte 0 becomes
 * byte 3, byte 1 becomes byte 2, byte 2 becomes byte 1, byte 3
 * becomes byte 0.
 */
uint bswap(uint v) pure;

/**
 * Swaps bytes in an 8 byte ulong end-to-end, i.e. byte 0 becomes
 * byte 7, byte 1 becomes byte 6, etc.
 */
ulong bswap(ulong v) pure
{
    auto sv = Split64(v);

    const temp = sv.lo;
    sv.lo = bswap(sv.hi);
    sv.hi = bswap(temp);

    return (cast(ulong) sv.hi << 32) | sv.lo;
}

version (DigitalMars) version (AnyX86) @system // not pure
{
    /**
     * Reads I/O port at port_address.
     */
    ubyte inp(uint port_address);


    /**
     * ditto
     */
    ushort inpw(uint port_address);


    /**
     * ditto
     */
    uint inpl(uint port_address);


    /**
     * Writes and returns value to I/O port at port_address.
     */
    ubyte outp(uint port_address, ubyte value);


    /**
     * ditto
     */
    ushort outpw(uint port_address, ushort value);


    /**
     * ditto
     */
    uint outpl(uint port_address, uint value);
}


/**
 *  Calculates the number of set bits in an integer.
 */
int popcnt(uint x) pure
{
    // Select the fastest method depending on the compiler and CPU architecture
    version(LDC)
    {
        return _popcnt(x);
    }
    else
    {
        version(DigitalMars)
        {
            static if (is(typeof(_popcnt(uint.max))))
            {
                import core.cpuid;
                if (!__ctfe && hasPopcnt)
                    return _popcnt(x);
            }
        }

        return softPopcnt!uint(x);
    }
}

unittest
{
    assert( popcnt( 0 ) == 0 );
    assert( popcnt( 7 ) == 3 );
    assert( popcnt( 0xAA )== 4 );
    assert( popcnt( 0x8421_1248 ) == 8 );
    assert( popcnt( 0xFFFF_FFFF ) == 32 );
    assert( popcnt( 0xCCCC_CCCC ) == 16 );
    assert( popcnt( 0x7777_7777 ) == 24 );

    // Make sure popcnt() is available at CTFE
    enum test_ctfe = popcnt(uint.max);
    assert(test_ctfe == 32);
}

/// ditto
int popcnt(ulong x) pure
{
    // Select the fastest method depending on the compiler and CPU architecture
    version(LDC)
    {
        return _popcnt(x);
    }
    else
    {
        import core.cpuid;

        static if (size_t.sizeof == uint.sizeof)
        {
            const sx = Split64(x);
            version(DigitalMars)
            {
                static if (is(typeof(_popcnt(uint.max))))
                {
                    if (!__ctfe && hasPopcnt)
                        return _popcnt(sx.lo) + _popcnt(sx.hi);
                }
            }

            return softPopcnt!uint(sx.lo) + softPopcnt!uint(sx.hi);
        }
        else static if (size_t.sizeof == ulong.sizeof)
        {
            version(DigitalMars)
            {
                static if (is(typeof(_popcnt(ulong.max))))
                {
                    if (!__ctfe && hasPopcnt)
                        return _popcnt(x);
                }
            }

            return softPopcnt!ulong(x);
        }
        else
            static assert(false);
    }
}

unittest
{
    assert(popcnt(0uL) == 0);
    assert(popcnt(1uL) == 1);
    assert(popcnt((1uL << 32) - 1) == 32);
    assert(popcnt(0x48_65_6C_6C_6F_3F_21_00uL) == 28);
    assert(popcnt(ulong.max) == 64);

    // Make sure popcnt() is available at CTFE
    enum test_ctfe = popcnt(ulong.max);
    assert(test_ctfe == 64);
}

private int softPopcnt(N)(N x) pure
    if (is(N == uint) || is(N == ulong))
{
    // Avoid branches, and the potential for cache misses which
    // could be incurred with a table lookup.

    // We need to mask alternate bits to prevent the
    // sum from overflowing.
    // add neighbouring bits. Each bit is 0 or 1.
    enum mask1 = cast(N) 0x5555_5555_5555_5555L;
    x = x - ((x>>1) & mask1);
    // now each two bits of x is a number 00,01 or 10.
    // now add neighbouring pairs
    enum mask2a = cast(N) 0xCCCC_CCCC_CCCC_CCCCL;
    enum mask2b = cast(N) 0x3333_3333_3333_3333L;
    x = ((x & mask2a)>>2) + (x & mask2b);
    // now each nibble holds 0000-0100. Adding them won't
    // overflow any more, so we don't need to mask any more

    enum mask4 = cast(N) 0x0F0F_0F0F_0F0F_0F0FL;
    x = (x + (x >> 4)) & mask4;

    enum shiftbits = is(N == uint)? 24 : 56;
    enum maskMul = cast(N) 0x0101_0101_0101_0101L;
    x = (x * maskMul) >> shiftbits;

    return cast(int) x;
}

version (DigitalMars) version (AnyX86)
{
    /**
     * Calculates the number of set bits in an integer
     * using the X86 SSE4 POPCNT instruction.
     * POPCNT is not available on all X86 CPUs.
     */
    ushort _popcnt( ushort x ) pure;
    /// ditto
    int _popcnt( uint x ) pure;
    version (X86_64)
    {
        /// ditto
        int _popcnt( ulong x ) pure;
    }

    unittest
    {
        // Not everyone has SSE4 instructions
        import core.cpuid;
        if (!hasPopcnt)
            return;

        static int popcnt_x(ulong u) nothrow @nogc
        {
            int c;
            while (u)
            {
                c += u & 1;
                u >>= 1;
            }
            return c;
        }

        for (uint u = 0; u < 0x1_0000; ++u)
        {
            //writefln("%x %x %x", u,   _popcnt(cast(ushort)u), popcnt_x(cast(ushort)u));
            assert(_popcnt(cast(ushort)u) == popcnt_x(cast(ushort)u));

            assert(_popcnt(cast(uint)u) == popcnt_x(cast(uint)u));
            uint ui = u * 0x3_0001;
            assert(_popcnt(ui) == popcnt_x(ui));

            version (X86_64)
            {
                assert(_popcnt(cast(ulong)u) == popcnt_x(cast(ulong)u));
                ulong ul = u * 0x3_0003_0001;
                assert(_popcnt(ul) == popcnt_x(ul));
            }
        }
    }
}


/*************************************
 * Read/write value from/to the memory location indicated by ptr.
 *
 * These functions are recognized by the compiler, and calls to them are guaranteed
 * to not be removed (as dead assignment elimination or presumed to have no effect)
 * or reordered in the same thread.
 *
 * These reordering guarantees are only made with regards to other
 * operations done through these functions; the compiler is free to reorder regular
 * loads/stores with regards to loads/stores done through these functions.
 *
 * This is useful when dealing with memory-mapped I/O (MMIO) where a store can
 * have an effect other than just writing a value, or where sequential loads
 * with no intervening stores can retrieve
 * different values from the same location due to external stores to the location.
 *
 * These functions will, when possible, do the load/store as a single operation. In
 * general, this is possible when the size of the operation is less than or equal to
 * $(D (void*).sizeof), although some targets may support larger operations. If the
 * load/store cannot be done as a single operation, multiple smaller operations will be used.
 *
 * These are not to be conflated with atomic operations. They do not guarantee any
 * atomicity. This may be provided by coincidence as a result of the instructions
 * used on the target, but this should not be relied on for portable programs.
 * Further, no memory fences are implied by these functions.
 * They should not be used for communication between threads.
 * They may be used to guarantee a write or read cycle occurs at a specified address.
 */

ubyte  volatileLoad(ubyte * ptr);
ushort volatileLoad(ushort* ptr);  /// ditto
uint   volatileLoad(uint  * ptr);  /// ditto
ulong  volatileLoad(ulong * ptr);  /// ditto

void volatileStore(ubyte * ptr, ubyte  value);   /// ditto
void volatileStore(ushort* ptr, ushort value);   /// ditto
void volatileStore(uint  * ptr, uint   value);   /// ditto
void volatileStore(ulong * ptr, ulong  value);   /// ditto

@system unittest
{
    alias TT(T...) = T;

    foreach (T; TT!(ubyte, ushort, uint, ulong))
    {
        T u;
        T* p = &u;
        volatileStore(p, 1);
        T r = volatileLoad(p);
        assert(r == u);
    }
}


/**
 * Reverses the order of bits in a 32-bit integer.
 */
pragma(inline, true)
uint bitswap( uint x ) pure
{
    if (!__ctfe)
    {
        static if (is(typeof(asmBitswap32(x))))
            return asmBitswap32(x);
    }

    return softBitswap!uint(x);
}

unittest
{
    static void test(alias impl)()
    {
        assert (impl( 0x8000_0100 ) == 0x0080_0001);
        foreach(i; 0 .. 32)
            assert (impl(1 << i) == 1 << 32 - i - 1);
    }

    test!(bitswap)();
    test!(softBitswap!uint)();
    static if (is(typeof(asmBitswap32(0u))))
        test!(asmBitswap32)();

    // Make sure bitswap() is available at CTFE
    enum test_ctfe = bitswap(1U);
    assert(test_ctfe == (1U << 31));
}

/**
 * Reverses the order of bits in a 64-bit integer.
 */
pragma(inline, true)
ulong bitswap ( ulong x ) pure
{
    if (!__ctfe)
    {
        static if (is(typeof(asmBitswap64(x))))
            return asmBitswap64(x);
    }

    return softBitswap!ulong(x);
}

unittest
{
    static void test(alias impl)()
    {
        assert (impl( 0b1000000000000000000000010000000000000000100000000000000000000001)
            == 0b1000000000000000000000010000000000000000100000000000000000000001);
        assert (impl( 0b1110000000000000000000010000000000000000100000000000000000000001)
            == 0b1000000000000000000000010000000000000000100000000000000000000111);
        foreach (i; 0 .. 64)
            assert (impl(1UL << i) == 1UL << 64 - i - 1);
    }

    test!(bitswap)();
    test!(softBitswap!ulong)();
    static if (is(typeof(asmBitswap64(0uL))))
        test!(asmBitswap64)();

    // Make sure bitswap() is available at CTFE
    enum test_ctfe = bitswap(1UL);
    assert(test_ctfe == (1UL << 63));
}

private N softBitswap(N)(N x) pure
    if (is(N == uint) || is(N == ulong))
{
    // swap 1-bit pairs:
    enum mask1 = cast(N) 0x5555_5555_5555_5555L;
    x = ((x >> 1) & mask1) | ((x & mask1) << 1);
    // swap 2-bit pairs:
    enum mask2 = cast(N) 0x3333_3333_3333_3333L;
    x = ((x >> 2) & mask2) | ((x & mask2) << 2);
    // swap 4-bit pairs:
    enum mask4 = cast(N) 0x0F0F_0F0F_0F0F_0F0FL;
    x = ((x >> 4) & mask4) | ((x & mask4) << 4);

    // reverse the order of all bytes:
    x = bswap(x);

    return x;
}

version (AsmX86)
{
    private uint asmBitswap32(uint x) @trusted pure
    {
        asm pure nothrow @nogc { naked; }

        version (D_InlineAsm_X86_64)
        {
            version (Win64)
                asm pure nothrow @nogc { mov EAX, ECX; }
            else
                asm pure nothrow @nogc { mov EAX, EDI; }
        }

        asm pure nothrow @nogc
        {
            // Author: Tiago Gasiba.
            mov EDX, EAX;
            shr EAX, 1;
            and EDX, 0x5555_5555;
            and EAX, 0x5555_5555;
            shl EDX, 1;
            or  EAX, EDX;
            mov EDX, EAX;
            shr EAX, 2;
            and EDX, 0x3333_3333;
            and EAX, 0x3333_3333;
            shl EDX, 2;
            or  EAX, EDX;
            mov EDX, EAX;
            shr EAX, 4;
            and EDX, 0x0f0f_0f0f;
            and EAX, 0x0f0f_0f0f;
            shl EDX, 4;
            or  EAX, EDX;
            bswap EAX;
            ret;
        }
    }
}

version (D_InlineAsm_X86_64)
{
    private ulong asmBitswap64(ulong x) @trusted pure
    {
        asm pure nothrow @nogc { naked; }

        version (Win64)
            asm pure nothrow @nogc { mov RAX, RCX; }
        else
            asm pure nothrow @nogc { mov RAX, RDI; }

        asm pure nothrow @nogc
        {
            // Author: Tiago Gasiba.
            mov RDX, RAX;
            shr RAX, 1;
            mov RCX, 0x5555_5555_5555_5555L;
            and RDX, RCX;
            and RAX, RCX;
            shl RDX, 1;
            or  RAX, RDX;

            mov RDX, RAX;
            shr RAX, 2;
            mov RCX, 0x3333_3333_3333_3333L;
            and RDX, RCX;
            and RAX, RCX;
            shl RDX, 2;
            or  RAX, RDX;

            mov RDX, RAX;
            shr RAX, 4;
            mov RCX, 0x0f0f_0f0f_0f0f_0f0fL;
            and RDX, RCX;
            and RAX, RCX;
            shl RDX, 4;
            or  RAX, RDX;
            bswap RAX;
            ret;
        }
    }
}

/**
 *  Bitwise rotates unsigned integer types
 */
pure T rol(T)(in T value, in uint count)
    if (__traits(isIntegral, T) && __traits(isUnsigned, T))
{
    assert(count < 8 * T.sizeof);
    return cast(T) ((value << count) | (value >> (-count & (T.sizeof * 8 - 1))));
}
/// ditto
pure T ror(T)(in T value, in uint count)
    if (__traits(isIntegral, T) && __traits(isUnsigned, T))
{
    assert(count < 8 * T.sizeof);
    return cast(T) ((value >> count) | (value << (-count & (T.sizeof * 8 - 1))));
}
/// ditto
pure T rol(uint count, T)(in T value)
    if (__traits(isIntegral, T) && __traits(isUnsigned, T))
{
    static assert(count < 8 * T.sizeof);
    return cast(T) ((value << count) | (value >> (-count & (T.sizeof * 8 - 1))));
}
/// ditto
pure T ror(uint count, T)(in T value)
    if (__traits(isIntegral, T) && __traits(isUnsigned, T))
{
    static assert(count < 8 * T.sizeof);
    return cast(T) ((value >> count) | (value << (-count & (T.sizeof * 8 - 1))));
}

///
unittest
{
    ubyte a = 0b10101010U;
    ulong b = ulong.max;

    assert(rol(a, 1) == 0b01010101);
    assert(ror(a, 1) == 0b01010101);
    assert(rol(a, 3) == 0b01010101);
    assert(ror(a, 3) == 0b01010101);

    assert(rol(a, 0) == a);
    assert(ror(a, 0) == a);

    assert(rol(b, 63) == ulong.max);
    assert(ror(b, 63) == ulong.max);

    assert(rol!3(a) == 0b01010101);
    assert(ror!3(a) == 0b01010101);
}
