/**
 * Scratch allocator for short-lived write-once buffers.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   xoxorwr
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/root/scratch.d, root/_scratch.d)
 */

module dmd.root.scratch;

import core.stdc.stdlib : malloc, free;
import core.stdc.string : memcpy;

/******************************************
 * A scratch allocator for transient buffers.
 *
 * Blocks are bump-allocated from chunks, but `free` returns them to
 * size-classed free lists for reuse, so ordinary alloc/free cycles behave as
 * expected. `reset()` releases everything at once by emptying the chunks and
 * reuse lists, which is what a long-lived consumer wants: transient stores
 * (e.g. an `OutBuffer` used for formatting or diagnostics) can be reclaimed
 * wholesale without tracking every allocation.
 *
 * Chunks are retained across `reset()` and reused, so memory is bounded by
 * peak usage rather than churning the C allocator.
 */
extern (D) struct ScratchAllocator
{
  nothrow:

    private:
        enum ChunkSize = 1024 * 1024;
        enum Align = 16;
        enum Bins = 24;

        /// Per-allocation header. Padded so payloads stay 16-byte aligned.
        struct Header
        {
            size_t size; // requested size
            size_t cap;  // aligned capacity
        }

        struct Chunk
        {
            ubyte* base;
            size_t used;
            size_t cap;
            Chunk* next;
        }

        /// A freed block stores the next free block in its own payload.
        struct FreeBlock
        {
            FreeBlock* next;
        }

        static assert(Header.sizeof == Align);
        static assert(FreeBlock.sizeof <= Align);

        Chunk* chunks;
        FreeBlock*[Bins] bins;

        static size_t alignUp(size_t n) pure @nogc
        {
            return (n + Align - 1) & ~(Align - 1);
        }

        /// Smallest bin whose size class can hold `cap`.
        static size_t binOf(size_t cap) pure @nogc
        {
            size_t b = 0;
            size_t s = Align;
            while (b + 1 < Bins && cap > s)
            {
                s <<= 1;
                ++b;
            }
            return b;
        }

        static Header* headerOf(void* p) pure @nogc
        {
            return cast(Header*)(cast(ubyte*) p - Header.sizeof);
        }

        Chunk* newChunk(size_t need)
        {
            const cap = need > ChunkSize ? need : ChunkSize;
            auto base = cast(ubyte*) malloc(cap);
            if (!base)
                return null;
            auto c = cast(Chunk*) malloc(Chunk.sizeof);
            if (!c)
            {
                free(base);
                return null;
            }
            c.base = base;
            c.used = 0;
            c.cap = cap;
            c.next = null;
            return c;
        }

    public:
        /// Allocate `n` bytes, or null on failure. Uninitialized.
        void* alloc(size_t n)
        {
            if (!n)
                return null;
            const cap = alignUp(n);
            foreach (b; binOf(cap) .. Bins)
            {
                FreeBlock* prev = null;
                for (auto f = bins[b]; f; prev = f, f = f.next)
                {
                    auto h = headerOf(cast(void*) f);
                    if (h.cap < cap)
                        continue;
                    if (prev)
                        prev.next = f.next;
                    else
                        bins[b] = f.next;
                    h.size = n;
                    return cast(void*) f;
                }
            }

            const total = Header.sizeof + cap;
            Chunk* c = null;
            for (auto it = chunks; it; it = it.next)
            {
                if (it.cap - it.used >= total)
                {
                    c = it;
                    break;
                }
            }
            if (!c)
            {
                c = newChunk(total);
                if (!c)
                    return null;
                c.next = chunks;
                chunks = c;
            }
            auto h = cast(Header*)(c.base + c.used);
            h.size = n;
            h.cap = cap;
            auto p = c.base + c.used + Header.sizeof;
            c.used += total;
            return p;
        }

        /// Grow (or shrink) `p` to `n` bytes. `p` must be null or from here.
        void* realloc(void* p, size_t n)
        {
            if (!p)
                return alloc(n);
            auto h = headerOf(p);
            if (alignUp(n) <= h.cap)
            {
                h.size = n;
                return p;
            }
            auto np = alloc(n);
            if (!np)
                return null;
            memcpy(np, p, h.size);
            free(p);
            return np;
        }

        /// Return `p` to its size class for reuse.
        void free(void* p)
        {
            if (!p)
                return;
            auto h = headerOf(p);
            auto f = cast(FreeBlock*) p;
            f.next = bins[binOf(h.cap)];
            bins[binOf(h.cap)] = f;
        }

        /// The number of bytes requested for `p` (0 if not from here).
        size_t sizeOf(void* p) pure @nogc
        {
            return p ? headerOf(p).size : 0;
        }

        /// Release every allocation. Chunks are retained for reuse.
        void reset()
        {
            for (auto c = chunks; c; c = c.next)
                c.used = 0;
            bins[] = null;
        }

        /// Total capacity currently held (diagnostic).
        size_t capacity() pure @nogc
        {
            size_t t;
            for (auto c = chunks; c; c = c.next)
                t += c.cap;
            return t;
        }
}

/// The per-thread pool.
ScratchAllocator scratch;

/// Release all scratch allocations made by the current thread.
void resetScratch() nothrow
{
    scratch.reset();
}

unittest
{
    scratch.reset();
    auto a = scratch.alloc(10);
    auto b = scratch.alloc(1000);
    assert(a !is b);
    assert(scratch.sizeOf(a) == 10 && scratch.sizeOf(b) == 1000);

    // freed blocks are reused
    scratch.free(a);
    auto c = scratch.alloc(8);
    assert(c is a);

    auto d = scratch.realloc(b, 100);
    assert(scratch.sizeOf(d) == 100);
    d = scratch.realloc(d, 5000);
    assert(scratch.sizeOf(d) == 5000);

    auto cap = scratch.capacity();
    assert(cap > 0);
    scratch.reset();
    assert(scratch.capacity() == cap); // chunks retained
}
