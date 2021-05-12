/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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

extern (C++):
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
            version (SCPP)
                Symbol* Emember;       // if PEFmember, this is the member
            version (HTOD)
                Symbol* Emember;       // if PEFmember, this is the member
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
    version (MARS)
        return e.Ety;
    else
        return PARSER ? e.ET.Tty : e.Ety;
}

@trusted
FL el_fl(const elem* e) { return cast(FL)e.EV.Vsym.Sfl; }

//#define Eoffset         EV.sp.Voffset
//#define Esymnum         EV.sp.Vsymnum

@trusted
inout(elem)* list_elem(inout list_t list) { return cast(inout(elem)*)list_ptr(list); }

@trusted
void list_setelem(list_t list, void* ptr) { list.ptr = cast(elem *)ptr; }

//#define cnst(e) ((e)->Eoper == OPconst) /* Determine if elem is a constant */
//#define E1        EV.eop.Eleft          /* left child                   */
//#define E2        EV.eop.Eright         /* right child                  */
//#define Erd       EV.sp.spu.Erd         // reaching definition

void el_init();
void el_reset();
void el_term();
elem *el_calloc();
void el_free(elem *);
elem *el_combine(elem *,elem *);
elem *el_param(elem *,elem *);
elem *el_params(elem *, ...);
elem *el_params(void **args, int length);
elem *el_combines(void **args, int length);
int el_nparams(const elem *e);
void el_paramArray(elem ***parray, elem *e);
elem *el_pair(tym_t, elem *, elem *);
void el_copy(elem *, const elem *);
elem *el_alloctmp(tym_t);
elem *el_selecte1(elem *);
elem *el_selecte2(elem *);
elem *el_copytree(elem *);
void  el_replace_sym(elem *e,const Symbol *s1,Symbol *s2);
elem *el_scancommas(elem *);
int el_countCommas(const(elem)*);
bool el_sideeffect(const elem *);
int el_depends(const(elem)* ea, const elem *eb);
targ_llong el_tolongt(elem *);
targ_llong el_tolong(elem *);
bool el_allbits(const elem*, int);
bool el_signx32(const elem *);
targ_ldouble el_toldouble(elem *);
void el_toconst(elem *);
elem *el_same(elem **);
elem *el_copytotmp(elem **);
bool el_match(const elem *, const elem *);
bool el_match2(const elem *, const elem *);
bool el_match3(const elem *, const elem *);
bool el_match4(const elem *, const elem *);
bool el_match5(const elem *, const elem *);
int el_appears(const(elem)* e, const Symbol *s);
Symbol *el_basesym(elem *e);
bool el_anydef(const elem *ed, const(elem)* e);
elem* el_bint(OPER, type*,elem*, elem*);
elem* el_unat(OPER, type*, elem*);
elem* el_bin(OPER, tym_t, elem*, elem*);
elem* el_una(OPER, tym_t, elem*);
extern(C) elem *el_longt(type *,targ_llong);
elem *el_settype(elem *,type *);
elem *el_typesize(type *);
elem *el_ptr_offset(Symbol *s,targ_size_t offset);
void el_replacesym(elem *,const Symbol *,Symbol *);
elem *el_nelems(type *);

extern (C) elem *el_long(tym_t,targ_llong);

bool ERTOL(const elem *);
bool el_returns(const(elem) *);
//elem *el_dctor(elem *e,void *decl);
//elem *el_ddtor(elem *e,void *decl);
elem *el_ctor_dtor(elem *ec, elem *ed, elem **pedtor);
elem *el_ctor(elem *ector,elem *e,Symbol *sdtor);
elem *el_dtor(elem *edtor,elem *e);
elem *el_zero(type *t);
elem *el_const(tym_t, eve *);
elem *el_test(tym_t, eve *);
elem ** el_parent(elem *,elem **);

//#ifdef DEBUG
//void el_check(const(elem)*);
//#else
//#define el_check(e)     ((void)0)
//#endif

elem *el_convfloat(elem *);
elem *el_convstring(elem *);
elem *el_convert(elem *e);
bool el_isdependent(elem *);
uint el_alignsize(elem *);

size_t el_opN(const elem *e, OPER op);
void el_opArray(elem ***parray, elem *e, OPER op);
void el_opFree(elem *e, OPER op);
extern (C) elem *el_opCombine(elem **args, size_t length, OPER op, tym_t ty);

void elem_print(const elem *, int nestlevel = 0);
void elem_print_const(const elem *);
void el_hydrate(elem **);
void el_dehydrate(elem **);

// elpicpie.d
elem *el_var(Symbol *);
elem *el_ptr(Symbol *);

