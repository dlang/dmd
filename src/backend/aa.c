// Compiler implementation of the D programming language
// Copyright (c) 2000-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/backend/aa.c


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "tinfo.h"
#include "aa.h"

// Implementation of associative array
// Auto-rehash and pre-allocate - Dave Fladebo

static unsigned long prime_list[] =
{
    97UL,         389UL,
    1543UL,       6151UL,
    24593UL,      98317UL,
    393241UL,     1572869UL,
    6291469UL,    25165843UL,
    100663319UL,  402653189UL,
    1610612741UL, 4294967291UL
};


/**********************************
 * Align to next pointer boundary, so value
 * will be aligned.
 */

size_t aligntsize(size_t tsize)
{
    // Is pointer alignment on the x64 4 bytes or 8?
    return (tsize + sizeof(size_t) - 1) & ~(sizeof(size_t) - 1);
}

static int hashCmp(hash_t lhs, hash_t rhs)
{
    if (lhs == rhs)
        return 0;
    else if (lhs < rhs)
        return -1;
    return 1;
}

/**********************************
 * Constructor.
 */

AArray::AArray(TypeInfo *keyti, size_t valuesize)
{
    this->keyti = keyti;
    this->valuesize = valuesize;
    this->nodes = 0;
    this->buckets = NULL;
    this->buckets_length = 0;
}


/**********************************
 * Destructor.
 */

void delnodes(aaA* e)
{   aaA* en;

    do
    {
        if (e->left)
        {   if (!e->right)
            {   en = e;
                e = e->left;
                delete [] en;
                continue;
            }
            delnodes(e->left);
        }
        en = e;
        e = e->right;
        delete [] en;
    } while (e != NULL);
}

AArray::~AArray()
{
    if (buckets)
    {
        for (size_t i = 0; i < buckets_length; i++)
        {   aaA* e = buckets[i];

            if (e)
                delnodes(e);    // recursively free all nodes
        }
        delete [] buckets;
    }
}


/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there.
 */

void* AArray::get(void *pkey)
{
    //printf("AArray::get()\n");
    size_t i;
    aaA* e;
    size_t keysize = aligntsize(keyti->tsize());

    if (!buckets_length)
    {
        typedef aaA* aaAp;
        buckets_length = prime_list[0];
        buckets = new aaAp[buckets_length];
        memset(buckets, 0, buckets_length * sizeof(buckets[0]));
    }

    hash_t key_hash = keyti->getHash(pkey);
    i = key_hash % buckets_length;
    //printf("key_hash = %x, buckets_length = %d, i = %d\n", key_hash, buckets_length, i);
    aaA** pe = &buckets[i];
    while ((e = *pe) != NULL)
    {   int c;

        c = hashCmp(key_hash, e->hash);
        if (c == 0)
        {
            c = keyti->compare(pkey, e + 1);
            if (c == 0)
                goto Lret;
        }

        if (c < 0)
            pe = &e->left;
        else
            pe = &e->right;
    }

    // Not found, create new elem
    //printf("create new one\n");
    e = (aaA *) new char[sizeof(aaA) + keysize + valuesize];
    memcpy(e + 1, pkey, keysize);
    memset((unsigned char *)(e + 1) + keysize, 0, valuesize);
    e->hash = key_hash;
    e->left = NULL;
    e->right = NULL;
    *pe = e;

    ++nodes;
    //printf("length = %d, nodes = %d\n", buckets_length, nodes);
    if (nodes > buckets_length * 4)
    {
        //printf("rehash()\n");
        rehash();
    }

Lret:
    return (void *)((char *)(e + 1) + keysize);
}


/*************************************************
 * Determine if key is in aa.
 * Returns:
 *      NULL    not in aa
 *      !=NULL  in aa, return pointer to value
 */

void* AArray::in(void *pkey)
{
    //printf("_aaIn(), .length = %d, .ptr = %x\n", aa.a.length, cast(uint)aa.a.ptr);
    size_t len = buckets_length;

    if (len)
    {
        hash_t key_hash = keyti->getHash(pkey);
        //printf("hash = %d\n", key_hash);
        size_t i = key_hash % len;
        aaA *e = buckets[i];
        while (e != NULL)
        {   int c;

            c = hashCmp(key_hash, e->hash);
            if (c == 0)
            {
                c = keyti->compare(pkey, e + 1);
                if (c == 0)
                    return (char *)(e + 1) + aligntsize(keyti->tsize());
            }

            if (c < 0)
                e = e->left;
            else
                e = e->right;
        }
    }

    // Not found
    return NULL;
}


/*************************************************
 * Delete key entry in aa[].
 * If key is not in aa[], do nothing.
 */

void AArray::del(void *pkey)
{
    aaA* e;

    if (buckets_length)
    {
        hash_t key_hash = keyti->getHash(pkey);
        //printf("hash = %d\n", key_hash);
        size_t i = key_hash % buckets_length;
        aaA** pe = &buckets[i];
        while ((e = *pe) != NULL)       // NULL means not found
        {   int c;

            c = hashCmp(key_hash, e->hash);
            if (c == 0)
            {
                c = keyti->compare(pkey, e + 1);
                if (c == 0)
                {
                    if (!e->left && !e->right)
                    {
                        *pe = NULL;
                    }
                    else if (e->left && !e->right)
                    {
                        *pe = e->left;
                         e->left = NULL;
                    }
                    else if (!e->left && e->right)
                    {
                        *pe = e->right;
                         e->right = NULL;
                    }
                    else
                    {
                        *pe = e->left;
                        e->left = NULL;
                        do
                            pe = &(*pe)->right;
                        while (*pe);
                        *pe = e->right;
                        e->right = NULL;
                    }

                    nodes--;

                    delete[] e;
                    break;
                }
            }

            if (c < 0)
                pe = &e->left;
            else
                pe = &e->right;
        }
    }
}


/********************************************
 * Produce array of keys from aa.
 */

void *AArray::keys()
{
    void *p = NULL;

    if (nodes)
    {
        size_t keysize = keyti->tsize();

        typedef char* charp;
        p = (void *)new charp[nodes * keysize];
        void *q = p;
        for (size_t i = 0; i < buckets_length; i++)
        {   aaA* e = buckets[i];

            if (e)
                q = keys_x(e, q, keysize);
        }
    }
    return p;
}

void *AArray::keys_x(aaA* e, void *p, size_t keysize)
{
    do
    {
        memcpy(p, e + 1, keysize);
        if (e->left)
        {   if (!e->right)
            {   e = e->left;
                continue;
            }
            p = keys_x(e->left, p, keysize);
        }
        e = e->right;
    } while (e != NULL);
    return p;
}

/********************************************
 * Produce array of values from aa.
 */

void *AArray::values()
{
    void *p = NULL;

    if (nodes)
    {
        p = (void *)new char[nodes * valuesize];
        void *q = p;
        for (size_t i = 0; i < buckets_length; i++)
        {   aaA *e = buckets[i];

            if (e)
                q = values_x(e, q);
        }
    }
    return p;
}

void *AArray::values_x(aaA *e, void *p)
{
    size_t keysize = keyti->tsize();
    do
    {
        memcpy(p,
               (char *)(e + 1) + keysize,
               valuesize);
        p = (void *)((char *)p + valuesize);
        if (e->left)
        {   if (!e->right)
            {   e = e->left;
                continue;
            }
            p = values_x(e->left, p);
        }
        e = e->right;
    } while (e != NULL);
    return p;
}


/********************************************
 * Rehash an array.
 */

void AArray::rehash()
{
    //printf("Rehash\n");
    if (buckets_length)
    {
        size_t len = nodes;

        if (len)
        {   size_t i;
            aaA** newbuckets;
            size_t newbuckets_length;

            for (i = 0; i < sizeof(prime_list)/sizeof(prime_list[0]) - 1; i++)
            {
                if (len <= prime_list[i])
                    break;
            }
            newbuckets_length = prime_list[i];
            typedef aaA* aaAp;
            newbuckets = new aaAp[newbuckets_length];
            memset(newbuckets, 0, newbuckets_length * sizeof(newbuckets[0]));

            for (i = 0; i < buckets_length; i++)
            {   aaA *e = buckets[i];

                if (e)
                    rehash_x(e, newbuckets, newbuckets_length);
            }

            delete[] buckets;
            buckets = newbuckets;
            buckets_length = newbuckets_length;
        }
    }
}

void AArray::rehash_x(aaA* olde, aaA** newbuckets, size_t newbuckets_length)
{
    while (1)
    {
        aaA* left = olde->left;
        aaA* right = olde->right;
        olde->left = NULL;
        olde->right = NULL;

        aaA* e;

        //printf("rehash %p\n", olde);
        hash_t key_hash = olde->hash;
        size_t i = key_hash % newbuckets_length;
        aaA** pe = &newbuckets[i];
        while ((e = *pe) != NULL)
        {   int c;

            //printf("\te = %p, e->left = %p, e->right = %p\n", e, e->left, e->right);
            assert(e->left != e);
            assert(e->right != e);
            c = hashCmp(key_hash, e->hash);
            if (c == 0)
                c = keyti->compare(olde + 1, e + 1);
            if (c < 0)
                pe = &e->left;
            else if (c > 0)
                pe = &e->right;
            else
                assert(0);
        }
        *pe = olde;

        if (right)
        {
            if (!left)
            {   olde = right;
                continue;
            }
            rehash_x(right, newbuckets, newbuckets_length);
        }
        if (!left)
            break;
        olde = left;
    }
}


/*********************************************
 * For each element in the AArray,
 * call dg(void *parameter, void *pkey, void *pvalue)
 * If dg returns !=0, stop and return that value.
 */

typedef int (*dg2_t)(void *, void *, void *);

int AArray::apply(void *parameter, dg2_t dg)
{   int result = 0;

    //printf("_aaApply(aa = %p, keysize = %d, dg = %p)\n", this, keyti->tsize(), dg);

    if (nodes)
    {
        size_t keysize = aligntsize(keyti->tsize());

        for (size_t i = 0; i < buckets_length; i++)
        {   aaA* e = buckets[i];

            if (e)
            {
                result = apply_x(e, dg, keysize, parameter);
                if (result)
                    break;
            }
        }
    }
    return result;
}

int AArray::apply_x(aaA* e, dg2_t dg, size_t keysize, void *parameter)
{   int result;

    do
    {
        //printf("apply_x(e = %p, dg = %p)\n", e, dg);
        result = (*dg)(parameter, e + 1, (char *)(e + 1) + keysize);
        if (result)
            break;
        if (e->right)
        {   if (!e->left)
            {
                e = e->right;
                continue;
            }
            result = apply_x(e->right, dg, keysize, parameter);
            if (result)
                break;
        }
        e = e->left;
    } while (e);

    return result;
}


