// Copyright (C) 1984-1996 by Symantec
// Copyright (C) 2000-2012 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Globals

//#pragma once
#ifndef GLOBAL_H
#define GLOBAL_H        1

#ifndef EL_H
#include        "el.h"
#endif

#include        "obj.h"

#ifdef DEBUG
extern char debuga;            /* cg - watch assignaddr()              */
extern char debugb;            /* watch block optimization             */
extern char debugc;            /* watch code generated                 */
extern char debugd;            /* watch debug information generated    */
extern char debuge;            // dump eh info
extern char debugf;            /* trees after dooptim                  */
extern char debugg;            /* trees for code generator             */
extern char debugo;            // watch optimizer
extern char debugr;            // watch register allocation
extern char debugs;            /* watch common subexp eliminator       */
extern char debugt;            /* do test points                       */
extern char debugu;
extern char debugw;            /* watch progress                       */
extern char debugx;            /* suppress predefined CPP stuff        */
extern char debugy;            /* watch output to il buffer            */
#endif /* DEBUG */

#define CR '\r'                 // Used because the MPW version of the compiler warps
#define LF '\n'                 // \n into \r and \r into \n.  The translator version
                                // does not and this causes problems with the compilation
                                // with the translator
#define CR_STR  "\r"
#define LF_STR "\n"

struct seg_data;

/************************
 * Bit masks
 */

extern const unsigned mask[32];
extern const unsigned long maskl[32];

extern  char *argv0;
extern char *finname,*foutname,*foutdir;

extern char OPTIMIZER,PARSER;
extern symtab_t globsym;

extern Config config;                  // precompiled part of configuration
extern Configv configv;                // non-ph part of configuration
extern char sytab[];

extern volatile int controlc_saw;      /* a control C was seen         */
extern unsigned maxblks;               /* array max for all block stuff                */
extern unsigned numblks;               /* number of basic blocks (if optimized) */
extern block *startblock;              /* beginning block of function  */

extern block **dfo;                    /* array of depth first order   */
extern unsigned dfotop;                /* # of items in dfo[]          */
extern block **labelarr;               /* dynamically allocated array, index is label #*/
extern unsigned labelmax;              /* size of labelarr[]                           */
extern unsigned labeltop;              /* # of used entries in labelarr[]              */
extern block *curblock;                /* current block being read in                  */
extern block *block_last;

extern int errcnt;
extern regm_t fregsaved;

#if SCPP
extern targ_size_t dsout;              /* # of bytes actually output to data */
#endif
extern tym_t pointertype;              /* default data pointer type */

// cg.c
extern symbol *localgot;
extern symbol *tls_get_addr_sym;

// iasm.c
Symbol *asm_define_label(const char *id);

// cpp.c
#if SCPP || MARS
char *cpp_mangle(Symbol *s);
#else
#define cpp_mangle(s)   ((s)->Sident)
#endif

// ee.c
void eecontext_convs(unsigned marksi);
void eecontext_parse();

// exp2.c
#define REP_THRESHOLD (REGSIZE * (6+ (REGSIZE == 4)))
        /* doesn't belong here, but func to OPxxx is in exp2 */
void exp2_setstrthis(elem *e,Symbol *s,targ_size_t offset,type *t);
symbol *exp2_qualified_lookup(Classsym *sclass, int flags, int *pflags);
elem *exp2_copytotemp(elem *e);

/* util.c */
#if __clang__
void util_exit(int) __attribute__((noreturn));
void util_assert(const char *, int) __attribute__((noreturn));
#elif _MSC_VER
__declspec(noreturn) void util_exit(int);
__declspec(noreturn) void util_assert(const char *, int);
#else
void util_exit(int);
void util_assert(const char *, int);
#if __DMC__
#pragma ZTC noreturn(util_exit)
#pragma ZTC noreturn(util_assert)
#endif
#endif

void util_progress();
void util_set16(void);
void util_set32(void);
void util_set64(void);
int ispow2(targ_ullong);

#if __GNUC__
#define util_malloc(n,size) mem_malloc((n)*(size))
#define util_calloc(n,size) mem_calloc((n)*(size))
#define util_free       mem_free
#define util_realloc(oldp,n,size) mem_realloc(oldp,(n)*(size))
#define parc_malloc     mem_malloc
#define parc_calloc     mem_calloc
#define parc_realloc    mem_realloc
#define parc_strdup     mem_strdup
#define parc_free       mem_free
#else
void *util_malloc(unsigned n,unsigned size);
void *util_calloc(unsigned n,unsigned size);
void util_free(void *p);
void *util_realloc(void *oldp,unsigned n,unsigned size);
void *parc_malloc(size_t len);
void *parc_calloc(size_t len);
void *parc_realloc(void *oldp,size_t len);
char *parc_strdup(const char *s);
void parc_free(void *p);
#endif

void swap(int *,int *);
void crlf(FILE *);
char *unsstr(unsigned);
int isignore(int);
int isillegal(int);

#if !defined(__DMC__) && !defined(_MSC_VER)
int ishex(int);
#endif

/* from cgcs.c */
extern void comsubs(void);
void cgcs_term();

/* errmsgs.c */
extern char *dlcmsgs(int);
extern void errmsgs_term();

/* from evalu8.c */
int boolres(elem *);
int iftrue(elem *);
int iffalse(elem *);
elem *poptelem(elem *);
elem *poptelem2(elem *);
elem *poptelem3(elem *);
elem *poptelem4(elem *);
elem *selecte1(elem *,type *);

//extern       type *declar(type *,char *,int);

/* from err.c */
void err_message(const char *format,...);
void dll_printf(const char *format,...);
void cmderr(unsigned,...);
int synerr(unsigned,...);
void preerr(unsigned,...);

#if __clang__
void err_exit(void) __attribute__((analyzer_noreturn));
void err_nomem(void) __attribute__((analyzer_noreturn));
void err_fatal(unsigned,...) __attribute__((analyzer_noreturn));
#else
void err_exit(void);
void err_nomem(void);
void err_fatal(unsigned,...);
#if __DMC__
#pragma ZTC noreturn(err_exit)
#pragma ZTC noreturn(err_nomem)
#pragma ZTC noreturn(err_fatal)
#endif
#endif

int cpperr(unsigned,...);
#if TX86
int tx86err(unsigned,...);
extern int errmsgs_tx86idx;
#endif
void warerr(unsigned,...);
void err_warning_enable(unsigned warnum, int on);
extern void lexerr(unsigned,...);

int typerr(int,type *,type *,...);
void err_noctor(Classsym *stag,list_t arglist);
void err_nomatch(const char *, list_t);
void err_ambiguous(Symbol *,Symbol *);
void err_noinstance(Symbol *s1,Symbol *s2);
void err_redeclar(Symbol *s,type *t1,type *t2);
void err_override(Symbol *sfbase,Symbol *sfder);
void err_notamember(const char *id, Classsym *s, symbol *alternate = NULL);

/* exp.c */
elem *expression(void),*const_exp(void),*assign_exp(void);
elem *exp_simplecast(type *);

/* file.c */
char *file_getsource(const char *iname);
int file_isdir(const char *fname);
void file_progress(void);
void file_remove(char *fname);
int file_stat(const char *fname,struct stat *pbuf);
int file_exists(const char *fname);
long file_size(const char *fname);
void file_term(void);
#if __NT__ && _WINDLL
char *file_nettranslate(const char *filename,const char *mode);
#else
#define file_nettranslate(f,m)  ((char *)(f))
#endif
char *file_unique();

/* from msc.c */
type *newpointer(type *),
     *newpointer_share(type *),
     *reftoptr(type *t),
     *newref(type *),
     *topointer(type *),
     *type_ptr(elem *, type *);
int type_chksize(unsigned long);
tym_t tym_conv(type *);
type * type_arrayroot(type *);
void chklvalue(elem *);
int tolvalue(elem **);
void chkassign(elem *);
void chknosu(elem *);
void chkunass(elem *);
void chknoabstract(type *);
extern targ_llong msc_getnum(void);
extern targ_size_t alignmember(type *,targ_size_t,targ_size_t);
extern targ_size_t align(targ_size_t,targ_size_t);

/* nteh.c */
unsigned char *nteh_context_string();
void nteh_declarvars(Blockx *bx);
elem *nteh_setScopeTableIndex(Blockx *blx, int scope_index);
Symbol *nteh_contextsym();
unsigned nteh_contextsym_size();
Symbol *nteh_ecodesym();
code *nteh_unwind(regm_t retregs,unsigned index);
code *linux_unwind(regm_t retregs,unsigned index);
int nteh_offset_sindex();
int nteh_offset_sindex_seh();
int nteh_offset_info();

/* os.c */
void *globalrealloc(void *oldp,size_t nbytes);
void *vmem_baseaddr();
void vmem_reservesize(unsigned long *psize);
unsigned long vmem_physmem();
void *vmem_reserve(void *ptr,unsigned long size);
int   vmem_commit(void *ptr, unsigned long size);
void vmem_decommit(void *ptr,unsigned long size);
void vmem_release(void *ptr,unsigned long size);
void *vmem_mapfile(const char *filename,void *ptr,unsigned long size,int flag);
void vmem_setfilesize(unsigned long size);
void vmem_unmapfile();
void os_loadlibrary(const char *dllname);
void os_freelibrary();
void *os_getprocaddress(const char *funcname);
void os_heapinit();
void os_heapterm();
void os_term();
unsigned long os_unique();
int os_file_exists(const char *name);
long os_file_size(int fd);
char *file_8dot3name(const char *filename);
int file_write(char *name, void *buffer, unsigned len);
int file_createdirs(char *name);
#if DMDV1
int os_critsecsize32();
int os_critsecsize64();
#endif

#ifdef PSEUDO_REGS
/* pseudo.c */
Symbol *pseudo_declar(char *);

extern unsigned char pseudoreg[];
extern regm_t pseudomask[];
#endif /* PSEUDO_REGS */

/* Symbol.c */
symbol **symtab_realloc(symbol **tab, size_t symmax);
symbol **symtab_malloc(size_t symmax);
symbol **symtab_calloc(size_t symmax);
void symtab_free(symbol **tab);
#if TERMCODE
void symbol_keep(Symbol *s);
#else
#define symbol_keep(s) ((void)(s))
#endif
void symbol_print(Symbol *s);
void symbol_term(void);
char *symbol_ident(symbol *s);
Symbol *symbol_calloc(const char *id);
Symbol *symbol_name(const char *name, int sclass, type *t);
Symbol *symbol_generate(int sclass, type *t);
Symbol *symbol_genauto(type *t);
Symbol *symbol_genauto(elem *e);
Symbol *symbol_genauto(tym_t ty);
void symbol_func(Symbol *);
void symbol_struct_addField(Symbol *s, const char *name, type *t, unsigned offset);
Funcsym *symbol_funcalias(Funcsym *sf);
Symbol *defsy(const char *p, Symbol **parent);
void symbol_addtotree(Symbol **parent,Symbol *s);
//Symbol *lookupsym(const char *p);
Symbol *findsy(const char *p, Symbol *rover);
void createglobalsymtab(void);
void createlocalsymtab(void);
void deletesymtab(void);
void meminit_free(meminit_t *m);
baseclass_t *baseclass_find(baseclass_t *bm,Classsym *sbase);
baseclass_t *baseclass_find_nest(baseclass_t *bm,Classsym *sbase);
int baseclass_nitems(baseclass_t *b);
void symbol_free(Symbol *s);
SYMIDX symbol_add(Symbol *s);
void freesymtab(Symbol **stab, SYMIDX n1, SYMIDX n2);
Symbol * symbol_copy(Symbol *s);
Symbol * symbol_searchlist(symlist_t sl, const char *vident);
void slist_add(Symbol *s);
void slist_reset();


#if TX86
// cg87.c
void cg87_reset();
#endif

unsigned char loadconst(elem *e, int im);

/* From cgopt.c */
extern void opt(void);


// objrecor.c
void objfile_open(const char *);
void objfile_close(void *data, unsigned len);
void objfile_delete();
void objfile_term();

/* cod3.c */
void cod3_thunk(Symbol *sthunk,Symbol *sfunc,unsigned p,tym_t thisty,
        targ_size_t d,int i,targ_size_t d2);

/* out.c */
void outfilename(char *name,int linnum);
void outcsegname(char *csegname);
void outthunk(Symbol *sthunk, Symbol *sfunc, unsigned p, tym_t thisty, targ_size_t d, int i, targ_size_t d2);
void outdata(Symbol *s);
void outcommon(Symbol *s, targ_size_t n);
void out_readonly(Symbol *s);
void out_regcand(symtab_t *);
void writefunc(Symbol *sfunc);
void alignOffset(int seg,targ_size_t datasize);
void out_reset();
symbol *out_readonly_sym(tym_t ty, void *p, int len);

/* blockopt.c */
extern unsigned bc_goal[BCMAX];

block *block_calloc();
void block_init();
void block_term();
#if MARS
void block_next(Blockx *bctx,enum BC bc,block *bn);
block *block_goto(Blockx *bctx,enum BC bc,block *bn);
#else
void block_next(enum BC,block *);
#endif
void block_setlabel(unsigned lbl);
void block_goto();
void block_goto(block *);
void block_goto(block *bgoto, block *bnew);
void block_ptr(void);
void block_pred(void);
void block_clearvisit();
void block_visit(block *b);
void block_compbcount(void);
void blocklist_free(block **pb);
void block_optimizer_free(block *b);
void block_free(block *b);
void blocklist_hydrate(block **pb);
void blocklist_dehydrate(block **pb);
void block_appendexp(block *b, elem *e);
void block_initvar(Symbol *s);
void block_endfunc(int flag);
void brcombine(void);
void blockopt(int);
void compdfo(void);

#define block_initvar(s) (curblock->Binitvar = (s))

#ifdef DEBUG

/* debug.c */
extern const char *regstring[];

void WRclass(enum SC c);
void WRTYxx(tym_t t);
void WROP(unsigned oper);
void WRBC(unsigned bc);
void WRarglst(list_t a);
void WRblock(block *b);
void WRblocklist(list_t bl);
void WReqn(elem *e);
void WRfunc(void);
void WRdefnod(void);
void WRFL(enum FL);
char *sym_ident(SYMIDX si);

#endif

/* cgelem.c     */
elem *doptelem(elem *, goal_t);
void postoptelem(elem *);
unsigned swaprel(unsigned);
int elemisone(elem *);

/* msc.c */
targ_size_t size(tym_t);
Symbol *symboldata(targ_size_t offset,tym_t ty);
bool dom(block *A , block *B);
unsigned revop(unsigned op);
unsigned invrel(unsigned op);
int binary(const char *p, const char ** tab, int high);
int binary(const char *p, size_t len, const char ** tab, int high);

/* go.c */
void go_term(void);
int go_flag(char *cp);
void optfunc(void);

/* filename.c */
#if !MARS
extern Srcfiles srcfiles;
Sfile **filename_indirect(Sfile *sf);
Sfile *filename_search( const char *name );
Sfile *filename_add( const char *name );
void filename_hydrate( Srcfiles *fn );
void filename_dehydrate( Srcfiles *fn );
void filename_merge( Srcfiles *fn );
void filename_mergefl(Sfile *sf);
void filename_translate(Srcpos *);
void filename_free( void );
int filename_cmp(const char *f1,const char *f2);
void srcpos_hydrate(Srcpos *);
void srcpos_dehydrate(Srcpos *);
#endif

// tdb.c
unsigned long tdb_gettimestamp();
void tdb_write(void *buf,unsigned size,unsigned numindices);
unsigned long tdb_typidx(void *buf);
//unsigned long tdb_typidx(unsigned char *buf,unsigned length);
void tdb_term();

// rtlsym.c
void rtlsym_init();
void rtlsym_reset();
void rtlsym_term();

#if SYMDEB_DWARF
void dwarf_CFA_set_loc(size_t location);
void dwarf_CFA_set_reg_offset(int reg, int offset);
void dwarf_CFA_offset(int reg, int offset);
void dwarf_CFA_args_size(size_t sz);
#endif

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
elem * exp_isconst();
elem *lnx_builtin_next_arg(elem *efunc,list_t arglist);
char *lnx_redirect_funcname(const char *);
void  lnx_funcdecl(symbol *,enum SC,enum_SC,int);
int  lnx_attributes(int hinttype,const void *hint, type **ptyp, tym_t *ptym,int *pattrtype);
#endif

#endif /* GLOBAL_H */

