/**
 * Implementation of associative arrays.
 *
 */

#include <stdio.h>
#include <string.h>
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
};

static const AA bbinit = { NULL, };

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
        *a = bbinit;
        a->b = a->binit;
        a->b_length = sizeof(a->binit) / sizeof(a->binit[0]);
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
    e = new aaA();
    e->next = NULL;
    e->key = key;
    e->value = NULL;
    *pe = e;

    size_t nodes = ++(*paa)->nodes;
    //printf("length = %d, nodes = %d\n", paa.a.b.length, nodes);
    if (nodes > (*paa)->b_length * 4)
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
    if (!aa)
        return NULL;

    size_t len = aa->b_length;

    if (len)
    {
        size_t i = (size_t)key % len;
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
        AA newb = bbinit;
        AA *aa = *paa;
        size_t len = _aaLen(*paa);
        if (len)
        {   size_t i;

            for (i = 0; i < sizeof(prime_list)/sizeof(prime_list[0]) - 1; i++)
            {
                if (len <= prime_list[i])
                    break;
            }
            len = prime_list[i];
            newb.b = new aaA*[len];
            memset(newb.b, 0, len * sizeof(aaA*));
            newb.b_length = len;

            for (size_t k = 0; k < aa->b_length; k++)
            {   aaA *e = aa->b[k];
                while (e)
                {   aaA* enext = e->next;
                    size_t j = (size_t)e->key % len;
                    e->next = newb.b[j];
                    newb.b[j] = e;
                    e = enext;
                }
            }
            if (aa->b != aa->binit)
                delete[] aa->b;

            newb.nodes = aa->nodes;
        }

        **paa = newb;
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
