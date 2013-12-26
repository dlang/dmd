
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef ARRAY_H
#define ARRAY_H

#if __DMC__
#pragma once
#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rmem.h"
#include "object.h"

template <typename TYPE>
struct Array
{
    size_t dim;
    TYPE *data;

  private:
    size_t allocdim;
    #define SMALLARRAYCAP       1
    TYPE smallarray[SMALLARRAYCAP];    // inline storage for small arrays

  public:
    Array()
    {
        data = SMALLARRAYCAP ? &smallarray[0] : NULL;
        dim = 0;
        allocdim = SMALLARRAYCAP;
    }

    ~Array()
    {
        if (data != &smallarray[0])
            mem.free(data);
    }

    char *toChars()
    {
        char **buf = (char **)malloc(dim * sizeof(char *));
        assert(buf);
        size_t len = 2;
        for (size_t u = 0; u < dim; u++)
        {
            buf[u] = ((RootObject *)data[u])->toChars();
            len += strlen(buf[u]) + 1;
        }
        char *str = (char *)mem.malloc(len);

        str[0] = '[';
        char *p = str + 1;
        for (size_t u = 0; u < dim; u++)
        {
            if (u)
                *p++ = ',';
            len = strlen(buf[u]);
            memcpy(p,buf[u],len);
            p += len;
        }
        *p++ = ']';
        *p = 0;
        free(buf);
        return str;
    }

    void reserve(size_t nentries)
    {
        //printf("Array::reserve: dim = %d, allocdim = %d, nentries = %d\n", (int)dim, (int)allocdim, (int)nentries);
        if (allocdim - dim < nentries)
        {
            if (allocdim == 0)
            {   // Not properly initialized, someone memset it to zero
                if (nentries <= SMALLARRAYCAP)
                {   allocdim = SMALLARRAYCAP;
                    data = SMALLARRAYCAP ? &smallarray[0] : NULL;
                }
                else
                {   allocdim = nentries;
                    data = (TYPE *)mem.malloc(allocdim * sizeof(*data));
                }
            }
            else if (allocdim == SMALLARRAYCAP)
            {
                allocdim = dim + nentries;
                data = (TYPE *)mem.malloc(allocdim * sizeof(*data));
                memcpy(data, &smallarray[0], dim * sizeof(*data));
            }
            else
            {   allocdim = dim + nentries;
                data = (TYPE *)mem.realloc(data, allocdim * sizeof(*data));
            }
        }
    }

    void setDim(size_t newdim)
    {
        if (dim < newdim)
        {
            reserve(newdim - dim);
        }
        dim = newdim;
    }

    void fixDim()
    {
        if (dim != allocdim)
        {
            if (allocdim >= SMALLARRAYCAP)
            {
                if (dim <= SMALLARRAYCAP)
                {
                    memcpy(&smallarray[0], data, dim * sizeof(*data));
                    mem.free(data);
                }
                else
                    data = (TYPE *)mem.realloc(data, dim * sizeof(*data));
            }
            allocdim = dim;
        }
    }

    TYPE pop()
    {
        return data[--dim];
    }

    void shift(TYPE ptr)
    {
        reserve(1);
        memmove(data + 1, data, dim * sizeof(*data));
        data[0] = ptr;
        dim++;
    }

    void remove(size_t i)
    {
        if (dim - i - 1)
            memmove(data + i, data + i + 1, (dim - i - 1) * sizeof(data[0]));
        dim--;
    }

    void zero()
    {
        memset(data,0,dim * sizeof(data[0]));
    }

    TYPE tos()
    {
        return dim ? data[dim - 1] : NULL;
    }

    void sort()
    {
        struct ArraySort
        {
            static int
    #if _WIN32
              __cdecl
    #endif
            Array_sort_compare(const void *x, const void *y)
            {
                RootObject *ox = *(RootObject **)x;
                RootObject *oy = *(RootObject **)y;

                return ox->compare(oy);
            }
        };

        if (dim)
        {
            qsort(data, dim, sizeof(RootObject *), &ArraySort::Array_sort_compare);
        }
    }

    TYPE *tdata()
    {
        return data;
    }

    TYPE& operator[] (size_t index)
    {
#ifdef DEBUG
        assert(index < dim);
#endif
        return data[index];
    }

    void insert(size_t index, TYPE v)
    {
        reserve(1);
        memmove(data + index + 1, data + index, (dim - index) * sizeof(*data));
        data[index] = v;
        dim++;
    }

    void insert(size_t index, Array *a)
    {
        if (a)
        {
            size_t d = a->dim;
            reserve(d);
            if (dim != index)
                memmove(data + index + d, data + index, (dim - index) * sizeof(*data));
            memcpy(data + index, a->data, d * sizeof(*data));
            dim += d;
        }
    }

    void append(Array *a)
    {
        insert(dim, a);
    }

    void push(TYPE a)
    {
        reserve(1);
        data[dim++] = a;
    }

    Array *copy()
    {
        Array *a = new Array();

        a->setDim(dim);
        memcpy(a->data, data, dim * sizeof(*data));
        return a;
    }

    typedef int (*Array_apply_ft_t)(TYPE, void *);
    int apply(Array_apply_ft_t fp, void *param)
    {
        for (size_t i = 0; i < dim; i++)
        {   TYPE e = (*this)[i];

            if (e)
            {
                if (e->apply(fp, param))
                    return 1;
            }
        }
        return 0;
    }
};

#endif
