// Copyright (C) 1985-1995 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* Routines to handle elems.                            */

#if __DMC__
#pragma once
#endif

#ifndef EL_H
#define EL_H    1

/******************************************
 * Elems:
 *      Elems are the basic tree element. They can be either
 *      terminal elems (leaves), unary elems (left subtree exists)
 *      or binary elems (left and right subtrees exist).
 */

struct elem
{
#ifdef DEBUG
    unsigned short      id;
#define IDelem 0x4C45   // 'EL'
#define elem_debug(e) assert((e)->id == IDelem)
#else
#define elem_debug(e)
#endif

    unsigned char Eoper;        // operator (OPxxxx)
    unsigned char Ecount;       // # of parents of this elem - 1,
                                // always 0 until CSE elimination is done
    unsigned char Eflags;
    #define EFLAGS_variadic 1   // variadic function call

    union eve EV;               // variants for each type of elem
    union
    {
        // PARSER
        struct
        {
            unsigned PEFflags_;
            #define PEFflags _EU._EP.PEFflags_
                #define PEFnotlvalue    1       // although elem may look like
                                                // an lvalue, it isn't
                #define PEFtemplate_id  0x10    // symbol is a template-id
                #define PEFparentheses  0x20    // expression was within ()
                #define PEFaddrmem      0x40    // address of member
                #define PEFdependent    0x80    // value-dependent
                #define PEFmember       0x100   // was a class member access
            Symbol *Emember_;                   // if PEFmember, this is the member
            #define Emember _EU._EP.Emember_
        }_EP;

        // OPTIMIZER
        struct
        {
            tym_t Ety_;                 // data type (TYxxxx)
            #define Ety _EU._EO.Ety_
            unsigned Eexp_;             // index into expnod[]
            #define Eexp _EU._EO.Eexp_

            // These flags are all temporary markers, used once and then
            // thrown away.
            unsigned char Nflags_;      // NFLxxx
            #define Nflags _EU._EO.Nflags_
                #define NFLli     1     // loop invariant
                #define NFLnogoal 2     // evaluate elem for side effects only
                #define NFLassign 8     // unambiguous assignment elem
                #define NFLaecp 0x10    // AE or CP or VBE expression
                #define NFLdelcse 0x40  // this is not the generating CSE
                #define NFLtouns 0x80   // relational operator was changed from signed to unsigned
#if MARS
            unsigned char Ejty_;                // original Mars type
            #define Ejty _EU._EO.Ejty_
#endif
        }_EO;

        // CODGEN
        struct
        {
            // Ety2: Must be in same position as Ety!
            tym_t Ety2_;                        // data type (TYxxxx)
            #define Ety2 _EU._EC.Ety2_
            unsigned char Ecomsub_;     // number of remaining references to
                                        // this common subexp (used to determine
                                        // first, intermediate, and last references
                                        // to a CSE)
            #define Ecomsub _EU._EC.Ecomsub_
        }_EC;
    }_EU;

    struct TYPE *ET;            // pointer to type of elem if TYstruct | TYarray
    Srcpos Esrcpos;             // source file position
};

#define typemask(e)     ((!MARS && PARSER) ? (e)->ET->Tty : (e)->Ety )
#define typetym(e)      ((e)->ET->Tty)
#define el_fl(e)        ((enum FL)((e)->EV.sp.Vsym->Sfl))
#define Eoffset         EV.sp.Voffset
#define Esymnum         EV.sp.Vsymnum

#define list_elem(list) ((elem *) list_ptr(list))
#define list_setelem(list,ptr) list_ptr(list) = (elem *)(ptr)
#define cnst(e) ((e)->Eoper == OPconst) /* Determine if elem is a constant */
#define E1        EV.eop.Eleft          /* left child                   */
#define E2        EV.eop.Eright         /* right child                  */
#define Erd       EV.sp.spu.Erd         // reaching definition

#define el_int(a,b)     el_long(a,b)

typedef elem *elem_p;   /* try to reduce the symbol table size  */

void el_init(void);
void el_reset(void);
void el_term(void);
elem_p el_calloc(void);
void el_free(elem_p);
elem_p el_combine(elem_p ,elem_p);
elem_p el_param(elem_p ,elem_p);
elem_p el_params(elem_p , ...);
elem *el_params(void **args, int length);
elem *el_combines(void **args, int length);
int el_nparams(elem *e);
void el_paramArray(elem ***parray, elem *e);
elem_p el_pair(tym_t, elem_p, elem_p);
void el_copy(elem_p ,elem_p);
elem_p el_alloctmp(tym_t);
elem_p el_selecte1(elem_p);
elem_p el_selecte2(elem_p);
elem_p el_copytree(elem_p);
void   el_replace_sym(elem *e,symbol *s1,symbol *s2);
elem_p el_scancommas(elem_p);
int el_countCommas(elem_p);
int el_sideeffect(elem_p);
int el_depends(elem *ea,elem *eb);
targ_llong el_tolongt(elem_p);
targ_llong el_tolong(elem_p);
int el_allbits(elem_p,int);
int el_signx32(elem_p);
targ_ldouble el_toldouble(elem_p);
void el_toconst(elem_p);
elem_p el_same(elem_p *);
elem_p el_copytotmp(elem_p *);
int el_match(elem_p ,elem_p);
int el_match2(elem_p ,elem_p);
int el_match3(elem_p ,elem_p);
int el_match4(elem_p ,elem_p);
int el_match5(elem_p ,elem_p);

int el_appears(elem *e,symbol *s);
Symbol *el_basesym(elem *e);
int el_anydef(elem *ed, elem *e);
elem_p el_bint(unsigned,type *,elem_p ,elem_p);
elem_p el_unat(unsigned,type *,elem_p);
elem_p el_bin(unsigned,tym_t,elem_p ,elem_p);
elem_p el_una(unsigned,tym_t,elem_p);
elem_p el_longt(type *,targ_llong);
symbol *el_alloc_localgot();
elem_p el_var(symbol *);
elem_p el_settype(elem_p ,type *);
elem_p el_typesize(type *);
elem_p el_ptr(symbol *);
void el_replace_sym(elem *e,symbol *s1,symbol *s2);
elem * el_ptr_offset(symbol *s,targ_size_t offset);
void el_replacesym(elem *,symbol *,symbol *);
elem_p el_nelems(type *);

elem_p el_long(tym_t,targ_llong);

int ERTOL(elem_p);
int el_noreturn(elem_p);
elem *el_dctor(elem *e,void *decl);
elem *el_ddtor(elem *e,void *decl);
elem *el_ctor(elem *ector,elem *e,symbol *sdtor);
elem *el_dtor(elem *edtor,elem *e);
elem *el_zero(type *t);
elem_p el_const(tym_t,union eve *);
elem_p el_test(tym_t,union eve *);
elem_p * el_parent(elem_p ,elem_p *);

#ifdef DEBUG
void el_check(elem_p);
#else
#define el_check(e)     ((void)0)
#endif

elem *el_convfloat(elem *);
elem *el_convstring(elem *);
elem *el_convert(elem *e);
int el_isdependent(elem *);
unsigned el_alignsize(elem *);

size_t el_opN(elem *e, unsigned op);
void el_opArray(elem ***parray, elem *e, unsigned op);
void el_opFree(elem *e, unsigned op);
elem *el_opCombine(elem **args, size_t length, unsigned op, unsigned ty);

#ifdef DEBUG
void elem_print(elem *);
#else
#define elem_print(e)
#endif
void elem_print_const(elem *);
void el_hydrate(elem **);
void el_dehydrate(elem **);

#endif

