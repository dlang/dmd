/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/aa.h
 */


#ifndef AA_H
#define AA_H

#include <stdlib.h>

#include "tinfo.h"

struct aaA
{
    aaA *left;
    aaA *right;
    hash_t hash;
    /* key   */
    /* value */
};

struct AArray
{
    TypeInfo *keyti;
    size_t valuesize;
    size_t nodes;

    aaA** buckets;
    size_t buckets_length;

    AArray(TypeInfo *keyti, size_t valuesize);

    ~AArray();

    size_t length()
    {
        return nodes;
    }

    /*************************************************
     * Get pointer to value in associative array indexed by key.
     * Add entry for key if it is not already there.
     */

    void* get(void *pkey);

    void* get(char *string) { return get(&string); }

    /*************************************************
     * Determine if key is in aa.
     * Returns:
     *  null    not in aa
     *  !=null  in aa, return pointer to value
     */

    void* in(void *pkey);

    void* in(char *string) { return in(&string); }

    /*************************************************
     * Delete key entry in aa[].
     * If key is not in aa[], do nothing.
     */

    void del(void *pkey);

    /********************************************
     * Produce array of keys from aa.
     */

    void *keys();

    /********************************************
     * Produce array of values from aa.
     */

    void *values();

    /********************************************
     * Rehash an array.
     */

    void rehash();

    /*********************************************
     * For each element in the AArray,
     * call dg(void *parameter, void *pkey, void *pvalue)
     * If dg returns !=0, stop and return that value.
     */

    typedef int (*dg2_t)(void *, void *, void *);

    int apply(void *parameter, dg2_t dg);

  private:
    void *keys_x(aaA* e, void *p, size_t keysize);
    void *values_x(aaA *e, void *p);
    void rehash_x(aaA* olde, aaA** newbuckets, size_t newbuckets_length);
    int apply_x(aaA* e, dg2_t dg, size_t keysize, void *parameter);
};

#endif

