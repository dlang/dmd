// Copyright (C) 1987-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* Globals for C++				*/

//#pragma once
#ifndef CPP_H
#define CPP_H	1

typedef char *char_p;
typedef symbol *symbol_p;

/* Names for special variables	*/
//extern char cpp_name[2*IDMAX + 1];
extern char cpp_name_ct[];
extern char cpp_name_dt[];
extern char cpp_name_as[];
extern char cpp_name_vc[];
extern char cpp_name_this[];
extern char cpp_name_free[];
extern char cpp_name_initvbases[];
extern char cpp_name_new[];
extern char cpp_name_delete[];
extern char cpp_name_anew[];
extern char cpp_name_adelete[];
extern char cpp_name_primdt[];
extern char cpp_name_scaldeldt[];
extern char cpp_name_priminv[];
extern char cpp_name_none[];
extern char cpp_name_invariant[];

extern list_t cpp_stidtors;	// auto destructors that go in _STIxxxx

/* From init.c */
extern bool init_staticctor;

/* From cpp.c */
/* List of elems which are the constructor and destructor calls to make	*/
extern list_t constructor_list;		/* for _STIxxxx			*/
extern list_t destructor_list;		/* for _STDxxxx			*/
extern symbol_p s_mptr;
extern symbol_p s_genthunk;
extern symbol_p s_vec_dtor;
extern symbol_p cpp_operfuncs[];
extern unsigned cpp_operfuncs_nspace[];

elem *cpp_istype(elem *e, type *t);
char *cpp_unmangleident(const char *p);
int cpp_opidx(int op);
char *cpp_opident(int op);
char *cpp_prettyident(symbol *s);
char *cpp_catname(char *n1 , char *n2);
char *cpp_genname(char *cl_name , char *mem_name);
void cpp_getpredefined(void);
char *cpp_operator(int *poper , type **pt);
char *cpp_operator2(token_t *to, int *pcastoverload);
elem *cpp_new(int global , symbol *sfunc , elem *esize , list_t arglist , type *tret);
elem *cpp_delete(int global , symbol *sfunc , elem *eptr , elem *esize);
#if SCPP
match_t cpp_matchtypes(elem *e1,type *t2, Match *m = NULL);
symbol *cpp_typecast(type *tclass , type *t2 , Match *pmatch);
#endif
int cpp_typecmp(type *t1, type *t2, int relax, param_t *p1 = NULL, param_t *p2 = NULL);
char *cpp_typetostring(type *t , char *prefix);
HINT cpp_cast(elem **pe1 , type *t2 , int doit);
elem *cpp_initctor(type *tclass , list_t arglist);
int cpp_casttoptr(elem **pe);
elem *cpp_bool(elem *e, int flags);
symbol *cpp_findopeq(Classsym *stag);
symbol *cpp_overload(symbol *sf,type *tthis,list_t arglist,Classsym *sclass,param_t *ptal, unsigned flags);
symbol *cpp_findfunc(type *t, param_t *ptpl, symbol *s, int td);
int cpp_funccmp(symbol *s1, symbol *s2);
int cpp_funccmp(type *t1, param_t *ptpl1, symbol *s2);
elem *cpp_opfunc(elem *e);
elem *cpp_ind(elem *e);
int cpp_funcisfriend(symbol *sfunc , Classsym *sclass);
int cpp_classisfriend(Classsym *s , Classsym *sclass);
symbol *cpp_findmember(Classsym *sclass , const char *sident , unsigned flag);
symbol *cpp_findmember_nest(Classsym **psclass , const char *sident , unsigned flag);
int cpp_findaccess(symbol *smember , Classsym *sclass);
void cpp_memberaccess(symbol *smember , symbol *sfunc , Classsym *sclass);
type *cpp_thistype(type *tfunc , Classsym *stag);
symbol *cpp_declarthis(symbol *sfunc , Classsym *stag);
elem *cpp_fixptrtype(elem *e,type *tclass);
int cpp_vtbloffset(Classsym *sclass , symbol *sfunc);
elem *cpp_getfunc(type *tclass , symbol *sfunc , elem **pethis);
elem *cpp_constructor(elem *ethis , type *tclass , list_t arglist , elem *enelems , list_t pvirtbase , int flags);
elem *cpp_destructor(type *tclass , elem *eptr , elem *enelems , int dtorflag);
void cpp_build_STI_STD(void);
symbol *cpp_getlocalsym(symbol *sfunc , char *name);
symbol *cpp_getthis(symbol *sfunc);
symbol *cpp_findctor0(Classsym *stag);
void cpp_buildinitializer(symbol *s_ctor , list_t baseinit , int flag);
void cpp_fixconstructor(symbol *s_ctor);
int cpp_ctor(Classsym *stag);
int cpp_dtor(type *tclass);
void cpp_fixdestructor(symbol *s_dtor);
elem *cpp_structcopy(elem *e);
elem *cpp_hdlptr(elem *e);
void cpp_fixmain(void);
int cpp_needInvariant(type *tclass);
void cpp_fixinvariant(symbol *s_dtor);
elem *cpp_invariant(type *tclass,elem *eptr,elem *enelems,int invariantflag);
elem *Funcsym_invariant(Funcsym *s, int Fflag);
void cpp_init(void);
void cpp_term(void);
symbol *mangle_tbl(int,type *,Classsym *,baseclass_t *);
void cpp_alloctmps(elem *e);
#if SCPP
symbol *cpp_lookformatch(symbol *sfunc , type *tthis , list_t arglist,
		Match *pmatch, symbol **pambig, match_t *pma, param_t *ptal,
		unsigned flags, symbol *sfunc2, type *tthis2, symbol *stagfriend = NULL);
#endif

#if TARGET_MAC
elem *cpp_hdlptr(elem *e);
#define M68HDL(e)	cpp_hdlptr(e)
#else
#define M68HDL(e)	(e)
#endif

struct OPTABLE
{   unsigned char tokn;		/* token(TKxxxx)		*/
    unsigned char oper;		/* corresponding operator(OPxxxx) */
    char __near *string;	/* identifier string		*/
    char pretty[5];		/* for pretty-printing		*/
    				/* longest OP is OPunord	*/
};

#endif /* CPP_H */
