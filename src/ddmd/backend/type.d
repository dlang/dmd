/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/_type.d
 */

module ddmd.backend.type;

import ddmd.backend.cdef;
import ddmd.backend.cc : block, Blockx, Classsym, Symbol;
import ddmd.backend.code;
import ddmd.backend.el : elem;
import ddmd.backend.ty;

import tk.dlist;

extern (C++):
@nogc:
nothrow:

// type.h

alias mangle_t = ubyte;
enum
{
    mTYman_c      = 1,      // C mangling
    mTYman_cpp    = 2,      // C++ mangling
    mTYman_pas    = 3,      // Pascal mangling
    mTYman_for    = 4,      // FORTRAN mangling
    mTYman_sys    = 5,      // _syscall mangling
    mTYman_std    = 6,      // _stdcall mangling
    mTYman_d      = 7,      // D mangling
}

/// Values for Tflags:
alias type_flags_t = ushort;
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
}

struct PARAM;
alias type = TYPE;

void type_incCount(type* t);
void type_setIdent(type* t, char* ident);

type* type_pointer(type* tnext);
type* type_dyn_array(type* tnext);
extern extern (C) type* type_static_array(targ_size_t dim, type* tnext);
type* type_assoc_array(type* tkey, type* tvalue);
type* type_delegate(type* tnext);
extern extern (C) type* type_function(tym_t tyf, type** ptypes, size_t nparams, bool variadic, type* tret);
type* type_enum(const(char)* name, type* tbase);
type* type_struct_class(const(char)* name, uint alignsize, uint structsize,
    type* arg1type, type* arg2type, bool isUnion, bool isClass, bool isPOD);

void symbol_struct_addField(Symbol* s, const(char)* name, type* t, uint offset);

// Return true if type is a struct, class or union
bool type_struct(type* t) { return tybasic(t.Tty) == TYstruct; }

struct TYPE
{
    debug ushort id;

    tym_t Tty;     /* mask (TYxxx)                         */
    type_flags_t Tflags; // TFxxxxx

    mangle_t Tmangle; // name mangling

    uint Tcount; // # pointing to this type
    TYPE* Tnext; // next in list
                                // TYenum: gives base type
    union
    {
        targ_size_t Tdim;   // TYarray: # of elements in array
        elem* Tel;          // TFvla: gives dimension (NULL if '*')
        PARAM* Tparamtypes; // TYfunc, TYtemplate: types of function parameters
        Classsym* Ttag;     // TYstruct,TYmemptr: tag symbol
                            // TYenum,TYvtshape: tag symbol
        char* Tident;       // TYident: identifier
        type* Tkey;         // typtr: key type for associative arrays
    }

    list_t Texcspec;        // tyfunc(): list of types of exception specification
    Symbol *Ttypedef;       // if this type came from a typedef, this is
                            // the typedef symbol


    static uint sizeCheck();
    unittest { assert(sizeCheck() == TYPE.sizeof); }
}

// Workaround 2.066.x bug by resolving the TYMAX value before using it as dimension.
static if (__VERSION__ <= 2066)
    private enum computeEnumValue = TYMAX;

extern __gshared type*[TYMAX] tstypes;
extern __gshared type*[TYMAX] tsptr2types;

extern __gshared
{
    type* tslogical;
    type* chartype;
    type* tsclib;
    type* tsdlib;
    type* tspvoid;
    type* tspcvoid;
    type* tsptrdiff;
    type* tssize;
    type* tstrace;
}

targ_size_t type_size(type *);
uint type_alignsize(type *);
uint type_paramsize(type *t);
type *type_alloc(tym_t);
type *type_alloc_template(Symbol *s);
type *type_allocn(tym_t,type *tn);
type *type_allocmemptr(Classsym *stag,type *tn);
type *type_fake(tym_t);
type *type_setty(type **,uint);
type *type_settype(type **pt, type *t);
type *type_setmangle(type **pt,mangle_t mangle);
type *type_setcv(type **pt,tym_t cv);
int type_embed(type *t,type *u);
int type_isvla(type *t);

