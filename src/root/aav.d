// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.aav;

import core.stdc.stdlib, core.stdc.string;
import ddmd.root.rmem;

extern (C++) size_t hash(size_t a)
{
    a ^= (a >> 20) ^ (a >> 12);
    return a ^ (a >> 7) ^ (a >> 4);
}

alias Key = void*;
alias Value = void*;

struct aaA
{
    aaA* next;
    Key key;
    Value value;
}

struct AA
{
    aaA** b;
    size_t b_length;
    size_t nodes; // total number of aaA nodes
    aaA*[4] binit; // initial value of b[]
    aaA aafirst; // a lot of these AA's have only one entry
}

/****************************************************
 * Determine number of entries in associative array.
 */
extern (C++) size_t dmd_aaLen(AA* aa)
{
    return aa ? aa.nodes : 0;
}

/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there, returning a pointer to a null Value.
 * Create the associative array if it does not already exist.
 */
extern (C++) Value* dmd_aaGet(AA** paa, Key key)
{
    //printf("paa = %p\n", paa);
    if (!*paa)
    {
        AA* a = cast(AA*)mem.xmalloc(AA.sizeof);
        a.b = cast(aaA**)a.binit;
        a.b_length = 4;
        a.nodes = 0;
        a.binit[0] = null;
        a.binit[1] = null;
        a.binit[2] = null;
        a.binit[3] = null;
        *paa = a;
        assert((*paa).b_length == 4);
    }
    //printf("paa = %p, *paa = %p\n", paa, *paa);
    assert((*paa).b_length);
    size_t i = hash(cast(size_t)key) & ((*paa).b_length - 1);
    aaA** pe = &(*paa).b[i];
    aaA* e;
    while ((e = *pe) !is null)
    {
        if (key == e.key)
            return &e.value;
        pe = &e.next;
    }
    // Not found, create new elem
    //printf("create new one\n");
    size_t nodes = ++(*paa).nodes;
    e = (nodes != 1) ? cast(aaA*)mem.xmalloc(aaA.sizeof) : &(*paa).aafirst;
    //e = new aaA();
    e.next = null;
    e.key = key;
    e.value = null;
    *pe = e;
    //printf("length = %d, nodes = %d\n", (*paa)->b_length, nodes);
    if (nodes > (*paa).b_length * 2)
    {
        //printf("rehash\n");
        dmd_aaRehash(paa);
    }
    return &e.value;
}

/*************************************************
 * Get value in associative array indexed by key.
 * Returns NULL if it is not already there.
 */
extern (C++) Value dmd_aaGetRvalue(AA* aa, Key key)
{
    //printf("_aaGetRvalue(key = %p)\n", key);
    if (aa)
    {
        size_t i;
        size_t len = aa.b_length;
        i = hash(cast(size_t)key) & (len - 1);
        aaA* e = aa.b[i];
        while (e)
        {
            if (key == e.key)
                return e.value;
            e = e.next;
        }
    }
    return null; // not found
}

/********************************************
 * Rehash an array.
 */
extern (C++) void dmd_aaRehash(AA** paa)
{
    //printf("Rehash\n");
    if (*paa)
    {
        AA* aa = *paa;
        if (aa)
        {
            size_t len = aa.b_length;
            if (len == 4)
                len = 32;
            else
                len *= 4;
            aaA** newb = cast(aaA**)mem.xmalloc(aaA.sizeof * len);
            memset(newb, 0, len * (aaA*).sizeof);
            for (size_t k = 0; k < aa.b_length; k++)
            {
                aaA* e = aa.b[k];
                while (e)
                {
                    aaA* enext = e.next;
                    size_t j = hash(cast(size_t)e.key) & (len - 1);
                    e.next = newb[j];
                    newb[j] = e;
                    e = enext;
                }
            }
            if (aa.b != cast(aaA**)aa.binit)
                mem.xfree(aa.b);
            aa.b = newb;
            aa.b_length = len;
        }
    }
}

unittest
{
    AA* aa = null;
    Value v = dmd_aaGetRvalue(aa, null);
    assert(!v);
    Value* pv = dmd_aaGet(&aa, null);
    assert(pv);
    *pv = cast(void*)3;
    v = dmd_aaGetRvalue(aa, null);
    assert(v == cast(void*)3);
}
