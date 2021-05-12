/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/code.d, backend/_code.d)
 */

module dmd.backend.code;

// Online documentation: https://dlang.org/phobos/dmd_backend_code.html

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.el : elem;
import dmd.backend.oper : OPMAX;
import dmd.backend.outbuf;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):

nothrow:
@safe:

alias segidx_t = int;           // index into SegData[]

/**********************************
 * Code data type
 */

struct _Declaration;
struct _LabelDsymbol;

union evc
{
    targ_int    Vint;           /// also used for tmp numbers (FLtmp)
    targ_uns    Vuns;
    targ_long   Vlong;
    targ_llong  Vllong;
    targ_size_t Vsize_t;
    struct
    {
        targ_size_t Vpointer;
        int Vseg;               /// segment the pointer is in
    }
    Srcpos      Vsrcpos;        /// source position for OPlinnum
    elem       *Vtor;           /// OPctor/OPdtor elem
    block      *Vswitch;        /// when FLswitch and we have a switch table
    code       *Vcode;          /// when code is target of a jump (FLcode)
    block      *Vblock;         /// when block " (FLblock)
    struct
    {
        targ_size_t Voffset;    /// offset from symbol
        Symbol  *Vsym;          /// pointer to symbol table (FLfunc,FLextern)
    }

    struct
    {
        targ_size_t Vdoffset;   /// offset from symbol
        _Declaration *Vdsym;    /// pointer to D symbol table
    }

    struct
    {
        targ_size_t Vloffset;   /// offset from symbol
        _LabelDsymbol *Vlsym;   /// pointer to D Label
    }

    struct
    {
        size_t len;
        char *bytes;
    }                           // asm node (FLasm)
}

/********************** PUBLIC FUNCTIONS *******************/

code *code_calloc();
void code_free(code *);
void code_term();

code *code_next(code *c) { return c.next; }

code *code_chunk_alloc();
extern __gshared code *code_list;

@trusted
code *code_malloc()
{
    //printf("code %d\n", sizeof(code));
    code *c = code_list ? code_list : code_chunk_alloc();
    code_list = code_next(c);
    //printf("code_malloc: %p\n",c);
    return c;
}

extern __gshared con_t regcon;

/************************************
 * Register save state.
 */

struct REGSAVE
{
    targ_size_t off;            // offset on stack
    uint top;                   // high water mark
    uint idx;                   // current number in use
    int alignment;              // 8 or 16

  nothrow:
    @trusted
    void reset() { off = 0; top = 0; idx = 0; alignment = _tysize[TYnptr]/*REGSIZE*/; }
    void save(ref CodeBuilder cdb, reg_t reg, uint *pidx) { REGSAVE_save(this, cdb, reg, *pidx); }
    void restore(ref CodeBuilder cdb, reg_t reg, uint idx) { REGSAVE_restore(this, cdb, reg, idx); }
}

void REGSAVE_save(ref REGSAVE regsave, ref CodeBuilder cdb, reg_t reg, out uint idx);
void REGSAVE_restore(const ref REGSAVE regsave, ref CodeBuilder cdb, reg_t reg, uint idx);

extern __gshared REGSAVE regsave;

/************************************
 * Local sections on the stack
 */
struct LocalSection
{
    targ_size_t offset;         // offset of section from frame pointer
    targ_size_t size;           // size of section
    int alignment;              // alignment size

  nothrow:
    void init()                 // initialize
    {   offset = 0;
        size = 0;
        alignment = 0;
    }
}

/*******************************
 * As we generate code, collect information about
 * what parts of NT exception handling we need.
 */

extern __gshared uint usednteh;

enum
{
    NTEH_try        = 1,      // used _try statement
    NTEH_except     = 2,      // used _except statement
    NTEHexcspec     = 4,      // had C++ exception specification
    NTEHcleanup     = 8,      // destructors need to be called
    NTEHtry         = 0x10,   // had C++ try statement
    NTEHcpp         = (NTEHexcspec | NTEHcleanup | NTEHtry),
    EHcleanup       = 0x20,   // has destructors in the 'code' instructions
    EHtry           = 0x40,   // has BCtry or BC_try blocks
    NTEHjmonitor    = 0x80,   // uses Mars monitor
    NTEHpassthru    = 0x100,
}

/********************** Code Generator State ***************/

struct CGstate
{
    int stackclean;     // if != 0, then clean the stack after function call

    LocalSection funcarg;       // where function arguments are placed
    targ_size_t funcargtos;     // current high water level of arguments being moved onto
                                // the funcarg section. It is filled from top to bottom,
                                // as if they were 'pushed' on the stack.
                                // Special case: if funcargtos==~0, then no
                                // arguments are there.
    bool accessedTLS;           // set if accessed Thread Local Storage (TLS)
}

// nteh.c
void nteh_prolog(ref CodeBuilder cdb);
void nteh_epilog(ref CodeBuilder cdb);
void nteh_usevars();
void nteh_filltables();
void nteh_gentables(Symbol *sfunc);
void nteh_setsp(ref CodeBuilder cdb, opcode_t op);
void nteh_filter(ref CodeBuilder cdb, block *b);
void nteh_framehandler(Symbol *, Symbol *);
void nteh_gensindex(ref CodeBuilder, int);
enum GENSINDEXSIZE = 7;
void nteh_monitor_prolog(ref CodeBuilder cdb,Symbol *shandle);
void nteh_monitor_epilog(ref CodeBuilder cdb,regm_t retregs);
code *nteh_patchindex(code* c, int index);
void nteh_unwind(ref CodeBuilder cdb,regm_t retregs,uint index);

// cgen.c
code *code_last(code *c);
void code_orflag(code *c,uint flag);
void code_orrex(code *c,uint rex);
code *setOpcode(code *c, code *cs, opcode_t op);
code *cat(code *c1, code *c2);
code *gen (code *c , code *cs );
code *gen1 (code *c , opcode_t op );
code *gen2 (code *c , opcode_t op , uint rm );
code *gen2sib(code *c,opcode_t op,uint rm,uint sib);
code *genc2 (code *c , opcode_t op , uint rm , targ_size_t EV2 );
code *genc (code *c , opcode_t op , uint rm , uint FL1 , targ_size_t EV1 , uint FL2 , targ_size_t EV2 );
code *genlinnum(code *,Srcpos);
void cgen_prelinnum(code **pc,Srcpos srcpos);
code *gennop(code *);
void gencodelem(ref CodeBuilder cdb,elem *e,regm_t *pretregs,bool constflag);
bool reghasvalue (regm_t regm , targ_size_t value , reg_t *preg );
void regwithvalue(ref CodeBuilder cdb, regm_t regm, targ_size_t value, reg_t *preg, regm_t flags);

// cgreg.c
void cgreg_init();
void cgreg_term();
void cgreg_reset();
void cgreg_used(uint bi,regm_t used);
void cgreg_spillreg_prolog(block *b,Symbol *s,ref CodeBuilder cdbstore,ref CodeBuilder cdbload);
void cgreg_spillreg_epilog(block *b,Symbol *s,ref CodeBuilder cdbstore,ref CodeBuilder cdbload);
int cgreg_assign(Symbol *retsym);
void cgreg_unregister(regm_t conflict);

// cgsched.c
void cgsched_block(block *b);

alias IDXSTR = uint;
alias IDXSEC = uint;
alias IDXSYM = uint;

struct seg_data
{
    segidx_t             SDseg;         // index into SegData[]
    targ_size_t          SDoffset;      // starting offset for data
    int                  SDalignment;   // power of 2

    static if (1) // for Windows
    {
        bool isfarseg;
        int segidx;                     // internal object file segment number
        int lnameidx;                   // lname idx of segment name
        int classidx;                   // lname idx of class name
        uint attr;                      // segment attribute
        targ_size_t origsize;           // original size
        int seek;                       // seek position in output file
        void* ledata;                   // (Ledatarec) current one we're filling in
    }

    //ELFOBJ || MACHOBJ
    IDXSEC           SDshtidx;          // section header table index
    Outbuffer       *SDbuf;             // buffer to hold data
    Outbuffer       *SDrel;             // buffer to hold relocation info

    //ELFOBJ
    IDXSYM           SDsymidx;          // each section is in the symbol table
    IDXSEC           SDrelidx;          // section header for relocation info
    targ_size_t      SDrelmaxoff;       // maximum offset encountered
    int              SDrelindex;        // maximum offset encountered
    int              SDrelcnt;          // number of relocations added
    IDXSEC           SDshtidxout;       // final section header table index
    Symbol          *SDsym;             // if !=NULL, comdat symbol
    segidx_t         SDassocseg;        // for COMDATs, if !=0, this is the "associated" segment

    uint             SDaranges_offset;  // if !=0, offset in .debug_aranges

    Barray!(linnum_data) SDlinnum_data;     // array of line number / offset data

  nothrow:
    @trusted
    int isCode() { return config.objfmt == OBJ_MACH ? mach_seg_data_isCode(this) : mscoff_seg_data_isCode(this); }
}

extern int mach_seg_data_isCode(const ref seg_data sd) @system;
extern int mscoff_seg_data_isCode(const ref seg_data sd) @system;

struct linnum_data
{
    const(char) *filename;
    uint filenumber;        // corresponding file number for DW_LNS_set_file

    Barray!(LinOff) linoff;    // line numbers and offsets
}

struct LinOff
{
    uint lineNumber;
    uint offset;
}

extern __gshared Rarray!(seg_data*) SegData;

@trusted
ref targ_size_t Offset(int seg) { return SegData[seg].SDoffset; }

@trusted
ref targ_size_t Doffset() { return Offset(DATA); }

@trusted
ref targ_size_t CDoffset() { return Offset(CDATA); }

/**************************************************/

/* Allocate registers to function parameters
 */

struct FuncParamRegs
{
    //this(tym_t tyf);
    @trusted
    static FuncParamRegs create(tym_t tyf) { return FuncParamRegs_create(tyf); }

    @trusted
    int alloc(type *t, tym_t ty, ubyte *reg1, ubyte *reg2)
    { return FuncParamRegs_alloc(this, t, ty, reg1, reg2); }

  private:
  public: // for the moment
    tym_t tyf;                  // type of function
    int i;                      // ith parameter
    int regcnt;                 // how many general purpose registers are allocated
    int xmmcnt;                 // how many fp registers are allocated
    uint numintegerregs;        // number of gp registers that can be allocated
    uint numfloatregs;          // number of fp registers that can be allocated
    const(ubyte)* argregs;      // map to gp register
    const(ubyte)* floatregs;    // map to fp register
}

extern FuncParamRegs FuncParamRegs_create(tym_t tyf) @system;
extern int FuncParamRegs_alloc(ref FuncParamRegs fpr, type *t, tym_t ty, reg_t *preg1, reg_t *preg2) @system;

extern __gshared
{
    regm_t msavereg,mfuncreg,allregs;

    int BPRM;
    regm_t FLOATREGS;
    regm_t FLOATREGS2;
    regm_t DOUBLEREGS;
    //const char datafl[],stackfl[],segfl[],flinsymtab[];
    char needframe,gotref;
    targ_size_t localsize,
        funcoffset,
        framehandleroffset;
    segidx_t cseg;
    int STACKALIGN;
    int TARGET_STACKALIGN;
    LocalSection Para;
    LocalSection Fast;
    LocalSection Auto;
    LocalSection EEStack;
    LocalSection Alloca;
}

/* cgcod.c */
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
extern __gshared targ_size_t retoffset;
extern __gshared targ_size_t retsize;
extern __gshared uint stackpush;
extern __gshared int stackchanged;
extern __gshared int refparam;
extern __gshared int reflocal;
extern __gshared bool anyiasm;
extern __gshared char calledafunc;
extern __gshared bool calledFinally;

void codgen(Symbol *);

debug
{
    reg_t findreg(regm_t regm , int line, const(char)* file);
    @trusted
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
reg_t allocScratchReg(ref CodeBuilder cdb, regm_t regm);
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

/* cdxxx.c: functions that go into cdxxx[] table */
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
void cddiv(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdmulass(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cddivass(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
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
void cdtoprec(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvecfill(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvecsto(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvector(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void cdvoid(ref CodeBuilder cdb, elem* e, regm_t* pretregs);
void loaddata(ref CodeBuilder cdb, elem* e, regm_t* pretregs);

/* cod1.c */
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
void argtypes(type* t, ref type* arg1type, ref type* arg2type);

/* cod2.c */
bool movOnly(const elem *e);
regm_t idxregm(const code *c);
void opdouble(ref CodeBuilder cdb, elem *e, regm_t *pretregs, uint clib);
void WRcodlst(code *c);
void getoffset(ref CodeBuilder cdb, elem *e, reg_t reg);

/* cod3.c */

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
targ_size_t cod3_spoff();
void makeitextern (Symbol *s );
void fltused();
int branch(block *bl, int flag);
void cod3_adjSymOffsets();
void assignaddr(block *bl);
void assignaddrc(code *c);
targ_size_t cod3_bpoffset(Symbol *s);
void pinholeopt (code *c , block *bn );
void simplify_code(code *c);
void jmpaddr (code *c);
int code_match(code *c1,code *c2);
uint calcblksize (code *c);
uint calccodsize(code *c);
uint codout(int seg, code *c);
size_t addtofixlist(Symbol *s , targ_size_t soffset , int seg , targ_size_t val , int flags );
void searchfixlist(Symbol *s) {}
void outfixlist();
void code_hydrate(code **pc);
void code_dehydrate(code **pc);
regm_t allocretregs(const tym_t ty, type* t, const tym_t tyf, out reg_t reg1, out reg_t reg2);

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
void prolog_frame(ref CodeBuilder cdb, bool farfunc, ref uint xlocalsize, out bool enter, out int cfa_offset);
void prolog_frameadj(ref CodeBuilder cdb, tym_t tyf, uint xlocalsize, bool enter, bool* pushalloc);
void prolog_frameadj2(ref CodeBuilder cdb, tym_t tyf, uint xlocalsize, bool* pushalloc);
void prolog_setupalloca(ref CodeBuilder cdb);
void prolog_saveregs(ref CodeBuilder cdb, regm_t topush, int cfa_offset);
void prolog_stackalign(ref CodeBuilder cdb);
void prolog_trace(ref CodeBuilder cdb, bool farfunc, uint* regsaved);
void prolog_gen_win64_varargs(ref CodeBuilder cdb);
void prolog_genvarargs(ref CodeBuilder cdb, Symbol* sv, regm_t namedargs);
void prolog_loadparams(ref CodeBuilder cdb, tym_t tyf, bool pushalloc, out regm_t namedargs);

/* cod4.c */
extern __gshared
{
const reg_t[4] dblreg;
int cdcmp_flag;
}

int doinreg(Symbol *s, elem *e);
void modEA(ref CodeBuilder cdb, code *c);
void longcmp(ref CodeBuilder,elem *,bool,uint,code *);

/* cod5.c */
void cod5_prol_epi();
void cod5_noprol();

/* cgxmm.c */
bool isXMMstore(opcode_t op);
void orthxmm(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void xmmeq(ref CodeBuilder cdb, elem *e, opcode_t op, elem *e1, elem *e2, regm_t *pretregs);
void xmmcnvt(ref CodeBuilder cdb,elem *e,regm_t *pretregs);
void xmmopass(ref CodeBuilder cdb,elem *e, regm_t *pretregs);
void xmmpost(ref CodeBuilder cdb, elem *e, regm_t *pretregs);
void xmmneg(ref CodeBuilder cdb,elem *e, regm_t *pretregs);
void xmmabs(ref CodeBuilder cdb,elem *e, regm_t *pretregs);
void cloadxmm(ref CodeBuilder cdb,elem *e, regm_t *pretregs);
uint xmmload(tym_t tym, bool aligned = true);
uint xmmstore(tym_t tym, bool aligned = true);
bool xmmIsAligned(elem *e);
void checkSetVex3(code *c);
void checkSetVex(code *c, tym_t ty);

/* cg87.c */
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
void fixresult87(ref CodeBuilder cdb, elem *e, regm_t retregs, regm_t *pretregs, bool isReturnValue = false);
void fixresult_complex87(ref CodeBuilder cdb,elem *e,regm_t retregs,regm_t *pretregs, bool isReturnValue = false);
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
@trusted
void regimmed_set(int reg, targ_size_t e)
{
    regcon.immed.value[reg] = e;
    regcon.immed.mval |= 1 << (reg);
    //printf("regimmed_set %s %d\n", regm_str(1 << reg), cast(int)e);
}





