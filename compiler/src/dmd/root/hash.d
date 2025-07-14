/**
 * Hash functions for arbitrary binary data.
 *
 * Copyright: Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:   Martin Nowak, Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/root/hash.d, root/_hash.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_hash.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/root/hash.d
 */

module dmd.root.hash;

// Constants (compile-time)
private enum uint   M_MIX   = 0x5bd1e995u;
private enum int    R_SHIFT = 24;
private enum size_t GOLDEN_NUMBER  = 0x9e3779b9UL;

// MurmurHash2 was written by Austin Appleby, and is placed in the public
// domain. The author hereby disclaims copyright to this source code.
// https://github.com/aappleby/smhasher/
uint calcHash(scope const(char)[] data) @nogc nothrow pure @safe
{
    return calcHash(cast(const(ubyte)[])data);
}

/// ditto
uint calcHash(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    // 'M_MIX' and 'R_SHIFT' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.

    // Initialize the hash to a 'random' value
    uint h = cast(uint) data.length;
    
    // Mix 4 bytes at a time into the hash
    while (data.length >= 4)
    {
        uint k = data[3] << 24 | data[2] << 16 | data[1] << 8 | data[0];
        k *= M_MIX;
        k ^= k >> R_SHIFT;
        h = (h * M_MIX) ^ (k * M_MIX);
        data = data[4..$];
    }
    // Handle the last few bytes of the input array
    switch (data.length & 3)
    {
    case 3:
        h ^= data[2] << 16;
        goto case;
    case 2:
        h ^= data[1] << 8;
        goto case;
    case 1:
        h ^= data[0];
        h *= M_MIX;
        goto default;
    default:
        break;
    }
    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.
    h ^= h >> 13;
    h *= M_MIX;
    h ^= h >> 15;
    return h;
}

unittest
{
    char[10] data = "0123456789";
    assert(calcHash(data[0..$]) ==   439_272_720);
    assert(calcHash(data[1..$]) == 3_704_291_687);
    assert(calcHash(data[2..$]) == 2_125_368_748);
    assert(calcHash(data[3..$]) == 3_631_432_225);
}

// Golden-ratio constant for hashing 
static if (size_t.sizeof == 8)
    enum size_t golden = 0x9E37_79B9_7F4A_7C15UL; // 64-bit
else
    enum size_t golden = 0x9E37_79B9U;            // 32-bit


// combine and mix two words (boost::hash_combine)
size_t mixHash(size_t h, size_t k) @nogc nothrow pure @safe
{
    return h ^ (k + GOLDEN_NUMBER + (h << 6) + (h >> 2));
}

unittest
{
    // & uint.max because mixHash output is truncated on 32-bit targets
    assert((mixHash(0xDE00_1540, 0xF571_1A47) & uint.max) == 0x952D_FC10);
}
