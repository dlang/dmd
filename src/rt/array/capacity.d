/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC rt/_array/_capacity.d)
*/
module rt.array.capacity;

// HACK:  This is a lie.  `_d_arraysetcapacity` is neither `nothrow` nor `pure`, but this lie is
// necessary for now to prevent breaking code.
private extern (C) size_t _d_arraysetcapacity(const TypeInfo ti, size_t newcapacity, void[]* arrptr) pure nothrow;

/**
(Property) Gets the current _capacity of a slice. The _capacity is the size
that the slice can grow to before the underlying array must be
reallocated or extended.

If an append must reallocate a slice with no possibility of extension, then
`0` is returned. This happens when the slice references a static array, or
if another slice references elements past the end of the current slice.

Note: The _capacity of a slice may be impacted by operations on other slices.
*/
@property size_t capacity(T)(T[] arr) pure nothrow @trusted
{
    return _d_arraysetcapacity(typeid(T[]), 0, cast(void[]*)&arr);
}

///
@safe unittest
{
    //Static array slice: no capacity
    int[4] sarray = [1, 2, 3, 4];
    int[]  slice  = sarray[];
    assert(sarray.capacity == 0);
    //Appending to slice will reallocate to a new array
    slice ~= 5;
    assert(slice.capacity >= 5);

    //Dynamic array slices
    int[] a = [1, 2, 3, 4];
    int[] b = a[1 .. $];
    int[] c = a[1 .. $ - 1];
    debug(SENTINEL) {} else // non-zero capacity very much depends on the array and GC implementation
    {
        assert(a.capacity != 0);
        assert(a.capacity == b.capacity + 1); //both a and b share the same tail
    }
    assert(c.capacity == 0);              //an append to c must relocate c.
}

/**
Reserves capacity for a slice. The capacity is the size
that the slice can grow to before the underlying array must be
reallocated or extended.

Returns: The new capacity of the array (which may be larger than
the requested capacity).
*/
size_t reserve(T)(ref T[] arr, size_t newcapacity) pure nothrow @trusted
{
    if (__ctfe)
        return newcapacity;
    else
        return _d_arraysetcapacity(typeid(T[]), newcapacity, cast(void[]*)&arr);
}

///
@safe unittest
{
    //Static array slice: no capacity. Reserve relocates.
    int[4] sarray = [1, 2, 3, 4];
    int[]  slice  = sarray[];
    auto u = slice.reserve(8);
    assert(u >= 8);
    assert(&sarray[0] !is &slice[0]);
    assert(slice.capacity == u);

    //Dynamic array slices
    int[] a = [1, 2, 3, 4];
    a.reserve(8); //prepare a for appending 4 more items
    auto p = &a[0];
    u = a.capacity;
    a ~= [5, 6, 7, 8];
    assert(p == &a[0]);      //a should not have been reallocated
    assert(u == a.capacity); //a should not have been extended
}

// https://issues.dlang.org/show_bug.cgi?id=12330, reserve() at CTFE time
@safe unittest
{
    int[] foo() {
        int[] result;
        auto a = result.reserve = 5;
        assert(a == 5);
        return result;
    }
    enum r = foo();
}

// Issue 6646: should be possible to use array.reserve from SafeD.
@safe unittest
{
    int[] a;
    a.reserve(10);
}

// HACK:  This is a lie.  `_d_arrayshrinkfit` is not `nothrow`, but this lie is necessary
// for now to prevent breaking code.
private extern (C) void _d_arrayshrinkfit(const TypeInfo ti, void[] arr) nothrow;

/**
Assume that it is safe to append to this array. Appends made to this array
after calling this function may append in place, even if the array was a
slice of a larger array to begin with.

Use this only when it is certain there are no elements in use beyond the
array in the memory block.  If there are, those elements will be
overwritten by appending to this array.

Warning: Calling this function, and then using references to data located after the
given array results in undefined behavior.

Returns:
  The input is returned.
*/
auto ref inout(T[]) assumeSafeAppend(T)(auto ref inout(T[]) arr) nothrow @system
{
    _d_arrayshrinkfit(typeid(T[]), *(cast(void[]*)&arr));
    return arr;
}

///
@system unittest
{
    int[] a = [1, 2, 3, 4];

    // Without assumeSafeAppend. Appending relocates.
    int[] b = a [0 .. 3];
    b ~= 5;
    assert(a.ptr != b.ptr);

    debug(SENTINEL) {} else
    {
        // With assumeSafeAppend. Appending overwrites.
        int[] c = a [0 .. 3];
        c.assumeSafeAppend() ~= 5;
        assert(a.ptr == c.ptr);
    }
}

@system unittest
{
    int[] arr;
    auto newcap = arr.reserve(2000);
    assert(newcap >= 2000);
    assert(newcap == arr.capacity);
    auto ptr = arr.ptr;
    foreach (i; 0..2000)
        arr ~= i;
    assert(ptr == arr.ptr);
    arr = arr[0..1];
    arr.assumeSafeAppend();
    arr ~= 5;
    assert(ptr == arr.ptr);
}

@system unittest
{
    int[] arr = [1, 2, 3];
    void foo(ref int[] i)
    {
        i ~= 5;
    }
    arr = arr[0 .. 2];
    foo(assumeSafeAppend(arr)); //pass by ref
    assert(arr[]==[1, 2, 5]);
    arr = arr[0 .. 1].assumeSafeAppend(); //pass by value
}

// https://issues.dlang.org/show_bug.cgi?id=10574
@system unittest
{
    int[] a;
    immutable(int[]) b;
    auto a2 = &assumeSafeAppend(a);
    auto b2 = &assumeSafeAppend(b);
    auto a3 = assumeSafeAppend(a[]);
    auto b3 = assumeSafeAppend(b[]);
    assert(is(typeof(*a2) == int[]));
    assert(is(typeof(*b2) == immutable(int[])));
    assert(is(typeof(a3) == int[]));
    assert(is(typeof(b3) == immutable(int[])));
}

// HACK: `nothrow` and `pure` is faked.
private extern (C) void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p) nothrow pure;
private extern (C) void[] _d_arraysetlengthiT(const TypeInfo ti, size_t newlength, void[]* p) nothrow pure;

// This wrapper is needed because a externDFunc cannot be cast()ed directly.
private void accumulate(string file, uint line, string funcname, string type, ulong sz) @nogc
{
    import core.internal.traits : externDFunc;

    alias func = externDFunc!("rt.profilegc.accumulate", void function(string file, uint line, string funcname, string type, ulong sz) @nogc);
    return func(file, line, funcname, type, sz);
}

/*
 * This template is needed because there need to be a `_d_arraysetlengthTTrace!Tarr` instance for every
 * `_d_arraysetlengthT!Tarr`. By wrapping both of these functions inside of this template we force the
 * compiler to create a instance of both function for every type that is used.
 */

/// Implementation of `_d_arraysetlengthT` and `_d_arraysetlengthTTrace`
template _d_arraysetlengthTImpl(Tarr : T[], T)
{
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
        pragma(inline, false);
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
            assert(0, "Cannot resize arrays if compiling without support for runtime type information!");
    }


    /**
    * TraceGC wrapper around $(REF _d_arraysetlengthT, rt,array,rt.array.capacity).
    * Bugs:
    *   The safety level of this function is faked. It shows itself as `@trusted pure nothrow` to not break existing code.
    */
    size_t _d_arraysetlengthTTrace(string file, int line, string funcname, return scope ref Tarr arr, size_t newlength) @trusted pure nothrow
    {
        version (D_TypeInfo)
        {
            pragma(inline, false);
            import core.memory : GC;

            auto accumulate = cast(void function(string file, uint line, string funcname, string type, ulong sz) @nogc nothrow pure)&accumulate;
            auto gcStats = cast(GC.Stats function() nothrow pure)&GC.stats;

            string name = Tarr.stringof;

            // FIXME: use rt.tracegc.accumulator when it is accessable in the future.
            version (tracegc)
            {
                import core.stdc.stdio;

                printf("%s file = '%.*s' line = %d function = '%.*s' type = %.*s\n",
                    __FUNCTION__.ptr,
                    file.length, file.ptr,
                    line,
                    funcname.length, funcname.ptr,
                    name.length, name.ptr
                );
            }

            ulong currentlyAllocated = gcStats().allocatedInCurrentThread;

            scope(exit)
            {
                ulong size = gcStats().allocatedInCurrentThread - currentlyAllocated;
                if (size > 0)
                    accumulate(file, line, funcname, name, size);
            }
            return _d_arraysetlengthT(arr, newlength);
        }
        else
            assert(0, "Cannot resize arrays if compiling without support for runtime type information!");
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
