/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/code.h
 */

#include <stddef.h>

struct _LabelDsymbol;             // D only
class Declaration;              // D only
struct CodeBuilder;

typedef int segidx_t;           // index into SegData[]

#define CNIL ((code *) NULL)

/**********************************
 * Code data type
 */

union evc
{
    targ_int    Vint;           // also used for tmp numbers (FLtmp)
    targ_uns    Vuns;
    targ_long   Vlong;
    targ_llong  Vllong;
    targ_size_t Vsize_t;
    struct
    {   targ_size_t Vpointer;
        int Vseg;               // segment the pointer is in
    }_EP;
    Srcpos      Vsrcpos;        // source position for OPlinnum
    struct elem  *Vtor;         // OPctor/OPdtor elem
    struct block *Vswitch;      // when FLswitch and we have a switch table
    code *Vcode;                // when code is target of a jump (FLcode)
    struct block *Vblock;       // when block " (FLblock)
    struct
    {
        targ_size_t Voffset;    // offset from symbol
        symbol  *Vsym;          // pointer to symbol table (FLfunc,FLextern)
    } sp;

    struct
    {
        targ_size_t Voffset;    // offset from symbol
        Declaration *Vsym;      // pointer to D symbol table
    } dsp;

    struct
    {
        targ_size_t Voffset;    // offset from symbol
        _LabelDsymbol *Vsym;    // pointer to D Label
    } lab;

    struct
    {   size_t len;
        char *bytes;
    } as;                       // asm node (FLasm)
};

#if DM_TARGET_CPU_X86
#include "code_x86.h"
#elif DM_TARGET_CPU_stub
#include "code_stub.h"
#else
#error unknown cpu
#endif

/********************** PUBLIC FUNCTIONS *******************/

code *code_calloc();
void code_free (code *);
void code_term();

#define code_next(c)    ((c)->next)

code *code_chunk_alloc();
extern code *code_list;

inline code *code_malloc()
{
    //printf("code %d\n", sizeof(code));
    code *c = code_list ? code_list : code_chunk_alloc();
    code_list = code_next(c);
    //printf("code_malloc: %p\n",c);
    return c;
}


extern con_t regcon;

/****************************
 * Table of common subexpressions stored on the stack.
 *      csextab[]       array of info on saved CSEs
 *      CSEpe           pointer to saved elem
 *      CSEregm         mask of register that was saved (so for multi-
 *                      register variables we know which part we have)
 */

struct CSE
{       elem    *e;             // pointer to elem
        code    csimple;        // if CSEsimple, this is the code to regenerate it
        regm_t  regm;           // mask of register stored there
        char    flags;          // flag bytes
#define CSEload         1       // set if the CSE was ever loaded
#define CSEsimple       2       // CSE can be regenerated easily

// != 0 if CSE was ever loaded
#define CSE_loaded(i)   (csextab[i].flags & CSEload)
};

/************************************
 * Register save state.
 */

extern "C++"
{
struct REGSAVE
{
    targ_size_t off;            // offset on stack
    unsigned top;               // high water mark
    unsigned idx;               // current number in use
    int alignment;              // 8 or 16

    void reset() { off = 0; top = 0; idx = 0; alignment = REGSIZE; }
    code *save(code *c, int reg, unsigned *pidx);
    code *restore(code *c, int reg, unsigned idx);
};
}
extern REGSAVE regsave;

/************************************
 * Local sections on the stack
 */
struct LocalSection
{
    targ_size_t offset;         // offset of section from frame pointer
    targ_size_t size;           // size of section
    int alignment;              // alignment size

    void init()                 // initialize
    {   offset = 0;
        size = 0;
        alignment = 0;
    }
};

/*******************************
 * As we generate code, collect information about
 * what parts of NT exception handling we need.
 */

extern unsigned usednteh;

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
};

/********************** Code Generator State ***************/

typedef struct CGstate
{
    int stackclean;     // if != 0, then clean the stack after function call

    LocalSection funcarg;       // where function arguments are placed
    targ_size_t funcargtos;     // current high water level of arguments being moved onto
                                // the funcarg section. It is filled from top to bottom,
                                // as if they were 'pushed' on the stack.
                                // Special case: if funcargtos==~0, then no
                                // arguments are there.
} CGstate;

extern CGstate cgstate;

/***********************************************************/

extern regm_t msavereg,mfuncreg,allregs;

extern  int BPRM;
extern  regm_t FLOATREGS;
extern  regm_t FLOATREGS2;
extern  regm_t DOUBLEREGS;
extern  const char datafl[],stackfl[],segfl[],flinsymtab[];
extern  char needframe,gotref;
extern  targ_size_t localsize,
        funcoffset,
        framehandleroffset;
extern  segidx_t cseg;
extern  int STACKALIGN;
extern  LocalSection Para;
extern  LocalSection Fast;
extern  LocalSection Auto;
extern  LocalSection EEStack;
extern  LocalSection Alloca;
#if TARGET_OSX
extern  targ_size_t localgotoffset;
#endif

/* cgcod.c */
extern int pass;
enum
{
    PASSinitial,        // initial pass through code generator
    PASSreg,         // register assignment pass
    PASSfinal,       // final pass
};

extern  int dfoidx;
extern  struct CSE *csextab;
#if TX86
extern  bool floatreg;
#endif
extern  targ_size_t prolog_allocoffset;
extern  targ_size_t startoffset;
extern  targ_size_t retoffset;
extern  targ_size_t retsize;
extern  unsigned stackpush;
extern  int stackchanged;
extern  int refparam;
extern  int reflocal;
extern  bool anyiasm;
extern  char calledafunc;
extern  void(*cdxxx[])(CodeBuilder&,elem *,regm_t *);

void stackoffsets(int);
void codgen(Symbol *);
#ifdef DEBUG
unsigned findreg (regm_t regm , int line , const char *file );
#define findreg(regm) findreg((regm),__LINE__,__FILE__)
#else
unsigned findreg (regm_t regm );
#endif
#define findregmsw(regm) findreg((regm) & mMSW)
#define findreglsw(regm) findreg((regm) & (mLSW | mBP))
void freenode (elem *e );
int isregvar (elem *e , regm_t *pregm , unsigned *preg );
#ifdef DEBUG
void allocreg(CodeBuilder& cdb, regm_t *pretregs, unsigned *preg, tym_t tym, int line, const char *file);
#define allocreg(a,b,c,d) allocreg((a),(b),(c),(d),__LINE__,__FILE__)
#else
void allocreg(CodeBuilder& cdb, regm_t *pretregs, unsigned *preg, tym_t tym);
#endif
regm_t lpadregs();
void useregs (regm_t regm );
void getregs(CodeBuilder& cdb, regm_t r);
void getregsNoSave(regm_t r);
void getregs_imm(CodeBuilder& cdb, regm_t r);
void cse_flush(CodeBuilder&, int);
bool cse_simple(code *c, elem *e);
void gen_testcse(CodeBuilder& cdb, unsigned sz, targ_uns i);
void gen_loadcse(CodeBuilder& cdb, unsigned reg, targ_uns i);
bool cssave (elem *e , regm_t regm , unsigned opsflag );
bool evalinregister (elem *e );
regm_t getscratch();
void codelem(CodeBuilder& cdb, elem *e, regm_t *pretregs, bool constflag);
void scodelem(CodeBuilder& cdb, elem *e, regm_t *pretregs, regm_t keepmsk, bool constflag);
const char *regm_str(regm_t rm);
int numbitsset(regm_t);

/* cdxxx.c: functions that go into cdxxx[] table */
typedef code *cd_t (elem *e , regm_t *pretregs); // old way

typedef void cdxxx_t (CodeBuilder& cdb, elem *e, regm_t *pretregs);

cdxxx_t
        cdabs,
        cdaddass,
        cdasm,
        cdbscan,
        cdbswap,
        cdbt,
        cdbtst,
        cdbyteint,
        cdcmp,
        cdcmpxchg,
        cdcnvt,
        cdcom,
        cdcomma,
        cdcond,
        cdconvt87,
        cdctor,
        cddctor,
        cdddtor,
        cddtor,
        cdeq,
        cderr,
        cdfar16,
        cdframeptr,
        cdfunc,
        cdgot,
        cdhalt,
        cdind,
        cdinfo,
        cdlngsht,
        cdloglog,
        cdmark,
        cdmemcmp,
        cdmemcpy,
        cdmemset,
        cdmsw,
        cdmul,
        cdmulass,
        cdneg,
        cdnot,
        cdorth,
        cdpair,
        cdpopcnt,
        cdport,
        cdpost,
        cdprefetch,
        cdrelconst,
        cdrndtol,
        cdscale,
        cdsetjmp,
        cdshass,
        cdshift,
        cdshtlng,
        cdstrcmp,
        cdstrcpy,
        cdstreq,
        cdstrlen,
        cdstrthis,
        cdvecfill,
        cdvecsto,
        cdvector,
        cdvoid,
        loaddata;


/* cod1.c */
extern int clib_inited;

int isscaledindex(elem *);
int ssindex(int op,targ_uns product);
void buildEA(code *c,int base,int index,int scale,targ_size_t disp);
unsigned buildModregrm(int mod, int reg, int rm);
void andregcon (con_t *pregconsave);
void genEEcode();
void docommas(CodeBuilder& cdb,elem **pe);
unsigned gensaverestore(regm_t, code **, code **);
unsigned gensaverestore2(regm_t regm,code **csave,code **crestore);
void genstackclean(CodeBuilder& cdb,unsigned numpara,regm_t keepmsk);
void logexp(CodeBuilder& cdb, elem *e, int jcond, unsigned fltarg, code *targ);
unsigned getaddrmode (regm_t idxregs );
void setaddrmode(code *c, regm_t idxregs);
void fltregs(CodeBuilder& cdb, code *pcs, tym_t tym);
void tstresult(CodeBuilder& cdb, regm_t regm, tym_t tym, unsigned saveflag);
void fixresult(CodeBuilder& cdb, elem *e, regm_t retregs, regm_t *pretregs);
void callclib(CodeBuilder& cdb, elem *e, unsigned clib, regm_t *pretregs, regm_t keepmask);
void pushParams(CodeBuilder& cdb,elem *, unsigned);
void offsetinreg(CodeBuilder& cdb, elem *e, regm_t *pretregs);

/* cod2.c */
int movOnly(elem *e);
regm_t idxregm(code *c);
#if TARGET_WINDOS
void opdouble(CodeBuilder& cdb, elem *e, regm_t *pretregs, unsigned clib);
#endif
void WRcodlst (code *c );
void getoffset(CodeBuilder& cdb, elem *e, unsigned reg);

/* cod3.c */

int cod3_EA(code *c);
regm_t cod3_useBP();
void cod3_initregs();
void cod3_setdefault();
void cod3_set32 (void );
void cod3_set64 (void );
void cod3_align_bytes(int seg, size_t nbytes);
void cod3_align(int seg);
void cod3_buildmodulector(Outbuffer* buf, int codeOffset, int refOffset);
void cod3_stackadj(CodeBuilder& cdb, int nbytes);
regm_t regmask(tym_t tym, tym_t tyf);
void cgreg_dst_regs(unsigned *dst_integer_reg, unsigned *dst_float_reg);
void cgreg_set_priorities(tym_t ty, unsigned char **pseq, unsigned char **pseqmsw);
void outblkexitcode(CodeBuilder& cdb, block *bl, int& anyspill, const char* sflsave, symbol** retsym, const regm_t mfuncregsave );
void outjmptab (block *b );
void outswitab (block *b );
int jmpopcode (elem *e );
void cod3_ptrchk(CodeBuilder& cdb,code *pcs,regm_t keepmsk);
code *genregs (code *c , unsigned op , unsigned dstreg , unsigned srcreg );
code *gentstreg (code *c , unsigned reg );
code *genpush (code *c , unsigned reg );
code *genpop (code *c , unsigned reg );
code* gensavereg(unsigned& reg, targ_uns slot);
code *genmovreg (code *c , unsigned to , unsigned from );
void genmulimm(CodeBuilder& cdb,unsigned r1,unsigned r2,targ_int imm);
void genshift(CodeBuilder& cdb);
void movregconst(CodeBuilder& cdb,unsigned reg,targ_size_t value,regm_t flags);
void genjmp(CodeBuilder& cdb, unsigned op, unsigned fltarg, block *targ);
void prolog(CodeBuilder& cdb);
void epilog (block *b);
void gen_spill_reg(CodeBuilder& cdb, Symbol *s, bool toreg);
code *load_localgot();
targ_size_t cod3_spoff();
void makeitextern (symbol *s );
void fltused(void);
int branch(block *bl, int flag);
void cod3_adjSymOffsets();
void assignaddr (block *bl );
void assignaddrc (code *c );
targ_size_t cod3_bpoffset(symbol *s);
void pinholeopt (code *c , block *bn );
void simplify_code(code *c);
void jmpaddr (code *c );
int code_match(code *c1,code *c2);
unsigned calcblksize (code *c);
unsigned calccodsize(code *c);
unsigned codout(int seg, code *c);
size_t addtofixlist (symbol *s , targ_size_t soffset , int seg , targ_size_t val , int flags );
void searchfixlist (symbol *s );
void outfixlist (void );
void code_hydrate(code **pc);
void code_dehydrate(code **pc);

extern int hasframe;            /* !=0 if this function has a stack frame */
extern targ_size_t spoff;
extern targ_size_t Foff;        // BP offset of floating register
extern targ_size_t CSoff;       // offset of common sub expressions
extern targ_size_t NDPoff;      // offset of saved 8087 registers
extern targ_size_t pushoff;     // offset of saved registers
extern bool pushoffuse;         // using pushoff
extern int BPoff;               // offset from BP
extern int EBPtoESP;            // add to EBP offset to get ESP offset

void prolog_ifunc(CodeBuilder& cdb, tym_t* tyf);
void prolog_ifunc2(CodeBuilder& cdb, tym_t tyf, tym_t tym, bool pushds);
void prolog_16bit_windows_farfunc(CodeBuilder& cdb, tym_t* tyf, bool* pushds);
void prolog_frame(CodeBuilder& cdb, unsigned farfunc, unsigned* xlocalsize, bool* enter, int* cfa_offset);
void prolog_frameadj(CodeBuilder& cdb, tym_t tyf, unsigned xlocalsize, bool enter, bool* pushalloc);
void prolog_frameadj2(CodeBuilder& cdb, tym_t tyf, unsigned xlocalsize, bool* pushalloc);
void prolog_setupalloca(CodeBuilder& cdb);
void prolog_saveregs(CodeBuilder& cdb, regm_t topush, int cfa_offset);
void prolog_trace(CodeBuilder& cdb, bool farfunc, unsigned* regsaved);
void prolog_gen_win64_varargs(CodeBuilder& cdb);
void prolog_genvarargs(CodeBuilder& cdb, symbol* sv, regm_t* namedargs);
void prolog_loadparams(CodeBuilder& cdb, tym_t tyf, bool pushalloc, regm_t* namedargs);

/* cod4.c */
extern  const unsigned dblreg[];
extern int cdcmp_flag;

int doinreg(symbol *s, elem *e);
void modEA(CodeBuilder& cdb, code *c);
void longcmp(CodeBuilder&,elem *,bool,unsigned,code *);

/* cod5.c */
void cod5_prol_epi();
void cod5_noprol();

/* cgxmm.c */
bool isXMMstore(unsigned op);
void orthxmm(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void xmmeq(CodeBuilder& cdb, elem *e, unsigned op, elem *e1, elem *e2,regm_t *pretregs);
void xmmcnvt(CodeBuilder& cdb,elem *e,regm_t *pretregs);
void xmmopass(CodeBuilder& cdb,elem *e, regm_t *pretregs);
void xmmpost(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void xmmneg(CodeBuilder& cdb,elem *e, regm_t *pretregs);
unsigned xmmload(tym_t tym, bool aligned = true);
unsigned xmmstore(tym_t tym, bool aligned = true);
bool xmmIsAligned(elem *e);
void checkSetVex3(code *c);
void checkSetVex(code *c, tym_t ty);

/* cg87.c */
void note87(elem *e, unsigned offset, int i);
#ifdef DEBUG
void pop87(int, const char *);
#else
void pop87();
#endif
void push87(CodeBuilder& cdb);
void save87(CodeBuilder& cdb);
void save87regs(CodeBuilder& cdb, unsigned n);
void gensaverestore87(regm_t, code **, code **);
code *genfltreg(code *c,unsigned opcode,unsigned reg,targ_size_t offset);
code *genxmmreg(code *c,unsigned opcode,unsigned xreg,targ_size_t offset, tym_t tym);
void genfwait(CodeBuilder& cdb);
void comsub87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void fixresult87(CodeBuilder& cdb, elem *e, regm_t retregs, regm_t *pretregs);
void fixresult_complex87(CodeBuilder& cdb,elem *e,regm_t retregs,regm_t *pretregs);
void orth87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void load87(CodeBuilder& cdb, elem *e, unsigned eoffset, regm_t *pretregs, elem *eleft, int op);
int cmporder87 (elem *e );
void eq87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void complex_eq87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void opass87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void cdnegass87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void post87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void cnvt87(CodeBuilder& cdb, elem *e , regm_t *pretregs );
void neg87(CodeBuilder& cdb, elem *e , regm_t *pretregs);
void neg_complex87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void cdind87(CodeBuilder& cdb,elem *e,regm_t *pretregs);
#if TX86
extern int stackused;
#endif
void cload87(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void cdd_u64(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void cdd_u32(CodeBuilder& cdb, elem *e, regm_t *pretregs);
void loadPair87(CodeBuilder& cdb, elem *e, regm_t *pretregs);

#ifdef DEBUG
#define pop87() pop87(__LINE__,__FILE__)
#endif

/* iasm.c */
void iasm_term( void );
regm_t iasm_regs( block *bp );

// nteh.c
void nteh_prolog(CodeBuilder& cdb);
void nteh_epilog(CodeBuilder& cdb);
void nteh_usevars();
void nteh_filltables();
void nteh_gentables(Symbol *sfunc);
void nteh_setsp(CodeBuilder& cdb, int op);
void nteh_filter(CodeBuilder& cdb, block *b);
void nteh_framehandler(Symbol *, Symbol *);
void nteh_gensindex(CodeBuilder&, int);
#define GENSINDEXSIZE 7
void nteh_monitor_prolog(CodeBuilder& cdb,Symbol *shandle);
void nteh_monitor_epilog(CodeBuilder& cdb,regm_t retregs);
code *nteh_patchindex(code* c, int index);
void nteh_unwind(CodeBuilder& cdb,regm_t retregs,unsigned index);

// cgen.c
code *code_last(code *c);
void code_orflag(code *c,unsigned flag);
void code_orrex(code *c,unsigned rex);
code *setOpcode(code *c, code *cs, unsigned op);
code *cat(code *c1, code *c2);
code *gen (code *c , code *cs );
code *gen1 (code *c , unsigned op );
code *gen2 (code *c , unsigned op , unsigned rm );
code *gen2sib(code *c,unsigned op,unsigned rm,unsigned sib);
code *genasm (code *c ,unsigned char *s , unsigned slen );
code *gencsi (code *c , unsigned op , unsigned rm , unsigned FL2 , SYMIDX si );
code *gencs (code *c , unsigned op , unsigned rm , unsigned FL2 , symbol *s );
code *genc2 (code *c , unsigned op , unsigned rm , targ_size_t EV2 );
code *genc1 (code *c , unsigned op , unsigned rm , unsigned FL1 , targ_size_t EV1 );
code *genc (code *c , unsigned op , unsigned rm , unsigned FL1 , targ_size_t EV1 , unsigned FL2 , targ_size_t EV2 );
code *genlinnum(code *,Srcpos);
void cgen_prelinnum(code **pc,Srcpos srcpos);
code *genadjesp(code *c, int offset);
code *genadjfpu(code *c, int offset);
code *gennop(code *);
void gencodelem(CodeBuilder& cdb,elem *e,regm_t *pretregs,bool constflag);
bool reghasvalue (regm_t regm , targ_size_t value , unsigned *preg );
void regwithvalue(CodeBuilder& cdb, regm_t regm, targ_size_t value, unsigned *preg, regm_t flags);

// cgreg.c
void cgreg_init();
void cgreg_term();
void cgreg_reset();
void cgreg_used(unsigned bi,regm_t used);
void cgreg_spillreg_prolog(block *b,Symbol *s,code **pcstore,code **pcload);
void cgreg_spillreg_epilog(block *b,Symbol *s,code **pcstore,code **pcload);
int cgreg_assign(Symbol *retsym);
void cgreg_unregister(regm_t conflict);

// cgsched.c
void cgsched_block(block *b);

//      Data and code can be in any number of sections
//
//      Generalize the Windows platform concept of CODE,DATA,UDATA,etc
//      into multiple segments

struct Ledatarec;               // OMF
struct linnum_data;             // Elf, Mach


typedef unsigned int IDXSTR;
typedef unsigned int IDXSEC;
typedef unsigned int IDXSYM;

struct seg_data
{
    segidx_t             SDseg;         // index into SegData[]
    targ_size_t          SDoffset;      // starting offset for data
    int                  SDalignment;   // power of 2

#if OMFOBJ
    bool isfarseg;
    int segidx;                         // internal object file segment number
    int lnameidx;                       // lname idx of segment name
    int classidx;                       // lname idx of class name
    unsigned attr;                      // segment attribute
    targ_size_t origsize;               // original size
    long seek;                          // seek position in output file
    Ledatarec *ledata;                  // current one we're filling in
#endif

#if 1 //ELFOBJ || MACHOBJ
    IDXSEC               SDshtidx;      // section header table index
    Outbuffer           *SDbuf;         // buffer to hold data
    Outbuffer           *SDrel;         // buffer to hold relocation info

    //ELFOBJ
    IDXSYM               SDsymidx;      // each section is in the symbol table
    IDXSEC               SDrelidx;      // section header for relocation info
    targ_size_t          SDrelmaxoff;   // maximum offset encountered
    int                  SDrelindex;    // maximum offset encountered
    int                  SDrelcnt;      // number of relocations added
    IDXSEC               SDshtidxout;   // final section header table index
    Symbol              *SDsym;         // if !=NULL, comdat symbol
    segidx_t             SDassocseg;    // for COMDATs, if !=0, this is the "associated" segment

    unsigned            SDaranges_offset;       // if !=0, offset in .debug_aranges

    unsigned             SDlinnum_count;
    unsigned             SDlinnum_max;
    linnum_data         *SDlinnum_data; // array of line number / offset data

    int isCode();
#endif
};



struct linnum_data
{
    const char *filename;
    unsigned filenumber;        // corresponding file number for DW_LNS_set_file

    unsigned linoff_count;
    unsigned linoff_max;
    unsigned (*linoff)[2];      // [0] = line number, [1] = offset
};


extern seg_data **SegData;
#define Offset(seg) SegData[seg]->SDoffset
#define Doffset Offset(DATA)
#define CDoffset Offset(CDATA)

/**************************************************/

/* Allocate registers to function parameters
 */

struct FuncParamRegs
{
    FuncParamRegs(tym_t tyf);
    static FuncParamRegs create(tym_t tyf);

    int alloc(type *t, tym_t ty, unsigned char *reg1, unsigned char *reg2);

  private:
    tym_t tyf;                  // type of function
    int i;                      // ith parameter
    int regcnt;                 // how many general purpose registers are allocated
    int xmmcnt;                 // how many fp registers are allocated
    unsigned numintegerregs;    // number of gp registers that can be allocated
    unsigned numfloatregs;      // number of fp registers that can be allocated
    const unsigned char* argregs;       // map to gp register
    const unsigned char* floatregs;     // map to fp register
};

extern "C++" { extern const unsigned mask[32]; }

inline regm_t Symbol::Spregm()
{
    /*assert(Sclass == SCfastpar);*/
    return mask[Spreg] | (Spreg2 == NOREG ? 0 : mask[Spreg2]);
}


/**********************************
 * Set value in regimmed for reg.
 * NOTE: For 16 bit generator, this is always a (targ_short) sign-extended
 *      value.
 */

inline void regimmed_set(int reg, targ_size_t e)
{
    regcon.immed.value[reg] = e;
    regcon.immed.mval |= 1 << (reg);
    //printf("regimmed_set %s %d\n", regm_str(mask[reg]), (int)e);
}


struct CodeBuilder
{
  private:

    code *head;
    code **pTail;

  public:
    CodeBuilder() { head = NULL; pTail = &head; }
    CodeBuilder(code *c);
    code *finish() { return head; }
    code *peek() { return head; }       // non-destructively look at the list
    void reset() { head = NULL; pTail = &head; }

    void append(CodeBuilder& cdb);
    void append(CodeBuilder& cdb1, CodeBuilder& cdb2);
    void append(CodeBuilder& cdb1, CodeBuilder& cdb2, CodeBuilder& cdb3);
    void append(CodeBuilder& cdb1, CodeBuilder& cdb2, CodeBuilder& cdb3, CodeBuilder& cdb4);
    void append(CodeBuilder& cdb1, CodeBuilder& cdb2, CodeBuilder& cdb3, CodeBuilder& cdb4, CodeBuilder& cdb5);

    void append(code *c);

    void gen(code *cs);
    void gen1(unsigned op);
    void gen2(unsigned op, unsigned rm);
    void genf2(unsigned op, unsigned rm);
    void gen2sib(unsigned op, unsigned rm, unsigned sib);
    void genasm(char *s, unsigned slen);
    void genasm(_LabelDsymbol *label);
    void genasm(block *label);
    void gencsi(unsigned op, unsigned rm, unsigned FL2, SYMIDX si);
    void gencs(unsigned op, unsigned rm, unsigned FL2, symbol *s);
    void genc2(unsigned op, unsigned rm, targ_size_t EV2);
    void genc1(unsigned op, unsigned rm, unsigned FL1, targ_size_t EV1);
    void genc(unsigned op, unsigned rm, unsigned FL1, targ_size_t EV1, unsigned FL2, targ_size_t EV2);
    void genlinnum(Srcpos);
    void genadjesp(int offset);
    void genadjfpu(int offset);
    void gennop();
    void genfltreg(unsigned opcode,unsigned reg,targ_size_t offset);
    void genxmmreg(unsigned opcode,unsigned xreg,targ_size_t offset, tym_t tym);

    /*****************
     * Returns:
     *  code that pTail points to
     */
    code *last()
    {
        // g++ and clang++ complain about offsetof() because of the code::code() constructor.
        // return (code *)((char *)pTail - offsetof(code, next));
        // So do our own.
        return (code *)((char *)pTail - ((char*)&(*pTail)->next - (char*)*pTail));
    }
};


