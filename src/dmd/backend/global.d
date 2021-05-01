/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/global.d, backend/global.d)
 */
module dmd.backend.global;

// Online documentation: https://dlang.org/phobos/dmd_backend_global.html

extern (C++):
@nogc:
nothrow:

import core.stdc.stdio;
import core.stdc.stdint;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.cc : Symbol, block, Classsym, Blockx;
import dmd.backend.code_x86 : code;
import dmd.backend.code;
import dmd.backend.dlist;
import dmd.backend.el;
import dmd.backend.el : elem;
import dmd.backend.mem;
import dmd.backend.symtab;
import dmd.backend.type;
//import dmd.backend.obj;

import dmd.backend.barray;

nothrow:
@safe:

extern __gshared
{
    char debuga;            // cg - watch assignaddr()
    char debugb;            // watch block optimization
    char debugc;            // watch code generated
    char debugd;            // watch debug information generated
    char debuge;            // dump eh info
    char debugf;            // trees after dooptim
    char debugg;            // trees for code generator
    char debugo;            // watch optimizer
    char debugr;            // watch register allocation
    char debugs;            // watch common subexp eliminator
    char debugt;            // do test points
    char debugu;
    char debugw;            // watch progress
    char debugx;            // suppress predefined CPP stuff
    char debugy;            // watch output to il buffer
}

enum CR = '\r';             // Used because the MPW version of the compiler warps
enum LF = '\n';             // \n into \r and \r into \n.  The translator version
                            // does not and this causes problems with the compilation
                            // with the translator
enum CR_STR = "\r";
enum LF_STR = "\n";

extern __gshared
{
    const uint[32] mask;            // bit masks
    const uint[32] maskl;           // bit masks

    char* argv0;
    char* finname, foutname, foutdir;

    char OPTIMIZER,PARSER;
    symtab_t globsym;

//    Config config;                  // precompiled part of configuration
    char[SCMAX] sytab;

    extern (C) /*volatile*/ int controlc_saw;    // a control C was seen
    block* startblock;              // beginning block of function

    Barray!(block*) dfo;            // array of depth first order

    block* curblock;                // current block being read in
    block* block_last;

    int errcnt;
    regm_t fregsaved;

    tym_t pointertype;              // default data pointer type

    // cg.c
    Symbol* localgot;
    Symbol* tls_get_addr_sym;
}

version (MARS)
    __gshared Configv configv;                // non-ph part of configuration
else
    extern __gshared Configv configv;                // non-ph part of configuration

// iasm.c
Symbol *asm_define_label(const(char)* id);

// cpp.c
const(char)* cpp_mangle(Symbol* s);

// ee.c
void eecontext_convs(SYMIDX marksi);
void eecontext_parse();

// exp2.c
//#define REP_THRESHOLD (REGSIZE * (6+ (REGSIZE == 4)))
        /* doesn't belong here, but func to OPxxx is in exp2 */
void exp2_setstrthis(elem *e,Symbol *s,targ_size_t offset,type *t);
Symbol *exp2_qualified_lookup(Classsym *sclass, int flags, int *pflags);
elem *exp2_copytotemp(elem *e);

/* util.c */
//#if __clang__
//void util_exit(int) __attribute__((noreturn));
//void util_assert(const(char)*, int) __attribute__((noreturn));
//#elif _MSC_VER
//__declspec(noreturn) void util_exit(int);
//__declspec(noreturn) void util_assert(const(char)*, int);
//#else
void util_exit(int);
void util_assert(const(char)*, int);
//#if __DMC__
//#pragma ZTC noreturn(util_exit)
//#pragma ZTC noreturn(util_assert)
//#endif
//#endif

void util_progress();
void util_set16();
void util_set32();
void util_set64();
int ispow2(uint64_t);

version (Posix)
{
void* util_malloc(uint n,uint size) { return mem_malloc(n * size); }
void* util_calloc(uint n,uint size) { return mem_calloc(n * size); }
void util_free(void *p) { mem_free(p); }
void *util_realloc(void *oldp,size_t n,size_t size) { return mem_realloc(oldp, n * size); }
//#define parc_malloc     mem_malloc
//#define parc_calloc     mem_calloc
//#define parc_realloc    mem_realloc
//#define parc_strdup     mem_strdup
//#define parc_free       mem_free
}
else
{
void *util_malloc(uint n,uint size);
void *util_calloc(uint n,uint size);
void util_free(void *p);
void *util_realloc(void *oldp,size_t n,size_t size);
void *parc_malloc(size_t len);
void *parc_calloc(size_t len);
void *parc_realloc(void *oldp,size_t len);
char *parc_strdup(const(char)* s);
void parc_free(void *p);
}

void swap(int *, int *);
//void crlf(FILE *);
int isignore(int);
int isillegal(int);

//#if !defined(__DMC__) && !defined(_MSC_VER)
int ishex(int);
//#endif

/* from cgcs.c */
void comsubs();
void cgcs_term();

/* errmsgs.c */
char *dlcmsgs(int);
void errmsgs_term();

/* from evalu8.c */
int boolres(elem *);
int iftrue(elem *);
int iffalse(elem *);
elem *poptelem(elem *);
elem *poptelem2(elem *);
elem *poptelem3(elem *);
elem *poptelem4(elem *);
elem *selecte1(elem *, type *);

//extern       type *declar(type *,char *,int);

/* from err.c */
void err_message(const(char)* format,...);
void dll_printf(const(char)* format,...);
void cmderr(uint,...);
int synerr(uint,...);
void preerr(uint,...);

//#if __clang__
//void err_exit() __attribute__((analyzer_noreturn));
//void err_nomem() __attribute__((analyzer_noreturn));
//void err_fatal(uint,...) __attribute__((analyzer_noreturn));
//#else
void err_exit();
void err_nomem();
void err_fatal(uint,...);
//#if __DMC__
//#pragma ZTC noreturn(err_exit)
//#pragma ZTC noreturn(err_nomem)
//#pragma ZTC noreturn(err_fatal)
//#endif
//#endif

int cpperr(uint,...);
int tx86err(uint,...);
extern __gshared int errmsgs_tx86idx;
void warerr(uint,...);
void err_warning_enable(uint warnum, int on);
void lexerr(uint,...);

int typerr(int,type *,type *, ...);
void err_noctor(Classsym *stag,list_t arglist);
void err_nomatch(const(char)*, list_t);
void err_ambiguous(Symbol *,Symbol *);
void err_noinstance(Symbol *s1,Symbol *s2);
void err_redeclar(Symbol *s,type *t1,type *t2);
void err_override(Symbol *sfbase,Symbol *sfder);
void err_notamember(const(char)* id, Classsym *s, Symbol *alternate = null);

/* exp.c */
elem *expression();
elem *const_exp();
elem *assign_exp();
elem *exp_simplecast(type *);

/* file.c */
char *file_getsource(const(char)* iname);
int file_isdir(const(char)* fname);
void file_progress();
void file_remove(char *fname);
int file_exists(const(char)* fname);
int file_size(const(char)* fname);
void file_term();
char *file_unique();

/* from msc.c */
type *newpointer(type *);
type *newpointer_share(type *);
type *reftoptr(type *t);
type *newref(type *);
type *topointer(type *);
type *type_ptr(elem *, type *);
int type_chksize(uint);
tym_t tym_conv(const type *);
inout(type)* type_arrayroot(inout type *);
void chklvalue(elem *);
int tolvalue(elem **);
void chkassign(elem *);
void chknosu(const elem *);
void chkunass(const elem *);
void chknoabstract(const type *);
targ_llong msc_getnum();
targ_size_t alignmember(const type *,targ_size_t,targ_size_t);
targ_size_t _align(targ_size_t,targ_size_t);

/* nteh.c */
ubyte *nteh_context_string();
void nteh_declarvars(Blockx *bx);
elem *nteh_setScopeTableIndex(Blockx *blx, int scope_index);
Symbol *nteh_contextsym();
uint nteh_contextsym_size();
Symbol *nteh_ecodesym();
code *nteh_unwind(regm_t retregs,uint index);
code *linux_unwind(regm_t retregs,uint index);
int nteh_offset_sindex();
int nteh_offset_sindex_seh();
int nteh_offset_info();

/* os.c */
void *globalrealloc(void *oldp,size_t nbytes);
void *vmem_baseaddr();
void vmem_reservesize(uint *psize);
uint vmem_physmem();
void *vmem_reserve(void *ptr,uint size);
int   vmem_commit(void *ptr, uint size);
void vmem_decommit(void *ptr,uint size);
void vmem_release(void *ptr,uint size);
void *vmem_mapfile(const(char)* filename,void *ptr,uint size,int flag);
void vmem_setfilesize(uint size);
void vmem_unmapfile();
void os_loadlibrary(const(char)* dllname);
void os_freelibrary();
void *os_getprocaddress(const(char)* funcname);
void os_heapinit();
void os_heapterm();
void os_term();
uint os_unique();
int os_file_exists(const(char)* name);
int os_file_mtime(const(char)* name);
long os_file_size(int fd);
long os_file_size(const(char)* filename);
char *file_8dot3name(const(char)* filename);
int file_write(char *name, void *buffer, uint len);
int file_createdirs(char *name);

/* pseudo.c */
Symbol *pseudo_declar(char *);
extern __gshared
{
    ubyte[24] pseudoreg;
    regm_t[24] pseudomask;
}

/* Symbol.c */
//#if TERMCODE
//void symbol_keep(Symbol *s);
//#else
//#define symbol_keep(s) (()(s))
//#endif
void symbol_keep(Symbol *s) { }
void symbol_print(const Symbol* s);
void symbol_term();
const(char)* symbol_ident(const Symbol *s);
Symbol *symbol_calloc(const(char)* id);
Symbol *symbol_calloc(const(char)* id, uint len);
Symbol *symbol_name(const(char)* name, int sclass, type *t);
Symbol *symbol_name(const(char)* name, uint len, int sclass, type *t);
Symbol *symbol_generate(int sclass, type *t);
Symbol *symbol_genauto(type *t);
Symbol *symbol_genauto(elem *e);
Symbol *symbol_genauto(tym_t ty);
void symbol_func(Symbol *);
//void symbol_struct_addField(Symbol *s, const(char)* name, type *t, uint offset);
Funcsym *symbol_funcalias(Funcsym *sf);
Symbol *defsy(const(char)* p, Symbol **parent);
void symbol_addtotree(Symbol **parent,Symbol *s);
//Symbol *lookupsym(const(char)* p);
Symbol *findsy(const(char)* p, Symbol *rover);
void createglobalsymtab();
void createlocalsymtab();
void deletesymtab();
void meminit_free(meminit_t *m);
baseclass_t *baseclass_find(baseclass_t *bm,Classsym *sbase);
baseclass_t *baseclass_find_nest(baseclass_t *bm,Classsym *sbase);
int baseclass_nitems(baseclass_t *b);
void symbol_free(Symbol *s);
SYMIDX symbol_add(Symbol *s);
SYMIDX symbol_add(ref symtab_t, Symbol *s);
SYMIDX symbol_insert(ref symtab_t, Symbol *s, SYMIDX n);
void freesymtab(Symbol **stab, SYMIDX n1, SYMIDX n2);
Symbol *symbol_copy(Symbol *s);
Symbol *symbol_searchlist(symlist_t sl, const(char)* vident);
void symbol_reset(Symbol *s);
tym_t symbol_pointerType(const Symbol* s);

// cg87.c
void cg87_reset();

ubyte loadconst(elem *e, int im);

/* From cgopt.c */
void opt();


// objrecor.c
void objfile_open(const(char)*);
void objfile_close(void *data, uint len);
void objfile_delete();
void objfile_term();

/* cod3.c */
void cod3_thunk(Symbol *sthunk,Symbol *sfunc,uint p,tym_t thisty,
        uint d,int i,uint d2);

/* out.c */
void outfilename(char *name,int linnum);
void outcsegname(char *csegname);
extern (C) void outthunk(Symbol *sthunk, Symbol *sfunc, uint p, tym_t thisty, targ_size_t d, int i, targ_size_t d2);
void outdata(Symbol *s);
void outcommon(Symbol *s, targ_size_t n);
void out_readonly(Symbol *s);
void out_readonly_comdat(Symbol *s, const(void)* p, uint len, uint nzeros);
void out_regcand(symtab_t *);
void writefunc(Symbol *sfunc);
@trusted void alignOffset(int seg,targ_size_t datasize);
void out_reset();
Symbol *out_readonly_sym(tym_t ty, void *p, int len);
Symbol *out_string_literal(const(char)* str, uint len, uint sz);

/* blockopt.c */
extern __gshared uint[BCMAX] bc_goal;

block* block_calloc();
void block_init();
void block_term();
void block_next(int,block *);
void block_next(Blockx *bctx,int bc,block *bn);
block *block_goto(Blockx *bctx,BC bc,block *bn);
void block_setlabel(uint lbl);
void block_goto();
void block_goto(block *);
void block_goto(block *bgoto, block *bnew);
void block_ptr();
void block_pred();
void block_clearvisit();
void block_visit(block *b);
void block_compbcount();
void blocklist_free(block **pb);
void block_optimizer_free(block *b);
void block_free(block *b);
void blocklist_hydrate(block **pb);
void blocklist_dehydrate(block **pb);
void block_appendexp(block *b, elem *e);
void block_initvar(Symbol *s);
void block_endfunc(int flag);
void brcombine();
void blockopt(int);
void compdfo();

//#define block_initvar(s) (curblock->Binitvar = (s))

/* debug.c */
extern __gshared const(char)*[32] regstring;

void WRclass(int c);
void WRTYxx(tym_t t);
void WROP(uint oper);
void WRBC(uint bc);
void WRarglst(list_t a);
void WRblock(block *b);
void WRblocklist(list_t bl);
void WReqn(elem *e);
void numberBlocks(block* startblock);
void WRfunc();
void WRdefnod();
void WRFL(FL);
char *sym_ident(SYMIDX si);

/* cgelem.c     */
elem *doptelem(elem *, goal_t);
void postoptelem(elem *);
int elemisone(elem *);

/* msc.c */
targ_size_t size(tym_t);
@trusted Symbol *symboldata(targ_size_t offset,tym_t ty);
bool dom(const block* A, const block* B);
uint revop(uint op);
uint invrel(uint op);
int binary(const(char)* p, const(char)** tab, int high);
int binary(const(char)* p, size_t len, const(char)** tab, int high);

/* go.c */
void go_term();
int go_flag(char *cp);
void optfunc();

/* filename.c */
version (SCPP)
{
    extern __gshared Srcfiles srcfiles;
    Sfile **filename_indirect(Sfile *sf);
    Sfile  *filename_search(const(char)* name);
    Sfile *filename_add(const(char)* name);
    void filename_hydrate(Srcfiles *fn);
    void filename_dehydrate(Srcfiles *fn);
    void filename_merge(Srcfiles *fn);
    void filename_mergefl(Sfile *sf);
    void filename_translate(Srcpos *);
    void filename_free();
    int filename_cmp(const(char)* f1,const(char)* f2);
    void srcpos_hydrate(Srcpos *);
    void srcpos_dehydrate(Srcpos *);
}
version (SPP)
{
    extern __gshared Srcfiles srcfiles;
    Sfile **filename_indirect(Sfile *sf);
    Sfile  *filename_search(const(char)* name);
    Sfile *filename_add(const(char)* name);
    int filename_cmp(const(char)* f1,const(char)* f2);
    void filename_translate(Srcpos *);
}
version (HTOD)
{
    extern __gshared Srcfiles srcfiles;
    Sfile **filename_indirect(Sfile *sf);
    Sfile  *filename_search(const(char)* name);
    Sfile *filename_add(const(char)* name);
    void filename_hydrate(Srcfiles *fn);
    void filename_dehydrate(Srcfiles *fn);
    void filename_merge(Srcfiles *fn);
    void filename_mergefl(Sfile *sf);
    int filename_cmp(const(char)* f1,const(char)* f2);
    void filename_translate(Srcpos *);
    void srcpos_hydrate(Srcpos *);
    void srcpos_dehydrate(Srcpos *);
}

// tdb.c
uint tdb_gettimestamp();
void tdb_write(void *buf,uint size,uint numindices);
uint tdb_typidx(void *buf);
//uint tdb_typidx(ubyte *buf,uint length);
void tdb_term();

// rtlsym.c
void rtlsym_init();
void rtlsym_reset();
void rtlsym_term();

// compress.c
extern(C) char *id_compress(const char *id, int idlen, size_t *plen);

// Dwarf
void dwarf_CFA_set_loc(uint location);
void dwarf_CFA_set_reg_offset(int reg, int offset);
void dwarf_CFA_offset(int reg, int offset);
void dwarf_CFA_args_size(size_t sz);

// Posix
elem *exp_isconst();
elem *lnx_builtin_next_arg(elem *efunc,list_t arglist);
char *lnx_redirect_funcname(const(char)*);
void  lnx_funcdecl(Symbol *,SC,enum_SC,int);
int  lnx_attributes(int hinttype,const void *hint, type **ptyp, tym_t *ptym,int *pattrtype);
