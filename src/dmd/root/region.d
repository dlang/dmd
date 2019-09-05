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

/*****
 * Simple region storage allocator.
 */
struct Region
{
    void* head;         // beginning of first pool
    void* last;         // beginning of last pool
    void[] available;   // available to allocate

    enum ChunkSize = 4096 * 32;
    enum OverheadSize = 16;
    enum MaxAllocSize = ChunkSize - OverheadSize;

  nothrow:

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
            void* next = last ? *cast(void**)last : null;
            if (next)
            {   // Reuse next page
                last = next;
                available = (last + OverheadSize)[0 .. MaxAllocSize];
            }
            else
            {   // Allocate next page
                auto h = Mem.check(.malloc(ChunkSize));
                *cast(void**)h = null;
                if (!head)
                    last = cast(void*)&head;
                *cast(void**)last = h;
                last = h;
                available = (h + OverheadSize)[0 .. MaxAllocSize];
            }
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
        if (!head)
            return;

        version (all)
        {
            /* Keep the memory for next time
             */
            last = head;
            available = (last + OverheadSize)[0 .. MaxAllocSize];
        }
        else
        {
            /* Free the memory
             */
            void* next;
            for (auto h = head; h; h = next)
            {
                next = *cast(void**)h;
                memset(h, 0xFC, ChunkSize); // 0xFC is larger than TOK.max
                .free(h);
            }

            head = null;
            last = null;
            available = null;
        }
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
        if (!p)
            return false;

        for (auto h = head; h; h = *cast(void**)h)
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
        size_t size;
        for (auto h = head; h; h = *cast(void**)h)
        {
            size += ChunkSize;
        }
        return size;
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

    assert(reg.size() > 0 && reg.size() >= Region.ChunkSize);
    assert(!reg.contains(&reg));

    reg.release();
}
