// Copyright (C) 1989-1997 by Symantec
// Copyright (C) 2000-2013 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* Definitions only used by the parser                  */

//#pragma once
#ifndef PARSER_H
#define PARSER_H 1

#if SCPP
#ifndef SCOPE_H
#include        "scope.h"
#endif
#endif

#ifndef __TYPE_H
#include        "type.h"
#endif

#if !MARS
extern linkage_t linkage;       /* current linkage that is in effect    */
extern int linkage_spec;        /* !=0 if active linkage specification  */

#if MEMMODELS == 1
extern tym_t functypetab[LINK_MAXDIM];
#define FUNC_TYPE(l,m) functypetab[l]
#else
extern tym_t functypetab[LINK_MAXDIM][MEMMODELS];
#define FUNC_TYPE(l,m) functypetab[l][m]
#endif

extern mangle_t funcmangletab[LINK_MAXDIM];
extern mangle_t varmangletab[LINK_MAXDIM];
#endif

#ifndef EL_H
#include        "el.h"
#endif

void list_hydrate(list_t *plist, void (*hydptr)(void *));
void list_dehydrate(list_t *plist, void (*dehydptr)(void *));

/* Type matches */
#define TMATCHnomatch   0       /* no match                             */
#define TMATCHellipsis  0x01    /* match using ellipsis                 */
#define TMATCHuserdef   0x09    /* match using user-defined conversions */
#define TMATCHboolean   0x0E    // conversion of pointer or pointer-to-member to boolean
#define TMATCHstandard  0xFA    /* match with standard conversions      */
#define TMATCHpromotions 0xFC   /* match using promotions               */
#define TMATCHexact     0xFF    /* exact type match                     */

typedef unsigned char match_t;

#if SCPP
struct Match
{
    match_t m;
    match_t m2;         // for user defined conversion, this is the second
                        // sequence match level (the second sequence is the
                        // one on the result of the user defined conversion)
    Symbol *s;          // user defined conversion function or constructor
    int ref;            // !=0 if reference binding
    tym_t toplevelcv;

    Match()
    {   m = 0;
        m2 = 0;
        s = NULL;
        ref = 0;
        toplevelcv = 0;
    }

    static int cmp(Match& m1, Match& m2);
};
#endif

/***************************
 * Type of destructor call
 */

#define DTORfree        1       // it is destructor's responsibility to
                                //   free the pointer
#define DTORvecdel      2       // delete array syntax
#define DTORmostderived 4       // destructor is invoked for most-derived
                                //  instance, not for a base class
#define DTORvector      8       // destructor has been invoked for an
                                //   array of instances of known size
#define DTORvirtual     0x10    // use virtual destructor, if any
#define DTORnoeh        0x20    // do not append eh stuff
#define DTORnoaccess    0x40    // do not perform access check


struct phstring_t
{
#define PHSTRING_ARRAY 1
#if PHSTRING_ARRAY
    phstring_t() { dim = 0; }

    size_t length() { return dim; }

    int cmp(phstring_t s2, int (*func)(void *,void *));

    bool empty() { return dim == 0; }

    char* operator[] (size_t index)
    {
        return dim == 1 ? (char *)data : data[index];
    }

    void push(const char *s);

    void hydrate();

    void dehydrate();

    int find(const char *s);

    void free(list_free_fp freeptr);

  private:
    size_t dim;
    char** data;
#else
    phstring_t() { list = NULL; }

    size_t length() { return list_nitems(list); }

    int cmp(phstring_t s2, int (*func)(void *,void *))
    {
        return list_cmp(list, s2.list, func);
    }

    bool empty() { return list == NULL; }

    char* operator[] (size_t index)
    {
        return (char *)list_ptr(list_nth(list, index));
    }

    void push(const char *s) { list_append(&list, (void *)s); }

    void hydrate() { list_hydrate(&list, NULL); }

    void dehydrate() { list_dehydrate(&list, NULL); }

    int find(const char *s);

    void free(list_free_fp freeptr) { list_free(&list, freeptr); }

  private:
    list_t list;
#endif
};



/***************************
 * Macros.
 */
#if !TX86
#pragma ZTC align 1
#endif

struct MACRO
{
#ifdef DEBUG
    unsigned short      id;
#define IDmacro 0x614D
#define macro_debug(m) assert((m)->id == IDmacro)
#else
#define macro_debug(m)
#endif

    char *Mtext;                // replacement text
    phstring_t Marglist;        // list of arguments (as char*'s)
    macro_t *ML,*MR;
#if TX86
    macro_t *Mnext;             // next macro in threaded list (all macros
                                // are on one list or another)
#endif
    unsigned char Mflags;
#define Mdefined        1       // if macro is defined
#define Mfixeddef       2       // if can't be re/un defined
#define Minuse          4       // if macro is currently being expanded
#define Mellipsis       0x8     // if arglist had trailing ...
#define Mnoparen        0x10    // if macro has no parentheses
#define Mkeyword        0x20    // this is a C/C++ keyword
#define Mconcat         0x40    // if macro uses concat operator
#define Mnotexp         0x80    // if macro should be expanded
    unsigned char Mval;         // if Mkeyword, this is the TKval
#if TX86
    char Mid[1];                // macro identifier
#else
    str4 Mid[];                 /* macro identifier as a 4 byte string */
#endif
};

#if !TX86
#pragma ZTC align
#endif

/**********************
 * Flags for #include files.
 */

#define FQcwd           1       // search current working directory
#define FQpath          2       // search INCLUDE path
#define FQsystem        4       // this is a system include
#if TX86
#define FQtop           8       // top level file, already open
#define FQqual          0x10    // filename is already qualified
#endif
#define FQnext          0x20    // search starts after directory
                                // of last included file (for #include_next)

/***************************************************************************
 * Which block is active is maintained by the BLKLST, which is a backwardly
 * linked list of which blocks are active.
 */

struct BLKLST
{
    /* unsigned because of the chars with the 8th bit set       */
    unsigned char  *BLtextp;    /* current position in text buffer      */
    unsigned char  *BLtext;     /* start of text buffer                 */
    struct BLKLST  *BLprev;     /* enclosing blklst                     */
    unsigned char   BLflags;    /* input block list flags               */
#       define BLspace   0x01   /* we've put out an extra space         */
#       define BLexpanded 0x40  // already macro expanded; don't do it again
#       define BLtokens  0x10   // saw tokens in input
#       define BLsystem  0x04   // it's a system #include (and it must be 4)
    char        BLtyp;          /* type of block (BLxxxx)               */
#       define BLstr    2       /* string                               */
#       define BLfile   3       /* a #include file                      */
#       define BLarg    4       /* macro argument                       */
#       define BLrtext  5       // random text

#if IMPLIED_PRAGMA_ONCE
#       define BLnew     0x02   // start of new file
#       define BLifndef  0x20   // found #ifndef/#define at start
#       define BLendif   0x08   // found matching #endif
    unsigned ifnidx;            // index into ifn[] of IF_FIRSTIF
#endif

    list_t      BLaargs;        /* actual arguments                     */
    list_t      BLeargs;        /* actual arguments                     */
    int         BLnargs;        /* number of dummy args                 */
    int         BLtextmax;      /* size of text buffer                  */
    unsigned char *BLbuf;       // BLfile: file buffer
    unsigned char *BLbufp;      // BLfile: next position in file buffer
#if IMPLIED_PRAGMA_ONCE
    char        *BLinc_once_id; // macro identifier for #include guard
#endif
    Srcpos      BLsrcpos;       /* BLfile, position in that file        */
    int         BLsearchpath;   // BLfile: remaining search path for #include_next

    void print();
};

struct BlklstSave
{
    blklst *BSbl;
    unsigned char *BSbtextp;
    unsigned char BSxc;
};

#if IMPLIED_PRAGMA_ONCE
extern int TokenCnt;
#endif

#if TX86
/* Get filename for BLfile block        */
#define blklst_filename(b)      (srcpos_name((b)->BLsrcpos))
#endif

/* Different types of special values that can occur in the character stream */
#define PRE_ARG 0xFF    // the next char following is a parameter number
                        // If next char is PRE_ARG, then PRE_ARG is the char
#define PRE_BRK 0xFE    // token separator
#define PRE_STR 0xFA    // If immediately following PRE_ARG, then the
                        // parameter is to be 'stringized'
#define PRE_EXP 0xFC    // following identifier may not be expanded as a macro
#define PRE_CAT 0xFB    // concatenate tokens
#define PRE_EOB 0       // end of block
#define PRE_EOF 0       // end of file
#define PRE_SPACE  0xFD // token separator

#define PRE_ARGMAX 0xFB // maximum number of arguments to a macro

#if 1
#define EGCHAR()                                                \
        ((((xc = *btextp) != PRE_EOB && xc != PRE_ARG)  \
        ?   (btextp++,(config.flags2 & CFG2expand && (explist(xc),1)),1) \
        :   egchar2()                                           \
        ),xc)
#else
#define EGCHAR() egchar()
#endif



/**********************************
 * Function return value methods.
 */

#define RET_REGS        1       /* returned in registers                */
#define RET_STACK       2       /* returned on stack                    */
#define RET_STATIC      4       /* returned in static memory location   */
#define RET_NDPREG      8       /* returned in floating point register  */
#define RET_PSTACK      2       // returned on stack (DOS pascal style)

/* from blklst.c */
extern blklst *bl;
extern unsigned char *btextp;
extern int blklst_deferfree;
extern char *eline;
extern int elinmax;             /* # of chars in buffer eline[]         */
extern int elini;               /* index into eline[]                   */
extern int elinnum;             /* expanded line number                 */
extern int expflag;            /* != 0 means not expanding list file   */
blklst *blklst_getfileblock(void);
void putback(int);

unsigned char *macro_replacement_text(macro_t *m, phstring_t args);
unsigned char *macro_rescan(macro_t *m, unsigned char *text);
unsigned char *macro_expand(unsigned char *text);

extern void explist(int);
void expstring(const char *);
void expinsert(int);
void expbackup(void);

/***************************************
 * Erase the current line of expanded output.
 */

inline void experaseline()
{
    // Remove the #pragma once from the expanded listing
    if (config.flags2 & CFG2expand && expflag == 0)
    {   elini = 0;
        eline[0] = 0;
    }
}

void wrtexp(FILE *);
extern unsigned egchar2(void);
extern unsigned egchar(void);

void insblk(unsigned char *text,int typ,list_t aargs,int nargs,macro_t *m);
void insblk2(unsigned char *text,int typ);

#if __GNUC__
unsigned getreallinnum();
extern void getcharnum(void);
#endif

Srcpos getlinnum(void);
unsigned blklst_linnum(void);
void blklst_term();

/* adl.c */
symbol *adl_lookup(char *id, symbol *so, list_t arglist);

/* exp.c */
extern elem *exp_sizeof(int);

/* exp2.c */
extern elem *typechk(elem *,type *),
        *exp2_cast(elem *,type *),
        *cast(elem *,type *),
        *doarray(elem *),
        *doarrow(elem *),
        *xfunccall(elem *efunc,elem *ethis,list_t pvirtbase,list_t arglist),
        *exp2_gethidden(elem *e),
        *dodotstar(elem *, elem *),
        *reftostar(elem *),
        *reftostart(elem *,type *),
        *exp2_copytotemp(elem *),
        *dofunc(elem *),
        *builtinFunc(elem *),
        *arraytoptr(elem *),
        *convertchk(elem *),
        *lptrtooffset(elem *),
        *dodot(elem *,type *,bool bColcol),
        *minscale(elem *);
elem *exp2_addr(elem *);
void getarglist(list_t *);
elem *exp2_ptrvbaseclass(elem *ethis,Classsym *stag,Classsym *sbase);
int t1isbaseoft2(type *,type *);
int c1isbaseofc2(elem **,symbol *,symbol *);
int c1dominatesc2(symbol *stag, symbol *c1, symbol *c2);
int exp2_retmethod(type *);
type *exp2_hiddentype(type *);
int typematch(type *,type *,int);
int typecompat(type *,type *);
int t1isSameOrSubsett2(type *,type *);
void handleaccess(elem *);
void chkarithmetic(elem *);
void chkintegral(elem *);
void scale(elem *);
void impcnv(elem *);
void exp2_ptrtocomtype(elem *);
int  exp2_ptrconv(type *,type *);
void getinc(elem *);
int paramlstmatch(param_t *,param_t *);
int template_paramlstmatch(type *, type *);

/* from file.c */
extern char ext_obj[];
extern char ext_i[];
extern char ext_dep[];
extern char ext_lst[];
extern char ext_hpp[];
extern char ext_c[];
extern char ext_cpp[];
extern char ext_sym[];
extern char ext_tdb[];
#if HTOD
extern char ext_dmodule[];
extern int includenest;
#endif

int file_qualify(char **pfilename,int flag,phstring_t pathlist, int *next_path);
void afopen(char *,blklst *,int);
FILE *file_openwrite(const char *name,const char *mode);
void file_iofiles(void);
int readln(void);
void wrtpos(FILE *);
void wrtlst(FILE *);

/* from func.c */
void func_nest(symbol *);
void func_body(symbol *);
elem *addlinnum(elem *);
void func_conddtors(elem **pe, SYMIDX sistart, SYMIDX siend);
void func_expadddtors(elem **,SYMIDX,SYMIDX,bool,bool);
void paramtypadj(type **);
void func_noreturnvalue(void);
elem *func_expr_dtor(int keepresult);
elem *func_expr();

/* getcmd.c */
extern unsigned long netspawn_flags;
void getcmd(int,char *[]);
void getcmd_term(void);

/* init.c */
void datadef(symbol *);
dt_t **dtnbytes(dt_t **,targ_size_t,const char *);
dt_t **dtnzeros(dt_t **pdtend,targ_size_t size);
dt_t **dtxoff(dt_t **pdtend,symbol *s,targ_size_t offset,tym_t ty);
dt_t **dtcoff(dt_t **pdtend,targ_size_t offset);
void dtsymsize(symbol *);
void init_common(symbol *);
symbol *init_typeinfo_data(type *ptype);
symbol *init_typeinfo(type *ptype);
elem *init_constructor(symbol *,type *,list_t,targ_size_t,int,symbol *);
void init_vtbl(symbol *,symlist_t,Classsym *,Classsym *);
void init_vbtbl(symbol *,baseclass_t *,Classsym *,targ_size_t);
void init_sym(symbol *, elem *);

/* inline.c */
void inline_do(symbol *sfunc);
bool inline_possible(symbol *sfunc);

/* msc.c */
void list_hydrate(list_t *plist, void (*hydptr)(void *));
void list_dehydrate(list_t *plist, void (*dehydptr)(void *));
void list_hydrate_d(list_t *plist);
void list_dehydrate_d(list_t *plist);

// nspace.c
void namespace_definition();
void using_declaration();
symbol *nspace_search(const char *id,Nspacesym *sn);
symbol *nspace_searchmember(const char *id,Nspacesym *sn);
symbol *nspace_qualify(Nspacesym *sn);
symbol *nspace_getqual(int);
void nspace_add(void *snv,symbol *s);
void nspace_addfuncalias(Funcsym *s,Funcsym *s2);
symbol *using_member_declaration(Classsym *stag);
void scope_push_nspace(Nspacesym *sn);
void nspace_checkEnclosing(symbol *s);
int nspace_isSame(symbol *s1, symbol *s2);

/* nwc.c */
void thunk_hydrate(struct Thunk **);
void thunk_dehydrate(struct Thunk **);
void nwc_defaultparams(param_t *,param_t *);
void nwc_musthaveinit(param_t *);
void nwc_addstatic(symbol *);
void output_func(void);
void queue_func(symbol *);
void savesymtab(func_t *f);
void nwc_mustwrite(symbol *);
void ext_def(int);
type *declar_abstract(type *);
type *new_declarator(type *);
type *ptr_operator(type *);
type *declar_fix(type *,char *);
void fixdeclar(type *);
type *declar(type *,char *,int);
int type_specifier(type **);
int declaration_specifier(type **ptyp_spec, enum SC *pclass, unsigned long *pclassm);
symbol *id_expression();
elem *declaration(int flag);
int funcdecl(symbol *,enum SC,int,Declar *);
symbol *symdecl(char *,type *,enum SC,param_t *);
void nwc_typematch(type *,type *,symbol *);
int isexpression(void);
void nwc_setlinkage(char *,long,mangle_t);
tym_t nwc_declspec();
void parse_static_assert();
type *parse_decltype();

/* struct.c */
type *stunspec(enum_TK tk, Symbol *s, Symbol *stempsym, param_t *template_argument_list);
Classsym * n2_definestruct(char *struct_tag,unsigned flags,tym_t ptrtype,
        symbol *stempsym,param_t *template_argument_list,int nestdecl);
void n2_classfriends(Classsym *stag);
int n2_isstruct(symbol **ps);
void n2_addfunctoclass(Classsym *,Funcsym *,int flags);
void n2_chkexist(Classsym *stag, char *name);
void n2_addmember(Classsym *stag,symbol *smember);
symbol *n2_searchmember(Classsym *,const char *);
symbol *struct_searchmember(const char *,Classsym *);
void n2_instantiate_memfunc(symbol *s);
type *n2_adjfunctype(type *t);
int n2_anypure(list_t);
void n2_genvtbl(Classsym *stag, enum SC sc , int);
void n2_genvbtbl(Classsym *stag, enum SC sc , int);
void n2_creatector(type *tclass);
/*void n2_createdtor(type *tclass);*/
symbol *n2_createprimdtor(Classsym *stag);
symbol *n2_createpriminv(Classsym *stag);
symbol *n2_createscaldeldtor(Classsym *stag);
symbol *n2_vecctor(Classsym *stag);
symbol *n2_veccpct(Classsym *stag);
symbol *n2_vecdtor(Classsym *stag, elem *enelems);
symbol *n2_delete(Classsym *stag,symbol *sfunc,unsigned nelems);
void n2_createopeq(Classsym *stag, int flag);
void n2_lookforcopyctor(Classsym *stag);
int n2_iscopyctor(symbol *scpct);
void n2_createcopyctor(Classsym *stag, int flag);
char *n2_genident (void);
symbol *nwc_genthunk(symbol *s, targ_size_t d, int i, targ_size_t d2);
type *enumspec(void);
int type_covariant(type *t1, type *t2);

/* ph.c */
extern char *ph_directory;              /* directory to read PH files from      */
#if MARS
void ph_init();
#else
void ph_init(void *, unsigned reservesize);
#endif
void ph_term(void);
void ph_comdef(symbol *);
void ph_testautowrite(void);
void ph_autowrite(void);
void ph_write(const char *,int);
void ph_auto(void);
int ph_read(char *filename);
int ph_autoread(char *filename);
void *ph_malloc(size_t nbytes);
void *ph_calloc(size_t nbytes);
void ph_free(void *p);
#if TX86
void *ph_realloc(void *p , size_t nbytes);
#else
void *ph_realloc(void *p , size_t nbytes,unsigned short uFlag);
#endif
void ph_add_global_symdef(symbol *s, unsigned sctype);

#if H_STYLE & H_OFFSET
#define dohydrate       ph_hdradjust
#define isdehydrated(p) (ph_hdrbaseaddress <= (p) && (p) < ph_hdrmaxaddress)
#define ph_hydrate(p)   ((isdehydrated(*(void **)(p)) && (*(char **)(p) -= ph_hdradjust)),*(void **)(p))
#define ph_dehydrate(p) ((void)(p))
extern void *ph_hdrbaseaddress;
extern void *ph_hdrmaxaddress;
extern int   ph_hdradjust;
#elif H_STYLE & H_BIT0
#define dohydrate       1
#define isdehydrated(p) ((int)(p) & 1)
extern int ph_hdradjust;
#define ph_hydrate(p)   ((isdehydrated(*(void **)(p)) && (*(char **)(p) -= ph_hdradjust)),*(void **)(p))
#define ph_dehydrate(p) ((*(long *)(p)) && (*(long *)(p) |= 1))
#elif H_STYLE & H_COMPLEX
#define dohydrate       1
#define isdehydrated(p) ((int)(p) & 1)
void *ph_hydrate(void *pp);
void *ph_dehydrate(void *pp);
#elif H_STYLE & H_NONE
#define dohydrate       0
#define isdehydrated(p) 0
#define ph_hydrate(p)   (*(void **)(p))
#define ph_dehydrate(p) ((void)(p))
#else
#error "H_STYLE set wrong"
#endif

/* pragma.c */
#if PRAGMA_PARAM
extern short pragma_param_cnt;
#endif
int pragma_search(const char *id);
macro_t *macfind(void);
macro_t *macdefined(const char *id, unsigned hash);
void listident(void);
char *filename_stringize(char *name);
unsigned char *macro_predefined(macro_t *m);
int macprocess(macro_t *m, phstring_t *pargs, BlklstSave *blsave);
void pragma_include(char *filename,int flag);
void pragma_init(void);
void pragma_term(void);
macro_t *defmac(const char *name , const char *text);
void definedmac();
macro_t *fixeddefmac(const char *name , const char *text);
macro_t *defkwd(const char *name , enum_TK val);
void macro_freelist(macro_t *m);
int pragma_defined(void);
void macro_print(macro_t *m);
void macrotext_print(char *p);

void pragma_hydrate_macdefs(macro_t **pmb,int flag);
void pragma_dehydrate_macdefs(macro_t **pm);

void *pragma_dehydrate(void);
void pragma_hydrate(macro_t **pmactabroot);

// rtti.c
Classsym *rtti_typeinfo();
elem *rtti_cast(enum_TK,elem *,type *);
elem *rtti_typeid(type *,elem *);

/* symbol.c */
char *symbol_ident(symbol *s);
symbol *symbol_search(const char *);
void symbol_tree_hydrate(symbol **ps);
void symbol_tree_dehydrate(symbol **ps);
symbol *symbol_hydrate(symbol **ps);
void symbol_dehydrate(symbol **ps);

inline Classsym *Classsym_hydrate(Classsym **ps)
{
    return (Classsym *) symbol_hydrate((symbol **)ps);
}

inline void Classsym_dehydrate(Classsym **ps)
{
    symbol_dehydrate((symbol **)ps);
}

void symbol_symdefs_dehydrate(symbol **ps);
void symbol_symdefs_hydrate(symbol **ps,symbol **parent,int flag);
void symboltable_hydrate(symbol *s, symbol **parent);
void symboltable_clean(symbol *s);
void symboltable_balance(symbol **ps);
symbol *symbol_membersearch(const char *id);
void symbol_gendebuginfo(void);

/* template.c */
#if TEMPLATE_ACCESS
extern enum SC template_access;
int template_getcmd(char,char *);
#else
int template_getcmd(char *);
#endif
void template_declaration(Classsym *stag, unsigned access_specifier);
void template_instantiate(void);
type *template_expand_type(symbol *s);
Classsym *template_expand(symbol *s, int flag);
void template_instantiate_forward(Classsym *stag);
param_t *template_gargs(symbol *s);
param_t *template_gargs2(symbol *s);
void template_createsymtab(param_t *pt , param_t *p);
void template_deletesymtab(void);
symbol *template_createsym(const char *id, type *t, symbol **proot);
char *template_mangle(symbol *s , param_t *arglist);
symbol *template_matchfunc(symbol *stemp, param_t *pl, int, match_t, param_t *ptal, symbol *stagfriend = NULL);
symbol *template_matchfunctempl(symbol *sfunc, param_t *ptali, type *tf, symbol *stagfriend = NULL, int flags = 1);
int template_match_expanded_type(type *ptyTemplate, param_t *ptpl, param_t *ptal, type *ptyActual,
        type *ptyFormal );
int template_classname(char *vident, Classsym *stag);
void template_free_ptal(param_t *ptal);
int template_function_leastAsSpecialized(symbol *f1, symbol *f2, param_t *ptal);
#if SCPP
Match template_matchtype(type *tp,type *te,elem *ee,param_t *ptpl, param_t *ptal, int flags);
Match template_deduce_ptal(type *tthis, symbol *sfunc, param_t *ptali,
        Match *ma, int flags, param_t *pl, param_t **pptal);
#endif
void template_function_verify(symbol *sfunc, list_t arglist, param_t *ptali, int matchStage);
int template_arglst_match(param_t *p1, param_t *p2);
type * template_tyident(type *t,param_t *ptal,param_t *ptpl, int flag);

void tmf_free(TMF *tmf);
void tmf_hydrate(TMF **ptmf);
void tmf_dehydrate(TMF **ptmf);

void tme_free(TME *tme);
void tme_hydrate(TME **ptme);
void tme_dehydrate(TME **ptme);

void tmne_free(TMNE *tmne);
void tmne_hydrate(TMNE **ptmne);
void tmne_dehydrate(TMNE **ptmne);

void tmnf_free(TMNF *tmnf);
void tmnf_hydrate(TMNF **ptmnf);
void tmnf_dehydrate(TMNF **ptmnf);

extern symlist_t template_ftlist;       // list of template function symbols
extern symbol *template_class_list;
extern symbol **template_class_list_p;
#if PUBLIC_EXT
extern short template_expansion;
#endif

// from htod.c
#if HTOD
void htod_init(const char *name);
void htod_term();
void htod_include(const char *p, int flag);
void htod_include_pop();
void htod_writeline();
void htod_define(macro_t *m);
void htod_decl(symbol *s);
#endif

// from token.c
extern char *Arg;

/* tytostr.c    */
char *type_tostring(Outbuffer *,type *);
char *param_tostring(Outbuffer *,type *);
char *arglist_tostring(Outbuffer *,list_t el);
char *ptpl_tostring(Outbuffer *, param_t *ptpl);
char *el_tostring(Outbuffer *, elem *e);

extern phstring_t pathlist;             // include paths
extern int pathsysi;                    // pathlist[pathsysi] is start of -isystem=
extern list_t headers;                  // pre-include files

extern int structalign;                 /* alignment for members of structures  */
extern char dbcs;
extern int colnumber;                   /* current column number                */
extern int xc;                /* character last read                  */
extern targ_size_t      dsout;          /* # of bytes actually output to data   */
                                        /* segment, used to pad for alignment   */
extern phstring_t fdeplist;
extern char *fdepname;
extern FILE *fdep;
extern char *flstname,*fsymname,*fphreadname,*ftdbname;
extern FILE *flst;
#if HTOD
extern char *fdmodulename;
extern FILE *fdmodule;
#endif
#if SPP
extern FILE *fout;
#endif

extern unsigned idhash;        // hash value of identifier
extern tym_t pointertype;       // default data pointer type
extern int level;               // declaration level
                                // -2: base class list
                                // -1: class body
                                // 0: top level
                                // 1: function parameter declarations
                                // 2: function local declarations
                                // 3+: compound statement decls
#if !TX86
extern symbol *symlinkage;              /* symbol linkage table                 */
#endif
extern param_t *paramlst;               /* function parameter list              */

struct RawString
{
    enum { RAWdchar, RAWstring, RAWend, RAWdone, RAWerror } rawstate;
    char dcharbuf[16 + 1];
    int dchari;

    void init();
    bool inString(unsigned char c);
};

#endif /* PARSER_H */
