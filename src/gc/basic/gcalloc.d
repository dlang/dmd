/**
 * This module contains allocation functions for the garbage collector.
 *
 * Copyright: Copyright (C) 2005-2006 Digital Mars, www.digitalmars.com.
 *            All rights reserved.
 * License:
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 * Authors:   Walter Bright, David Friedman, Sean Kelly
 */

module gc.gcalloc;


version (Windows)
{
    private import core.sys.windows.windows;

    alias int pthread_t;

    pthread_t pthread_self()
    {
        return cast(pthread_t) GetCurrentThreadId();
    }

    //version = GC_Use_Alloc_Win32;
}
else version (Posix)
{
    private import core.sys.posix.sys.mman;
    private import core.stdc.stdlib;

    //version = GC_Use_Alloc_MMap;
}
else
{
    private import core.stdc.stdlib;

    //version = GC_Use_Alloc_Malloc;
}

/+
static if(is(typeof(VirtualAlloc)))
    version = GC_Use_Alloc_Win32;
else static if (is(typeof(mmap)))
    version = GC_Use_Alloc_MMap;
else static if (is(typeof(valloc)))
    version = GC_Use_Alloc_Valloc;
else static if (is(typeof(malloc)))
    version = GC_Use_Alloc_Malloc;
else static assert(false, "No supported allocation methods available.");
+/

static if (is(typeof(VirtualAlloc))) // version (GC_Use_Alloc_Win32)
{
    /**
     * Map memory.
     */
    void *os_mem_map(size_t nbytes)
    {
        return VirtualAlloc(null, nbytes, MEM_RESERVE, PAGE_READWRITE);
    }


    /**
     * Commit memory.
     * Returns:
     *      0       success
     *      !=0     failure
     */
    int os_mem_commit(void *base, size_t offset, size_t nbytes)
    {   void *p;

        p = VirtualAlloc(base + offset, nbytes, MEM_COMMIT, PAGE_READWRITE);
    return cast(int)(p is null);
    }


    /**
     * Decommit memory.
     * Returns:
     *      0       success
     *      !=0     failure
     */
    int os_mem_decommit(void *base, size_t offset, size_t nbytes)
    {
    return cast(int)(VirtualFree(base + offset, nbytes, MEM_DECOMMIT) == 0);
    }


    /**
     * Unmap memory allocated with os_mem_map().
     * Memory must have already been decommitted.
     * Returns:
     *      0       success
     *      !=0     failure
     */
    int os_mem_unmap(void *base, size_t nbytes)
    {
        return cast(int)(VirtualFree(base, 0, MEM_RELEASE) == 0);
    }
}
else static if (is(typeof(mmap)))  // else version (GC_Use_Alloc_MMap)
{
    void *os_mem_map(size_t nbytes)
    {   void *p;

        p = mmap(null, nbytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
        return (p == MAP_FAILED) ? null : p;
    }


    int os_mem_commit(void *base, size_t offset, size_t nbytes)
    {
        return 0;
    }


    int os_mem_decommit(void *base, size_t offset, size_t nbytes)
    {
        return 0;
    }


    int os_mem_unmap(void *base, size_t nbytes)
    {
        return munmap(base, nbytes);
    }
}
else static if (is(typeof(valloc))) // else version (GC_Use_Alloc_Valloc)
{
    void *os_mem_map(size_t nbytes)
    {
        return valloc(nbytes);
    }


    int os_mem_commit(void *base, size_t offset, size_t nbytes)
    {
        return 0;
    }


    int os_mem_decommit(void *base, size_t offset, size_t nbytes)
    {
        return 0;
    }


    int os_mem_unmap(void *base, size_t nbytes)
    {
        free(base);
        return 0;
    }
}
else static if (is(typeof(malloc))) // else version (GC_Use_Alloc_Malloc)
{
    // NOTE: This assumes malloc granularity is at least (void*).sizeof.  If
    //       (req_size + PAGESIZE) is allocated, and the pointer is rounded up
    //       to PAGESIZE alignment, there will be space for a void* at the end
    //       after PAGESIZE bytes used by the GC.


    private import gcx : PAGESIZE;


    const size_t PAGE_MASK = PAGESIZE - 1;


    void *os_mem_map(size_t nbytes)
    {   byte *p, q;
        p = cast(byte *) malloc(nbytes + PAGESIZE);
        q = p + ((PAGESIZE - ((cast(size_t) p & PAGE_MASK))) & PAGE_MASK);
        * cast(void**)(q + nbytes) = p;
        return q;
    }


    int os_mem_commit(void *base, size_t offset, size_t nbytes)
    {
        return 0;
    }


    int os_mem_decommit(void *base, size_t offset, size_t nbytes)
    {
        return 0;
    }


    int os_mem_unmap(void *base, size_t nbytes)
    {
        free( *cast(void**)( cast(byte*) base + nbytes ) );
        return 0;
    }
}
else
{
    static assert(false, "No supported allocation methods available.");
}
