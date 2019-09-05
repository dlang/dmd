/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Region storage allocator implementation.
 *
 * Copyright:   Copyright (C) 2019-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/region.d, root/_region.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_region.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/region.d
 */

module dmd.root.region;

import core.stdc.string;
import core.stdc.stdlib;

import dmd.root.rmem;
import dmd.root.array;

/*****
 * Simple region storage allocator.
 */
struct Region
{
  nothrow:
  private:

    Array!(void*) array; // array of chunks
    int used;            // number of chunks used in array[]
    void[] available;    // slice of chunk that's available to allocate

    enum ChunkSize = 4096 * 1024;
    enum MaxAllocSize = ChunkSize;

  public:

    /******
     * Allocate nbytes. Aborts on failure.
     * Params:
     *  nbytes = number of bytes to allocate, can be 0, must be <= than MaxAllocSize
     * Returns:
     *  allocated data, null for nbytes==0
     */
    void* malloc(size_t nbytes)
    {
        if (!nbytes)
            return null;

        nbytes = (nbytes + 15) & ~15;
        if (nbytes > available.length)
        {
            assert(nbytes <= MaxAllocSize);
            if (used == array.length)
            {
                auto h = Mem.check(.malloc(ChunkSize));
                array.push(h);
            }

            available = array[used][0 .. MaxAllocSize];
            ++used;
        }

        auto p = available.ptr;
        available = (p + nbytes)[0 .. available.length - nbytes];
        return p;
    }

    /********************
     * Release all the memory in this pool.
     */
    void release()
    {
        used = 0;
        available = null;
    }

    /****************************
     * If pointer points into Region.
     * Params:
     *  p = pointer to check
     * Returns:
     *  true if it points into the region
     */
    bool contains(void* p)
    {
        foreach (h; array[0 .. used])
        {
            if (h <= p && p < h + ChunkSize)
                return true;
        }
        return false;
    }

    /*********************
     * Returns: size of Region
     */
    size_t size()
    {
        return used * MaxAllocSize - available.length;
    }
}


unittest
{
    Region reg;
    void* p = reg.malloc(0);
    assert(p == null);
    assert(!reg.contains(p));

    p = reg.malloc(100);
    assert(p !is null);
    assert(reg.contains(p));
    memset(p, 0, 100);

    p = reg.malloc(100);
    assert(p !is null);
    assert(reg.contains(p));
    memset(p, 0, 100);

    assert(reg.size() > 0);
    assert(!reg.contains(&reg));

    reg.release();
}
