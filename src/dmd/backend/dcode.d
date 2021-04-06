/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1987-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dcode.d, backend/dcode.d)
 */

module dmd.backend.dcode;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.global;
import dmd.backend.mem;

extern (C++):

nothrow:
@safe:

__gshared
code *code_list = null;

/************************************
 * Allocate a chunk of code's and add them to
 * code_list.
 */
@trusted
code *code_chunk_alloc()
{
    const size_t n = 4096 / code.sizeof;
    //printf("code_chunk_alloc() n = %d\n", n);
    code *chunk = cast(code *)mem_fmalloc(n * code.sizeof);
    for (size_t i = 0; i < n - 1; ++i)
    {
        chunk[i].next = &chunk[i + 1];
    }
    chunk[n - 1].next = null;
    code_list = chunk;
    return chunk;
}

/*****************
 * Allocate code
 */

@trusted
code *code_calloc()
{
    //printf("code %d\n", code.sizeof);
    code *c = code_list ? code_list : code_chunk_alloc();
    code_list = code_next(c);
    memset(c, 0, code.sizeof);

    //dbg_printf("code_calloc: %p\n",c);
    return c;
}


/*****************
 * Free code
 */

@trusted
void code_free(code *cstart)
{
    if (cstart)
    {
        code *c = cstart;
        while (1)
        {
            if (c.Iop == ASM)
            {
                mem_free(c.IEV1.bytes);
            }
            code *cnext = code_next(c);
            if (!cnext)
                break;
            c = cnext;
        }
        c.next = code_list;
        code_list = cstart;
    }
}

/*****************
 * Terminate code
 */

@trusted
void code_term()
{
static if (TERMCODE)
{
    code *cn;
    int count = 0;

    while (code_list)
    {   cn = code_next(code_list);
        //mem_ffree(code_list);
        code_list = cn;
        count++;
    }
    debug printf("Max # of codes = %d\n",count);
}
else
{
debug
{
    int count = 0;

    for (code *cn = code_list; cn; cn = code_next(cn))
        count++;
    printf("Max # of codes = %d\n",count);
}
}
}

}
