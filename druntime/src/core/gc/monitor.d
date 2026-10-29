/**
* Contains hooks to monitor garbage collector allocations and deallocations.
*
* Copyright: Copyright D Language Foundation 2026.
* License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
* Authors:   Mathias Lang
*/

module core.gc.monitor;

/**
 * Callback invoked after the GC allocated a block of memory.
 *
 * Treat this callback like you would a signal handler: do not
 * allocate, throw, or do any heavy lifting here.
 *
 * Params:
 *   ptr  = pointer to the beginning of the allocated block,
 *          as returned to the user
 *   size = the requested allocation size in bytes
 */
alias GCAllocMonitor = void function(void* ptr, size_t size) nothrow @nogc;

/**
 * Callback invoked when the GC deallocates a block of memory.
 *
 * Deallocation can happen through an explicit `core.memory.GC.free`,
 * or because the block was reclaimed by a collection.
 *
 * Treat this callback like you would a signal handler: do not
 * allocate, throw, or do any heavy lifting here.
 *
 * Params:
 *   ptr       = pointer to the beginning of the block being freed,
 *               as previously reported by the allocation monitor
 *   size      = size of the block in bytes; this is the GC's allocated
 *               block size, which may be larger than the requested size
 *               reported by the allocation monitor
 *   collected = true if the block was reclaimed by a collection,
 *               false if it was freed explicitly (e.g. `GC.free`)
 */
alias GCFreeMonitor = void function(void* ptr, size_t size, bool collected) nothrow @nogc;

/**
 * Register monitor callbacks for GC allocations and deallocations.
 *
 * The callbacks are invoked from inside the GC: the allocation monitor
 * runs with the GC lock held, and the free monitor may run while all
 * threads are suspended during a collection. Consequently a monitor
 * must be `nothrow @nogc`, must not allocate GC memory, and must not
 * call any GC function, directly or indirectly.
 *
 * Registration is not synchronized: it is expected to happen during
 * startup, before other threads are spawned and before druntime is
 * initialized, e.g. from a `pragma(crt_constructor)`. Allocations and
 * deallocations that happen before registration are not reported.
 *
 * Only the conservative GC (the default) currently reports to the
 * monitors; other GC implementations may not invoke the callbacks.
 *
 * Params:
 *   alloc = callback for allocations, or `null` to disable
 *   free  = callback for deallocations, or `null` to disable
 */
void setGCMonitor(GCAllocMonitor alloc, GCFreeMonitor free) nothrow @nogc
{
    allocMonitor = alloc;
    freeMonitor = free;
}

/// Monitors currently in effect; read by GC implementations.
package(core) __gshared GCAllocMonitor allocMonitor;
package(core) __gshared GCFreeMonitor freeMonitor;
