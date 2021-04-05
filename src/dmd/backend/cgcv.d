/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgcv.c, backend/cgcv.c)
 */

/* Header for cgcv.c    */

module dmd.backend.cgcv;

// Online documentation: https://dlang.org/phobos/dmd_backend_cgcv.html

import dmd.backend.cc : Classsym, Symbol;
import dmd.backend.dlist;
import dmd.backend.type;

extern (C++):
@nogc:
nothrow:
@safe:

alias symlist_t = LIST*;

extern __gshared char* ftdbname;

void cv_init();
uint cv_typidx(type* t);
void cv_outsym(Symbol* s);
void cv_func(Symbol* s);
void cv_term();

void dwarf_outsym(Symbol* s);

uint cv4_struct(Classsym*, int);


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

debtyp_t* debtyp_alloc(uint length);
int cv_stringbytes(const(char)* name);
uint cv4_numericbytes(uint value);
void cv4_storenumeric(ubyte* p, uint value);
uint cv4_signednumericbytes(int value);
void cv4_storesignednumeric(ubyte* p, int value);
idx_t cv_debtyp(debtyp_t* d);
int cv_namestring(ubyte* p, const(char)* name, int length = -1);
uint cv4_typidx(type* t);
idx_t cv4_arglist(type* t, uint* pnparam);
ubyte cv4_callconv(type* t);
idx_t cv_numdebtypes();

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

void cv8_initfile(const(char)* filename);
void cv8_termfile(const(char)* objfilename);
void cv8_initmodule(const(char)* filename, const(char)* modulename);
void cv8_termmodule();
void cv8_func_start(Symbol* sfunc);
void cv8_func_term(Symbol* sfunc);
//void cv8_linnum(Srcpos srcpos, uint offset);  // Srcpos isn't available yet
void cv8_outsym(Symbol* s);
void cv8_udt(const(char)* id, idx_t typidx);
int cv8_regnum(Symbol* s);
idx_t cv8_fwdref(Symbol* s);
idx_t cv8_darray(type* tnext, idx_t etypidx);
idx_t cv8_ddelegate(type* t, idx_t functypidx);
idx_t cv8_daarray(type* t, idx_t keyidx, idx_t validx);


