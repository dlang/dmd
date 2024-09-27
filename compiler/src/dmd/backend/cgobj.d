/**
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgobj.d, backend/cgobj.d)
 */
module dmd.backend.cgobj;

import core.stdc.stdio;
import dmd.backend.barray;
import dmd.backend.code;

nothrow:
@safe:

__gshared
{
    extern (C++) Rarray!(seg_data*) SegData;
}

/***********************************
 * Upper case a string in place.
 * Params:
 *      s = string to uppercase
 * Returns:
 *      uppercased string
 */
@trusted
extern (C) char* strupr(char* s)
{
    for (char* p = s; *p; ++p)
    {
        char c = *p;
        if ('a' <= c && c <= 'z')
            *p = cast(char)(c - 'a' + 'A');
    }
    return s;
}
