/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/bitarray.d, root/_bitarray.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_array.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/bitarray.d
 */

module dmd.root.bitarray;

import core.stdc.string;

import dmd.root.rmem;

struct BitArray
{
nothrow:

    alias Chunk_t = size_t;
    enum ChunkSize = Chunk_t.sizeof;
    enum BitsPerChunk = ChunkSize * 8;

    size_t length() const pure nothrow @nogc @safe
    {
        return len;
    }

    void length(size_t nlen) pure nothrow
    {
        immutable ochunks = ( len + BitsPerChunk - 1) / BitsPerChunk;
        immutable nchunks = (nlen + BitsPerChunk - 1) / BitsPerChunk;
        if (ochunks != nchunks)
        {
            ptr = cast(size_t*)mem.xrealloc_noscan(ptr, nchunks * ChunkSize);
        }
        if (nchunks > ochunks)
           ptr[ochunks .. nchunks] = 0;
        if (nlen & (BitsPerChunk - 1))
           ptr[nchunks - 1] &= (cast(Chunk_t)1 << (nlen & (BitsPerChunk - 1))) - 1;
        len = nlen;
    }

    bool opIndex(size_t idx) const pure nothrow @nogc
    {
        import core.bitop : bt;

        assert(idx < length);
        return !!bt(ptr, idx);
    }

    void opIndexAssign(bool val, size_t idx) pure nothrow @nogc
    {
        import core.bitop : btc, bts;

        assert(idx < length);
        if (val)
            bts(ptr, idx);
        else
            btc(ptr, idx);
    }

    bool opEquals(const ref BitArray b) const
    {
        return len == b.len && memcmp(ptr, b.ptr, (len + BitsPerChunk - 1) / 8) == 0;
    }

    @disable this(this);

    ~this() pure nothrow
    {
        mem.xfree(ptr);
    }

private:
    size_t len;         // length in bits
    size_t *ptr;
}

unittest
{
    BitArray array;
    array.length = 20;
    assert(array[19] == 0);
    array[10] = 1;
    assert(array[10] == 1);
    array[10] = 0;
    assert(array[10] == 0);
    assert(array.length == 20);

    BitArray a,b;
    assert(a != array);
    a.length = 200;
    assert(a != array);
    a[100] = true;
    b.length = 200;
    b[100] = true;
    assert(a == b);
    a.length = 300;
    b.length = 300;
    assert(a == b);
    b[299] = true;
    assert(a != b);
}


