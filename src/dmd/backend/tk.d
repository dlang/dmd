/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/tk.c, backend/tk.c)
 */

import core.stdc.stdlib : malloc, calloc, realloc, free;
import core.stdc.string : strdup;

extern (C) @nogc nothrow:
char* mem_strdup(const char* p) { return strdup(p); }
void* mem_malloc(size_t u) { return malloc(u); }
void* mem_fmalloc(size_t u) { return malloc(u); }
void* mem_calloc(size_t u) { return calloc(u, 1); }
void* mem_realloc(void* p, size_t u) { return realloc(p, u); }
void mem_free(void* p) { free(p); }
