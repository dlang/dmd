/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Simple bit vector implementation.
 *
 * Copyright:   Copyright (C) 2013-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dvec.d, backend/dvec.d)
 */

module dmd.backend.dvec;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import core.bitop;

extern (C):

nothrow:
@nogc:
@safe:

alias vec_base_t = size_t;                     // base type of vector
alias vec_t = vec_base_t*;

enum VECBITS = vec_base_t.sizeof * 8;        // # of bits per entry
enum VECMASK = VECBITS - 1;                  // mask for bit position
enum VECSHIFT = (VECBITS == 16) ? 4 : (VECBITS == 32 ? 5 : 6);   // # of bits in VECMASK

static assert(vec_base_t.sizeof == 2 && VECSHIFT == 4 ||
              vec_base_t.sizeof == 4 && VECSHIFT == 5 ||
              vec_base_t.sizeof == 8 && VECSHIFT == 6);

struct VecGlobal
{
    int count;           // # of vectors allocated
    int initcount;       // # of times package is initialized
    vec_t[30] freelist;  // free lists indexed by dim

  nothrow:
  @nogc:

    void initialize()
    {
        if (initcount++ == 0)
            count = 0;
    }

    @trusted
    void terminate()
    {
        if (--initcount == 0)
        {
            debug
            {
                if (count != 0)
                {
                    printf("vecGlobal.count = %d\n", count);
                    assert(0);
                }
            }
            else
                assert(count == 0);

            foreach (size_t i; 0 .. freelist.length)
            {
                void **vn;
                for (void** v = cast(void **)freelist[i]; v; v = vn)
                {
                    vn = cast(void **)(*v);
                    //mem_free(v);
                    .free(v);
                }
                freelist[i] = null;
            }
        }
    }

    @trusted
    vec_t allocate(size_t numbits)
    {
        if (numbits == 0)
            return cast(vec_t) null;
        const dim = (numbits + (VECBITS - 1)) >> VECSHIFT;
        vec_t v;
        if (dim < freelist.length && (v = freelist[dim]) != null)
        {
            freelist[dim] = *cast(vec_t *)v;
            v += 2;
            switch (dim)
            {
                case 5:     v[4] = 0;  goto case 4;
                case 4:     v[3] = 0;  goto case 3;
                case 3:     v[2] = 0;  goto case 2;
                case 2:     v[1] = 0;  goto case 1;
                case 1:     v[0] = 0;
                            break;
                default:    memset(v,0,dim * vec_base_t.sizeof);
                            break;
            }
            goto L1;
        }
        else
        {
            v = cast(vec_t) calloc(dim + 2, vec_base_t.sizeof);
            assert(v);
        }
        if (v)
        {
            v += 2;
        L1:
            vec_dim(v) = dim;
            vec_numbits(v) = numbits;
            /*printf("vec_calloc(%d): v = %p vec_numbits = %d vec_dim = %d\n",
                numbits,v,vec_numbits(v),vec_dim(v));*/
            count++;
        }
        return v;
    }

    @trusted
    vec_t dup(const vec_t v)
    {
        if (!v)
            return null;

        const dim = vec_dim(v);
        const nbytes = (dim + 2) * vec_base_t.sizeof;
        vec_t vc;
        vec_t result;
        if (dim < freelist.length && (vc = freelist[dim]) != null)
        {
            freelist[dim] = *cast(vec_t *)vc;
            goto L1;
        }
        else
        {
            vc = cast(vec_t) calloc(nbytes, 1);
            assert(vc);
        }
        if (vc)
        {
          L1:
            memcpy(vc,v - 2,nbytes);
            count++;
            result = vc + 2;
        }
        else
            result = null;
        return result;
    }

    @trusted
    void free(vec_t v)
    {
        /*printf("vec_free(%p)\n",v);*/
        if (v)
        {
            const dim = vec_dim(v);
            v -= 2;
            if (dim < freelist.length)
            {
                *cast(vec_t *)v = freelist[dim];
                freelist[dim] = v;
            }
            else
                .free(v);
            count--;
        }
    }

}

__gshared VecGlobal vecGlobal;

private pure vec_base_t MASK(uint b) { return cast(vec_base_t)1 << (b & VECMASK); }

@trusted
pure ref inout(vec_base_t) vec_numbits(inout vec_t v) { return v[-1]; }
@trusted
pure ref inout(vec_base_t) vec_dim(inout vec_t v) { return v[-2]; }

/**************************
 * Initialize package.
 */

@trusted
void vec_init()
{
    vecGlobal.initialize();
}


/**************************
 * Terminate package.
 */

@trusted
void vec_term()
{
    vecGlobal.terminate();
}

/********************************
 * Allocate a vector given # of bits in it.
 * Clear the vector.
 */

@trusted
vec_t vec_calloc(size_t numbits)
{
    return vecGlobal.allocate(numbits);
}

/********************************
 * Allocate copy of existing vector.
 */

@trusted
vec_t vec_clone(const vec_t v)
{
    return vecGlobal.dup(v);
}

/**************************
 * Free a vector.
 */

@trusted
void vec_free(vec_t v)
{
    /*printf("vec_free(%p)\n",v);*/
    return vecGlobal.free(v);
}

/**************************
 * Realloc a vector to have numbits bits in it.
 * Extra bits are set to 0.
 */

@trusted
vec_t vec_realloc(vec_t v, size_t numbits)
{
    /*printf("vec_realloc(%p,%d)\n",v,numbits);*/
    if (!v)
        return vec_calloc(numbits);
    if (!numbits)
    {   vec_free(v);
        return null;
    }
    const vbits = vec_numbits(v);
    if (numbits == vbits)
        return v;
    vec_t newv = vec_calloc(numbits);
    if (newv)
    {
        const nbytes = (vec_dim(v) < vec_dim(newv)) ? vec_dim(v) : vec_dim(newv);
        memcpy(newv,v,nbytes * vec_base_t.sizeof);
        vec_clearextrabits(newv);
    }
    vec_free(v);
    return newv;
}

/********************************
 * Recycle a vector `v` to a new size `numbits`, clear all bits.
 * Re-uses original if possible.
 */
void vec_recycle(ref vec_t v, size_t numbits)
{
    vec_free(v);
    v = vec_calloc(numbits);
}


/**************************
 * Set bit b in vector v.
 */

@trusted
pure
void vec_setbit(size_t b, vec_t v)
{
    debug
    {
        if (!(v && b < vec_numbits(v)))
            printf("vec_setbit(v = %p,b = %d): numbits = %d dim = %d\n",
                v, cast(int) b, cast(int) (v ? vec_numbits(v) : 0), cast(int) (v ? vec_dim(v) : 0));
    }
    assert(v && b < vec_numbits(v));
    core.bitop.bts(v, b);
}

/**************************
 * Clear bit b in vector v.
 */

@trusted
pure
void vec_clearbit(size_t b, vec_t v)
{
    assert(v && b < vec_numbits(v));
    core.bitop.btr(v, b);
}

/**************************
 * Test bit b in vector v.
 */

@trusted
pure
size_t vec_testbit(size_t b, const vec_t v)
{
    if (!v)
        return 0;
    debug
    {
        if (!(v && b < vec_numbits(v)))
            printf("vec_setbit(v = %p,b = %d): numbits = %d dim = %d\n",
                v, cast(int) b, cast(int) (v ? vec_numbits(v) : 0), cast(int) (v ? vec_dim(v) : 0));
    }
    assert(v && b < vec_numbits(v));
    return core.bitop.bt(v, b);
}

/********************************
 * Find first set bit starting from b in vector v.
 * If no bit is found, return vec_numbits(v).
 */

@trusted
pure
size_t vec_index(size_t b, const vec_t vec)
{
    if (!vec)
        return 0;
    const(vec_base_t)* v = vec;
    if (b < vec_numbits(v))
    {
        const vtop = &vec[vec_dim(v)];
        const bit = b & VECMASK;
        if (bit != b)                   // if not starting in first word
            v += b >> VECSHIFT;
        size_t starv = *v >> bit;
        while (1)
        {
            while (starv)
            {
                if (starv & 1)
                    return b;
                b++;
                starv >>= 1;
            }
            b = (b + VECBITS) & ~VECMASK;   // round up to next word
            if (++v >= vtop)
                break;
            starv = *v;
        }
    }
    return vec_numbits(vec);
}

/********************************
 * Compute v1 &= v2.
 */

@trusted
pure
void vec_andass(vec_t v1, const(vec_base_t)* v2)
{
    if (v1)
    {
        assert(v2);
        assert(vec_numbits(v1)==vec_numbits(v2));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++)
            *v1 &= *v2;
    }
    else
        assert(!v2);
}

/********************************
 * Compute v1 = v2 & v3.
 */

@trusted
pure
void vec_and(vec_t v1, const(vec_base_t)* v2, const(vec_base_t)* v3)
{
    if (v1)
    {
        assert(v2 && v3);
        assert(vec_numbits(v1)==vec_numbits(v2) && vec_numbits(v1)==vec_numbits(v3));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++,v3++)
            *v1 = *v2 & *v3;
    }
    else
        assert(!v2 && !v3);
}

/********************************
 * Compute v1 ^= v2.
 */

@trusted
pure
void vec_xorass(vec_t v1, const(vec_base_t)* v2)
{
    if (v1)
    {
        assert(v2);
        assert(vec_numbits(v1)==vec_numbits(v2));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++)
            *v1 ^= *v2;
    }
    else
        assert(!v2);
}

/********************************
 * Compute v1 = v2 ^ v3.
 */

@trusted
pure
void vec_xor(vec_t v1, const(vec_base_t)* v2, const(vec_base_t)* v3)
{
    if (v1)
    {
        assert(v2 && v3);
        assert(vec_numbits(v1)==vec_numbits(v2) && vec_numbits(v1)==vec_numbits(v3));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++,v3++)
            *v1 = *v2 ^ *v3;
    }
    else
        assert(!v2 && !v3);
}

/********************************
 * Compute v1 |= v2.
 */

@trusted
pure
void vec_orass(vec_t v1, const(vec_base_t)* v2)
{
    if (v1)
    {
        debug assert(v2);
        debug assert(vec_numbits(v1)==vec_numbits(v2));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++)
            *v1 |= *v2;
    }
    else
        assert(!v2);
}

/********************************
 * Compute v1 = v2 | v3.
 */

@trusted
pure
void vec_or(vec_t v1, const(vec_base_t)* v2, const(vec_base_t)* v3)
{
    if (v1)
    {
        assert(v2 && v3);
        assert(vec_numbits(v1)==vec_numbits(v2) && vec_numbits(v1)==vec_numbits(v3));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++,v3++)
                *v1 = *v2 | *v3;
    }
    else
        assert(!v2 && !v3);
}

/********************************
 * Compute v1 -= v2.
 */

@trusted
pure
void vec_subass(vec_t v1, const(vec_base_t)* v2)
{
    if (v1)
    {
        assert(v2);
        assert(vec_numbits(v1)==vec_numbits(v2));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++)
            *v1 &= ~*v2;
    }
    else
        assert(!v2);
}

/********************************
 * Compute v1 = v2 - v3.
 */

@trusted
pure
void vec_sub(vec_t v1, const(vec_base_t)* v2, const(vec_base_t)* v3)
{
    if (v1)
    {
        assert(v2 && v3);
        assert(vec_numbits(v1)==vec_numbits(v2) && vec_numbits(v1)==vec_numbits(v3));
        const vtop = &v1[vec_dim(v1)];
        for (; v1 < vtop; v1++,v2++,v3++)
            *v1 = *v2 & ~*v3;
    }
    else
        assert(!v2 && !v3);
}

/****************
 * Clear vector.
 */

@trusted
pure
void vec_clear(vec_t v)
{
    if (v)
        memset(v, 0, v[0].sizeof * vec_dim(v));
}

/****************
 * Set vector.
 */

@trusted
pure
void vec_set(vec_t v)
{
    if (v)
    {
        memset(v, ~0, v[0].sizeof * vec_dim(v));
        vec_clearextrabits(v);
    }
}

/***************
 * Copy vector.
 */

@trusted
pure
void vec_copy(vec_t to, const vec_t from)
{
    if (to != from)
    {
        debug
        {
            if (!(to && from && vec_numbits(to) == vec_numbits(from)))
                printf("to = x%p, from = x%p, numbits(to) = %d, numbits(from) = %d\n",
                    to, from, cast(int) (to ? vec_numbits(to) : 0),
                    cast(int) (from ? vec_numbits(from): 0));
        }
        assert(to && from && vec_numbits(to) == vec_numbits(from));
        memcpy(to, from, to[0].sizeof * vec_dim(to));
    }
}

/****************
 * Return 1 if vectors are equal.
 */

@trusted
pure
int vec_equal(const vec_t v1, const vec_t v2)
{
    if (v1 == v2)
        return 1;
    assert(v1 && v2 && vec_numbits(v1) == vec_numbits(v2));
    return !memcmp(v1, v2, v1[0].sizeof * vec_dim(v1));
}

/********************************
 * Return 1 if (v1 & v2) == 0
 */

@trusted
pure
int vec_disjoint(const(vec_base_t)* v1, const(vec_base_t)* v2)
{
    assert(v1 && v2);
    assert(vec_numbits(v1) == vec_numbits(v2));
    const vtop = &v1[vec_dim(v1)];
    for (; v1 < vtop; v1++,v2++)
        if (*v1 & *v2)
            return 0;
    return 1;
}

/*********************
 * Clear any extra bits in vector.
 */

@trusted
pure
void vec_clearextrabits(vec_t v)
{
    assert(v);
    const n = vec_numbits(v);
    if (n & VECMASK)
        v[vec_dim(v) - 1] &= MASK(cast(uint)n) - 1;
}

/******************
 * Write out vector.
 */

pure
void vec_println(const vec_t v)
{
    debug
    {
        vec_print(v);
        fputc('\n',stdout);
    }
}

@trusted
pure
void vec_print(const vec_t v)
{
    debug
    {
        printf(" Vec %p, numbits %d dim %d", v, cast(int) vec_numbits(v), cast(int) vec_dim(v));
        if (v)
        {
            fputc('\t',stdout);
            for (size_t i = 0; i < vec_numbits(v); i++)
                fputc((vec_testbit(i,v)) ? '1' : '0',stdout);
        }
    }
}


