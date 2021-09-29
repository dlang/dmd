
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/aa.h
 */

class AssocArrayLiteralExp;

#pragma once

#include "root/dsystem.h"

struct AALayout
{
    const uint32_t init_size;
    const uint32_t keysz;
    const uint32_t valsz;
    const uint32_t valalign;
    const uint32_t valoff;
    const uint32_t padSize;
    const uint32_t entrySize;
};

struct AABucket
{
    uint64_t hash;
    uint32_t elementIndex;
};

struct BucketUsageInfo
{
    uint32_t used;
    uint32_t first_used;
    uint32_t last_used;
};

/// compute memory requirements of AA-literal
extern AALayout computeLayout(AssocArrayLiteralExp* aale);

/// Prepare the bucket array for emission
extern BucketUsageInfo MakeAALiteralInfo(AssocArrayLiteralExp* aale, AALayout aaLayout, AABucket* bucketMem);
