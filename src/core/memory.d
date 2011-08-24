/**
 * The memory module provides an interface to the garbage collector and to
 * any other OS or API-level memory management facilities.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/_memory.d)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.memory;


private
{
    extern (C) void gc_init();
    extern (C) void gc_term();

    extern (C) void gc_enable();
    extern (C) void gc_disable();
    extern (C) void gc_collect();
    extern (C) void gc_minimize();

    extern (C) uint gc_getAttr( in void* p );
    extern (C) uint gc_setAttr( in void* p, uint a );
    extern (C) uint gc_clrAttr( in void* p, uint a );

    extern (C) void*    gc_malloc( size_t sz, uint ba = 0 );
    extern (C) void*    gc_calloc( size_t sz, uint ba = 0 );
    extern (C) BlkInfo_ gc_qalloc( size_t sz, uint ba = 0 );
    extern (C) void*    gc_realloc( void* p, size_t sz, uint ba = 0 );
    extern (C) size_t   gc_extend( void* p, size_t mx, size_t sz );
    extern (C) size_t   gc_reserve( size_t sz );
    extern (C) void     gc_free( void* p );

    extern (C) void*   gc_addrOf( in void* p );
    extern (C) size_t  gc_sizeOf( in void* p );

    struct BlkInfo_
    {
        void*  base;
        size_t size;
        uint   attr;
    }

    extern (C) BlkInfo_ gc_query( in void* p );

    extern (C) void gc_addRoot( in void* p );
    extern (C) void gc_addRange( in void* p, size_t sz );

    extern (C) void gc_removeRoot( in void* p );
    extern (C) void gc_removeRange( in void* p );
}


/**
 * This struct encapsulates all garbage collection functionality for the D
 * programming language.
 */
struct GC
{
    /**
     * Enables automatic garbage collection behavior if collections have
     * previously been suspended by a call to disable.  This function is
     * reentrant, and must be called once for every call to disable before
     * automatic collections are enabled.
     */
    static void enable()
    {
        gc_enable();
    }


    /**
     * Disables automatic garbage collections performed to minimize the
     * process footprint.  Collections may continue to occur in instances
     * where the implementation deems necessary for correct program behavior,
     * such as during an out of memory condition.  This function is reentrant,
     * but enable must be called once for each call to disable.
     */
    static void disable()
    {
        gc_disable();
    }


    /**
     * Begins a full collection.  While the meaning of this may change based
     * on the garbage collector implementation, typical behavior is to scan
     * all stack segments for roots, mark accessible memory blocks as alive,
     * and then to reclaim free space.  This action may need to suspend all
     * running threads for at least part of the collection process.
     */
    static void collect()
    {
        gc_collect();
    }

    /**
     * Indicates that the managed memory space be minimized by returning free
     * physical memory to the operating system.  The amount of free memory
     * returned depends on the allocator design and on program behavior.
     */
    static void minimize()
    {
        gc_minimize();
    }


    /**
     * Elements for a bit field representing memory block attributes.  These
     * are manipulated via the getAttr, setAttr, clrAttr functions.
     */
    enum BlkAttr : uint
    {
        FINALIZE    = 0b0000_0001, /// Finalize the data in this block on collect.
        NO_SCAN     = 0b0000_0010, /// Do not scan through this block on collect.
        NO_MOVE     = 0b0000_0100,  /// Do not move this memory block on collect.
        APPENDABLE  = 0b0000_1000, /// This block contains the info to allow appending.
        
        /**
        This block is guaranteed to have a pointer to its base while it's
        alive.  Interior pointers can be safely ignored.  This attribute
        is useful for eliminating false pointers in very large data structures
        and is only implemented for data structures at least a page in size.
        */
        NO_INTERIOR = 0b0001_0000  
                                   
    }


    /**
     * Contains aggregate information about a block of managed memory.  The
     * purpose of this struct is to support a more efficient query style in
     * instances where detailed information is needed.
     *
     * base = A pointer to the base of the block in question.
     * size = The size of the block, calculated from base.
     * attr = Attribute bits set on the memory block.
     */
    alias BlkInfo_ BlkInfo;


    /**
     * Returns a bit field representing all block attributes set for the memory
     * referenced by p.  If p references memory not originally allocated by
     * this garbage collector, points to the interior of a memory block, or if
     * p is null, zero will be returned.
     *
     * Params:
     *  p = A pointer to the root of a valid memory block or to null.
     *
     * Returns:
     *  A bit field containing any bits set for the memory block referenced by
     *  p or zero on error.
     */
    static uint getAttr( in void* p )
    {
        return gc_getAttr( p );
    }


    /**
     * Sets the specified bits for the memory references by p.  If p references
     * memory not originally allocated by this garbage collector, points to the
     * interior of a memory block, or if p is null, no action will be
     * performed.
     *
     * Params:
     *  p = A pointer to the root of a valid memory block or to null.
     *  a = A bit field containing any bits to set for this memory block.
     *
     *  The result of a call to getAttr after the specified bits have been
     *  set.
     */
    static uint setAttr( in void* p, uint a )
    {
        return gc_setAttr( p, a );
    }


    /**
     * Clears the specified bits for the memory references by p.  If p
     * references memory not originally allocated by this garbage collector,
     * points to the interior of a memory block, or if p is null, no action
     * will be performed.
     *
     * Params:
     *  p = A pointer to the root of a valid memory block or to null.
     *  a = A bit field containing any bits to clear for this memory block.
     *
     * Returns:
     *  The result of a call to getAttr after the specified bits have been
     *  cleared.
     */
    static uint clrAttr( in void* p, uint a )
    {
        return gc_clrAttr( p, a );
    }


    /**
     * Requests an aligned block of managed memory from the garbage collector.
     * This memory may be deleted at will with a call to free, or it may be
     * discarded and cleaned up automatically during a collection run.  If
     * allocation fails, this function will call onOutOfMemory which is
     * expected to throw an OutOfMemoryException.
     *
     * Params:
     *  sz = The desired allocation size in bytes.
     *  ba = A bitmask of the attributes to set on this block.
     *
     * Returns:
     *  A reference to the allocated memory or null if insufficient memory
     *  is available.
     *
     * Throws:
     *  OutOfMemoryException on allocation failure.
     */
    static void* malloc( size_t sz, uint ba = 0 )
    {
        return gc_malloc( sz, ba );
    }


    /**
     * Requests an aligned block of managed memory from the garbage collector.
     * This memory may be deleted at will with a call to free, or it may be
     * discarded and cleaned up automatically during a collection run.  If
     * allocation fails, this function will call onOutOfMemory which is
     * expected to throw an OutOfMemoryException.
     *
     * Params:
     *  sz = The desired allocation size in bytes.
     *  ba = A bitmask of the attributes to set on this block.
     *
     * Returns:
     *  Information regarding the allocated memory block or BlkInfo.init on
     *  error.
     *
     * Throws:
     *  OutOfMemoryException on allocation failure.
     */
    static BlkInfo qalloc( size_t sz, uint ba = 0 )
    {
        return gc_qalloc( sz, ba );
    }


    /**
     * Requests an aligned block of managed memory from the garbage collector,
     * which is initialized with all bits set to zero.  This memory may be
     * deleted at will with a call to free, or it may be discarded and cleaned
     * up automatically during a collection run.  If allocation fails, this
     * function will call onOutOfMemory which is expected to throw an
     * OutOfMemoryException.
     *
     * Params:
     *  sz = The desired allocation size in bytes.
     *  ba = A bitmask of the attributes to set on this block.
     *
     * Returns:
     *  A reference to the allocated memory or null if insufficient memory
     *  is available.
     *
     * Throws:
     *  OutOfMemoryException on allocation failure.
     */
    static void* calloc( size_t sz, uint ba = 0 )
    {
        return gc_calloc( sz, ba );
    }


    /**
     * If sz is zero, the memory referenced by p will be deallocated as if
     * by a call to free.  A new memory block of size sz will then be
     * allocated as if by a call to malloc, or the implementation may instead
     * resize the memory block in place.  The contents of the new memory block
     * will be the same as the contents of the old memory block, up to the
     * lesser of the new and old sizes.  Note that existing memory will only
     * be freed by realloc if sz is equal to zero.  The garbage collector is
     * otherwise expected to later reclaim the memory block if it is unused.
     * If allocation fails, this function will call onOutOfMemory which is
     * expected to throw an OutOfMemoryException.  If p references memory not
     * originally allocated by this garbage collector, or if it points to the
     * interior of a memory block, no action will be taken.  If ba is zero
     * (the default) and p references the head of a valid, known memory block
     * then any bits set on the current block will be set on the new block if a
     * reallocation is required.  If ba is not zero and p references the head
     * of a valid, known memory block then the bits in ba will replace those on
     * the current memory block and will also be set on the new block if a
     * reallocation is required.
     *
     * Params:
     *  p  = A pointer to the root of a valid memory block or to null.
     *  sz = The desired allocation size in bytes.
     *  ba = A bitmask of the attributes to set on this block.
     *
     * Returns:
     *  A reference to the allocated memory on success or null if sz is
     *  zero.  On failure, the original value of p is returned.
     *
     * Throws:
     *  OutOfMemoryException on allocation failure.
     */
    static void* realloc( void* p, size_t sz, uint ba = 0 )
    {
        return gc_realloc( p, sz, ba );
    }


    /**
     * Requests that the managed memory block referenced by p be extended in
     * place by at least mx bytes, with a desired extension of sz bytes.  If an
     * extension of the required size is not possible, if p references memory
     * not originally allocated by this garbage collector, or if p points to
     * the interior of a memory block, no action will be taken.
     *
     * Params:
     *  mx = The minimum extension size in bytes.
     *  sz = The  desired extension size in bytes.
     *
     * Returns:
     *  The size in bytes of the extended memory block referenced by p or zero
     *  if no extension occurred.
     */
    static size_t extend( void* p, size_t mx, size_t sz )
    {
        return gc_extend( p, mx, sz );
    }


    /**
     * Requests that at least sz bytes of memory be obtained from the operating
     * system and marked as free.
     *
     * Params:
     *  sz = The desired size in bytes.
     *
     * Returns:
     *  The actual number of bytes reserved or zero on error.
     */
    static size_t reserve( size_t sz )
    {
        return gc_reserve( sz );
    }


    /**
     * Deallocates the memory referenced by p.  If p is null, no action
     * occurs.  If p references memory not originally allocated by this
     * garbage collector, or if it points to the interior of a memory block,
     * no action will be taken.  The block will not be finalized regardless
     * of whether the FINALIZE attribute is set.  If finalization is desired,
     * use delete instead.
     *
     * Params:
     *  p = A pointer to the root of a valid memory block or to null.
     */
    static void free( void* p )
    {
        gc_free( p );
    }


    /**
     * Returns the base address of the memory block containing p.  This value
     * is useful to determine whether p is an interior pointer, and the result
     * may be passed to routines such as sizeOf which may otherwise fail.  If p
     * references memory not originally allocated by this garbage collector, if
     * p is null, or if the garbage collector does not support this operation,
     * null will be returned.
     *
     * Params:
     *  p = A pointer to the root or the interior of a valid memory block or to
     *      null.
     *
     * Returns:
     *  The base address of the memory block referenced by p or null on error.
     */
    static void* addrOf( in void* p )
    {
        return gc_addrOf( p );
    }


    /**
     * Returns the true size of the memory block referenced by p.  This value
     * represents the maximum number of bytes for which a call to realloc may
     * resize the existing block in place.  If p references memory not
     * originally allocated by this garbage collector, points to the interior
     * of a memory block, or if p is null, zero will be returned.
     *
     * Params:
     *  p = A pointer to the root of a valid memory block or to null.
     *
     * Returns:
     *  The size in bytes of the memory block referenced by p or zero on error.
     */
    static size_t sizeOf( in void* p )
    {
        return gc_sizeOf( p );
    }


    /**
     * Returns aggregate information about the memory block containing p.  If p
     * references memory not originally allocated by this garbage collector, if
     * p is null, or if the garbage collector does not support this operation,
     * BlkInfo.init will be returned.  Typically, support for this operation
     * is dependent on support for addrOf.
     *
     * Params:
     *  p = A pointer to the root or the interior of a valid memory block or to
     *      null.
     *
     * Returns:
     *  Information regarding the memory block referenced by p or BlkInfo.init
     *  on error.
     */
    static BlkInfo query( in void* p )
    {
        return gc_query( p );
    }


    /**
     * Adds the memory address referenced by p to an internal list of roots to
     * be scanned during a collection.  If p is null, no operation is
     * performed.
     *
     * Params:
     *  p = A pointer to a valid memory address or to null.
     */
    static void addRoot( in void* p )
    {
        gc_addRoot( p );
    }


    /**
     * Adds the memory block referenced by p and of size sz to an internal list
     * of ranges to be scanned during a collection.  If p is null, no operation
     * is performed.
     *
     * Params:
     *  p  = A pointer to a valid memory address or to null.
     *  sz = The size in bytes of the block to add.  If sz is zero then the
     *       no operation will occur.  If p is null then sz must be zero.
     */
    static void addRange( in void* p, size_t sz )
    {
        gc_addRange( p, sz );
    }


    /**
     * Removes the memory block referenced by p from an internal list of roots
     * to be scanned during a collection.  If p is null or does not represent
     * a value previously passed to add(void*) then no operation is performed.
     *
     *  p  = A pointer to a valid memory address or to null.
     */
    static void removeRoot( in void* p )
    {
        gc_removeRoot( p );
    }


    /**
     * Removes the memory block referenced by p from an internal list of ranges
     * to be scanned during a collection.  If p is null or does not represent
     * a value previously passed to add(void*, size_t) then no operation is
     * performed.
     *
     * Params:
     *  p  = A pointer to a valid memory address or to null.
     */
    static void removeRange( in void* p )
    {
        gc_removeRange( p );
    }
}
