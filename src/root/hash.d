/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:   Martin Nowak, Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC root/_hash.d)
 */

module ddmd.root.hash;

// MurmurHash2 was written by Austin Appleby, and is placed in the public
// domain. The author hereby disclaims copyright to this source code.
// https://sites.google.com/site/murmurhash/
uint calcHash(const(char)* data, size_t len) pure nothrow @nogc
{
    return calcHash(cast(const(ubyte)*)data, len);
}

uint calcHash(const(ubyte)* data, size_t len) pure nothrow @nogc
{
    // 'm' and 'r' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.
    enum uint m = 0x5bd1e995;
    enum int r = 24;
    // Initialize the hash to a 'random' value
    uint h = cast(uint)len;
    // Mix 4 bytes at a time into the hash
    while (len >= 4)
    {
        uint k = data[3] << 24 | data[2] << 16 | data[1] << 8 | data[0];
        k *= m;
        k ^= k >> r;
        h = (h * m) ^ (k * m);
        data += 4;
        len -= 4;
    }
    // Handle the last few bytes of the input array
    switch (len & 3)
    {
    case 3:
        h ^= data[2] << 16;
        goto case;
    case 2:
        h ^= data[1] << 8;
        goto case;
    case 1:
        h ^= data[0];
        h *= m;
        goto default;
    default:
        break;
    }
    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.
    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;
    return h;
}

// combine and mix two words (boost::hash_combine)
size_t mixHash(size_t h, size_t k)
{
    return h ^ (k + 0x9e3779b9 + (h << 6) + (h >> 2));
}
