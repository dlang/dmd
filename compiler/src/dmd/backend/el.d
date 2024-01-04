/**
 * Expression trees (intermediate representation)
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/el.d, backend/el.d)
 */

module dmd.backend.el;

// Online documentation: https://dlang.org/phobos/dmd_backend_el.html

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.type;

import dmd.backend.cc : Symbol;

import dmd.backend.dlist;

@nogc:
nothrow:
@safe:

/* Routines to handle elems.                            */

alias eflags_t = ubyte;
enum
{
    EFLAGS_variadic = 1,   // variadic function call
}

alias pef_flags_t = uint;
enum
{
    PEFnotlvalue    = 1,       // although elem may look like
                               // an lvalue, it isn't
    PEFtemplate_id  = 0x10,    // symbol is a template-id
    PEFparentheses  = 0x20,    // expression was within ()
    PEFaddrmem      = 0x40,    // address of member
    PEFdependent    = 0x80,    // value-dependent
    PEFmember       = 0x100,   // was a class member access
}

alias nflags_t = ubyte;
enum
{
    NFLli     = 1,     // loop invariant
    NFLnogoal = 2,     // evaluate elem for side effects only
    NFLassign = 8,     // unambiguous assignment elem
    NFLdelcse = 0x40,  // this is not the generating CSE
    NFLtouns  = 0x80,  // relational operator was changed from signed to unsigned
}

/******************************************
 * Elems:
 *      Elems are the basic tree element. They can be either
 *      terminal elems (leaves), unary elems (left subtree exists)
 *      or binary elems (left and right subtrees exist).
 */

struct elem
{
    debug ushort      id;
    enum IDelem = 0x4C45;   // 'EL'

    version (OSX) // workaround https://issues.dlang.org/show_bug.cgi?id=16466
        align(16) eve EV; // variants for each type of elem
    else
        eve EV;           // variants for each type of elem

    ubyte Eoper;        // operator (OPxxxx)
    ubyte Ecount;       // # of parents of this elem - 1,
                        // always 0 until CSE elimination is done
    eflags_t Eflags;

    union
    {
        // PARSER
        struct
        {
            pef_flags_t PEFflags;
        }

        // OPTIMIZER
        struct
        {
            tym_t Ety;         // data type (TYxxxx)
            uint Eexp;         // index into expnod[]
            uint Edef;         // index into expdef[]

            // These flags are all temporary markers, used once and then
            // thrown away.
            nflags_t Nflags;   // NFLxxx

            // MARS
            ubyte Ejty;        // original Mars type
        }

        // CODGEN
        struct
        {
            // Ety2: Must be in same position as Ety!
            tym_t Ety2;        // data type (TYxxxx)
            ubyte Ecomsub;     // number of remaining references to
                               // this common subexp (used to determine
                               // first, intermediate, and last references
                               // to a CSE)
        }
    }

    type *ET;            // pointer to type of elem if TYstruct | TYarray
    Srcpos Esrcpos;      // source file position
}

void elem_debug(const elem* e)
{
    debug assert(e.id == e.IDelem);
}

@trusted tym_t typemask(const elem* e)
{
    return e.Ety;
}

@trusted
FL el_fl(const elem* e) { return e.EV.Vsym.Sfl; }

//#define Eoffset         EV.sp.Voffset
//#define Esymnum         EV.sp.Vsymnum

@trusted
inout(elem)* list_elem(inout list_t list) { return cast(inout(elem)*)list_ptr(list); }

@trusted
void list_setelem(list_t list, void* ptr) { list.ptr = cast(elem *)ptr; }

public import dmd.backend.elem;
public import dmd.backend.elpicpie : el_var, el_ptr;
