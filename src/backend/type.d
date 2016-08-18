/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC backend/_type.d)
 */

module ddmd.backend.type;

import ddmd.backend.cdef;
import ddmd.backend.cc : block, Blockx, Classsym, Symbol;
import ddmd.backend.el : elem;
import ddmd.backend.ty;

import tk.dlist;

extern (C++):
@nogc:
nothrow:

struct code;

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

alias targ_size_t = ulong;

struct PARAM;
alias type = TYPE;

type* type_fake(tym_t);
void type_incCount(type* t);
void type_setIdent(type* t, char* ident);

type* type_alloc(tym_t);
type* type_allocn(tym_t, type* tn);

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
    ushort Tflags; // TFxxxxx

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

