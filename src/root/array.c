
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>

#if (defined (__SVR4) && defined (__sun))
#include <alloca.h>
#endif

#if _MSC_VER || __MINGW32__
#include <malloc.h>
#endif

#if IN_GCC
#include "gdc_alloca.h"
#endif

#if _WIN32
#include <windows.h>
#endif

#ifndef _WIN32
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <utime.h>
#endif

#include "port.h"
#include "root.h"
#include "dchar.h"
#include "rmem.h"


/********************************* Array ****************************/

Array::Array()
{
    data = SMALLARRAYCAP ? &smallarray[0] : NULL;
    dim = 0;
    allocdim = SMALLARRAYCAP;
}

Array::~Array()
{
    if (data != &smallarray[0])
        mem.free(data);
}

void Array::mark()
{   unsigned u;

    mem.mark(data);
    for (u = 0; u < dim; u++)
        mem.mark(data[u]);      // BUG: what if arrays of Object's?
}

void Array::reserve(unsigned nentries)
{
    //printf("Array::reserve: dim = %d, allocdim = %d, nentries = %d\n", dim, allocdim, nentries);
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
                data = (void **)mem.malloc(allocdim * sizeof(*data));
            }
        }
        else if (allocdim == SMALLARRAYCAP)
        {
            allocdim = dim + nentries;
            data = (void **)mem.malloc(allocdim * sizeof(*data));
            memcpy(data, &smallarray[0], dim * sizeof(*data));
        }
        else
        {   allocdim = dim + nentries;
            data = (void **)mem.realloc(data, allocdim * sizeof(*data));
        }
    }
}

void Array::setDim(unsigned newdim)
{
    if (dim < newdim)
    {
        reserve(newdim - dim);
    }
    dim = newdim;
}

void Array::fixDim()
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
                data = (void **)mem.realloc(data, dim * sizeof(*data));
        }
        allocdim = dim;
    }
}

void Array::push(void *ptr)
{
    reserve(1);
    data[dim++] = ptr;
}

void *Array::pop()
{
    return data[--dim];
}

void Array::shift(void *ptr)
{
    reserve(1);
    memmove(data + 1, data, dim * sizeof(*data));
    data[0] = ptr;
    dim++;
}

void Array::insert(unsigned index, void *ptr)
{
    reserve(1);
    memmove(data + index + 1, data + index, (dim - index) * sizeof(*data));
    data[index] = ptr;
    dim++;
}


void Array::insert(unsigned index, Array *a)
{
    if (a)
    {   unsigned d;

        d = a->dim;
        reserve(d);
        if (dim != index)
            memmove(data + index + d, data + index, (dim - index) * sizeof(*data));
        memcpy(data + index, a->data, d * sizeof(*data));
        dim += d;
    }
}


/***********************************
 * Append array a to this array.
 */

void Array::append(Array *a)
{
    insert(dim, a);
}

void Array::remove(unsigned i)
{
    if (dim - i - 1)
        memmove(data + i, data + i + 1, (dim - i - 1) * sizeof(data[0]));
    dim--;
}

char *Array::toChars()
{
    unsigned len;
    unsigned u;
    char **buf;
    char *str;
    char *p;

    buf = (char **)malloc(dim * sizeof(char *));
    assert(buf);
    len = 2;
    for (u = 0; u < dim; u++)
    {
        buf[u] = ((Object *)data[u])->toChars();
        len += strlen(buf[u]) + 1;
    }
    str = (char *)mem.malloc(len);

    str[0] = '[';
    p = str + 1;
    for (u = 0; u < dim; u++)
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

void Array::zero()
{
    memset(data,0,dim * sizeof(data[0]));
}

void *Array::tos()
{
    return dim ? data[dim - 1] : NULL;
}

int
#if _WIN32
  __cdecl
#endif
        Array_sort_compare(const void *x, const void *y)
{
    Object *ox = *(Object **)x;
    Object *oy = *(Object **)y;

    return ox->compare(oy);
}

void Array::sort()
{
    if (dim)
    {
        qsort(data, dim, sizeof(Object *), Array_sort_compare);
    }
}

Array *Array::copy()
{
    Array *a = new Array();

    a->setDim(dim);
    memcpy(a->data, data, dim * sizeof(void *));
    return a;
}

