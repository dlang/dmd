/**
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/mem.d, backend/mem.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/mem.d
 */


module dmd.backend.mem;

import core.stdc.stdlib : malloc, calloc, realloc, free;
import core.stdc.string : strdup;

import dmd.backend.global : err_nomem;

extern (C):

nothrow:
@nogc:
@safe:

@trusted
char* mem_strdup(const char* s)
{
    auto p = strdup(s);
    if (!p && s)
        err_nomem();
    return p;
}

@trusted
void* mem_malloc(size_t u)
{
    auto p = malloc(u);
    if (!p && u)
        err_nomem();
    return p;
}

alias mem_fmalloc = mem_malloc;

@trusted
void* mem_calloc(size_t u)
{
    auto p = calloc(u, 1);
    if (!p && u)
        err_nomem();
    return p;
}

@trusted
void* mem_realloc(void* p, size_t u)
{
    p = realloc(p, u);
    if (!p && u)
        err_nomem();
    return p;
}

@trusted
void mem_free(void* p) { free(p); }

@trusted
void mem_ffree(void *) { }
