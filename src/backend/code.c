// Copyright (C) 1987-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "global.h"

static code *code_list;

/*****************
 * Allocate code
 */

code *code_calloc()
{
    //printf("code %d\n", sizeof(code));
    code *c = code_list;
    if (!c)
    {
        const size_t n = 4096 / sizeof(*c);
        code *chunk = (code *)mem_fmalloc(n * sizeof(code));
        for (size_t i = 0; i < n - 1; ++i)
        {
            code_next(&chunk[i]) = &chunk[i + 1];
        }
        code_next(&chunk[n - 1]) = NULL;
        code_list = chunk;
        c = chunk;
    }

    code_list = code_next(c);
    MEMCLEAR(c, sizeof(*c));

    //dbg_printf("code_calloc: %p\n",c);
    return c;
}


/*****************
 * Free code
 */

void code_free(code *cstart)
{
    if (cstart)
    {
        code *c = cstart;
        while (1)
        {
            if (c->Iop == ASM)
            {
                mem_free(c->IEV1.as.bytes);
            }
            code *cnext = code_next(c);
            if (!cnext)
                break;
            c = cnext;
        }
        code_next(c) = code_list;
        code_list = cstart;
    }
}

/*****************
 * Terminate code
 */

void code_term()
{
#if TERMCODE
    code *cn;
    int count = 0;

    while (code_list)
    {   cn = code_next(code_list);
        //mem_ffree(code_list);
        code_list = cn;
        count++;
    }
#ifdef DEBUG
    printf("Max # of codes = %d\n",count);
#endif
#else
#ifdef DEBUG
    int count = 0;

    for (code *cn = code_list; cn; cn = code_next(cn))
        count++;
    printf("Max # of codes = %d\n",count);
#endif
#endif
}

#endif // !SPP
