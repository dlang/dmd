
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/tk.h
 */

#include        <stdio.h>
#include        <stdlib.h>
#include        <string.h>

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#include        "mem.h"
#include        "filespec.c"

#if 0
#define malloc          ph_malloc
#define calloc(x,y)     ph_calloc((x) * (y))
#define realloc         ph_realloc
#define free            ph_free
#endif

#if !MEM_DEBUG
#define MEM_NOMEMCOUNT  1
#define MEM_NONEW       1
#endif
#include        "mem.c"
#include        "list.c"
#include        "vec.c"
