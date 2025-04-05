/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_capacity.d)
*/
module core.internal.array.capacity;
import core.exception : onFinalizeError;

// HACK: `nothrow` and `pure` is faked.
private extern (C) void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p) nothrow pure;
private extern (C) void[] _d_arraysetlengthiT(const TypeInfo ti, size_t newlength, void[]* p) nothrow pure;

extern(C) {
    bool gc_shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic) nothrow;
    void[] gc_getArrayUsed(void *ptr, bool atomic) nothrow;

}

/**
Shrink the "allocated" length of an array to be the exact size of the array.

It doesn't matter what the current allocated length of the array is, the
user is telling the runtime that he knows what he is doing.

Params:
    ti = `TypeInfo` of array type
    arr = array to shrink. Its `.length` is element length, not byte length, despite `void` type
*/
void _d_arrayshrinkfit(T)(void[] arr) nothrow
{

    import core.internal.traits : hasElaborateDestructor;
    auto isshared = is(T == shared);
    debug(PRINTF) printf("_d_arrayshrinkfit, elemsize = %zd, arr.ptr = %p arr.length = %zd\n", ti.next.tsize, arr.ptr, arr.length);
    auto size = T.sizeof;                  // array element size
    auto reqsize = arr.length * size;

    auto curArr = gc_getArrayUsed(arr.ptr, isshared);
    if (curArr.ptr is null)
        // not a valid GC pointer
        return;

    // align the array.
    auto offset = arr.ptr - curArr.ptr;
    auto cursize = curArr.length - offset;
    if (cursize <= reqsize)
        // invalid situation, or no change.
        return;

    static if (is(T == struct) && hasElaborateDestructor!T)
    {
        try
        {
            finalize_array!T(arr.ptr + reqsize, cursize - reqsize);
        }
        catch (Exception e)
        {
            onFinalizeError(typeid(T), e);
        }
    }

    gc_shrinkArrayUsed(arr.ptr[0 .. reqsize], cursize, isshared);
}

void finalize_array(T)(void* p, size_t size)
{
    import object: destroy;

    // Due to the fact that the delete operator calls destructors
    // for arrays from the last element to the first, we maintain
    // compatibility here by doing the same.
    auto tsize = T.sizeof;
    for (auto curP = p + size - tsize; curP >= p; curP -= tsize)
    {
        // call destructor
        destroy(*cast(T*)curP);
    }
}





/*
 * This template is needed because there need to be a `_d_arraysetlengthTTrace!Tarr` instance for every
 * `_d_arraysetlengthT!Tarr`. By wrapping both of these functions inside of this template we force the
 * compiler to create a instance of both function for every type that is used.
 */

/// Implementation of `_d_arraysetlengthT` and `_d_arraysetlengthTTrace`
template _d_arraysetlengthTImpl(Tarr : T[], T)
{
    private enum errorMessage = "Cannot resize arrays if compiling without support for runtime type information!";

    /**
     * Resize dynamic array
     * Params:
     *  arr = the array that will be resized, taken as a reference
     *  newlength = new length of array
     * Returns:
     *  The new length of the array
     * Bugs:
     *   The safety level of this function is faked. It shows itself as `@trusted pure nothrow` to not break existing code.
     */
    size_t _d_arraysetlengthT(return scope ref Tarr arr, size_t newlength) @trusted pure nothrow
    {
        version (DigitalMars) pragma(inline, false);
        version (D_TypeInfo)
        {
            auto ti = typeid(Tarr);

            static if (__traits(isZeroInit, T))
                ._d_arraysetlengthT(ti, newlength, cast(void[]*)&arr);
            else
                ._d_arraysetlengthiT(ti, newlength, cast(void[]*)&arr);

            return arr.length;
        }
        else
            assert(0, errorMessage);
    }

    version (D_ProfileGC)
    {
        import core.internal.array.utils : _d_HookTraceImpl;

        /**
         * TraceGC wrapper around $(REF _d_arraysetlengthT, core,internal,array,core.internal.array.capacity).
         * Bugs:
         *  This function template was ported from a much older runtime hook that bypassed safety,
         *  purity, and throwabilty checks. To prevent breaking existing code, this function template
         *  is temporarily declared `@trusted pure nothrow` until the implementation can be brought up to modern D expectations.
         */
        alias _d_arraysetlengthTTrace = _d_HookTraceImpl!(Tarr, _d_arraysetlengthT, errorMessage);
    }
}

@safe unittest
{
    struct S
    {
        float f = 1.0;
    }

    int[] arr;
    _d_arraysetlengthTImpl!(typeof(arr))._d_arraysetlengthT(arr, 16);
    assert(arr.length == 16);
    foreach (int i; arr)
        assert(i == int.init);

    shared S[] arr2;
    _d_arraysetlengthTImpl!(typeof(arr2))._d_arraysetlengthT(arr2, 16);
    assert(arr2.length == 16);
    foreach (s; arr2)
        assert(s == S.init);
}

