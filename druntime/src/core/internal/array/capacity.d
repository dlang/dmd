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

import core.attribute : weak;

// for now, all GC array functions are not exposed via core.memory.
extern (C)
{
    size_t gc_reserveArrayCapacity(void[] slice, size_t request, bool atomic) nothrow pure;
    bool gc_shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic) nothrow pure;
}


/**
Set the array capacity.

If the array capacity isn't currently large enough
to hold the requested capacity (in number of elements), then the array is
resized/reallocated to the appropriate size.

Pass in a requested capacity of 0 to get the current capacity.

Params:
    T = the type of the elements in the array (this should be unqualified)
    newcapacity = requested new capacity
    p = pointer to array to set. Its `length` is left unchanged.
    isshared = true if the underlying data is shared

Returns: the number of elements that can actually be stored once the resizing is done
*/
size_t _d_arraysetcapacityPureNothrow(T)(size_t newcapacity, void[]* p, bool isshared) pure nothrow @trusted
do
{
    alias PureNothrowType = size_t function(size_t, void[]*, bool) pure nothrow @trusted;
    return (cast(PureNothrowType) &_d_arraysetcapacity!T)(newcapacity, p, isshared);
}

size_t _d_arraysetcapacity(T)(size_t newcapacity, void[]* p, bool isshared) @trusted
in
{
    assert(!(*p).length || (*p).ptr);
}
do
{
    import core.exception : onOutOfMemoryError;
    import core.stdc.string : memcpy, memset;
    import core.internal.array.utils: __typeAttrs;
    import core.internal.lifetime : __doPostblit;

    import core.memory : GC;

    alias BlkAttr = GC.BlkAttr;

    auto size = T.sizeof;
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
    auto attrs = __typeAttrs!T((*p).ptr) | BlkAttr.APPENDABLE;

    // use this static enum to avoid recomputing TypeInfo for every call.
    static enum ti = typeid(T);
    auto ptr = GC.malloc(reqsize, attrs, ti);
    if (ptr is null)
        goto Loverflow;

    // copy the data over.
    // note that malloc will have initialized the data we did not request to 0.
    memcpy(ptr, (*p).ptr, datasize);

    // handle postblit
    __doPostblit!T(cast(T[])ptr[0 .. datasize]);

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


// Shrinking an array of simple values
@safe unittest
{
    int[] arr = new int[100];
    arr.length = 50;
    _d_arrayshrinkfit!int(arr);
    assert(arr.length == 50);
}


// Shrinking an array of structs with destructors
@safe unittest
{

    static struct DtorTest {
        static int counter = 0;
        ~this() { counter++; }
    }

    DtorTest[] arr = new DtorTest[10];
    DtorTest.counter = 0;

    arr.length = 5; // shrink manually
    _d_arrayshrinkfit!DtorTest(arr); // simulate shrinkfit, destroying 5 elements

    assert(arr.length == 5);
    assert(DtorTest.counter == 5); // verify 5 destructors ran
}


// Shrinking a shared array
@safe unittest
{
    shared(int)[] arr = new shared int[100];
    arr.length = 10;
    _d_arrayshrinkfit!(shared int)(cast(void[])arr);
    assert(arr.length == 10);
}


// Shrink array with no elements (ptr is null)
@safe unittest
{
    int[] arr;
    assert(arr.ptr is null);
    _d_arrayshrinkfit!int(arr); // should be a no-op
    assert(arr.length == 0);
}


// Shrinking an array of class references (destroyable via GC)
@safe unittest
{
    class C { int x = 5; }
    C[] arr = new C[10];
    foreach (ref c; arr)
        c = new C();

    arr.length = 3;
    _d_arrayshrinkfit!C(arr);
    assert(arr.length == 3);
    foreach (c; arr)
        assert(c !is null && c.x == 5);
}
