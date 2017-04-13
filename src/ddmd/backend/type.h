/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/type.h
 */

#if __DMC__
#pragma once
#endif

#ifndef __TYPE_H
#define __TYPE_H

typedef unsigned char mangle_t;
enum
{
    mTYman_c      = 1,      // C mangling
    mTYman_cpp    = 2,      // C++ mangling
    mTYman_pas    = 3,      // Pascal mangling
    mTYman_for    = 4,      // FORTRAN mangling
    mTYman_sys    = 5,      // _syscall mangling
    mTYman_std    = 6,      // _stdcall mangling
    mTYman_d      = 7,      // D mangling
};

/// Values for Tflags:
typedef unsigned short type_flags_t;
enum
{
    TFprototype   = 1,      // if this function is prototyped
    TFfixed       = 2,      // if prototype has a fixed # of parameters
    TFgenerated   = 4,      // C: if we generated the prototype ourselves
    TFdependent   = 4,      // CPP: template dependent type
    TFforward     = 8,      // TYstruct: if forward reference of tag name
    TFsizeunknown = 0x10,   // TYstruct,TYarray: if size of type is unknown
                            // TYmptr: the Stag is TYident type
    TFfuncret     = 0x20,   // C++,tyfunc(): overload based on function return value
    TFfuncparam   = 0x20,   // TYarray: top level function parameter
    TFhydrated    = 0x20,   // type data already hydrated
    TFstatic      = 0x40,   // TYarray: static dimension
    TFvla         = 0x80,   // TYarray: variable length array
    TFemptyexc    = 0x100,  // tyfunc(): empty exception specification
};

/*********************************
 * Data type.
 */

#define list_type(tl)   ((struct TYPE *) list_ptr(tl))

struct TYPE
{
#ifdef DEBUG
    unsigned short      id;
#define IDtype  0x1234
#define type_debug(t) assert((t)->id == IDtype)
#else
#define type_debug(t)
#endif

    tym_t       Tty;            // mask (TYxxx)
    unsigned short Tflags;      // TFxxxxx

    mangle_t Tmangle;           // name mangling

    unsigned Tcount;            // # pointing to this type
    TYPE *Tnext;                // next in list
                                // TYenum: gives base type
    union
    {
        targ_size_t Tdim;       // TYarray: # of elements in array
        elem *Tel;              // TFvla: gives dimension (NULL if '*')
        param_t *Tparamtypes;   // TYfunc, TYtemplate: types of function parameters
        Classsym *Ttag;         // TYstruct,TYmemptr: tag symbol
                                // TYenum,TYvtshape: tag symbol
        char *Tident;           // TYident: identifier
        TYPE *Talternate;       // C++: typtr: type of parameter before converting
        TYPE *Tkey;             // typtr: key type for associative arrays
    };
    list_t Texcspec;            // tyfunc(): list of types of exception specification
    Symbol *Ttypedef;           // if this type came from a typedef, this is
                                // the typedef symbol

    static unsigned sizeCheck();
};

struct typetemp_t
{
    TYPE Ttype;

    /* Tsym should really be part of a derived class, as we only
        allocate room for it if TYtemplate
     */
    Symbol *Tsym;               // primary class template symbol
};

// Return name mangling of type
inline mangle_t type_mangle(type *t) { return t->Tmangle; }

// Return true if function type has a variable number of arguments
inline bool variadic(type *t) { return (t->Tflags & (TFprototype | TFfixed)) == TFprototype; }

/* Data         */

typedef type *typep_t;

extern typep_t tstypes[TYMAX];
extern typep_t tsptr2types[TYMAX];

#define tsbool    tstypes[TYbool]
#define tschar    tstypes[TYchar]
#define tsschar   tstypes[TYschar]
#define tsuchar   tstypes[TYuchar]
#define tschar16  tstypes[TYchar16]
#define tsshort   tstypes[TYshort]
#define tsushort  tstypes[TYushort]
#define tswchar_t tstypes[TYwchar_t]
#define tsint     tstypes[TYint]
#define tsuns     tstypes[TYuint]
#define tslong    tstypes[TYlong]
#define tsulong   tstypes[TYulong]
#define tsdchar   tstypes[TYdchar]
#define tsllong   tstypes[TYllong]
#define tsullong  tstypes[TYullong]
#define tsfloat   tstypes[TYfloat]
#define tsdouble  tstypes[TYdouble]
#define tsreal64  tstypes[TYdouble_alias]
#define tsldouble tstypes[TYldouble]
#define tsvoid    tstypes[TYvoid]

#define tsifloat   tstypes[TYifloat]
#define tsidouble  tstypes[TYidouble]
#define tsildouble tstypes[TYildouble]
#define tscfloat   tstypes[TYcfloat]
#define tscdouble  tstypes[TYcdouble]
#define tscldouble tstypes[TYcldouble]

#define tsnullptr tstypes[TYnullptr]

extern typep_t tslogical;
extern typep_t chartype;
extern typep_t tsclib;
extern typep_t tsdlib;
extern typep_t tspvoid,tspcvoid;
extern typep_t tsptrdiff, tssize;
extern typep_t tstrace;

#define tserr           tsint   /* error type           */

// Return !=0 if type is a struct, class or union
inline bool type_struct(type *t) { return tybasic(t->Tty) == TYstruct; }

/* Functions    */
void type_print(type *t);
void type_free(type *);
void type_init();
void type_term();
type *type_copy(type *);
elem *type_vla_fix(type **pt);
type *type_setdim(type **,targ_size_t);
type *type_setdependent(type *t);
int type_isdependent(type *t);
type *type_copy(type *);
void type_hydrate(type **);
void type_dehydrate(type **);

targ_size_t type_size(type *);
unsigned type_alignsize(type *);
unsigned type_paramsize(type *t);
type *type_alloc(tym_t);
type *type_alloc_template(symbol *s);
type *type_allocn(tym_t,type *tn);
type *type_allocmemptr(Classsym *stag,type *tn);
type *type_fake(tym_t);
type *type_setty(type **,unsigned);
type *type_settype(type **pt, type *t);
type *type_setmangle(type **pt,mangle_t mangle);
type *type_setcv(type **pt,tym_t cv);
int type_embed(type *t,type *u);
int type_isvla(type *t);

param_t *param_calloc();
param_t *param_append_type(param_t **,type *);
void param_free_l(param_t *);
void param_free(param_t **);
symbol *param_search(const char *name, param_t **pp);
void param_hydrate(param_t **);
void param_dehydrate(param_t **);
int typematch(type *t1, type *t2, int relax);

type *type_pointer(type *tnext);
type *type_dyn_array(type *tnext);
extern "C" type *type_static_array(targ_size_t dim, type *tnext);
type *type_assoc_array(type *tkey, type *tvalue);
type *type_delegate(type *tnext);
extern "C" type *type_function(tym_t tyf, type **ptypes, size_t nparams, bool variadic, type *tret);
type *type_enum(const char *name, type *tbase);
type *type_struct_class(const char *name, unsigned alignsize, unsigned structsize,
        type *arg1type, type *arg2type, bool isUnion, bool isClass, bool isPOD);

#endif
