/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2018-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/barrayf.d, backend/barray.d)
 * Documentation: https://dlang.org/phobos/dmd_backend_barray.html
 */

module dmd.backend.barray;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

nothrow:
@safe:

extern (C++): private void err_nomem();

/*************************************
 * A reusable array that ratchets up in capacity.
 */
struct Barray(T)
{
  @safe:

    /**********************
     * Set useable length of array.
     * Params:
     *  length = minimum number of elements in array
     */
    @trusted
    void setLength(size_t length)
    {
        static void enlarge(ref Barray barray, size_t length)
        {
            pragma(inline, false);
            auto newcap = (barray.capacity == 0) ? length : length + (length >> 1);
            barray.capacity = (newcap + 15) & ~15;
            T* p = cast(T*)realloc(barray.array.ptr, barray.capacity * T.sizeof);
            if (length && !p)
            {
                version (unittest)
                    assert(0);
                else
                    err_nomem();
            }
            barray.array = p[0 .. length];
        }

        if (length <= capacity)
            array = array.ptr[0 .. length];     // the fast path
        else
            enlarge(this, length);              // the slow path
    }

    /**********************
     * Resets length of array to 0 without
     * free'ing the array memory. This
     * sets it up for re-using the memory.
     */
    void reset()
    {
        setLength(0);
    }

    /*******************
     * Append element t to array.
     * Params:
     *  t = element to append
     */
    void push(T t)
    {
        const i = length;
        setLength(i + 1);
        array[i] = t;
    }

    /*******************
     * Append a 0-initialized element of T to array
     * Returns:
     *  pointer to appended element
     */
    @trusted
    T* push()
    {
        const i = length;
        setLength(i + 1);
        auto p = &array[i];
        memset(p, 0, T.sizeof);
        return p;
    }

    /**********************
     * Move the last element from the array into [i].
     * Reduce the array length by one.
     * Params:
     *  i = index of element to remove
     */
    void remove(size_t i)
    {
        const len = length - 1;
        if (i != len)
        {
            array[i] = array[len];
        }
        setLength(len);
    }

    /******************
     * Release all memory used.
     */
    @trusted
    void dtor()
    {
        free(array.ptr);
        array = null;
        capacity = 0;
    }

    alias array this;
    T[] array;

  private:
    size_t capacity;
}

unittest
{
    Barray!int a;
    a.setLength(10);
    assert(a.length == 10);
    a.setLength(4);
    assert(a.length == 4);
    foreach (i, ref v; a[])
        v = cast(int) i * 2;
    foreach (i, ref const v; a[])
        assert(v == i * 2);
    a.remove(3);
    assert(a.length == 3);
    a.push(50);
    a.remove(1);
    assert(a[1] == 50);
    a.dtor();
    assert(a.length == 0);
}

/**************************************
 * While Barray is good for reusing a Barray's previous allocation,
 * it doesn't work if an element of the Barray is itself a Barray.
 * Rarray aims to fix that.
 */

struct Rarray(T)
{
  @safe:

    /*******************
     * Append an uninitialized element of T to array.
     * This leaves allocations used by T intact.
     * Returns:
     *  pointer to appended element
     */
    T* push()
    {
        const i = length;
        ++length;
        if (i < barray.length)
        {
             return &barray.array[i];
        }
        return barray.push();
    }

    ref inout(T) opIndex(size_t i) inout nothrow pure @nogc
    {
        assert(i < length);
        return barray[i];
    }

    extern (D) inout(T)[] opSlice() inout nothrow pure @nogc
    {
        return barray[0 .. length];
    }

    extern (D) inout(T)[] opSlice(size_t a, size_t b) inout nothrow pure @nogc
    {
        assert(a <= b && b <= length);
        return barray[a .. b];
    }

    /**********************
     * Resets length of array to 0 without
     * free'ing the array memory. This
     * sets it up for re-using the memory.
     */
    void reset()
    {
        length = 0;
    }

    /******************
     * Release all memory used.
     */
    void dtor()
    {
        reset();
        barray.dtor();
    }

    alias opDollar = length;

    /* barray[0 .. barray.capacity] allocated length
     * barray[0 .. barray.length] initialized length
     * barray[0 .. length] in use length
     * 0 <= length <= barray.length <= barray.capacity
     */
    Barray!T barray;

    size_t length;      // <= barray.length
}
