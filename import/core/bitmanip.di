/**
 * This module contains a collection of bit-level operations.
 *
 * Copyright: Copyright (c) 2005-2008, The D Runtime Project
 * License:   BSD Style, see LICENSE
 * Authors:   Walter Bright, Don Clugston, Sean Kelly
 */
module core.bitmanip;


version( D_DDoc )
{
    /**
     * Scans the bits in v starting with bit 0, looking
     * for the first set bit.
     * Returns:
     *  The bit number of the first bit set.
     *  The return value is undefined if v is zero.
     */
    int bsf( uint v );


    /**
     * Scans the bits in v from the most significant bit
     * to the least significant bit, looking
     * for the first set bit.
     * Returns:
     *  The bit number of the first bit set.
     *  The return value is undefined if v is zero.
     * Example:
     * ---
     * import bitmanip;
     *
     * int main()
     * {
     *     uint v;
     *     int x;
     *
     *     v = 0x21;
     *     x = bsf(v);
     *     printf("bsf(x%x) = %d\n", v, x);
     *     x = bsr(v);
     *     printf("bsr(x%x) = %d\n", v, x);
     *     return 0;
     * }
     * ---
     * Output:
     *  bsf(x21) = 0<br>
     *  bsr(x21) = 5
     */
    int bsr( uint v );


    /**
     * Tests the bit.
     */
    int bt( uint* p, uint bitnum );


    /**
     * Tests and complements the bit.
     */
    int btc( uint* p, uint bitnum );


    /**
     * Tests and resets (sets to 0) the bit.
     */
    int btr( uint* p, uint bitnum );


    /**
     * Tests and sets the bit.
     * Params:
     * p = a non-NULL pointer to an array of uints.
     * index = a bit number, starting with bit 0 of p[0],
     * and progressing. It addresses bits like the expression:
    ---
    p[index / (uint.sizeof*8)] & (1 << (index & ((uint.sizeof*8) - 1)))
    ---
     * Returns:
     *  A non-zero value if the bit was set, and a zero
     *  if it was clear.
     *
     * Example:
     * ---
    import bitmanip;

    int main()
    {
        uint array[2];

        array[0] = 2;
        array[1] = 0x100;

        printf("btc(array, 35) = %d\n", <b>btc</b>(array, 35));
        printf("array = [0]:x%x, [1]:x%x\n", array[0], array[1]);

        printf("btc(array, 35) = %d\n", <b>btc</b>(array, 35));
        printf("array = [0]:x%x, [1]:x%x\n", array[0], array[1]);

        printf("bts(array, 35) = %d\n", <b>bts</b>(array, 35));
        printf("array = [0]:x%x, [1]:x%x\n", array[0], array[1]);

        printf("btr(array, 35) = %d\n", <b>btr</b>(array, 35));
        printf("array = [0]:x%x, [1]:x%x\n", array[0], array[1]);

        printf("bt(array, 1) = %d\n", <b>bt</b>(array, 1));
        printf("array = [0]:x%x, [1]:x%x\n", array[0], array[1]);

        return 0;
    }
     * ---
     * Output:
    <pre>
    btc(array, 35) = 0
    array = [0]:x2, [1]:x108
    btc(array, 35) = -1
    array = [0]:x2, [1]:x100
    bts(array, 35) = 0
    array = [0]:x2, [1]:x108
    btr(array, 35) = -1
    array = [0]:x2, [1]:x100
    bt(array, 1) = -1
    array = [0]:x2, [1]:x100
    </pre>
     */
    int bts( uint* p, uint bitnum );


    /**
     * Swaps bytes in a 4 byte uint end-to-end, i.e. byte 0 becomes
     * byte 3, byte 1 becomes byte 2, byte 2 becomes byte 1, byte 3
     * becomes byte 0.
     */
    uint bswap( uint v );


    /**
     * Reads I/O port at port_address.
     */
    ubyte inp( uint port_address );


    /**
     * ditto
     */
    ushort inpw( uint port_address );


    /**
     * ditto
     */
    uint inpl( uint port_address );


    /**
     * Writes and returns value to I/O port at port_address.
     */
    ubyte outp( uint port_address, ubyte value );


    /**
     * ditto
     */
    ushort outpw( uint port_address, ushort value );


    /**
     * ditto
     */
    uint outpl( uint port_address, uint value );
}
else
{
    public import std.intrinsic;
}


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
