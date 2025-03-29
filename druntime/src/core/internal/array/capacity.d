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

// HACK: This is a workaround `pure` is faked
extern(C) bool gc_expandArrayUsed(void[] slice, size_t newUsed, bool atomic) pure nothrow;

size_t _d_arraysetlengthT(Tarr : T[], T)(
    return scope ref Tarr arr,
    size_t newlength
) @trusted
{
    import core.memory : GC;
    import core.internal.array.utils : __arrayAlloc;
    import core.stdc.string : memcpy, memset;
    import core.internal.traits : Unqual;
    import core.lifetime : emplace;

    alias U = Unqual!T;

    // Handle zero-length case early
    if (newlength == 0)
    {
        arr = Tarr.init;
        return 0;
    }

    size_t elemSize = U.sizeof;
    size_t oldSize = arr.length * elemSize;
    size_t newSize;
    bool overflow = false;

    static size_t mulu(size_t a, size_t b, ref bool overflow)
    {
        size_t result = a * b;
        overflow = (b != 0 && result / b != a);
        return result;
    }

    newSize = mulu(elemSize, newlength, overflow);
    if (overflow)
    {
        return 0; // Memory allocation would fail
    }

    void[] oldSlice = arr.ptr ? cast(void[]) arr : null;

    // Attempt in-place expansion first
    if (gc_expandArrayUsed(oldSlice, newSize, is(U == shared)))
    {
        auto p = cast(U*) oldSlice.ptr;
        auto newElements = p + arr.length;

        static if (is(T == immutable) || is(T == const))
        {
            foreach (i; 0 .. (newlength - arr.length))
            {
                emplace(&newElements[i], U.init);
            }
        }
        else
        {
            memset(newElements, 0, newSize - oldSize);
        }

        arr = cast(Tarr) p[0 .. newlength];
        return arr.length;
    }

    // Allocate new array if expansion fails
    void[] allocatedData = __arrayAlloc!(Tarr)(newSize);
    if (allocatedData.ptr is null)
    {
        return 0; // Out of memory
    }

    auto p = cast(U*) allocatedData.ptr;

    // Copy old data
    if (arr.ptr !is null)
    {
        memcpy(p, cast(const void*) arr.ptr, oldSize);
    }

    auto newElements = p + arr.length;

    static if (is(T == immutable) || is(T == const))
    {
        foreach (i; 0 .. (newlength - arr.length))
        {
            emplace(&newElements[i], U.init);
        }
    }
    else
    {
        memset(newElements, 0, newSize - oldSize);
    }

    arr = cast(Tarr) p[0 .. newlength];
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

    // Test with an int array
    int[] arr;
    _d_arraysetlengthT!(typeof(arr))(arr, 16);
    assert(arr.length == 16);
    foreach (int i; arr)
        assert(i == int.init);  // Elements should be initialized to 0 (default for int)

    // Test with a shared struct array
    shared S[] arr2;
    _d_arraysetlengthT!(typeof(arr2))(arr2, 16);
    assert(arr2.length == 16);
    foreach (s; arr2)
        assert(s == S.init);  // Ensure elements are initialized to the default (S.init)
}
