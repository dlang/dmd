/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/type.d, backend/_type.d)
 */

module dmd.backend.type;

// Online documentation: https://dlang.org/phobos/dmd_backend_type.html

import dmd.backend.cdef;
import dmd.backend.cc : block, Blockx, Classsym, Symbol, param_t;
import dmd.backend.code;
import dmd.backend.dlist;
import dmd.backend.el : elem;
import dmd.backend.ty;

extern (C++):
@nogc:
nothrow:
@safe:

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

alias type = TYPE;

void type_incCount(type* t);
void type_setIdent(type* t, char* ident);

void symbol_struct_addField(Symbol* s, const(char)* name, type* t, uint offset);

// Return true if type is a struct, class or union
bool type_struct(const type* t) { return tybasic(t.Tty) == TYstruct; }

struct TYPE
{
    debug ushort id;
    enum IDtype = 0x1234;

    tym_t Tty;     /* mask (TYxxx)                         */
    type_flags_t Tflags; // TFxxxxx

    mangle_t Tmangle; // name mangling

    uint Tcount; // # pointing to this type
    char* Tident; // TYident: identifier; TYdarray, TYaarray: pretty name for debug info
    TYPE* Tnext; // next in list
                                // TYenum: gives base type
    union
    {
        targ_size_t Tdim;   // TYarray: # of elements in array
        elem* Tel;          // TFvla: gives dimension (NULL if '*')
        param_t* Tparamtypes; // TYfunc, TYtemplate: types of function parameters
        Classsym* Ttag;     // TYstruct,TYmemptr: tag symbol
                            // TYenum,TYvtshape: tag symbol
        type* Talternate;   // C++: typtr: type of parameter before converting
        type* Tkey;         // typtr: key type for associative arrays
    }

    list_t Texcspec;        // tyfunc(): list of types of exception specification
    Symbol *Ttypedef;       // if this type came from a typedef, this is
                            // the typedef symbol
}

struct typetemp_t
{
    TYPE Ttype;

    /* Tsym should really be part of a derived class, as we only
        allocate room for it if TYtemplate
     */
    Symbol *Tsym;               // primary class template symbol
}

void type_debug(const type* t)
{
    debug assert(t.id == t.IDtype);
}

// Return name mangling of type
mangle_t type_mangle(const type *t) { return t.Tmangle; }

// Return true if function type has a variable number of arguments
bool variadic(const type *t) { return (t.Tflags & (TFprototype | TFfixed)) == TFprototype; }

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

/* Functions    */
void type_print(const type* t);
void type_free(type *);
void type_init();
void type_term();
type *type_copy(type *);
elem *type_vla_fix(type **pt);
type *type_setdim(type **,targ_size_t);
type *type_setdependent(type *t);
int type_isdependent(type *t);
void type_hydrate(type **);
void type_dehydrate(type **);

version (SCPP)
    targ_size_t type_size(type *);
version (HTOD)
    targ_size_t type_size(type *);

targ_size_t type_size(const type *);
uint type_alignsize(type *);
bool type_zeroSize(type *t, tym_t tyf);
uint type_parameterSize(type *t, tym_t tyf);
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

param_t *param_calloc();
param_t *param_append_type(param_t **,type *);
void param_free_l(param_t *);
void param_free(param_t **);
Symbol *param_search(const(char)* name, param_t **pp);
void param_hydrate(param_t **);
void param_dehydrate(param_t **);
int typematch(type *t1, type *t2, int relax);

type *type_pointer(type *tnext);
type *type_dyn_array(type *tnext);
extern (C) type *type_static_array(targ_size_t dim, type *tnext);
type *type_assoc_array(type *tkey, type *tvalue);
type *type_delegate(type *tnext);
extern (C) type *type_function(tym_t tyf, type*[] ptypes, bool variadic, type *tret);
type *type_enum(const(char) *name, type *tbase);
type *type_struct_class(const(char)* name, uint alignsize, uint structsize,
        type *arg1type, type *arg2type, bool isUnion, bool isClass, bool isPOD, bool is0size);
