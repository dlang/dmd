
// Copyright (c) 2010-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/**
 * Implementation of associative arrays.
 *
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include "aav.h"

static const size_t prime_list[] = {
              31UL,
              97UL,            389UL,
            1543UL,           6151UL,
           24593UL,          98317UL,
          393241UL,        1572869UL,
         6291469UL,       25165843UL,
       100663319UL,      402653189UL,
      1610612741UL,     4294967291UL,
};

struct aaA
{
    aaA *next;
    Key key;
    Value value;
};

struct AA
{
    aaA* *b;
    size_t b_length;
    size_t nodes;       // total number of aaA nodes
    aaA* binit[4];      // initial value of b[]

    aaA aafirst;        // a lot of these AA's have only one entry
};

/****************************************************
 * Determine number of entries in associative array.
 */

size_t _aaLen(AA* aa)
{
    return aa ? aa->nodes : 0;
}


/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there.
 */

Value* _aaGet(AA** paa, Key key)
{
    //printf("paa = %p\n", paa);

    if (!*paa)
    {   AA *a = new AA();
        a->b = a->binit;
        a->b_length = sizeof(a->binit) / sizeof(a->binit[0]);
        a->nodes = 0;
        a->binit[0] = NULL;
        a->binit[1] = NULL;
        a->binit[2] = NULL;
        a->binit[3] = NULL;
        *paa = a;
        assert((*paa)->b_length == 4);
    }
    //printf("paa = %p, *paa = %p\n", paa, *paa);

    assert((*paa)->b_length);
    size_t i = (size_t)key % (*paa)->b_length;
    aaA** pe = &(*paa)->b[i];
    aaA *e;
    while ((e = *pe) != NULL)
    {
        if (key == e->key)
            return &e->value;
        pe = &e->next;
    }

    // Not found, create new elem
    //printf("create new one\n");

    size_t nodes = ++(*paa)->nodes;
    e = (nodes != 1) ? new aaA() : &(*paa)->aafirst;
    //e = new aaA();
    e->next = NULL;
    e->key = key;
    e->value = NULL;
    *pe = e;

    //printf("length = %d, nodes = %d\n", (*paa)->b_length, nodes);
    if (nodes > (*paa)->b_length * 2)
    {
        //printf("rehash\n");
        _aaRehash(paa);
    }

    return &e->value;
}


/*************************************************
 * Get value in associative array indexed by key.
 * Returns NULL if it is not already there.
 */

Value _aaGetRvalue(AA* aa, Key key)
{
    //printf("_aaGetRvalue(key = %p)\n", key);
    if (aa)
    {
        size_t i;
        size_t len = aa->b_length;
        if (len == 4)
            i = (size_t)key & 3;
        else if (len == 31)
            i = (size_t)key % 31;
        else
            i = (size_t)key % len;
        aaA* e = aa->b[i];
        while (e)
        {
            if (key == e->key)
                return e->value;
            e = e->next;
        }
    }
    return NULL;    // not found
}


/********************************************
 * Rehash an array.
 */

void _aaRehash(AA** paa)
{
    //printf("Rehash\n");
    if (*paa)
    {
        AA *aa = *paa;
        size_t len = _aaLen(aa);
        if (len)
        {   size_t i;

            for (i = 0; i < sizeof(prime_list)/sizeof(prime_list[0]) - 1; i++)
            {
                if (len <= prime_list[i])
                    break;
            }
            len = prime_list[i];
            aaA** newb = new aaA*[len];
            memset(newb, 0, len * sizeof(aaA*));

            for (size_t k = 0; k < aa->b_length; k++)
            {   aaA *e = aa->b[k];
                while (e)
                {   aaA* enext = e->next;
                    size_t j = (size_t)e->key % len;
                    e->next = newb[j];
                    newb[j] = e;
                    e = enext;
                }
            }
            if (aa->b != aa->binit)
                delete[] aa->b;

            aa->b = newb;
            aa->b_length = len;
        }
    }
}


#if UNITTEST

void unittest_aa()
{
    AA* aa = NULL;
    Value v = _aaGetRvalue(aa, NULL);
    assert(!v);
    Value *pv = _aaGet(&aa, NULL);
    assert(pv);
    *pv = (void *)3;
    v = _aaGetRvalue(aa, NULL);
    assert(v == (void *)3);
}

#endif
