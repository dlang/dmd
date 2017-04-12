/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cgcv.h
 */

/* Header for cgcv.c    */

#ifndef CGCV_H
#define CGCV_H
//#pragma once

struct Symbol;
struct Classsym;

extern char *ftdbname;

void cv_init();
unsigned cv_typidx ( type *t );
void cv_outsym ( Symbol *s );
void cv_func ( Symbol *s );
void cv_term();
unsigned cv4_struct(Classsym *,int);


/* =================== Added for MARS compiler ========================= */

typedef unsigned idx_t;        // type of type index

/* Data structure for a type record     */

#pragma pack(1)

struct debtyp_t
{
    unsigned prev;              // previous debtyp_t with same hash
    unsigned short length;      // length of following array
    unsigned char data[2];      // variable size array
};

#pragma pack()

struct Cgcv
{
    unsigned signature;
    symlist_t list;             // deferred list of symbols to output
    idx_t deb_offset;           // offset added to type index
    unsigned sz_idx;            // size of stored type index
    int LCFDoffset;
    int LCFDpointer;
    int FD_code;                // frame for references to code
};

extern Cgcv cgcv;

debtyp_t * debtyp_alloc(unsigned length);
int cv_stringbytes(const char *name);
unsigned cv4_numericbytes(unsigned value);
void cv4_storenumeric(unsigned char *p, unsigned value);
idx_t cv_debtyp ( debtyp_t *d );
int cv_namestring ( unsigned char *p , const char *name, int length = -1);
unsigned cv4_typidx(type *t);
idx_t cv4_arglist(type *t,unsigned *pnparam);
unsigned char cv4_callconv(type *t);
idx_t cv_numdebtypes();

#define TOIDX(a,b)      ((cgcv.sz_idx == 4) ? TOLONG(a,b) : TOWORD(a,b))

#define DEBSYM  5               /* segment of symbol info               */
#define DEBTYP  6               /* segment of type info                 */

/* ======================== Added for Codeview 8 =========================== */

void cv8_initfile(const char *filename);
void cv8_termfile(const char *objfilename);
void cv8_initmodule(const char *filename, const char *modulename);
void cv8_termmodule();
void cv8_func_start(Symbol *sfunc);
void cv8_func_term(Symbol *sfunc);
void cv8_linnum(Srcpos srcpos, unsigned offset);
void cv8_outsym(Symbol *s);
void cv8_udt(const char *id, idx_t typidx);
int cv8_regnum(Symbol *s);
idx_t cv8_fwdref(Symbol *s);
idx_t cv8_darray(type *tnext, idx_t etypidx);
idx_t cv8_ddelegate(type *t, idx_t functypidx);
idx_t cv8_daarray(type *t, idx_t keyidx, idx_t validx);

#endif

