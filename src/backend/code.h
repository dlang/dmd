// Copyright (C) 1985-1996 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if __cplusplus && TX86
extern "C" {
#endif

#if MARS
class LabelDsymbol;
class Declaration;
#endif

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
#if MARS
    struct
    {
        targ_size_t Voffset;    // offset from symbol
        Declaration *Vsym;      // pointer to D symbol table
    } dsp;
    struct
    {
        targ_size_t Voffset;    // offset from symbol
        LabelDsymbol *Vsym;     // pointer to Label
    } lab;
#endif
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
 *      cstop =         # of entries in table
 */

struct CSE
{       elem    *e;             // pointer to elem
        code    csimple;        // if CSEsimple, this is the code to regenerate it
        regm_t  regm;           // mask of register stored there
        char    flags;          // flag bytes
#define CSEload         1       // set if the CSE was ever loaded
#define CSEsimple       2       // CSE can be regenerated easilly

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

#define NTEH_try        1       // used _try statement
#define NTEH_except     2       // used _except statement
#define NTEHexcspec     4       // had C++ exception specification
#define NTEHcleanup     8       // destructors need to be called
#define NTEHtry         0x10    // had C++ try statement
#define NTEHcpp         (NTEHexcspec | NTEHcleanup | NTEHtry)
#define EHcleanup       0x20
#define EHtry           0x40
#define NTEHjmonitor    0x80    // uses Jupiter monitor
#define NTEHpassthru    0x100

/********************** Code Generator State ***************/

typedef struct CGstate
{
    int stackclean;     // if != 0, then clean the stack after function call
} CGstate;

extern CGstate cgstate;

/***********************************************************/

extern regm_t msavereg,mfuncreg,allregs;

typedef code *cd_t (elem *e , regm_t *pretregs );

extern  int BPRM;
extern  regm_t FLOATREGS;
extern  regm_t FLOATREGS2;
extern  regm_t DOUBLEREGS;
extern  const char datafl[],stackfl[],segfl[],flinsymtab[];
extern  char needframe,usedalloca,gotref;
extern  targ_size_t localsize,
        funcoffset,
        framehandleroffset;
extern  segidx_t cseg;
extern  int STACKALIGN;
extern  LocalSection Para;
extern  LocalSection Fast;
extern  LocalSection Auto;
extern  LocalSection EEStack;
#if TARGET_OSX
extern  targ_size_t localgotoffset;
#endif

/* cgcod.c */
extern int pass;
#define PASSinit        0       // initial pass through code generator
#define PASSreg         1       // register assignment pass
#define PASSfinal       2       // final pass

extern  int dfoidx;
extern  struct CSE *csextab;
extern  unsigned cstop;
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
extern  code *(*cdxxx[])(elem *,regm_t *);

void stackoffsets(int);
void codgen (void );
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
code *allocreg (regm_t *pretregs , unsigned *preg , tym_t tym , int line , const char *file );
#define allocreg(a,b,c) allocreg((a),(b),(c),__LINE__,__FILE__)
#else
code *allocreg (regm_t *pretregs , unsigned *preg , tym_t tym );
#endif
void useregs (regm_t regm );
code *getregs (regm_t r );
code *getregs_imm (regm_t r );
code *cse_flush(int);
bool cse_simple(code *c, elem *e);
code* gen_testcse(code *c, unsigned sz, targ_uns i);
code* gen_loadcse(code *c, unsigned reg, targ_uns i);
bool cssave (elem *e , regm_t regm , unsigned opsflag );
bool evalinregister (elem *e );
regm_t getscratch();
code *codelem (elem *e , regm_t *pretregs , bool constflag );
code *scodelem (elem *e , regm_t *pretregs , regm_t keepmsk , bool constflag );
const char *regm_str(regm_t rm);
int numbitsset(regm_t);

/* cod1.c */
extern int clib_inited;

int isscaledindex(elem *);
int ssindex(int op,targ_uns product);
void buildEA(code *c,int base,int index,int scale,targ_size_t disp);
unsigned buildModregrm(int mod, int reg, int rm);
void andregcon (con_t *pregconsave);
void genEEcode();
code *docommas (elem **pe );
unsigned gensaverestore(regm_t, code **, code **);
unsigned gensaverestore2(regm_t regm,code **csave,code **crestore);
code *genstackclean(code *c,unsigned numpara,regm_t keepmsk);
code *logexp (elem *e , int jcond , unsigned fltarg , code *targ );
unsigned getaddrmode (regm_t idxregs );
void setaddrmode(code *c, regm_t idxregs);
code *fltregs (code *pcs , tym_t tym );
code *tstresult (regm_t regm , tym_t tym , unsigned saveflag );
code *fixresult (elem *e , regm_t retregs , regm_t *pretregs );
code *callclib (elem *e , unsigned clib , regm_t *pretregs , regm_t keepmask );
cd_t cdfunc;
cd_t cdstrthis;
code *params(elem *, unsigned);
code *offsetinreg (elem *e , regm_t *pretregs );
code *loaddata (elem *e , regm_t *pretregs );

/* cod2.c */
int movOnly(elem *e);
regm_t idxregm(code *c);
#if TARGET_WINDOS
code *opdouble (elem *e , regm_t *pretregs , unsigned clib );
#endif
cd_t cdorth;
cd_t cdmul;
cd_t cdnot;
cd_t cdcom;
cd_t cdbswap;
cd_t cdpopcnt;
cd_t cdcond;
void WRcodlst (code *c );
cd_t cdcomma;
cd_t cdloglog;
cd_t cdshift;
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
cd_t cdindpic;
#endif
cd_t cdind;
cd_t cdstrlen;
cd_t cdstrcmp;
cd_t cdstrcpy;
cd_t cdmemchr;
cd_t cdmemcmp;
cd_t cdmemcpy;
cd_t cdmemset;
cd_t cdstreq;
cd_t cdrelconst;
code *getoffset (elem *e , unsigned reg );
cd_t cdneg;
cd_t cdabs;
cd_t cdpost;
cd_t cdcmpxchg;
cd_t cderr;
cd_t cdinfo;
cd_t cddctor;
cd_t cdddtor;
cd_t cdctor;
cd_t cddtor;
cd_t cdmark;
cd_t cdnullcheck;
cd_t cdclassinit;

/* cod3.c */

int cod3_EA(code *c);
regm_t cod3_useBP();
void cod3_initregs();
void cod3_setdefault();
void cod3_set32 (void );
void cod3_set64 (void );
void cod3_align_bytes (size_t nbytes);
void cod3_align (void );
void cod3_buildmodulector(Outbuffer* buf, int codeOffset, int refOffset);
code* cod3_stackadj(code* c, int nbytes);
regm_t regmask(tym_t tym, tym_t tyf);
void cgreg_dst_regs(unsigned *dst_integer_reg, unsigned *dst_float_reg);
void cgreg_set_priorities(tym_t ty, char **pseq, char **pseqmsw);
void outblkexitcode(block *bl, code*& c, int& anyspill, const char* sflsave, symbol** retsym, const regm_t mfuncregsave );
void doswitch (block *b );
void outjmptab (block *b );
void outswitab (block *b );
int jmpopcode (elem *e );
void cod3_ptrchk(code **pc,code *pcs,regm_t keepmsk);
code *genregs (code *c , unsigned op , unsigned dstreg , unsigned srcreg );
code *gentstreg (code *c , unsigned reg );
code *genpush (code *c , unsigned reg );
code *genpop (code *c , unsigned reg );
code* gensavereg(unsigned& reg, targ_uns slot);
code *genmovreg (code *c , unsigned to , unsigned from );
code *genmulimm(code *c,unsigned r1,unsigned r2,targ_int imm);
code *genshift(code *);
code *movregconst (code *c , unsigned reg , targ_size_t value , regm_t flags );
code *genjmp (code *c , unsigned op , unsigned fltarg , block *targ );
code *prolog (void );
void epilog (block *b);
code *gen_spill_reg(Symbol *s, bool toreg);
cd_t cdframeptr;
cd_t cdgot;
code *load_localgot();
targ_size_t cod3_spoff();
code *cod3_load_got();
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
unsigned codout (code *c );
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
extern int BPoff;                      // offset from BP
extern int EBPtoESP;            // add to EBP offset to get ESP offset
extern int AllocaOff;               // offset of alloca temporary

code* prolog_ifunc(tym_t* tyf);
code* prolog_ifunc2(tym_t tyf, tym_t tym, bool pushds);
code* prolog_16bit_windows_farfunc(tym_t* tyf, bool* pushds);
code* prolog_frame(unsigned farfunc, unsigned* xlocalsize, bool* enter);
code* prolog_frameadj(tym_t tyf, unsigned xlocalsize, bool enter, bool* pushalloc);
code* prolog_frameadj2(tym_t tyf, unsigned xlocalsize, bool* pushalloc);
code* prolog_setupalloca();
code* prolog_saveregs(code *c, regm_t topush);
code* prolog_trace(bool farfunc, unsigned* regsaved);
code* prolog_gen_win64_varargs();
code* prolog_genvarargs(symbol* sv, regm_t* namedargs);
code* prolog_loadparams(tym_t tyf, bool pushalloc, regm_t* namedargs);

/* cod4.c */
extern  const unsigned dblreg[];
extern int cdcmp_flag;

int doinreg(symbol *s, elem *e);
code *modEA(code *c);
cd_t cdeq;
cd_t cdaddass;
cd_t cdmulass;
cd_t cdshass;
cd_t cdcmp;
cd_t cdcnvt;
cd_t cdshtlng;
cd_t cdbyteint;
cd_t cdlngsht;
cd_t cdmsw;
cd_t cdport;
cd_t cdasm;
cd_t cdsetjmp;
cd_t cdvoid;
cd_t cdhalt;
cd_t cdfar16;
cd_t cdbtst;
cd_t cdbt;
cd_t cdbscan;
cd_t cdpair;
code *longcmp (elem *,bool,unsigned,code *);

/* cod5.c */
void cod5_prol_epi();
void cod5_noprol();

/* cgxmm.c */
bool isXMMstore(unsigned op);
code *movxmmconst(unsigned reg, unsigned sz, targ_size_t value, regm_t flags);
code *orthxmm(elem *e, regm_t *pretregs);
code *xmmeq(elem *e, unsigned op, elem *e1, elem *e2,regm_t *pretregs);
code *xmmcnvt(elem *e,regm_t *pretregs);
code *xmmopass(elem *e, regm_t *pretregs);
code *xmmneg(elem *e, regm_t *pretregs);
unsigned xmmload(tym_t tym);
unsigned xmmstore(tym_t tym);
code *cdvector(elem *e, regm_t *pretregs);
code *cdvecsto(elem *e, regm_t *pretregs);

/* cg87.c */
void note87(elem *e, unsigned offset, int i);
#ifdef DEBUG
void pop87(int, const char *);
#else
void pop87();
#endif
code *push87 (void );
code *save87 (void );
code *save87regs(unsigned n);
void gensaverestore87(regm_t, code **, code **);
code *genfltreg(code *c,unsigned opcode,unsigned reg,targ_size_t offset);
code *genfwait(code *c);
code *comsub87(elem *e, regm_t *pretregs);
code *fixresult87 (elem *e , regm_t retregs , regm_t *pretregs );
code *fixresult_complex87(elem *e,regm_t retregs,regm_t *pretregs);
code *orth87 (elem *e , regm_t *pretregs );
code *load87(elem *e, unsigned eoffset, regm_t *pretregs, elem *eleft, int op);
int cmporder87 (elem *e );
code *eq87 (elem *e , regm_t *pretregs );
code *complex_eq87 (elem *e , regm_t *pretregs );
code *opass87 (elem *e , regm_t *pretregs );
code *cdnegass87 (elem *e , regm_t *pretregs );
code *post87 (elem *e , regm_t *pretregs );
code *cnvt87 (elem *e , regm_t *pretregs );
code *cnvteq87 (elem *e , regm_t *pretregs );
cd_t cdrndtol;
cd_t cdscale;
code *neg87 (elem *e , regm_t *pretregs );
code *neg_complex87(elem *e, regm_t *pretregs);
code *cdind87(elem *e,regm_t *pretregs);
#if TX86
extern int stackused;
#endif
code *cdconvt87(elem *e, regm_t *pretregs);
code *cload87(elem *e, regm_t *pretregs);
code *cdd_u64(elem *e, regm_t *pretregs);
code *cdd_u32(elem *e, regm_t *pretregs);

#ifdef DEBUG
#define pop87() pop87(__LINE__,__FILE__)
#endif

/* iasm.c */
void iasm_term( void );
regm_t iasm_regs( block *bp );

// nteh.c
code *nteh_prolog(void);
code *nteh_epilog(void);
void nteh_usevars(void);
void nteh_filltables(void);
void nteh_gentables(void);
code *nteh_setsp(int op);
code *nteh_filter(block *b);
void nteh_framehandler(symbol *);
code *nteh_gensindex(int);
#define GENSINDEXSIZE 7
code *nteh_monitor_prolog(Symbol *shandle);
code *nteh_monitor_epilog(regm_t retregs);
code *nteh_patchindex(code* c, int index);

// cgen.c
code *code_last(code *c);
void code_orflag(code *c,unsigned flag);
void code_orrex(code *c,unsigned rex);
code *setOpcode(code *c, code *cs, unsigned op);
code * __pascal cat (code *c1 , code *c2 );
code * cat3 (code *c1 , code *c2 , code *c3 );
code * cat4 (code *c1 , code *c2 , code *c3 , code *c4 );
code * cat6 (code *c1 , code *c2 , code *c3 , code *c4 , code *c5 , code *c6 );
code *gen (code *c , code *cs );
code *gen1 (code *c , unsigned op );
code *gen2 (code *c , unsigned op , unsigned rm );
code *gen2sib(code *c,unsigned op,unsigned rm,unsigned sib);
code *genasm (code *c , char *s , unsigned slen );
code *gencsi (code *c , unsigned op , unsigned rm , unsigned FL2 , SYMIDX si );
code *gencs (code *c , unsigned op , unsigned rm , unsigned FL2 , symbol *s );
code *genc2 (code *c , unsigned op , unsigned rm , targ_size_t EV2 );
code *genc1 (code *c , unsigned op , unsigned rm , unsigned FL1 , targ_size_t EV1 );
code *genc (code *c , unsigned op , unsigned rm , unsigned FL1 , targ_size_t EV1 , unsigned FL2 , targ_size_t EV2 );
code *genlinnum(code *,Srcpos);
void cgen_linnum(code **pc,Srcpos srcpos);
void cgen_prelinnum(code **pc,Srcpos srcpos);
code *genadjesp(code *c, int offset);
code *genadjfpu(code *c, int offset);
code *gennop(code *);
code *gencodelem(code *c,elem *e,regm_t *pretregs,bool constflag);
bool reghasvalue (regm_t regm , targ_size_t value , unsigned *preg );
code *regwithvalue (code *c , regm_t regm , targ_size_t value , unsigned *preg , regm_t flags );

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
#if 1 //ELFOBJ
    IDXSYM               SDsymidx;      // each section is in the symbol table
    IDXSEC               SDrelidx;      // section header for relocation info
    targ_size_t          SDrelmaxoff;   // maximum offset encountered
    int                  SDrelindex;    // maximum offset encountered
    int                  SDrelcnt;      // number of relocations added
    IDXSEC               SDshtidxout;   // final section header table index
    Symbol              *SDsym;         // if !=NULL, comdat symbol
    segidx_t             SDassocseg;    // for COMDATs, if !=0, this is the "associated" segment
#endif

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
#define Doffset SegData[DATA]->SDoffset
#define CDoffset SegData[CDATA]->SDoffset
#define Coffset SegData[cseg]->SDoffset

/**************************************************/

/* Allocate registers to function parameters
 */

struct FuncParamRegs
{
    FuncParamRegs(tym_t tyf);

    int alloc(type *t, tym_t ty, unsigned char *reg1, unsigned char *reg2);

  private:
    tym_t tyf;                  // type of function
    int i;                      // ith parameter
    int regcnt;                 // how many general purpose registers are allocated
    int xmmcnt;                 // how many fp registers are allocated
    size_t numintegerregs;      // number of gp registers that can be allocated
    size_t numfloatregs;        // number of fp registers that can be allocated
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

#if 1
inline void regimmed_set(int reg, targ_size_t e)
{
    regcon.immed.value[reg] = e;
    regcon.immed.mval |= 1 << (reg);
    //printf("regimmed_set %s %d\n", regm_str(mask[reg]), (int)e);
}
#else
#define regimmed_set(reg,e) \
        (regcon.immed.value[reg] = (e),regcon.immed.mval |= 1 << (reg))
#endif

#if __cplusplus && TX86
}
#endif

