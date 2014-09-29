// Copyright (C) 2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Brad Roberts
/*
 * This file is licensed under the Boost 1.0 license.
 */

// this file stubs out all the apis that are platform specific

#include <stdio.h>

#include "cc.h"
#include "code.h"

static char __file__[] = __FILE__;
#include "tassert.h"

#if SCPP
#error SCPP not supported
#endif

int clib_inited = 0;
const unsigned dblreg[] = { -1 };

code* nteh_epilog()                               { assert(0); return NULL; }
code* nteh_filter(block* b)                       { assert(0); return NULL; }
void  nteh_framehandler(symbol* scopetable)       { assert(0); }
code *nteh_patchindex(code* c, int sindex)        { assert(0); return NULL; }
code* nteh_gensindex(int sindex)                  { assert(0); return NULL; }
code* nteh_monitor_epilog(regm_t retregs)         { assert(0); return NULL; }
code* nteh_monitor_prolog(Symbol* shandle)        { assert(0); return NULL; }
code* nteh_prolog()                               { assert(0); return NULL; }
code* nteh_setsp(int op)                          { assert(0); return NULL; }
code* nteh_unwind(regm_t retregs, unsigned index) { assert(0); return NULL; }

code* REGSAVE::restore(code* c, int reg, unsigned idx) { assert(0); return NULL; }
code* REGSAVE::save(code* c, int reg, unsigned* pidx) { assert(0); return NULL; }

FuncParamRegs::FuncParamRegs(tym_t tyf) { assert(0); }
int FuncParamRegs::alloc(type *t, tym_t ty, unsigned char *preg1, unsigned char *preg2) { assert(0); return 0; }

int dwarf_regno(int reg) { assert(0); return 0; }

code* prolog_ifunc(tym_t* tyf) { assert(0); return NULL; }
code* prolog_ifunc2(tym_t tyf, tym_t tym, bool pushds) { assert(0); return NULL; }
code* prolog_16bit_windows_farfunc(tym_t* tyf, bool* pushds) { assert(0); return NULL; }
code* prolog_frame(unsigned farfunc, unsigned* xlocalsize, bool* enter) { assert(0); return NULL; }
code* prolog_frameadj(tym_t tyf, unsigned xlocalsize, bool enter, bool* pushalloc) { assert(0); return NULL; }
code* prolog_frameadj2(tym_t tyf, unsigned xlocalsize, bool* pushalloc) { assert(0); return NULL; }
code* prolog_setupalloca() { assert(0); return NULL; }
code* prolog_trace(bool farfunc, unsigned* regsaved) { assert(0); return NULL; }
code* prolog_genvarargs(symbol* sv, regm_t* namedargs) { assert(0); return NULL; }
code* prolog_gen_win64_varargs() { assert(0); return NULL; }
code* prolog_loadparams(tym_t tyf, bool pushalloc, regm_t* namedargs) { assert(0); return NULL; }
code* prolog_saveregs(code *c, regm_t topush) { assert(0); return NULL; }
targ_size_t cod3_spoff() { assert(0); }

void  epilog(block* b) { assert(0); }
unsigned calcblksize(code* c) { assert(0); return 0; }
unsigned calccodsize(code* c) { assert(0); return 0; }
unsigned codout(code* c) { assert(0); return 0; }

void assignaddr(block* bl) { assert(0); }
int  branch(block* bl, int flag) { assert(0); return 0; }
void cgsched_block(block* b) { assert(0); }
void doswitch(block* b) { assert(0); }
void jmpaddr(code* c) { assert(0); }
void outblkexitcode(block* bl, code*& c, int& anyspill, const char* sflsave, symbol** retsym, const regm_t mfuncregsave) { assert(0); }
void outjmptab(block* b) { assert(0); }
void outswitab(block* b) { assert(0); }
void pinholeopt(code* c, block* bn) { assert(0); }

bool cse_simple(code* c, elem* e) { assert(0); return false; }
code* comsub87(elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* fixresult(elem* e, regm_t retregs, regm_t* pretregs) { assert(0); return NULL; }
code* genmovreg(code* c, unsigned to, unsigned from) { assert(0); return NULL; }
code* genpush(code *c , unsigned reg) { assert(0); return NULL; }
code* gensavereg(unsigned& reg, targ_uns slot) { assert(0); return NULL; }
code* gen_spill_reg(Symbol* s, bool toreg) { assert(0); return NULL; }
code* genstackclean(code* c, unsigned numpara, regm_t keepmsk) { assert(0); return NULL; }
code* loaddata(elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* longcmp(elem* e, bool jcond, unsigned fltarg, code* targ) { assert(0); return NULL; }
code* movregconst(code* c, unsigned reg, targ_size_t value, regm_t flags) { assert(0); return NULL; }
code* params(elem* e, unsigned stackalign) { assert(0); return NULL; }
code* save87() { assert(0); return NULL; }
code* tstresult(regm_t regm, tym_t tym, unsigned saveflag) { assert(0); return NULL; }
int cod3_EA(code* c) { assert(0); return 0; }
regm_t cod3_useBP() { assert(0); return 0; }
regm_t regmask(tym_t tym, tym_t tyf) { assert(0); return 0; }
targ_size_t cod3_bpoffset(symbol* s) { assert(0); return 0; }
unsigned char loadconst(elem* e, int im) { assert(0); return 0; }
void cod3_adjSymOffsets() { assert(0); }
void cod3_align() { assert(0); }
void cod3_align_bytes(size_t nbytes) { assert(0); }
void cod3_initregs() { assert(0); }
void cod3_setdefault() { assert(0); }
void cod3_set32() { assert(0); }
void cod3_set64() { assert(0); }
void cod3_thunk(symbol* sthunk, symbol* sfunc, unsigned p, tym_t thisty, targ_size_t d, int i, targ_size_t d2) { assert(0); }
void genEEcode() { assert(0); }
unsigned gensaverestore(regm_t regm, code** csave, code** crestore) { assert(0); return 0; }
unsigned gensaverestore2(regm_t regm, code** csave, code** crestore) { assert(0); return 0; }

bool isXMMstore(unsigned op) { assert(0); return false; }
const unsigned char* getintegerparamsreglist(tym_t tyf, size_t* num) { assert(0); *num = 0; return NULL; }
const unsigned char* getfloatparamsreglist(tym_t tyf, size_t* num) { assert(0); *num = 0; return NULL; }
void cod3_buildmodulector(Outbuffer* buf, int codeOffset, int refOffset) { assert(0); }
code* gen_testcse(code *c, unsigned sz, targ_uns i) { assert(0); return NULL; }
code* gen_loadcse(code *c, unsigned reg, targ_uns i) { assert(0); return NULL; }
code* cod3_stackadj(code* c, int nbytes) { assert(0); return NULL; }
void simplify_code(code *c) { assert(0); }
void cgreg_dst_regs(unsigned *dst_integer_reg, unsigned *dst_float_reg) { assert(0); }
void cgreg_set_priorities(tym_t ty, char **pseq, char **pseqmsw) { assert(0); }

code* cdabs      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdaddass   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdasm      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdbscan    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdbtst     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdbswap    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdbt       (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdbyteint  (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdcmp      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdcnvt     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdcom      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdcomma    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdcond     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdconvt87  (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdctor     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cddctor    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdddtor    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cddtor     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdeq       (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cderr      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdframeptr (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdfunc     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdgot      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdhalt     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdind      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdinfo     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdlngsht   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdloglog   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmark     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmemcmp   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmemcpy   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmemset   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmsw      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmul      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdmulass   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdneg      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdnot      (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdnullcheck(elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdorth     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdpair     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdpopcnt   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdport     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdpost     (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdrelconst (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdrndtol   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdscale    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdsetjmp   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdshass    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdshift    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdshtlng   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdstrcmp   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdstrcpy   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdstreq    (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdstrlen   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdstrthis  (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdvecsto   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdvector   (elem* e, regm_t* pretregs) { assert(0); return NULL; }
code* cdvoid     (elem* e, regm_t* pretregs) { assert(0); return NULL; }

