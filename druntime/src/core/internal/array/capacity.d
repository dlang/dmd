/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_capacity.d)
*/
module core.internal.array.capacity;

/*
 * Fully templated implementation of `_d_arraysetlengthT`, removing reliance on `TypeInfo`.
 * The old `_d_arraysetlengthT` and `_d_arraysetlengthiT` functions have been removed.
 */

/**
 * Resize a dynamic array by setting the `.length` property.
 *
 * Newly created elements are initialized to their default value.
 *
 * This function is **now fully templated**, eliminating the need for TypeInfo-based
 * `_d_arraysetlengthT` and `_d_arraysetlengthiT`, while efficiently handling both
 * zero-initialized and custom-initialized types.
 *
 * ---
 * ## Example Usage:
 * ```d
 * void main()
 * {
 *     int[] a = [1, 2];
 *     a.length = 3; // gets lowered to `_d_arraysetlengthT!(int[])(a, 3)`
 * }
 * ```
 * ---
 *
 * - Uses a **templated approach** to minimize `TypeInfo` dependencies.
 * - Follows `_d_newarrayU` for allocation and initialization.
 * - Handles memory allocation and resizing safely, ensuring correct initialization.
 */

/// Complete templated implementation of `_d_arraysetlengthT` and its GC profiling variant `_d_arraysetlengthTTrace`

size_t _d_arraysetlengthT(Tarr : T[], T)(
    return scope ref Tarr arr,
    size_t newlength,
    string file = __FILE__,
    int line = __LINE__,
    string func = __FUNCTION__
) @trusted
{
    import core.lifetime : emplace;
    import core.internal.array.utils : __arrayAlloc;
    import core.stdc.string : memcpy, memmove;
    import core.internal.traits : Unqual;

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

    static size_t mulu(size_t a, size_t b, ref bool overflow)
    {
        size_t result = a * b;
        overflow = (b != 0 && result / b != a);
        return result;
    }

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
        memmove(allocatedData.ptr, arr.ptr, size);
    }
    else
    {
        memcpy(allocatedData.ptr, arr.ptr, size);
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
    alias _d_arraysetlengthTTrace = _d_HookTraceImpl!(Tarr, _d_arraysetlengthT, "Array length set");
}

@safe unittest
{
    struct S
    {
        float f = 1.0;
    }

    int[] arr;
    _d_arraysetlengthT!(typeof(arr).elementType)(arr, 16);
    assert(arr.length == 16);
    foreach (int i; arr)
        assert(i == int.init);

    shared S[] arr2;
    _d_arraysetlengthT!(typeof(arr2).elementType)(arr2, 16);
    assert(arr2.length == 16);
    foreach (s; arr2)
        assert(s == S.init);
}
