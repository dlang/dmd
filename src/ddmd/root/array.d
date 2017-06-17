/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC root/_array.d)
 */

module ddmd.root.array;

import core.stdc.string;

import ddmd.root.rmem;

extern (C++) struct Array(T)
{
    size_t dim;
    T* data;

private:
    size_t allocdim;
    enum SMALLARRAYCAP = 1;
    T[SMALLARRAYCAP] smallarray; // inline storage for small arrays

public:
    @disable this(this);

    ~this() nothrow
    {
        if (data != &smallarray[0])
            mem.xfree(data);
    }

    const(char)* toChars()
    {
        static if (is(typeof(T.init.toChars())))
        {
            const(char)** buf = cast(const(char)**)mem.xmalloc(dim * (char*).sizeof);
            size_t len = 2;
            for (size_t u = 0; u < dim; u++)
            {
                buf[u] = data[u].toChars();
                len += strlen(buf[u]) + 1;
            }
            char* str = cast(char*)mem.xmalloc(len);

            str[0] = '[';
            char* p = str + 1;
            for (size_t u = 0; u < dim; u++)
            {
                if (u)
                    *p++ = ',';
                len = strlen(buf[u]);
                memcpy(p, buf[u], len);
                p += len;
            }
            *p++ = ']';
            *p = 0;
            mem.xfree(buf);
            return str;
        }
        else
        {
            assert(0);
        }
    }

    void push(T ptr) nothrow
    {
        reserve(1);
        data[dim++] = ptr;
    }

    void append(typeof(this)* a) nothrow
    {
        insert(dim, a);
    }

    void reserve(size_t nentries) nothrow
    {
        //printf("Array::reserve: dim = %d, allocdim = %d, nentries = %d\n", (int)dim, (int)allocdim, (int)nentries);
        if (allocdim - dim < nentries)
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
                allocdim = dim + nentries;
                data = cast(T*)mem.xmalloc(allocdim * (*data).sizeof);
                memcpy(data, smallarray.ptr, dim * (*data).sizeof);
            }
            else
            {
                allocdim = dim + nentries;
                data = cast(T*)mem.xrealloc(data, allocdim * (*data).sizeof);
            }
        }
    }

    void remove(size_t i) nothrow
    {
        if (dim - i - 1)
            memmove(data + i, data + i + 1, (dim - i - 1) * (data[0]).sizeof);
        dim--;
    }

    void insert(size_t index, typeof(this)* a) nothrow
    {
        if (a)
        {
            size_t d = a.dim;
            reserve(d);
            if (dim != index)
                memmove(data + index + d, data + index, (dim - index) * (*data).sizeof);
            memcpy(data + index, a.data, d * (*data).sizeof);
            dim += d;
        }
    }

    void insert(size_t index, T ptr) nothrow
    {
        reserve(1);
        memmove(data + index + 1, data + index, (dim - index) * (*data).sizeof);
        data[index] = ptr;
        dim++;
    }

    void setDim(size_t newdim) nothrow
    {
        if (dim < newdim)
        {
            reserve(newdim - dim);
        }
        dim = newdim;
    }

    ref inout(T) opIndex(size_t i) inout nothrow pure
    {
        return data[i];
    }

    inout(T)* tdata() inout nothrow
    {
        return data;
    }

    Array!T* copy() const nothrow
    {
        auto a = new Array!T();
        a.setDim(dim);
        memcpy(a.data, data, dim * (void*).sizeof);
        return a;
    }

    void shift(T ptr) nothrow
    {
        reserve(1);
        memmove(data + 1, data, dim * (*data).sizeof);
        data[0] = ptr;
        dim++;
    }

    void zero() nothrow pure
    {
        data[0 .. dim] = T.init;
    }

    T pop() nothrow pure
    {
        return data[--dim];
    }

    extern (D) inout(T)[] opSlice() inout nothrow pure
    {
        return data[0 .. dim];
    }

    extern (D) inout(T)[] opSlice(size_t a, size_t b) inout nothrow pure
    {
        assert(a <= b && b <= dim);
        return data[a .. b];
    }
}

struct BitArray
{
nothrow:
    size_t length() const pure
    {
        return len;
    }

    void length(size_t nlen)
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

    bool opIndex(size_t idx) const pure
    {
        import core.bitop : bt;

        assert(idx < length);
        return !!bt(ptr, idx);
    }

    void opIndexAssign(bool val, size_t idx) pure
    {
        import core.bitop : btc, bts;

        assert(idx < length);
        if (val)
            bts(ptr, idx);
        else
            btc(ptr, idx);
    }

    @disable this(this);

    ~this()
    {
        mem.xfree(ptr);
    }

private:
    size_t len;
    size_t *ptr;
}
