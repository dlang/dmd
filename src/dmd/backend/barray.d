/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2018 by The D Language Foundation, All Rights Reserved
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

extern (C++): void err_nomem();

/*************************************
 * A reusable array that ratchets up in capacity.
 */
struct Barray(T)
{
    /**********************
     * Set useable length of array.
     * Params:
     *  length = minimum number of elements in array
     */
    void setLength(size_t length)
    {
        if (capacity < length)
        {
            if (capacity == 0)
                capacity = length;
            else
                capacity = length + (length >> 1);
            capacity = (capacity + 15) & ~15;
            T* p = cast(T*)realloc(array.ptr, capacity * T.sizeof);
            if (length && !p)
            {
                version (unittest)
                    assert(0);
                else
                    err_nomem();
            }
            array = p[0 .. length];
        }
        else
            array = array.ptr[0 .. length];
    }

    /******************
     * Release all memory used.
     */
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
        v = i * 2;
    foreach (i, ref const v; a[])
        assert(v == i * 2);
    a.dtor();
    assert(a.length == 0);
}
