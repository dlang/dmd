/**
 This module contains support for controlling dynamic arrays' capacity

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
