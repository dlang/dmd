/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/el.d, backend/el.d)
 */

module dmd.backend.el;

// Online documentation: https://dlang.org/phobos/dmd_backend_el.html

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.dlist;
import dmd.backend.type;

import dmd.backend.cc : Symbol;

extern (C++):
@nogc:
nothrow:

/* Routines to handle elems.                            */

alias ubyte eflags_t;
enum
{
    EFLAGS_variadic = 1,   // variadic function call
}

alias uint pef_flags_t;
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

alias ubyte nflags_t;
enum
{
    NFLli     = 1,     // loop invariant
    NFLnogoal = 2,     // evaluate elem for side effects only
    NFLassign = 8,     // unambiguous assignment elem
    NFLaecp   = 0x10,  // AE or CP or VBE expression
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

void elem_debug(elem* e)
{
    debug assert(e.id == e.IDelem);
}

version (MARS)
    tym_t typemask(elem* e) { return e.Ety; }
else
    tym_t typemask(elem* e) { return PARSER ? e.ET.Tty : e.Ety; }

//FL el_fl(elem *e) { return cast(FL)e.EV.Vsym.Sfl; }

//#define Eoffset         EV.sp.Voffset
//#define Esymnum         EV.sp.Vsymnum

elem* list_elem(list_t list) { return cast(elem*)list_ptr(list); }

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
int el_nparams(elem *e);
void el_paramArray(elem ***parray, elem *e);
elem *el_pair(tym_t, elem *, elem *);
void el_copy(elem *,elem *);
elem *el_alloctmp(tym_t);
elem *el_selecte1(elem *);
elem *el_selecte2(elem *);
elem *el_copytree(elem *);
void  el_replace_sym(elem *e,Symbol *s1,Symbol *s2);
elem *el_scancommas(elem *);
int el_countCommas(elem *);
int el_sideeffect(elem *);
int el_depends(elem *ea,elem *eb);
targ_llong el_tolongt(elem *);
targ_llong el_tolong(elem *);
int el_allbits(elem *,int);
int el_signx32(elem *);
targ_ldouble el_toldouble(elem *);
void el_toconst(elem *);
elem *el_same(elem **);
elem *el_copytotmp(elem **);
int el_match(elem *,elem *);
int el_match2(elem *,elem *);
int el_match3(elem *,elem *);
int el_match4(elem *,elem *);
int el_match5(elem *,elem *);

int el_appears(elem *e,Symbol *s);
Symbol *el_basesym(elem *e);
int el_anydef(elem *ed, elem *e);
elem *el_bint(uint,type *,elem *,elem *);
elem *el_unat(uint,type *,elem *);
elem *el_bin(uint,tym_t,elem *,elem *);
elem *el_una(uint,tym_t,elem *);
elem *el_longt(type *,targ_llong);
Symbol *el_alloc_localgot();
elem *el_var(Symbol *);
elem *el_settype(elem *,type *);
elem *el_typesize(type *);
elem *el_ptr(Symbol *);
elem *el_ptr_offset(Symbol *s,targ_size_t offset);
void el_replacesym(elem *,Symbol *,Symbol *);
elem *el_nelems(type *);

extern (C) elem *el_long(tym_t,targ_llong);

int ERTOL(elem *);
bool el_returns(elem *);
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
//void el_check(elem *);
//#else
//#define el_check(e)     ((void)0)
//#endif

elem *el_convfloat(elem *);
elem *el_convstring(elem *);
elem *el_convert(elem *e);
int el_isdependent(elem *);
uint el_alignsize(elem *);

size_t el_opN(elem *e, uint op);
void el_opArray(elem ***parray, elem *e, uint op);
void el_opFree(elem *e, uint op);
extern (C) elem *el_opCombine(elem **args, size_t length, uint op, uint ty);

void elem_print(elem *);
void elem_print_const(elem *);
void el_hydrate(elem **);
void el_dehydrate(elem **);


