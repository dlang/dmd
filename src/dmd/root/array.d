/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/array.d, root/_array.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_array.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/array.d
 */

module dmd.root.array;

import core.stdc.string;

import dmd.root.rmem;

extern (C++) struct Array(T)
{
    size_t length;
    T* data;

private:
    size_t allocdim;
    enum SMALLARRAYCAP = 1;
    T[SMALLARRAYCAP] smallarray; // inline storage for small arrays

public:
    /*******************
     * Params:
     *  dim = initial length of array
     */
    this(size_t dim) pure nothrow
    {
        reserve(dim);
        this.length = dim;
    }

    @disable this(this);

    ~this() pure nothrow
    {
        if (data != &smallarray[0])
            mem.xfree(data);
    }
    ///returns elements comma separated in []
    extern(D) const(char)[] toString()
    {
        static if (is(typeof(T.init.toString())))
        {
            const(char)[][] buf = (cast(const(char)[]*)mem.xcalloc((char[]).sizeof, length))[0 .. length];
            size_t len = 2; // [ and ]
            foreach (u; 0 .. length)
            {
                buf[u] = data[u].toString();
                len += buf[u].length + 1; //length + ',' or null terminator
            }
            char[] str = (cast(char*)mem.xmalloc(len))[0..len];

            str[0] = '[';
            char* p = str.ptr + 1;
            foreach (u; 0 .. length)
            {
                if (u)
                    *p++ = ',';
                memcpy(p, buf[u].ptr, buf[u].length);
                p += buf[u].length;
            }
            *p++ = ']';
            *p = 0;
            assert(p - str.ptr == str.length - 1); //null terminator
            mem.xfree(buf.ptr);
            return str[0 .. $-1];
        }
        else
        {
            assert(0);
        }
    }
    ///ditto
    const(char)* toChars()
    {
        return toString.ptr;
    }

    ref Array push(T ptr) return pure nothrow
    {
        reserve(1);
        data[length++] = ptr;
        return this;
    }

    extern (D) ref Array pushSlice(T[] a) return pure nothrow
    {
        const oldLength = length;
        setDim(oldLength + a.length);
        memcpy(data + oldLength, a.ptr, a.length * T.sizeof);
        return this;
    }

    ref Array append(typeof(this)* a) return pure nothrow
    {
        insert(length, a);
        return this;
    }

    void reserve(size_t nentries) pure nothrow
    {
        //printf("Array::reserve: length = %d, allocdim = %d, nentries = %d\n", (int)length, (int)allocdim, (int)nentries);
        if (allocdim - length < nentries)
        {
            if (allocdim == 0)
            {
                // Not properly initialized, someone memset it to zero
                if (nentries <= SMALLARRAYCAP)
                {
                    allocdim = SMALLARRAYCAP;
                    data = SMALLARRAYCAP ? smallarray.ptr : null;
                }
                else
                {
                    allocdim = nentries;
                    data = cast(T*)mem.xmalloc(allocdim * (*data).sizeof);
                }
            }
            else if (allocdim == SMALLARRAYCAP)
            {
                allocdim = length + nentries;
                data = cast(T*)mem.xmalloc(allocdim * (*data).sizeof);
                memcpy(data, smallarray.ptr, length * (*data).sizeof);
            }
            else
            {
                /* Increase size by 1.5x to avoid excessive memory fragmentation
                 */
                auto increment = length / 2;
                if (nentries > increment)       // if 1.5 is not enough
                    increment = nentries;
                allocdim = length + increment;
                data = cast(T*)mem.xrealloc(data, allocdim * (*data).sizeof);
            }
        }
    }

    void remove(size_t i) pure nothrow @nogc
    {
        if (length - i - 1)
            memmove(data + i, data + i + 1, (length - i - 1) * (data[0]).sizeof);
        length--;
    }

    void insert(size_t index, typeof(this)* a) pure nothrow
    {
        if (a)
        {
            size_t d = a.length;
            reserve(d);
            if (length != index)
                memmove(data + index + d, data + index, (length - index) * (*data).sizeof);
            memcpy(data + index, a.data, d * (*data).sizeof);
            length += d;
        }
    }

    void insert(size_t index, T ptr) pure nothrow
    {
        reserve(1);
        memmove(data + index + 1, data + index, (length - index) * (*data).sizeof);
        data[index] = ptr;
        length++;
    }

    void setDim(size_t newdim) pure nothrow
    {
        if (length < newdim)
        {
            reserve(newdim - length);
        }
        length = newdim;
    }

    size_t find(T ptr) const nothrow pure
    {
        foreach (i; 0 .. length)
            if (data[i] is ptr)
                return i;
        return size_t.max;
    }

    bool contains(T ptr) const nothrow pure
    {
        return find(ptr) != size_t.max;
    }

    ref inout(T) opIndex(size_t i) inout nothrow pure
    {
        return data[i];
    }

    inout(T)* tdata() inout pure nothrow @nogc @safe
    {
        return data;
    }

    Array!T* copy() const pure nothrow
    {
        auto a = new Array!T();
        a.setDim(length);
        memcpy(a.data, data, length * T.sizeof);
        return a;
    }

    void shift(T ptr) pure nothrow
    {
        reserve(1);
        memmove(data + 1, data, length * (*data).sizeof);
        data[0] = ptr;
        length++;
    }

    void zero() nothrow pure @nogc
    {
        data[0 .. length] = T.init;
    }

    T pop() nothrow pure @nogc
    {
        return data[--length];
    }

    extern (D) inout(T)[] opSlice() inout nothrow pure @nogc
    {
        return data[0 .. length];
    }

    extern (D) inout(T)[] opSlice(size_t a, size_t b) inout nothrow pure @nogc
    {
        assert(a <= b && b <= length);
        return data[a .. b];
    }

    alias opDollar = length;
    alias dim = length;
}

unittest
{
    static struct S
    {
        int s = -1;
        string toString()
        {
            return "S";
        }
    }
    auto array = Array!S(4);
    assert(array.toString() == "[S,S,S,S]");
}

unittest
{
    auto array = Array!double(4);
    array.shift(10);
    array.push(20);
    array[2] = 15;
    assert(array[0] == 10);
    assert(array.find(10) == 0);
    assert(array.find(20) == 5);
    assert(!array.contains(99));
    array.remove(1);
    assert(array.length == 5);
    assert(array[1] == 15);
    assert(array.pop() == 20);
    assert(array.length == 4);
    array.insert(1, 30);
    assert(array[1] == 30);
    assert(array[2] == 15);
}

unittest
{
    auto arrayA = Array!int(0);
    int[3] buf = [10, 15, 20];
    arrayA.pushSlice(buf);
    assert(arrayA[] == buf[]);
    auto arrayPtr = arrayA.copy();
    assert(arrayPtr);
    assert((*arrayPtr)[] == arrayA[]);
    assert(arrayPtr.tdata != arrayA.tdata);

    arrayPtr.setDim(0);
    int[2] buf2 = [100, 200];
    arrayPtr.pushSlice(buf2);

    arrayA.append(arrayPtr);
    assert(arrayA[3..$] == buf2[]);
    arrayA.insert(0, arrayPtr);
    assert(arrayA[] == [100, 200, 10, 15, 20, 100, 200]);

    arrayA.zero();
    foreach(e; arrayA)
        assert(e == 0);
}

struct BitArray
{
nothrow:
    size_t length() const pure nothrow @nogc @safe
    {
        return len;
    }

    void length(size_t nlen) pure nothrow
    {
        immutable obytes = (len + 7) / 8;
        immutable nbytes = (nlen + 7) / 8;
        // bt*() access memory in size_t chunks, so round up.
        ptr = cast(size_t*)mem.xrealloc(ptr,
            (nbytes + (size_t.sizeof - 1)) & ~(size_t.sizeof - 1));
        if (nbytes > obytes)
            (cast(ubyte*)ptr)[obytes .. nbytes] = 0;
        len = nlen;
    }

    bool opIndex(size_t idx) const pure nothrow @nogc
    {
        import core.bitop : bt;

        assert(idx < length);
        return !!bt(ptr, idx);
    }

    void opIndexAssign(bool val, size_t idx) pure nothrow @nogc
    {
        import core.bitop : btc, bts;

        assert(idx < length);
        if (val)
            bts(ptr, idx);
        else
            btc(ptr, idx);
    }

    @disable this(this);

    ~this() pure nothrow
    {
        mem.xfree(ptr);
    }

private:
    size_t len;
    size_t *ptr;
}

unittest
{
    BitArray array;
    array.length = 20;
    assert(array[19] == 0);
    array[10] = 1;
    assert(array[10] == 1);
    array[10] = 0;
    assert(array[10] == 0);
    assert(array.length == 20);
}

/**
 * Exposes the given root Array as a standard D array.
 * Params:
 *  array = the array to expose.
 * Returns:
 *  The given array exposed to a standard D array.
 */
@property inout(T)[] peekSlice(T)(inout(Array!T)* array) pure nothrow @nogc
{
    return array ? (*array)[] : null;
}

/**
 * Splits the array at $(D index) and expands it to make room for $(D length)
 * elements by shifting everything past $(D index) to the right.
 * Params:
 *  array = the array to split.
 *  index = the index to split the array from.
 *  length = the number of elements to make room for starting at $(D index).
 */
void split(T)(ref Array!T array, size_t index, size_t length) pure nothrow
{
    if (length > 0)
    {
        auto previousDim = array.length;
        array.setDim(array.length + length);
        for (size_t i = previousDim; i > index;)
        {
            i--;
            array[i + length] = array[i];
        }
    }
}
unittest
{
    auto array = Array!int();
    array.split(0, 0);
    assert([] == array[]);
    array.push(1).push(3);
    array.split(1, 1);
    array[1] = 2;
    assert([1, 2, 3] == array[]);
    array.split(2, 3);
    array[2] = 8;
    array[3] = 20;
    array[4] = 4;
    assert([1, 2, 8, 20, 4, 3] == array[]);
    array.split(0, 0);
    assert([1, 2, 8, 20, 4, 3] == array[]);
    array.split(0, 1);
    array[0] = 123;
    assert([123, 1, 2, 8, 20, 4, 3] == array[]);
    array.split(0, 3);
    array[0] = 123;
    array[1] = 421;
    array[2] = 910;
    assert([123, 421, 910, 123, 1, 2, 8, 20, 4, 3] == (&array).peekSlice());
}

/**
 * Reverse an array in-place.
 * Params:
 *      a = array
 * Returns:
 *      reversed a[]
 */
T[] reverse(T)(T[] a) pure nothrow @nogc @safe
{
    if (a.length > 1)
    {
        const mid = (a.length + 1) >> 1;
        foreach (i; 0 .. mid)
        {
            T e = a[i];
            a[i] = a[$ - 1 - i];
            a[$ - 1 - i] = e;
        }
    }
    return a;
}

unittest
{
    int[] a1 = [];
    assert(reverse(a1) == []);
    int[] a2 = [2];
    assert(reverse(a2) == [2]);
    int[] a3 = [2,3];
    assert(reverse(a3) == [3,2]);
    int[] a4 = [2,3,4];
    assert(reverse(a4) == [4,3,2]);
    int[] a5 = [2,3,4,5];
    assert(reverse(a5) == [5,4,3,2]);
}

unittest
{
    //test toString/toChars.  Identifier is a simple object that has a usable .toString
    import dmd.identifier : Identifier;
    import core.stdc.string : strcmp;

    auto array = Array!Identifier();
    array.push(new Identifier("id1"));
    array.push(new Identifier("id2"));

    string expected = "[id1,id2]";
    assert(array.toString == expected);
    assert(strcmp(array.toChars, expected.ptr) == 0);
}
