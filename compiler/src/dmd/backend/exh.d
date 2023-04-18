/**
 * Interface for exception handling support
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1993-1998 by Symantec
 *              Copyright (C) 2000-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/exh.d, backend/exh.d)
 */

module dmd.backend.exh;

// Online documentation: https://dlang.org/phobos/dmd_backend_exh.html

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.el;
import dmd.backend.type;

extern (C++):
@nogc:
nothrow:

struct Aobject
{
    Symbol *AOsym;              // Symbol for active object
    targ_size_t AOoffset;       // offset from that object
    Symbol *AOfunc;             // cleanup function
}

// FIXME: this is implemented in the frontend, dmd/eh.d,
// importing it results in linker errors for dmd.backend.*__ModuleInfoZ
// because the backend is built with betterC while the frontend is not
Symbol *except_gentables();

public import dmd.backend.pdata : win64_pdata;
