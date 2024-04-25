/**
 * Types for the back end
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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

public import dmd.backend.symbol : symbol_struct_addField, symbol_struct_addBitField, symbol_struct_hasBitFields, symbol_struct_addBaseClass;

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

public import dmd.backend.var : chartype;

public import dmd.backend.dtype : type_print, type_free, type_init, type_term, type_copy,
    type_setdim, type_setdependent, type_isdependent, type_size, type_alignsize, type_zeroSize,
    type_parameterSize, type_paramsize, type_alloc, type_allocn, type_fake, type_setty,
    type_settype, type_setmangle, type_setcv, type_embed, type_isvla, param_calloc,
    param_append_type, param_free_l, param_free, param_search, typematch, type_pointer,
    type_dyn_array, type_static_array, type_assoc_array, type_delegate, type_function,
    type_enum, type_struct_class, tstypes, tsptr2types, tslogical, tsclib, tsdlib,
    tspvoid, tspcvoid, tsptrdiff, tssize, tstrace;
