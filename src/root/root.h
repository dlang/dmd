
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef ROOT_H
#define ROOT_H

#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>
#include "port.h"
#include "rmem.h"

#if __DMC__
#pragma once
#endif

typedef size_t hash_t;

/*
 * Root of our class library.
 */

struct OutBuffer;

// Can't include arraytypes.h here, need to declare these directly.
template <typename TYPE> struct Array;
typedef Array<struct File> Files;
typedef Array<const char> Strings;


class RootObject
{
public:
    RootObject() { }
    virtual ~RootObject() { }

    virtual bool equals(RootObject *o);

    /**
     * Return <0, ==0, or >0 if this is less than, equal to, or greater than obj.
     * Useful for sorting Objects.
     */
    virtual int compare(RootObject *obj);

    /**
     * Pretty-print an Object. Useful for debugging the old-fashioned way.
     */
    virtual void print();

    virtual char *toChars();
    virtual void toBuffer(OutBuffer *buf);

    /**
     * Used as a replacement for dynamic_cast. Returns a unique number
     * defined by the library user. For Object, the return value is 0.
     */
    virtual int dyncast();
};

struct FileName
{
public:
    const char *str;
    FileName(const char *str);
    bool equals(RootObject *obj);
    static int equals(const char *name1, const char *name2);
    int compare(RootObject *obj);
    static int compare(const char *name1, const char *name2);
    static int absolute(const char *name);
    static const char *ext(const char *);
    const char *ext();
    static const char *removeExt(const char *str);
    static const char *name(const char *);
    const char *name();
    static const char *path(const char *);
    static const char *replaceName(const char *path, const char *name);

    static const char *combine(const char *path, const char *name);
    static Strings *splitPath(const char *path);
    static const char *defaultExt(const char *name, const char *ext);
    static const char *forceExt(const char *name, const char *ext);
    static int equalsExt(const char *name, const char *ext);

    int equalsExt(const char *ext);

    void CopyTo(FileName *to);
    static const char *searchPath(Strings *path, const char *name, int cwd);
    static const char *safeSearchPath(Strings *path, const char *name);
    static int exists(const char *name);
    static void ensurePathExists(const char *path);
    static void ensurePathToNameExists(const char *name);
    static const char *canonicalName(const char *name);

    static void free(const char *str);
    char *toChars();
};

struct File
{
public:
    int ref;                    // != 0 if this is a reference to someone else's buffer
    unsigned char *buffer;      // data for our file
    size_t len;                 // amount of data in buffer[]
    void *touchtime;            // system time to use for file

    FileName *name;             // name of our file

    File(const char *);
    File(const FileName *);
    ~File();

    char *toChars();

    /* Read file, return !=0 if error
     */

    int read();

    /* Write file, either succeed or fail
     * with error message & exit.
     */

    void readv();

    /* Read file, return !=0 if error
     */

    int mmread();

    /* Write file, either succeed or fail
     * with error message & exit.
     */

    void mmreadv();

    /* Write file, return !=0 if error
     */

    int write();

    /* Write file, either succeed or fail
     * with error message & exit.
     */

    void writev();

    /* Return !=0 if file exists.
     *  0:      file doesn't exist
     *  1:      normal file
     *  2:      directory
     */

    /* Append to file, return !=0 if error
     */

    int append();

    /* Append to file, either succeed or fail
     * with error message & exit.
     */

    void appendv();

    /* Return !=0 if file exists.
     *  0:      file doesn't exist
     *  1:      normal file
     *  2:      directory
     */

    int exists();

    /* Given wildcard filespec, return an array of
     * matching File's.
     */

    static Files *match(char *);
    static Files *match(FileName *);

    // Compare file times.
    // Return   <0      this < f
    //          =0      this == f
    //          >0      this > f
    int compareTime(File *f);

    // Read system file statistics
    void stat();

    /* Set buffer
     */

    void setbuffer(void *buffer, size_t len)
    {
        this->buffer = (unsigned char *)buffer;
        this->len = len;
    }

    void checkoffset(size_t offset, size_t nbytes);

    void remove();              // delete file
};

struct OutBuffer
{
    unsigned char *data;
    size_t offset;
    size_t size;

    int doindent;
    int level;
    int notlinehead;

    OutBuffer();
    ~OutBuffer();
    char *extractData();

    void reserve(size_t nbytes);
    void setsize(size_t size);
    void reset();
    void write(const void *data, size_t nbytes);
    void writebstring(unsigned char *string);
    void writestring(const char *string);
    void prependstring(const char *string);
    void writenl();                     // write newline
    void writeByte(unsigned b);
    void writebyte(unsigned b) { writeByte(b); }
    void writeUTF8(unsigned b);
    void prependbyte(unsigned b);
    void writewchar(unsigned w);
    void writeword(unsigned w);
    void writeUTF16(unsigned w);
    void write4(unsigned w);
    void write(OutBuffer *buf);
    void write(RootObject *obj);
    void fill0(size_t nbytes);
    void align(size_t size);
    void vprintf(const char *format, va_list args);
    void printf(const char *format, ...);
    void bracket(char left, char right);
    size_t bracket(size_t i, const char *left, size_t j, const char *right);
    void spread(size_t offset, size_t nbytes);
    size_t insert(size_t offset, const void *data, size_t nbytes);
    void remove(size_t offset, size_t nbytes);
    char *toChars();
    char *extractString();
};

template <typename TYPE>
struct Array
{
    size_t dim;
    TYPE **data;

  private:
    size_t allocdim;
    #define SMALLARRAYCAP       1
    TYPE *smallarray[SMALLARRAYCAP];    // inline storage for small arrays

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
                    data = (TYPE **)mem.malloc(allocdim * sizeof(*data));
                }
            }
            else if (allocdim == SMALLARRAYCAP)
            {
                allocdim = dim + nentries;
                data = (TYPE **)mem.malloc(allocdim * sizeof(*data));
                memcpy(data, &smallarray[0], dim * sizeof(*data));
            }
            else
            {   allocdim = dim + nentries;
                data = (TYPE **)mem.realloc(data, allocdim * sizeof(*data));
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
                    data = (TYPE **)mem.realloc(data, dim * sizeof(*data));
            }
            allocdim = dim;
        }
    }

    TYPE *pop()
    {
        return data[--dim];
    }

    void shift(TYPE *ptr)
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

    TYPE *tos()
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

    TYPE **tdata()
    {
        return data;
    }

    TYPE*& operator[] (size_t index)
    {
#ifdef DEBUG
        assert(index < dim);
#endif
        return data[index];
    }

    void insert(size_t index, TYPE *v)
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

    void push(TYPE *a)
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

    typedef int (*Array_apply_ft_t)(TYPE *, void *);
    int apply(Array_apply_ft_t fp, void *param)
    {
        for (size_t i = 0; i < dim; i++)
        {   TYPE *e = (*this)[i];

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
