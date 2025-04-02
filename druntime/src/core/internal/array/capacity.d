/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_capacity.d)
*/
module core.internal.array.capacity;

import core.attribute : weak;

// for now, all GC array functions are not exposed via core.memory.
extern (C)
{
    size_t gc_reserveArrayCapacity(void[] slice, size_t request, bool atomic) nothrow pure;
    bool gc_shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic) nothrow pure;
}


private uint __typeAttrs(T)(void *copyAttrsFrom = null)
{
    import core.internal.traits : hasElaborateDestructor, hasIndirections;
    import core.memory : GC;

    alias BlkAttr = GC.BlkAttr;

    if (copyAttrsFrom)
    {
        // try to copy attrs from the given block
        auto info = GC.query(copyAttrsFrom);
        if (info.base)
            return info.attr;
    }

    uint attrs = 0;
    static if (hasIndirections!T)
        attrs |= BlkAttr.NO_SCAN;

    static if (hasElaborateDestructor!T)
        attrs |= BlkAttr.FINALIZE;

    return attrs;
}

private void __doPostblit(T)(T[] arr)
{
    // infer static postblit type, run postblit if any
    static if (__traits(hasPostblit, T))
    {
        static if (__traits(isStaticArray, T) && is(T : E[], E))
            __doPostblit(cast(E[]) arr);
        else static if (!is(typeof(arr[0].__xpostblit())) && is(immutable T == immutable U, U))
            foreach (ref elem; (() @trusted => cast(U[]) arr)())
                elem.__xpostblit();
        else
            foreach (ref elem; arr)
                elem.__xpostblit();
    }
}

/**
Set the array capacity.

If the array capacity isn't currently large enough
to hold the requested capacity (in number of elements), then the array is
resized/reallocated to the appropriate size.

Pass in a requested capacity of 0 to get the current capacity.

Params:
    ti = type info of element type
    newcapacity = requested new capacity
    p = pointer to array to set. Its `length` is left unchanged.

Returns: the number of elements that can actually be stored once the resizing is done
*/

size_t _d_arraysetcapacity(T)(size_t newcapacity, void[]* p) @weak @trusted
in
{
    assert(!(*p).length || (*p).ptr);
}
do
{
    import core.exception : onOutOfMemoryError;
    import core.internal.traits : Unqual;
    import core.stdc.string : memcpy, memset;

    import core.memory : GC;

    alias BlkAttr = GC.BlkAttr;

    const ti = typeid(T[]);
    auto isshared = typeid(ti) is typeid(TypeInfo_Shared);
    alias Unqual_T = Unqual!(T);
    auto tinext = typeid(Unqual_T);
    auto size = tinext.tsize;
    version (D_InlineAsm_X86)
    {
        size_t reqsize = void;

        asm nothrow pure
        {
            mov EAX, newcapacity;
            mul EAX, size;
            mov reqsize, EAX;
            jnc Lcontinue;
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        size_t reqsize = void;

        asm nothrow pure
        {
            mov RAX, newcapacity;
            mul RAX, size;
            mov reqsize, RAX;
            jnc Lcontinue;
        }
    }
    else
    {
        bool overflow = false;
        size_t reqsize = mulu(size, newcapacity, overflow);
        if (!overflow)
            goto Lcontinue;
    }
Loverflow:
    onOutOfMemoryError();
    assert(0);
Lcontinue:

    // step 1, see if we can ensure the capacity is valid in-place
    auto datasize = (*p).length * size;
    auto curCapacity = gc_reserveArrayCapacity((*p).ptr[0 .. datasize], reqsize, isshared);
    if (curCapacity != 0) // in-place worked!
        return curCapacity / size;

    if (reqsize <= datasize) // requested size is less than array size, the current array satisfies
        // the request. But this is not an appendable GC array, so return 0.
        return 0;

    // step 2, if reserving in-place doesn't work, allocate a new array with at
    // least the requested allocated size.
    auto attrs = __typeAttrs!Unqual_T((*p).ptr) | BlkAttr.APPENDABLE;
    auto ptr = GC.malloc(reqsize, attrs, tinext);
    if (ptr is null)
        goto Loverflow;

    // copy the data over.
    // note that malloc will have initialized the data we did not request to 0.
    memcpy(ptr, (*p).ptr, datasize);

    // handle postblit
    auto ptr_t = cast(Unqual_T*)ptr;
    __doPostblit!Unqual_T(ptr_t[0 .. (*p).length]);

    if (!(attrs & BlkAttr.NO_SCAN))
    {
        // need to memset the newly requested data, except for the data that
        // malloc returned that we didn't request.
        void* endptr = ptr + reqsize;
        void* begptr = ptr + datasize;

        // sanity check
        assert(endptr >= begptr);
        memset(begptr, 0, endptr - begptr);
    }

    *p = ptr[0 .. (*p).length];

    // set up the correct length. Note that we need to do this here, because
    // the GC malloc will automatically set the used size to what we requested.
    gc_shrinkArrayUsed(ptr[0 .. datasize], reqsize, isshared);

    curCapacity = gc_reserveArrayCapacity(ptr[0 .. datasize], 0, isshared);
    assert(curCapacity);
    return curCapacity / size;
}

// HACK: `nothrow` and `pure` is faked.
private extern (C) void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p) nothrow pure;
private extern (C) void[] _d_arraysetlengthiT(const TypeInfo ti, size_t newlength, void[]* p) nothrow pure;

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
