/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_capacity.d)
*/
module core.internal.array.capacity;

import core.checkedint : mulu;
import core.lifetime : emplace;
import core.internal.array.utils : __arrayAlloc;
import core.stdc.string : memcpy, memmove;
import core.internal.traits : Unqual;

/**
 * Resize a dynamic array by setting its `.length` property.
 *
 * Newly created elements are initialized to their default value.
 *
 * This function supports both mutable and immutable/const arrays:
 * - For `immutable` and `const` arrays, a new array is allocated.
 * - For `mutable` arrays, the existing memory is expanded or reallocated.
 *
 * ---
 * Example:
 * ```
 * void main()
 * {
 *     int[] a = [1, 2];
 *     a.length = 3; // gets lowered to `_d_arraysetlengthT!(int[], int)(a, 3)`
 * }
 * ```
 * ---
 *
 * Params:
 * - `arr`        = Reference to the array being resized.
 * - `newlength`  = New length to set for the array.
 *
 * Returns: The updated array with the new length.
 *
 * Notes:
 * - Elements are initialized using `emplace` when necessary.
 * - Uses `__arrayAlloc` for memory allocation.
 * - Ensures proper handling of `immutable` and `const` types.
 */

/// Complete templated implementation of `_d_arraysetlengthT` and its GC profiling variant `_d_arraysetlengthTTrace`

size_t _d_arraysetlengthT(Tarr : T[], T)(
    return scope ref Tarr arr,
    size_t newlength,
) @trusted
{

    alias U = Unqual!T; // Ensure non-inout type

    if (newlength == 0)
    {
        arr = Tarr.init;
        return 0;
    }

    static if (is(T == immutable) || is(T == const))
    {
        // Shrink case
        if (newlength <= arr.length)
        {
            arr = arr[0 .. newlength];
            return arr.length;
        }

        // Allocate new array for immutable/const
        auto tempArr = new U[newlength];

        // Copy existing elements
        if (arr.ptr !is null)
        {
            memcpy(cast(void*) tempArr.ptr, arr.ptr, arr.length * U.sizeof);
        }

        arr = cast(Tarr) tempArr;
        return arr.length;
    }

    // Mutable array case
    if (newlength <= arr.length)
    {
        arr = arr[0 .. newlength];
        return arr.length;
    }

    // Expand mutable array
    size_t sizeelem = U.sizeof;
    size_t newsize;
    bool overflow = false;

    newsize = mulu(sizeelem, newlength, overflow);
    if (overflow)
    {
        return 0;
    }

    if (arr.ptr is null)
    {
        assert(arr.length == 0);
        void[] allocatedData = __arrayAlloc!(Tarr)(sizeelem * newlength);
        if (allocatedData.length == 0)
        {
            return 0;
        }

        static if (!is(T == void) && !is(T == immutable) && !is(T == const))
        {
            auto p = cast(U*) allocatedData.ptr;
            foreach (i; 0 .. newlength)
            {
                emplace(&p[i], U.init);
            }
        }

        arr = cast(Tarr) (cast(U*) allocatedData.ptr)[0 .. newlength];
        return arr.length;
    }

    size_t size = arr.length * sizeelem;
    void[] allocatedData = __arrayAlloc!(Tarr)(sizeelem * newlength);
    if (allocatedData.length == 0)
    {
        return 0;
    }

    if (arr.ptr == allocatedData.ptr)
    {
        memmove(allocatedData.ptr, cast(const(void)*) arr.ptr, size);
    }
    else
    {
        memcpy(allocatedData.ptr, cast(const(void)*) arr.ptr, size);
    }

    static if (!is(T == void) && !is(T == immutable) && !is(T == const))
    {
        auto p = (cast(U*) allocatedData.ptr) + arr.length;
        foreach (i; 0 .. (newlength - arr.length))
        {
            emplace(&p[i], U.init);
        }
    }

    arr = cast(Tarr) (cast(U*) allocatedData.ptr)[0 .. newlength];
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
