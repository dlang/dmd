/**
 * Interface for CodeView symbol debug info generation
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgcv.c, backend/cgcv.c)
 */

/* Header for cgcv.c    */

module dmd.backend.cgcv;

// Online documentation: https://dlang.org/phobos/dmd_backend_cgcv.html

import dmd.backend.cc : Classsym, Symbol;
import dmd.backend.dlist;
import dmd.backend.type;

@nogc:
nothrow:
@safe:

alias symlist_t = LIST*;

public import dmd.backend.dcgcv : cv_init, cv_typidx, cv_outsym, cv_func, cv_term, cv4_struct,
    cv_stringbytes, cv4_numericbytes, cv4_storenumeric, cv4_signednumericbytes,
    cv4_storesignednumeric, cv_debtyp, cv_namestring, cv4_typidx, cv4_arglist, cv4_callconv,
    cv_numdebtypes, debtyp_alloc;

public import dmd.backend.dwarfdbginf : dwarf_outsym;

/* =================== Added for MARS compiler ========================= */

alias idx_t = uint;        // type of type index

/* Data structure for a type record     */

struct debtyp_t
{
  align(1):
    uint prev;          // previous debtyp_t with same hash
    ushort length;      // length of following array
    ubyte[2] data;      // variable size array
}

struct Cgcv
{
    uint signature;
    symlist_t list;     // deferred list of symbols to output
    idx_t deb_offset;   // offset added to type index
    uint sz_idx;        // size of stored type index
    int LCFDoffset;
    int LCFDpointer;
    int FD_code;        // frame for references to code
}

__gshared Cgcv cgcv;

@trusted
void TOWORD(ubyte* a, uint b)
{
    *cast(ushort*)a = cast(ushort)b;
}

@trusted
void TOLONG(ubyte* a, uint b)
{
    *cast(uint*)a = b;
}

@trusted
void TOIDX(ubyte* a, uint b)
{
    if (cgcv.sz_idx == 4)
        TOLONG(a,b);
    else
        TOWORD(a,b);
}

enum DEBSYM = 5;               // segment of symbol info
enum DEBTYP = 6;               // segment of type info

/* ======================== Added for Codeview 8 =========================== */

public import dmd.backend.cv8;
