/**
 * This module contains a collection of bit-level operations.
 *
 * Copyright: Copyright Don Clugston 2005 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Don Clugston, Sean Kelly, Walter Bright
 * Source:    $(DRUNTIMESRC core/_bitop.d)
 */

/*          Copyright Don Clugston 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.bitop;

nothrow:


/**
 * Scans the bits in v starting with bit 0, looking
 * for the first set bit.
 * Returns:
 *      The bit number of the first bit set.
 *      The return value is undefined if v is zero.
 * Example:
 * ---
 * import core.bitop;
 *
 * int main()
 * {
 *     assert(bsf(0x21) == 0);
 *     return 0;
 * }
 * ---
 */
pure int bsf(size_t v);

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
 * Example:
 * ---
 * import core.bitop;
 *
 * int main()
 * {
 *     assert(bsr(0x21) == 5);
 *     return 0;
 * }
 * ---
 */
pure int bsr(size_t v);

unittest
{
    assert(bsr(0x21) == 5);
}

/**
 * Tests the bit.
 */
pure int bt(in size_t* p, size_t bitnum);


/**
 * Tests and complements the bit.
 */
int btc(size_t* p, size_t bitnum);


/**
 * Tests and resets (sets to 0) the bit.
 */
int btr(size_t* p, size_t bitnum);


/**
 * Tests and sets the bit.
 * Params:
 * p = a non-NULL pointer to an array of size_ts.
 * index = a bit number, starting with bit 0 of p[0],
 * and progressing. It addresses bits like the expression:
---
p[index / (size_t.sizeof*8)] & (1 << (index & ((size_t.sizeof*8) - 1)))
---
 * Returns:
 *      A non-zero value if the bit was set, and a zero
 *      if it was clear.
 *
 * Example:
 * ---
import std.stdio;
import core.bitop;

int main()
{
    size_t array[2];

    array[0] = 2;
    array[1] = 0x100;

    assert(btc(array, 35) == 0);
    assert(array[0] == 2);
    assert(array[1] == 0x108);

    assert(btc(array, 35) == -1);
    assert(array[0] == 2);
    assert(array[1] == 0x100);

    assert(bts(array, 35) == 0);
    assert(array[0] == 2);
    assert(array[1] == 0x108);

    assert(btr(array, 35) == -1);
    assert(array[0] == 2);
    assert(array[1] == 0x100);

    assert(bt(array, 1) == -1);
    assert(array[0] == 2);
    assert(array[1] == 0x100);

    return 0;
}
 * ---
 */
int bts(size_t* p, size_t bitnum);

unittest
{
    size_t array[2];

    array[0] = 2;
    array[1] = 0x100;

    assert(btc(array, 35) == 0);
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

    assert(btc(array, 35) == -1);
    assert(array[0] == 2);
    assert(array[1] == 0x100);

    assert(bts(array, 35) == 0);
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

    assert(btr(array, 35) == -1);
    assert(array[0] == 2);
    assert(array[1] == 0x100);

    assert(bt(array, 1) == -1);
    assert(array[0] == 2);
    assert(array[1] == 0x100);
}

/**
 * Swaps bytes in a 4 byte uint end-to-end, i.e. byte 0 becomes
 * byte 3, byte 1 becomes byte 2, byte 2 becomes byte 1, byte 3
 * becomes byte 0.
 */
pure uint bswap(uint v);


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


/**
 *  Calculates the number of set bits in a 32-bit integer.
 */
int popcnt( uint x )
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


debug( UnitTest )
{
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
}


/**
 * Reverses the order of bits in a 32-bit integer.
 */
uint bitswap( uint x )
{

    version( D_InlineAsm_X86 )
    {
        asm
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


debug( UnitTest )
{
    unittest
    {
        assert( bitswap( 0x8000_0100 ) == 0x0080_0001 );
    }
}
