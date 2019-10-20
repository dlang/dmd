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
    size_t length() const pure nothrow @nogc @safe
    {
        return len;
    }

    void length(size_t nlen) pure nothrow
    {
        immutable obytes = (len + 7) / 8;
        immutable nbytes = (nlen + 7) / 8;
        // bt*() access memory in size_t chunks, so round up.
        ptr = cast(size_t*)mem.xrealloc_noscan(ptr,
            (nbytes + (size_t.sizeof - 1)) & ~(size_t.sizeof - 1));
        if (nbytes > obytes)
            (cast(ubyte*)ptr)[obytes .. nbytes] = 0;
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

    @disable this(this);

    ~this() pure nothrow
    {
        mem.xfree(ptr);
    }

private:
    size_t len;
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
}


