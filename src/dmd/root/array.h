/* Copyright (C) 2011-2019 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/array.h
 */

#pragma once

#include "dsystem.h"
#include "object.h"
#include "rmem.h"

template <typename TYPE>
struct Array
{
    d_size_t length;

  private:
    TYPE *data;
    d_size_t allocdim;
    #define SMALLARRAYCAP       1
    TYPE smallarray[SMALLARRAYCAP];    // inline storage for small arrays

    Array(const Array&);

  public:
    Array()
    {
        data = SMALLARRAYCAP ? &smallarray[0] : NULL;
        length = 0;
        allocdim = SMALLARRAYCAP;
    }

    ~Array()
    {
        if (data != &smallarray[0])
            mem.xfree(data);
    }

    char *toChars() const
    {
        const char **buf = (const char **)mem.xmalloc(length * sizeof(const char *));
        d_size_t len = 2;
        for (d_size_t u = 0; u < length; u++)
        {
            buf[u] = ((RootObject *)data[u])->toChars();
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

    void reserve(d_size_t nentries)
    {
        //printf("Array::reserve: length = %d, allocdim = %d, nentries = %d\n", (int)length, (int)allocdim, (int)nentries);
        if (allocdim - length < nentries)
        {
            if (allocdim == 0)
            {   // Not properly initialized, someone memset it to zero
                if (nentries <= SMALLARRAYCAP)
                {   allocdim = SMALLARRAYCAP;
                    data = SMALLARRAYCAP ? &smallarray[0] : NULL;
                }
                else
                {   allocdim = nentries;
                    data = (TYPE *)mem.xmalloc(allocdim * sizeof(*data));
                }
            }
            else if (allocdim == SMALLARRAYCAP)
            {
                allocdim = length + nentries;
                data = (TYPE *)mem.xmalloc(allocdim * sizeof(*data));
                memcpy(data, &smallarray[0], length * sizeof(*data));
            }
            else
            {
                /* Increase size by 1.5x to avoid excessive memory fragmentation
                 */
                d_size_t increment = length / 2;
                if (nentries > increment)       // if 1.5 is not enough
                    increment = nentries;
                allocdim = length + increment;
                data = (TYPE *)mem.xrealloc(data, allocdim * sizeof(*data));
            }
        }
    }

    void setDim(d_size_t newdim)
    {
        if (length < newdim)
        {
            reserve(newdim - length);
        }
        length = newdim;
    }

    TYPE pop()
    {
        return data[--length];
    }

    void shift(TYPE ptr)
    {
        reserve(1);
        memmove(data + 1, data, length * sizeof(*data));
        data[0] = ptr;
        length++;
    }

    void remove(d_size_t i)
    {
        if (length - i - 1)
            memmove(data + i, data + i + 1, (length - i - 1) * sizeof(data[0]));
        length--;
    }

    void zero()
    {
        memset(data,0,length * sizeof(data[0]));
    }

    TYPE *tdata()
    {
        return data;
    }

    TYPE& operator[] (d_size_t index)
    {
#ifdef DEBUG
        assert(index < length);
#endif
        return data[index];
    }

    void insert(d_size_t index, TYPE v)
    {
        reserve(1);
        memmove(data + index + 1, data + index, (length - index) * sizeof(*data));
        data[index] = v;
        length++;
    }

    void insert(d_size_t index, Array *a)
    {
        if (a)
        {
            d_size_t d = a->length;
            reserve(d);
            if (length != index)
                memmove(data + index + d, data + index, (length - index) * sizeof(*data));
            memcpy(data + index, a->data, d * sizeof(*data));
            length += d;
        }
    }

    void append(Array *a)
    {
        insert(length, a);
    }

    void push(TYPE a)
    {
        reserve(1);
        data[length++] = a;
    }

    Array *copy()
    {
        Array *a = new Array();
        a->setDim(length);
        memcpy(a->data, data, length * sizeof(*data));
        return a;
    }
};

struct BitArray
{
    BitArray()
      : len(0)
      , ptr(NULL)
    {}

    ~BitArray()
    {
        mem.xfree(ptr);
    }

    d_size_t len;
    d_size_t *ptr;

private:
    BitArray(const BitArray&);
};
