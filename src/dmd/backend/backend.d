/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 *
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/backend.d, backend/backend.d)
 */
module dmd.backend.backend;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.el;
import dmd.backend.outbuf;

extern (C++):

nothrow:

/* cgcod.d */
extern __gshared int pass;
enum
{
    PASSinitial,     // initial pass through code generator
    PASSreg,         // register assignment pass
    PASSfinal,       // final pass
}

extern __gshared int dfoidx;
extern __gshared bool floatreg;
extern __gshared targ_size_t prolog_allocoffset;
extern __gshared targ_size_t startoffset;
extern __gshared targ_size_t retsize;
extern __gshared uint stackpush;
extern __gshared int stackchanged;
extern __gshared int reflocal;
extern __gshared bool anyiasm;
extern __gshared char calledafunc;
extern __gshared bool calledFinally;

void stackoffsets(int);
void codgen(Symbol *);

debug
{
    reg_t findreg(regm_t regm , int line, const(char)* file);
    extern (D) reg_t findreg(regm_t regm , int line = __LINE__, string file = __FILE__)
    { return findreg(regm, line, file.ptr); }
}
else
{
    reg_t findreg(regm_t regm);
}

reg_t findregmsw(uint regm) { return findreg(regm & mMSW); }
reg_t findreglsw(uint regm) { return findreg(regm & (mLSW | mBP)); }
void freenode(elem *e);
int isregvar(elem *e, regm_t *pregm, reg_t *preg);
void allocreg(ref CodeBuilder cdb, regm_t *pretregs, reg_t *preg, tym_t tym, int line, const(char)* file);
void allocreg(ref CodeBuilder cdb, regm_t *pretregs, reg_t *preg, tym_t tym);
regm_t lpadregs();
void useregs (regm_t regm);
void getregs(ref CodeBuilder cdb, regm_t r);
void getregsNoSave(regm_t r);
void getregs_imm(ref CodeBuilder cdb, regm_t r);
void cse_flush(ref CodeBuilder, int);
bool cse_simple(code *c, elem *e);
bool cssave (elem *e , regm_t regm , uint opsflag );
bool evalinregister(elem *e);
regm_t getscratch();
void codelem(ref CodeBuilder cdb, elem *e, regm_t *pretregs, uint constflag);
void scodelem(ref CodeBuilder cdb, elem *e, regm_t *pretregs, regm_t keepmsk, bool constflag);
const(char)* regm_str(regm_t rm);
int numbitsset(regm_t);

/* cdxxx.d: functions that go into cdxxx[] table */
void cdabs(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdaddass(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdasm(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdbscan(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdbswap(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdbt(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdbtst(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdbyteint(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdcmp(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdcmpxchg(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdcnvt(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdcom(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdcomma(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdcond(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdconvt87(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdctor(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cddctor(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdddtor(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cddtor(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdeq(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cderr(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdfar16(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdframeptr(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdfunc(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdgot(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdhalt(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdind(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdinfo(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdlngsht(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdloglog(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmark(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmemcmp(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmemcpy(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmemset(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmsw(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmul(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmulass(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdneg(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdnot(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdorth(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdpair(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdpopcnt(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdport(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdpost(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdprefetch(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdrelconst(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdrndtol(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdscale(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdsetjmp(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdshass(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdshift(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdshtlng(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdstrcmp(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdstrcpy(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdstreq(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdstrlen(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdstrthis(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvecfill(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvecsto(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvector(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvoid(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void loaddata(ref CodeBuilder cdb, elem* e, regm_t* pretregs);

/* cod1.d */
extern __gshared int clib_inited;

bool regParamInPreg(Symbol* s);
int isscaledindex(elem *);
int ssindex(int op,targ_uns product);
void buildEA(code *c,int base,int index,int scale,targ_size_t disp);
uint buildModregrm(int mod, int reg, int rm);
void andregcon (con_t *pregconsave);
void genEEcode();
void docommas(ref CodeBuilder cdb,elem **pe);
uint gensaverestore(regm_t, ref CodeBuilder cdbsave, ref CodeBuilder cdbrestore);
void genstackclean(ref CodeBuilder cdb,uint numpara,regm_t keepmsk);
void logexp(ref CodeBuilder cdb, elem *e, int jcond, uint fltarg, code *targ);
uint getaddrmode(regm_t idxregs);
void setaddrmode(code *c, regm_t idxregs);
void fltregs(ref CodeBuilder cdb, code *pcs, tym_t tym);
void tstresult(ref CodeBuilder cdb, regm_t regm, tym_t tym, uint saveflag);
void fixresult(ref CodeBuilder cdb, elem *e, regm_t retregs, regm_t *pretregs);
void callclib(ref CodeBuilder cdb, elem *e, uint clib, regm_t *pretregs, regm_t keepmask);
void pushParams(ref CodeBuilder cdb,elem *, uint, tym_t tyf);
void offsetinreg(ref CodeBuilder cdb, elem *e, regm_t *pretregs);

/* cod2.d */
bool movOnly(const elem *e);
regm_t idxregm(const code *c);
void opdouble(ref CodeBuilder cdb, elem *e, regm_t *pretregs, uint clib);
void WRcodlst(code *c);
void getoffset(ref CodeBuilder cdb, elem *e, reg_t reg);

/* cod3.d */
int cod3_EA(code *c);
regm_t cod3_useBP();
void cod3_initregs();
void cod3_setdefault();
void cod3_set32();
void cod3_set64();
void cod3_align_bytes(int seg, size_t nbytes);
void cod3_align(int seg);
void cod3_buildmodulector(Outbuffer* buf, int codeOffset, int refOffset);
void cod3_stackadj(ref CodeBuilder cdb, int nbytes);
void cod3_stackalign(ref CodeBuilder cdb, int nbytes);
regm_t regmask(tym_t tym, tym_t tyf);
void cgreg_dst_regs(reg_t* dst_integer_reg, reg_t* dst_float_reg);
void cgreg_set_priorities(tym_t ty, const(reg_t)** pseq, const(reg_t)** pseqmsw);
void outblkexitcode(ref CodeBuilder cdb, block *bl, ref int anyspill, const(char)* sflsave, Symbol** retsym, const regm_t mfuncregsave );
void outjmptab(block *b);
void outswitab(block *b);
int jmpopcode(elem *e);
void cod3_ptrchk(ref CodeBuilder cdb,code *pcs,regm_t keepmsk);
void genregs(ref CodeBuilder cdb, opcode_t op, uint dstreg, uint srcreg);
void gentstreg(ref CodeBuilder cdb, uint reg);
void genpush(ref CodeBuilder cdb, reg_t reg);
void genpop(ref CodeBuilder cdb, reg_t reg);
void gen_storecse(ref CodeBuilder cdb, tym_t tym, reg_t reg, size_t slot);
void gen_testcse(ref CodeBuilder cdb, tym_t tym, uint sz, size_t i);
void gen_loadcse(ref CodeBuilder cdb, tym_t tym, reg_t reg, size_t slot);
code *genmovreg(uint to, uint from);
void genmovreg(ref CodeBuilder cdb, uint to, uint from);
void genmovreg(ref CodeBuilder cdb, uint to, uint from, tym_t tym);
void genmulimm(ref CodeBuilder cdb,uint r1,uint r2,targ_int imm);
void genshift(ref CodeBuilder cdb);
void movregconst(ref CodeBuilder cdb,reg_t reg,targ_size_t value,regm_t flags);
void genjmp(ref CodeBuilder cdb, opcode_t op, uint fltarg, block *targ);
void prolog(ref CodeBuilder cdb);
void epilog (block *b);
void gen_spill_reg(ref CodeBuilder cdb, Symbol *s, bool toreg);
void load_localgot(ref CodeBuilder cdb);
void makeitextern (Symbol *s );
void fltused();
int branch(block *bl, int flag);
void cod3_adjSymOffsets();
void assignaddr(block *bl);
void assignaddrc(code *c);
void pinholeopt (code *c , block *bn );
void simplify_code(code *c);
void jmpaddr (code *c);
int code_match(code *c1,code *c2);
uint calcblksize (code *c);
uint codout(int seg, code *c);
size_t addtofixlist(Symbol *s , targ_size_t soffset , int seg , targ_size_t val , int flags );
void searchfixlist(Symbol *s) {}
void outfixlist();
void code_hydrate(code **pc);
void code_dehydrate(code **pc);

extern __gshared
{
    int hasframe;            /* !=0 if this function has a stack frame */
    bool enforcealign;       /* enforced stack alignment */
    targ_size_t spoff;
    targ_size_t Foff;        // BP offset of floating register
    targ_size_t CSoff;       // offset of common sub expressions
    targ_size_t NDPoff;      // offset of saved 8087 registers
    targ_size_t pushoff;     // offset of saved registers
    bool pushoffuse;         // using pushoff
    int BPoff;               // offset from BP
    int EBPtoESP;            // add to EBP offset to get ESP offset
}

void prolog_ifunc(ref CodeBuilder cdb, tym_t* tyf);
void prolog_ifunc2(ref CodeBuilder cdb, tym_t tyf, tym_t tym, bool pushds);
void prolog_16bit_windows_farfunc(ref CodeBuilder cdb, tym_t* tyf, bool* pushds);
void prolog_frame(ref CodeBuilder cdb, uint farfunc, uint* xlocalsize, bool* enter, int* cfa_offset);
void prolog_frameadj(ref CodeBuilder cdb, tym_t tyf, uint xlocalsize, bool enter, bool* pushalloc);
void prolog_frameadj2(ref CodeBuilder cdb, tym_t tyf, uint xlocalsize, bool* pushalloc);
void prolog_setupalloca(ref CodeBuilder cdb);
void prolog_saveregs(ref CodeBuilder cdb, regm_t topush, int cfa_offset);
void prolog_stackalign(ref CodeBuilder cdb);
void prolog_trace(ref CodeBuilder cdb, bool farfunc, uint* regsaved);
void prolog_gen_win64_varargs(ref CodeBuilder cdb);
void prolog_genvarargs(ref CodeBuilder cdb, Symbol* sv, regm_t namedargs);
void prolog_loadparams(ref CodeBuilder cdb, tym_t tyf, bool pushalloc, out regm_t namedargs);

/* cod4.d */
extern __gshared
{
const reg_t[4] dblreg;
int cdcmp_flag;
}

int doinreg(Symbol *s, elem *e);
void modEA(ref CodeBuilder cdb, code *c);
void longcmp(ref CodeBuilder,elem *,bool,uint,code *);

/* cod5.d */
void cod5_prol_epi();
void cod5_noprol();

/* cgxmm.d */
void orthxmm(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void xmmeq(ref CodeBuilder cdb, elem *e, opcode_t op, elem *e1, elem *e2, regm_t *pretregs);
void xmmcnvt(ref CodeBuilder cdb,elem *e,regm_t *pretregs);
void xmmopass(ref CodeBuilder cdb,elem *e, regm_t *pretregs);
void xmmpost(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void xmmneg(ref CodeBuilder cdb,elem *e, regm_t *pretregs);
uint xmmload(tym_t tym, bool aligned = true);
uint xmmstore(tym_t tym, bool aligned = true);
bool xmmIsAligned(elem *e);
void checkSetVex(code *c, tym_t ty);

/* cg87.c */
extern __gshared { int stackused; }
extern __gshared NDP[8] _8087elems;

void note87(elem *e, uint offset, int i);
void pop87(int, const(char)*);
void pop87();
void push87(ref CodeBuilder cdb);
void save87(ref CodeBuilder cdb);
void save87regs(ref CodeBuilder cdb, uint n);
void gensaverestore87(regm_t, ref CodeBuilder cdbsave, ref CodeBuilder cdbrestore);
//code *genfltreg(code *c,opcode_t opcode,uint reg,targ_size_t offset);
void genfwait(ref CodeBuilder cdb);
void comsub87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void fixresult87(ref CodeBuilder cdb, elem *e, regm_t retregs, regm_t *pretregs);
void fixresult_complex87(ref CodeBuilder cdb,elem *e,regm_t retregs,regm_t *pretregs);
void orth87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void load87(ref CodeBuilder cdb, elem *e, uint eoffset, regm_t *pretregs, elem *eleft, int op);
int cmporder87 (elem *e );
void eq87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void complex_eq87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void opass87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void cdnegass87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void post87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void cnvt87(ref CodeBuilder cdb, elem *e , regm_t *pretregs );
void neg87(ref CodeBuilder cdb, elem *e , regm_t *pretregs);
void neg_complex87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void cdind87(ref CodeBuilder cdb,elem *e,regm_t *pretregs);
void cload87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void cdd_u64(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void cdd_u32(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void loadPair87(ref CodeBuilder cdb, elem *e, regm_t *pretregs);

/* iasm.c */
//void iasm_term();
regm_t iasm_regs(block *bp);


/**********************************
 * Set value in regimmed for reg.
 * NOTE: For 16 bit generator, this is always a (targ_short) sign-extended
 *      value.
 */

void regimmed_set(int reg, targ_size_t e)
{
    regcon.immed.value[reg] = e;
    regcon.immed.mval |= 1 << (reg);
    //printf("regimmed_set %s %d\n", regm_str(1 << reg), cast(int)e);
}


}
