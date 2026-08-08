/* Copyright (C) 2011-2026 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/array.h
 */

#pragma once

#include "dsystem.h"
#include "rmem.h"

template <typename TYPE>
struct Array
{
    uint32_t length;

  private:
    uint32_t allocated;
    #define SMALLARRAYCAP       1
    union
    {
        TYPE smallarray[SMALLARRAYCAP];    // inline storage for small arrays
        TYPE* _ptr;
    };
    TYPE* data() { return allocated <= SMALLARRAYCAP ? smallarray : _ptr; }
    const TYPE* data() const { return allocated <= SMALLARRAYCAP ? smallarray : _ptr; }

    Array(const Array&);

  public:
    Array()
    {
        length = 0;
        allocated = SMALLARRAYCAP;
    }

    ~Array()
    {
        if (allocated > SMALLARRAYCAP)
            mem.xfree(_ptr);
    }

    char *toChars() const
    {
        const char **buf = (const char **)mem.xmalloc(length * sizeof(const char *));
        d_size_t len = 2;
        for (d_size_t u = 0; u < length; u++)
        {
            buf[u] = (data()[u])->toChars();
            len += strlen(buf[u]) + 1;
        }
        char *str = (char *)mem.xmalloc(len);

        str[0] = '[';
        char *p = str + 1;
        for (d_size_t u = 0; u < length; u++)
        {
            if (u)
                *p++ = ',';
            len = strlen(buf[u]);
            memcpy(p,buf[u],len);
            p += len;
        }
        *p++ = ']';
        *p = 0;
        mem.xfree(buf);
        return str;
    }

    void push(TYPE ptr)
    {
        reserve(1);
        data()[length++] = ptr;
    }

    void append(Array *a)
    {
        insert(length, a);
    }

    void reserve(d_size_t nentries)
    {
        //printf("Array::reserve: length = %d, allocated = %d, nentries = %d\n", (int)length, (int)allocated, (int)nentries);
        if (allocated - length < nentries)
        {
            if (allocated == 0)
            {
                // Not properly initialized, someone memset it to zero
                if (nentries <= SMALLARRAYCAP)
                {
                    allocated = SMALLARRAYCAP;
                }
                else
                {
                    allocated = nentries;
                    _ptr = (TYPE *)mem.xmalloc(allocated * sizeof(TYPE));
                }
            }
            else if (allocated <= SMALLARRAYCAP)
            {
                allocated = length + nentries;
                TYPE* p = (TYPE *)mem.xmalloc(allocated * sizeof(TYPE));
                memcpy(p, &smallarray[0], length * sizeof(TYPE));
                _ptr = p;
            }
            else
            {
                /* Increase size by 1.5x to avoid excessive memory fragmentation
                 */
                auto increment = length / 2;
                if (nentries > increment)       // if 1.5 is not enough
                    increment = (uint32_t)nentries;
                allocated = length + increment;
                _ptr = (TYPE *)mem.xrealloc(_ptr, allocated * sizeof(TYPE));
            }
        }
    }

    void remove(d_size_t i)
    {
        if (length - i - 1)
            memmove(data() + i, data() + i + 1, (length - i - 1) * sizeof(TYPE));
        length--;
    }

    void insert(d_size_t index, Array *a)
    {
        if (a)
        {
            auto d = a->length;
            reserve(d);
            if (length != index)
                memmove(data() + index + d, data() + index, (length - index) * sizeof(TYPE));
            memcpy(data() + index, a->data(), d * sizeof(TYPE));
            length += d;
        }
    }

    void insert(d_size_t index, TYPE ptr)
    {
        reserve(1);
        memmove(data() + index + 1, data() + index, (length - index) * sizeof(TYPE));
        data()[index] = ptr;
        length++;
    }

    void setDim(d_size_t newdim)
    {
        if (length < newdim)
        {
            reserve(newdim - length);
        }
        length = newdim;
    }

    d_size_t find(TYPE ptr) const
    {
        for (d_size_t i = 0; i < length; i++)
        {
            if (data()[i] == ptr)
                return i;
        }
        return SIZE_MAX;
    }

    bool contains(TYPE ptr) const
    {
        return find(ptr) != SIZE_MAX;
    }

    TYPE& operator[] (d_size_t index)
    {
#ifdef DEBUG
        assert(index < length);
#endif
        return data()[index];
    }

    TYPE *tdata()
    {
        return data();
    }

    Array *copy()
    {
        Array *a = new Array();
        a->setDim(length);
        memcpy(a->data(), data(), length * sizeof(TYPE));
        return a;
    }

    void shift(TYPE ptr)
    {
        reserve(1);
        memmove(data() + 1, data(), length * sizeof(TYPE));
        data()[0] = ptr;
        length++;
    }

    void zero()
    {
        memset(data(), 0, length * sizeof(TYPE));
    }

    TYPE pop()
    {
        return data()[--length];
    }
};
