/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/outbuf.c, backend/outbuf.c)
 */

// Output buffer

#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <stdio.h>

#include "cc.h"

#include "outbuf.h"
#include "mem.h"

#if DEBUG
static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"
#else
#include        <assert.h>
#endif

Outbuffer::Outbuffer()
{
    buf = NULL;
    pend = NULL;
    p = NULL;
    origbuf = NULL;
}

Outbuffer::Outbuffer(d_size_t initialSize)
{
    buf = NULL;
    pend = NULL;
    p = NULL;
    origbuf = NULL;

    enlarge(initialSize);
}

Outbuffer::~Outbuffer()
{
    if (buf != origbuf)
    {
#if MEM_DEBUG
        mem_free(buf);
#else
        if (buf)
            free(buf);
#endif
    }
}

// Enlarge buffer size so there's at least nbytes available
void Outbuffer::enlarge(unsigned nbytes)
{
    const d_size_t oldlen = pend - buf;
    const d_size_t used = p - buf;

    d_size_t len = used + nbytes;
    if (len <= oldlen)
        return;

    const d_size_t newlen = oldlen + (oldlen >> 1);   // oldlen * 1.5
    if (len < newlen)
        len = newlen;
    len = (len + 15) & ~15;

#if MEM_DEBUG
    if (buf == origbuf)
    {
        buf = (unsigned char *) mem_malloc(len);
        if (buf)
            memcpy(buf, origbuf, oldlen);
    }
    else
        buf = (unsigned char *)mem_realloc(buf, len);
#else
     if (buf == origbuf && origbuf)
     {
         buf = (unsigned char *) malloc(len);
         if (buf)
             memcpy(buf, origbuf, used);
     }
     else
         buf = (unsigned char *) realloc(buf,len);
#endif
    if (!buf)
    {
        fprintf(stderr, "Fatal Error: Out of memory");
        exit(EXIT_FAILURE);
    }

    pend = buf + len;
    p = buf + used;
}
