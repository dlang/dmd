/**
 * This module contains a collection of bit-level operations.
 *
 * Copyright: Copyright Don Clugston 2005 - 2013.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Don Clugston, Sean Kelly, Walter Bright, Alex Rønne Petersen
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

/**
 * Scans the bits in v starting with bit 0, looking
 * for the first set bit.
 * Returns:
 *      The bit number of the first bit set.
 *      The return value is undefined if v is zero.
 */
int bsf(size_t v) pure;

///
unittest
{
    assert(bsf(0x21) == 0);
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

///
unittest
{
    assert(bsr(0x21) == 5);
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

version (AnyX86)
{
    /**
     * Calculates the number of set bits in a 32-bit integer
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
 *  Calculates the number of set bits in a 32-bit integer.
 */
int popcnt( uint x ) pure
{
    // Avoid branches, and the potential for cache misses which
    // could be incurred with a table lookup.

    // We need to mask alternate bits to prevent the
    // sum from overflowing.
    // add neighbouring bits. Each bit is 0 or 1.
    x = x - ((x>>1) & 0x5555_5555);
    // now each two bits of x is a number 00,01 or 10.
    // now add neighbouring pairs
    x = ((x&0xCCCC_CCCC)>>2) + (x&0x3333_3333);
    // now each nibble holds 0000-0100. Adding them won't
    // overflow any more, so we don't need to mask any more

    // Now add the nibbles, then the bytes, then the words
    // We still need to mask to prevent double-counting.
    // Note that if we used a rotate instead of a shift, we
    // wouldn't need the masks, and could just divide the sum
    // by 8 to account for the double-counting.
    // On some CPUs, it may be faster to perform a multiply.

    x += (x>>4);
    x &= 0x0F0F_0F0F;
    x += (x>>8);
    x &= 0x00FF_00FF;
    x += (x>>16);
    x &= 0xFFFF;
    return x;
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
}


/**
 * Reverses the order of bits in a 32-bit integer.
 */
@trusted uint bitswap( uint x ) pure
{
    version (AsmX86)
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
    else
    {
        // swap odd and even bits
        x = ((x >> 1) & 0x5555_5555) | ((x & 0x5555_5555) << 1);
        // swap consecutive pairs
        x = ((x >> 2) & 0x3333_3333) | ((x & 0x3333_3333) << 2);
        // swap nibbles
        x = ((x >> 4) & 0x0F0F_0F0F) | ((x & 0x0F0F_0F0F) << 4);
        // swap bytes
        x = ((x >> 8) & 0x00FF_00FF) | ((x & 0x00FF_00FF) << 8);
        // swap 2-byte long pairs
        x = ( x >> 16              ) | ( x               << 16);
        return x;

    }
}


unittest
{
    assert( bitswap( 0x8000_0100 ) == 0x0080_0001 );
    foreach(i; 0 .. 32)
        assert(bitswap(1 << i) == 1 << 32 - i - 1);
}

/**
 * Reverses the order of bits in a 64-bit integer.
 */
ulong bitswap ( ulong x ) pure @trusted
{
    version (D_InlineAsm_X86_64)
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
    else
    {
        // swap odd and even bits
        x = ((x >> 1) & 0x5555_5555_5555_5555L) | ((x & 0x5555_5555_5555_5555L) << 1);
        // swap consecutive pairs
        x = ((x >> 2) & 0x3333_3333_3333_3333L) | ((x & 0x3333_3333_3333_3333L) << 2);
        // swap nibbles
        x = ((x >> 4) & 0x0f0f_0f0f_0f0f_0f0fL) | ((x & 0x0f0f_0f0f_0f0f_0f0fL) << 4);
        // swap bytes
        x = ((x >> 8) & 0x00FF_00FF_00FF_00FFL) | ((x & 0x00FF_00FF_00FF_00FFL) << 8);
        // swap shorts
        x = ((x >> 16) & 0x0000_FFFF_0000_FFFFL) | ((x & 0x0000_FFFF_0000_FFFFL) << 16);
        // swap ints
        x = ( x >> 32 ) | ( x << 32);
        return x;
    }
}

unittest
{
    assert (bitswap( 0b1000000000000000000000010000000000000000100000000000000000000001)
        == 0b1000000000000000000000010000000000000000100000000000000000000001);
    assert (bitswap( 0b1110000000000000000000010000000000000000100000000000000000000001)
        == 0b1000000000000000000000010000000000000000100000000000000000000111);
    foreach (i; 0 .. 64)
        assert(bitswap(1UL << i) == 1UL << 64 - i - 1);
}
