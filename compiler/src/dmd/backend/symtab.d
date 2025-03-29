/**
 * Symbol table array.
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/symtab.d, backend/_symtab.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_symtab.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/symtab.d
 */

module dmd.backend.symtab;

import core.stdc.stdio;
import core.stdc.stdlib;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.mem;
import dmd.backend.barray;

nothrow:
@safe:

alias SYMIDX = size_t;    // symbol table index

alias symtab_t = Barray!(Symbol*);
