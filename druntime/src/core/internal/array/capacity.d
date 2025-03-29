/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_capacity.d)
*/
module core.internal.array.capacity;

/**
 * Resizes a dynamic array by modifying its `.length` property.
 *
 * Newly created elements are initialized to their default value.
 *
 * This function attempts in-place expansion using `gc_expandArrayUsed`. If that fails, 
 * it allocates a new array and copies existing elements.  
 *
 * Unlike the previous `_d_arraysetlengthT` in `rt/lifetime.d`, this version is 
 * fully templated and does not rely on `TypeInfo`, improving performance through 
 * compile-time specialization.
 *
 * ---
 * void main()
 * {
 *     int[] a = [1, 2];
 *     a.length = 3; // gets lowered to `_d_arraysetlengthT!(int[])(a, 3)`
 * }
 * ---
 *
 * Params:
 * - `arr` = The dynamic array whose `.length` is being updated.
 * - `newlength` = The new length to be assigned to the array.
 *
 * Returns:
 * - The new length of the array after resizing.
 *
 * Notes:
 * - If `newlength` is smaller than the current length, the array is shrunk.
 * - If `newlength` is greater, additional elements are initialized to `T.init`.
 * - If `gc_expandArrayUsed` succeeds, in-place expansion is used.
 * - If expansion fails, a new allocation is performed via `__arrayAlloc`.
 * - If allocation fails due to memory constraints, the function returns `0`.
 */

/// Complete templated implementation of `_d_arraysetlengthT` and its GC profiling variant `_d_arraysetlengthTTrace`

import core.checkedint : mulu;


import core.memory;
import core.stdc.string : memcpy, memset;
import core.internal.traits : Unqual;
import core.lifetime : emplace;
debug (PRINTF) import core.stdc.stdio : printf;
debug (VALGRIND) import etc.valgrind.valgrind;
alias BlkAttr = GC.BlkAttr;

// for now, all GC array functions are not exposed via core.memory.
extern(C) {
    void[] gc_getArrayUsed(void *ptr, bool atomic) nothrow;
    bool gc_expandArrayUsed(void[] slice, size_t newUsed, bool atomic) nothrow pure;
    size_t gc_reserveArrayCapacity(void[] slice, size_t request, bool atomic) nothrow;
    bool gc_shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic) nothrow;
}


// HACK: This is a workaround `pure` is faked
extern(C) bool gc_expandArrayUsed(void[] slice, size_t newUsed, bool atomic) pure nothrow;

size_t _d_arraysetlengthT(Tarr : T[], T)(
    return scope ref Tarr arr,
    size_t newlength,
    bool isMutable
) @trusted
{
    alias U = Unqual!T;

    debug (PRINTF) printf("[DEBUG] Resizing array: old=%zu, new=%zu\n", arr.length, newlength);

    static if (is(U == void))
    {
        arr = arr.ptr[0 .. newlength];
        debug (PRINTF) printf("[DEBUG] Final length (void case): %zu\n", arr.length);
        return newlength;
    }

    if (newlength == 0)
    {
        arr = Tarr.init;
        debug (PRINTF) printf("[DEBUG] Final length (zero case): %zu\n", arr.length);
        return 0;
    }

    size_t elemSize = U.sizeof;
    size_t oldSize = arr.length * elemSize;
    size_t newSize = elemSize * newlength;

    if (newSize / elemSize != newlength)
    {
        debug (PRINTF) printf("[ERROR] Overflow detected!\n");
        return 0;
    }

    void[] oldSlice = arr.ptr ? cast(void[]) arr : null;

    debug (PRINTF) printf("[DEBUG] Calling gc_expandArrayUsed (old ptr = %p, old length = %zu)\n",
                          arr.ptr, arr.length);

    if (oldSlice.ptr !is null && gc_expandArrayUsed(oldSlice, newSize, is(U == shared)))
    {
        debug (PRINTF) printf("[DEBUG] gc_expandArrayUsed succeeded. ptr = %p\n", oldSlice.ptr);

        auto p = cast(U*) oldSlice.ptr;
        auto newElements = p + arr.length;

        if (isMutable)
            memset(newElements, 0, newSize - oldSize);
        else static if (!is(U == void))
            foreach (i; 0 .. (newlength - arr.length))
                emplace(&newElements[i], U.init);

        arr = cast(Tarr) p[0 .. newlength];

        debug (PRINTF) printf("[DEBUG] Final length (gc_expandArrayUsed case): %zu\n", arr.length);
        return arr.length;
    }

    debug (PRINTF) printf("[DEBUG] gc_expandArrayUsed failed, using GC.malloc.\n");

    void* allocatedData = GC.malloc(newSize, GC.BlkAttr.NO_SCAN);
    if (allocatedData is null)
    {
        debug (PRINTF) printf("[ERROR] GC.malloc failed! Out of memory.\n");
        return 0;
    }

    auto p = cast(U*) allocatedData;
    debug (PRINTF) printf("[DEBUG] Allocated new memory at %p\n", p);

    if (arr.ptr !is null)
    {
        debug (PRINTF) printf("[DEBUG] Copying %zu bytes from old array.\n", oldSize);
        memcpy(p, cast(const void*) arr.ptr, oldSize);
    }

    auto newElements = p + arr.length;

    if (isMutable)
    {
        debug (PRINTF) printf("[DEBUG] Zero-initializing %zu bytes.\n", newSize - oldSize);
        memset(newElements, 0, newSize - oldSize);
    }
    else static if (!is(U == void))
    {
        debug (PRINTF) printf("[DEBUG] Emplacing %zu new elements.\n", newlength - arr.length);
        foreach (i; 0 .. (newlength - arr.length))
            emplace(&newElements[i], U.init);
    }

    arr = cast(Tarr) p[0 .. newlength];

    debug (PRINTF) printf("[DEBUG] Final length (GC.malloc case): %zu\n", arr.length);

    return arr.length;
}

version (D_ProfileGC)
{
    import core.internal.array.utils : _d_HookTraceImpl;

    /**
     * TraceGC wrapper around `_d_arraysetlengthT`.
     */
    alias _d_arraysetlengthTTrace = _d_HookTraceImpl!(Tarr, _d_arraysetlengthT, errorMessage);
}

@safe unittest
{
    struct S
    {
        float f = 1.0;
    }

    int[] arr;
    _d_arraysetlengthT(arr, 16, /* isMutable = */ true);
    assert(arr.length == 16);
    foreach (int i; arr)
        assert(i == int.init);

    shared S[] arr2;
    _d_arraysetlengthT(arr2, 16, /* isMutable = */ false);
    assert(arr2.length == 16);
    foreach (s; arr2)
        assert(s == S.init);
}
