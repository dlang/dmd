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

size_t _d_arraysetlengthT(Tarr : T[], T)(ref Tarr arr, size_t newlength)  @trusted
{
    import core.lifetime : emplace;
    import core.internal.array.utils : __arrayAlloc;
    import object : TypeInfo;
    import core.stdc.string : memset;
    import core.stdc.string : memcpy;
    import core.internal.traits : Unqual; // To remove immutability

    if (newlength == 0)
    {
        arr = Tarr.init;
        return 0;
    }

    // **Handle Immutable Arrays**  
    static if (is(T == immutable))
    {
        if (newlength <= arr.length)
        {
            arr = arr[0 .. newlength];  // ✅ Just slice it, no modification
            return arr.length;
        }

        // **Expanding Immutable Array (Requires New Memory)**
        auto tempArr = new Unqual!T[newlength];  // Mutable array of unqualified T

        // **Copy Old Elements (Only if `arr` isn't empty)**
        if (arr.ptr !is null)
        {
            size_t size = arr.length * T.sizeof;
            memcpy(tempArr.ptr, arr.ptr, size);
        }

        // **Initialize New Elements (Only if T is mutable)**
        static if (!is(T == immutable))
        {
            foreach (i; arr.length .. newlength)
            {
                tempArr[i] = Unqual!T.init;
            }
        }

        // **Cast Back to Immutable Array**
        arr = cast(Tarr) tempArr;
        return arr.length;
    }

    // **Handle Shrinking for Mutable Arrays**
    if (newlength <= arr.length)
    {
        arr = arr[0 .. newlength];  // ✅ Shrinking is always safe
        return arr.length;
    }

    // **Handle Expanding Mutable Arrays**
    size_t sizeelem = T.sizeof;
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
        return 0; // Fail safely in `nothrow` context
    }

    if (arr.ptr is null)
    {
        assert(arr.length == 0);
        
        // Allocate memory
        void[] allocatedData = __arrayAlloc!(Tarr)(sizeelem * newlength);
        if (allocatedData.length == 0)
        {
            return 0;
        }

        static if (!is(T == void) && !is(T == immutable))
        {
            auto p = cast(T*) allocatedData.ptr;
            foreach (i; 0 .. newlength)
            {
                p[i] = T.init;
            }
        }

        arr = (cast(T*) allocatedData.ptr)[0 .. newlength]; 
        return arr.length;
    }

    size_t size = arr.length * sizeelem;
    void* oldData = cast(void*) arr.ptr;

    // Allocate new memory
    void[] allocatedData = __arrayAlloc!(Tarr)(sizeelem * newlength);
    if (allocatedData.length == 0)
    {
        return 0;
    }

    // **Copy Old Elements**
    memcpy(allocatedData.ptr, oldData, size);
    
    // **Initialize New Elements (Only for Non-Void & Mutable Types)**
    static if (!is(T == void) && !is(T == immutable))
    {
        auto p = (cast(T*) allocatedData.ptr) + arr.length;
        foreach (i; 0 .. (newlength - arr.length))
        {
            p[i] = T.init;
        }
    }

    arr = (cast(T*) allocatedData.ptr)[0 .. newlength];
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
