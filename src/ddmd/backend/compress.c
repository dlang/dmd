/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/compress.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if TARGET_WINDOS

static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"
#else
#include        <assert.h>
#endif

/****************************************
 * Find longest match of pattern[0..plen] in dict[0..dlen].
 * Returns:
 *      true if match found
 */

static bool longest_match(char *dict, int dlen, char *pattern, int plen,
        int *pmatchoff, int *pmatchlen)
{
    int matchlen = 0;
    int matchoff;

    char c = pattern[0];
    for (int i = 0; i < dlen; i++)
    {
        if (dict[i] == c)
        {
            int len = dlen - i;
            if (plen < len)
                len = plen;
            int j;
            for (j = 1; j < len; j++)
            {
                if (dict[i + j] != pattern[j])
                    break;
            }
            if (j >= matchlen)
            {
                matchlen = j;
                matchoff = i;
            }
        }
    }

    if (matchlen > 1)
    {
        *pmatchlen = matchlen;
        *pmatchoff = matchoff;
        return true;                    // found a match
    }
    return false;                       // no match
}

/******************************************
 * Compress an identifier for name mangling purposes.
 * Format is if ASCII, then it's just the char.
 * If high bit set, then it's a length/offset pair
 *
 * Params:
 *      id = string to compress
 *      idlen = length of id
 *      plen = where to store length of compressed result
 * Returns:
 *      malloc'd compressed 0-terminated identifier
 */

char *id_compress(char *id, int idlen, size_t *plen)
{
    int count = 0;
    char *p = (char *)malloc(idlen + 1);
    for (int i = 0; i < idlen; i++)
    {
        int matchoff;
        int matchlen;

        int j = 0;
        if (i > 1023)
            j = i - 1023;

        if (longest_match(id + j, i - j, id + i, idlen - i, &matchoff, &matchlen))
        {   int off;

            matchoff += j;
            off = i - matchoff;
            //printf("matchoff = %3d, matchlen = %2d, off = %d\n", matchoff, matchlen, off);
            assert(off >= matchlen);

            if (off <= 8 && matchlen <= 8)
            {
                p[count] = 0xC0 | ((off - 1) << 3) | (matchlen - 1);
                count++;
                i += matchlen - 1;
                continue;
            }
            else if (matchlen > 2 && off < 1024)
            {
                if (matchlen >= 1024)
                    matchlen = 1023;    // longest representable match
                p[count + 0] = 0x80 | ((matchlen >> 4) & 0x38) | ((off >> 7) & 7);
                p[count + 1] = 0x80 | matchlen;
                p[count + 2] = 0x80 | off;
                count += 3;
                i += matchlen - 1;
                continue;
            }
        }
        p[count] = id[i];
        count++;
    }
    p[count] = 0;
    //printf("old size = %d, new size = %d\n", idlen, count);
    assert(count <= idlen);
    *plen = count;
    return p;
}


