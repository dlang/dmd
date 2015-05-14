
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
#ifdef DEBUG
#include <assert.h>
#endif
#include "port.h"

#if __DMC__
#pragma once
#endif

typedef size_t hash_t;

/*
 * Root of our class library.
 */

struct OutBuffer;

// Can't include arraytypes.h here, need to declare these directly.
template <typename TYPE> struct ArrayBase;
typedef ArrayBase<struct File> Files;
typedef ArrayBase<char> Strings;


struct Object
{
    Object() { }
    virtual ~Object() { }

    virtual int equals(Object *o);

    /**
     * Returns a hash code, useful for things like building hash tables of Objects.
     */
    virtual hash_t hashCode();

    /**
     * Return <0, ==0, or >0 if this is less than, equal to, or greater than obj.
     * Useful for sorting Objects.
     */
    virtual int compare(Object *obj);

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

    /**
     * Marks pointers for garbage collector by calling mem.mark() for all pointers into heap.
     */
    /*virtual*/         // not used, disable for now
        void mark();
};

struct String : Object
{
    const char *str;                  // the string itself

    String(const char *str);
    ~String();

    static hash_t calcHash(const char *str, size_t len);
    static hash_t calcHash(const char *str);
    hash_t hashCode();
    size_t len();
    int equals(Object *obj);
    int compare(Object *obj);
    char *toChars();
    void print();
    void mark();
};

struct FileName : String
{
    FileName(const char *str);
    hash_t hashCode();
    int equals(Object *obj);
    static int equals(const char *name1, const char *name2);
    int compare(Object *obj);
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
};

struct File : Object
{
    int ref;                    // != 0 if this is a reference to someone else's buffer
    unsigned char *buffer;      // data for our file
    size_t len;                 // amount of data in buffer[]
    void *touchtime;            // system time to use for file

    FileName *name;             // name of our file

    File(const char *);
    File(const FileName *);
    ~File();

    void mark();

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

struct OutBuffer : Object
{
    unsigned char *data;
    size_t offset;
    size_t size;

    int doindent, level, linehead;

    OutBuffer();
    ~OutBuffer();
    char *extractData();
    void mark();

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
    void write(Object *obj);
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
    // Append terminating null if necessary and get view of internal buffer
    char *peekString();
    // Append terminating null if necessary and take ownership of data
    char *extractString();
};

struct Array
{
    size_t dim;
    void **data;

  private:
    size_t allocdim;
    #define SMALLARRAYCAP       1
    void *smallarray[SMALLARRAYCAP];    // inline storage for small arrays

  public:
    Array();
    ~Array();
    //Array(const Array&);
    void mark();
    char *toChars();

    void reserve(size_t nentries);
    void setDim(size_t newdim);
    void fixDim();
    void push(void *ptr);
    void *pop();
    void shift(void *ptr);
    void insert(size_t index, void *ptr);
    void insert(size_t index, Array *a);
    void append(Array *a);
    void remove(size_t i);
    void zero();
    void *tos();
    void sort();
    Array *copy();
};

template <typename TYPE>
struct ArrayBase : Array
{
    TYPE **tdata()
    {
        return (TYPE **)data;
    }

    TYPE*& operator[] (size_t index)
    {
#ifdef DEBUG
        assert(index < dim);
#endif
        return ((TYPE **)data)[index];
    }

    void insert(size_t index, TYPE *v)
    {
        Array::insert(index, (void *)v);
    }

    void insert(size_t index, ArrayBase *a)
    {
        Array::insert(index, (Array *)a);
    }

    void append(ArrayBase *a)
    {
        Array::append((Array *)a);
    }

    void push(TYPE *a)
    {
        Array::push((void *)a);
    }

    ArrayBase *copy()
    {
        return (ArrayBase *)Array::copy();
    }

    typedef int (*ArrayBase_apply_ft_t)(TYPE *, void *);
    int apply(ArrayBase_apply_ft_t fp, void *param)
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

// TODO: Remove (only used by disabled GC)
struct Bits : Object
{
    unsigned bitdim;
    unsigned allocdim;
    unsigned *data;

    Bits();
    ~Bits();
    void mark();

    void resize(unsigned bitdim);

    void set(unsigned bitnum);
    void clear(unsigned bitnum);
    int test(unsigned bitnum);

    void set();
    void clear();
    void copy(Bits *from);
    Bits *clone();

    void sub(Bits *b);
};

#endif
