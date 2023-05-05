/**
 * Declarations for back end
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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

public import dmd.backend.var : debuga, debugb, debugc, debugd, debuge, debugf,
    debugr, debugs, debugt, debugu, debugw, debugx, debugy;

enum CR = '\r';             // Used because the MPW version of the compiler warps
enum LF = '\n';             // \n into \r and \r into \n.  The translator version
                            // does not and this causes problems with the compilation
                            // with the translator
enum CR_STR = "\r";
enum LF_STR = "\n";

public import dmd.backend.cgxmm : mask;
public import dmd.backend.var : OPTIMIZER, PARSER, globsym, controlc_saw, pointertype, sytab;
public import dmd.backend.cg : fregsaved, localgot, tls_get_addr_sym;
public import dmd.backend.blockopt : startblock, dfo, curblock, block_last;

__gshared Configv configv;                // non-ph part of configuration

public import dmd.backend.ee : eecontext_convs;
public import dmd.backend.elem : exp2_copytotemp;

void util_progress();
void util_set16();
void util_set32(exefmt_t);
void util_set64(exefmt_t);
int ispow2(ulong);

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
public import dmd.backend.ph2 : err_nomem;
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

/* file.c */
void file_progress();

/* from msc.c */
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

void symbol_keep(Symbol *s) { }
public import dmd.backend.symbol : symbol_print, symbol_term, symbol_ident, symbol_calloc,
    symbol_name, symbol_generate, symbol_genauto, symbol_genauto, symbol_genauto,
    symbol_func, symbol_funcalias, meminit_free, baseclass_find, baseclass_find_nest,
    baseclass_nitems, symbol_free, symbol_add, symbol_add, symbol_insert, freesymtab,
    symbol_copy, symbol_reset, symbol_pointerType;

public import dmd.backend.cg87 : loadconst, cg87_reset;

public import dmd.backend.cod3 : cod3_thunk;

public import dmd.backend.dout : outthunk, out_readonly, out_readonly_comdat,
    out_regcand, writefunc, alignOffset, out_reset, out_readonly_sym, out_string_literal;

void outdata(Symbol *s);

public import dmd.backend.blockopt : bc_goal, block_calloc, block_init, block_term, block_next,
    block_next, block_goto, block_goto, block_goto, block_goto, block_ptr, block_pred,
    block_clearvisit, block_visit, block_compbcount, blocklist_free, block_optimizer_free,
    block_free, block_appendexp, block_endfunc, brcombine, blockopt, compdfo;

public import dmd.backend.var : regstring;
public import dmd.backend.debugprint;
public import dmd.backend.cgelem : doptelem, postoptelem, elemisone;
public import dmd.backend.gloop : dom;
public import dmd.backend.util2 : binary;
/* msc.c */
@trusted Symbol *symboldata(targ_size_t offset,tym_t ty);
targ_size_t size(tym_t);

public import dmd.backend.go : go_flag, optfunc;
public import dmd.backend.drtlsym : rtlsym_init, rtlsym_reset, rtlsym_term;
public import dmd.backend.compress : id_compress;
public import dmd.backend.dwarfdbginf : dwarf_CFA_set_loc, dwarf_CFA_set_reg_offset,
    dwarf_CFA_offset, dwarf_CFA_args_size;
