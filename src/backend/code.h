// Copyright (C) 1985-1996 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if __cplusplus && TX86
extern "C" {
#endif

#if MARS
struct LabelDsymbol;
struct Declaration;
#endif

#define CNIL ((code *) NULL)

/* Register definitions */

#define AX      0
#define CX      1
#define DX      2
#define BX      3
#define SP      4
#define BP      5
#define SI      6
#define DI      7

#define R8      8
#define R9      9
#define R10     10
#define R11     11
#define R12     12
#define R13     13
#define R14     14
#define R15     15

#define XMM0    16
#define XMM1    17
#define XMM2    18
#define XMM3    19
#define XMM4    20
#define XMM5    21
#define XMM6    22
#define XMM7    23
/* There are also XMM8..XMM14 */
#define XMM15   31


#define ES      24
#define PSW     25
#define STACK   26      // top of stack
#define ST0     27      // 8087 top of stack register
#define ST01    28      // top two 8087 registers; for complex types

#define NOREG   29     // no register

#define AL      0
#define CL      1
#define DL      2
#define BL      3
#define AH      4
#define CH      5
#define DH      6
#define BH      7

#define mAX     1
#define mCX     2
#define mDX     4
#define mBX     8
#define mSP     0x10
#define mBP     0x20
#define mSI     0x40
#define mDI     0x80

#define mR8     (1 << R8)
#define mR9     (1 << R9)
#define mR10    (1 << R10)
#define mR11    (1 << R11)
#define mR12    (1 << R12)
#define mR13    (1 << R13)
#define mR14    (1 << R14)
#define mR15    (1 << R15)

#define mXMM0   (1 << XMM0)
#define mXMM1   (1 << XMM1)
#define mXMM2   (1 << XMM2)
#define mXMM3   (1 << XMM3)
#define mXMM4   (1 << XMM4)
#define mXMM5   (1 << XMM5)
#define mXMM6   (1 << XMM6)
#define mXMM7   (1 << XMM7)
#define XMMREGS  (mXMM0 |mXMM1 |mXMM2 |mXMM3 |mXMM4 |mXMM5 |mXMM6 |mXMM7)

#define mES     (1 << ES)       // 0x1000000
#define mPSW    (1 << PSW)      // 0x2000000

#define mSTACK  (1 << STACK)    // 0x4000000

#define mST0    (1 << ST0)      // 0x20000000
#define mST01   (1 << ST01)     // 0x40000000

// Flags for getlvalue (must fit in regm_t)
#define RMload  (1 << 30)
#define RMstore (1 << 31)

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    // To support positional independent code,
    // must be able to remove BX from available registers
extern regm_t ALLREGS;
#define ALLREGS_INIT            (mAX|mBX|mCX|mDX|mSI|mDI)
#define ALLREGS_INIT_PIC        (mAX|mCX|mDX|mSI|mDI)
extern regm_t BYTEREGS;
#define BYTEREGS_INIT           (mAX|mBX|mCX|mDX)
#define BYTEREGS_INIT_PIC       (mAX|mCX|mDX)
#else
#define ALLREGS                 (mAX|mBX|mCX|mDX|mSI|mDI)
#define ALLREGS_INIT            ALLREGS
#undef BYTEREGS
#define BYTEREGS                (mAX|mBX|mCX|mDX)
#endif

/* We use the same IDXREGS for the 386 as the 8088, because if
   we used ALLREGS, it would interfere with mMSW
 */
#define IDXREGS         (mBX|mSI|mDI)

#define FLOATREGS_64    mAX
#define FLOATREGS2_64   mDX
#define DOUBLEREGS_64   mAX
#define DOUBLEREGS2_64  mDX

#define FLOATREGS_32    mAX
#define FLOATREGS2_32   mDX
#define DOUBLEREGS_32   (mAX|mDX)
#define DOUBLEREGS2_32  (mCX|mBX)

#define FLOATREGS_16    (mDX|mAX)
#define FLOATREGS2_16   (mCX|mBX)
#define DOUBLEREGS_16   (mAX|mBX|mCX|mDX)

/*#define _8087REGS (mST0|mST1|mST2|mST3|mST4|mST5|mST6|mST7)*/

/* Segment registers    */
#define SEG_ES  0
#define SEG_CS  1
#define SEG_SS  2
#define SEG_DS  3

/*********************
 * Masks for register pairs.
 * Note that index registers are always LSWs. This is for the convenience
 * of implementing far pointers.
 */

#if 0
// Give us an extra one so we can enregister a long
#define mMSW    (mCX|mDX|mDI|mES)       // most significant regs
#define mLSW    (mAX|mBX|mSI)           // least significant regs
#else
#define mMSW    (mCX|mDX|mES)           /* most significant regs        */
#define mLSW    (mAX|mBX|mSI|mDI)       /* least significant regs       */
#endif

/* Return !=0 if there is a SIB byte   */
#define issib(rm)       (((rm) & 7) == 4 && ((rm) & 0xC0) != 0xC0)

#if 0
// relocation field size is always 32bits
#define is32bitaddr(x,Iflags) (1)
#else
//
// is32bitaddr works correctly only when x is 0 or 1.  This is
// true today for the current definition of I32, but if the definition
// of I32 changes, this macro will need to change as well
//
// Note: even for linux targets, CFaddrsize can be set by the inline
// assembler.
#define is32bitaddr(x,Iflags) (I64 || ((x) ^(((Iflags) & CFaddrsize) !=0)))
#endif

/*******************
 * Some instructions.
 */

#define SEGES   0x26
#define SEGCS   0x2E
#define SEGSS   0x36
#define SEGDS   0x3E
#define SEGFS   0x64
#define SEGGS   0x65

#define CALL    0xE8
#define JMP     0xE9    /* Intra-Segment Direct */
#define JMPS    0xEB    /* JMP SHORT            */
#define JCXZ    0xE3
#define LOOP    0xE2
#define LES     0xC4
#define LEA     0x8D

#define JO      0x70
#define JNO     0x71
#define JC      0x72
#define JB      0x72
#define JNC     0x73
#define JAE     0x73
#define JE      0x74
#define JNE     0x75
#define JBE     0x76
#define JA      0x77
#define JS      0x78
#define JNS     0x79
#define JP      0x7A
#define JNP     0x7B
#define JL      0x7C
#define JGE     0x7D
#define JLE     0x7E
#define JG      0x7F

/* NOP is used as a placeholder in the linked list of instructions, no  */
/* actual code will be generated for it.                                */
#define NOP     0x2E    /* actually CS: (we don't use 0x90 because the  */
                        /* silly Windows stuff wants to output 0x90's)  */

#define ESCAPE  0x3E    // marker that special information is here
                        // (Iop2 is the type of special information)
                        // (Same as DS:, but we will never generate
                        // a separate DS: opcode anyway)
    #define ESClinnum   (1 << 8)       // line number information
    #define ESCctor     (2 << 8)       // object is constructed
    #define ESCdtor     (3 << 8)       // object is destructed
    #define ESCmark     (4 << 8)       // mark eh stack
    #define ESCrelease  (5 << 8)       // release eh stack
    #define ESCoffset   (6 << 8)       // set code offset for eh
    #define ESCadjesp   (7 << 8)       // adjust ESP by IEV2.Vint
    #define ESCmark2    (8 << 8)       // mark eh stack
    #define ESCrelease2 (9 << 8)       // release eh stack
    #define ESCframeptr (10 << 8)      // replace with load of frame pointer
    #define ESCdctor    (11 << 8)      // D object is constructed
    #define ESCddtor    (12 << 8)      // D object is destructed
    #define ESCadjfpu   (13 << 8)      // adjust fpustackused by IEV2.Vint

#define ASM     0x36    // string of asm bytes, actually an SS: opcode

/*********************************
 * Macros to ease generating code
 * modregrm:    generate mod reg r/m field
 * modregxrm:   reg could be R8..R15
 * modregrmx:   rm could be R8..R15
 * modregxrmx:  reg or rm could be R8..R15
 * NEWREG:      change reg field of x to r
 * genorreg:    OR  t,f
 */

#define modregrm(m,r,rm)        (((m)<<6)|((r)<<3)|(rm))
#define modregxrm(m,r,rm)       ((((r)&8)<<15)|modregrm((m),(r)&7,rm))
#define modregrmx(m,r,rm)       ((((rm)&8)<<13)|modregrm((m),r,(rm)&7))
#define modregxrmx(m,r,rm)      ((((r)&8)<<15)|(((rm)&8)<<13)|modregrm((m),(r)&7,(rm)&7))

#define NEWREXR(x,r)            ((x)=((x)&~REX_R)|(((r)&8)>>1))
#define NEWREG(x,r)             ((x)=((x)&~(7<<3))|((r)<<3))
#define code_newreg(c,r)        (NEWREG((c)->Irm,(r)&7),NEWREXR((c)->Irex,(r)))

#define genorreg(c,t,f)         genregs((c),0x09,(f),(t))

#define REX     0x40            // REX prefix byte, OR'd with the following bits:
#define REX_W   8               // 0 = default operand size, 1 = 64 bit operand size
#define REX_R   4               // high bit of reg field of modregrm
#define REX_X   2               // high bit of sib index reg
#define REX_B   1               // high bit of rm field, sib base reg, or opcode reg

#define VEX2_B1(ivex)                           \
    (                                           \
        ivex.r    << 7 |                        \
        ivex.vvvv << 3 |                        \
        ivex.l    << 2 |                        \
        ivex.pp                                 \
    )

#define VEX3_B1(ivex)                           \
    (                                           \
        ivex.r    << 7 |                        \
        ivex.x    << 6 |                        \
        ivex.b    << 5 |                        \
        ivex.mmmm                               \
    )

#define VEX3_B2(ivex)                           \
    (                                           \
        ivex.w    << 7 |                        \
        ivex.vvvv << 3 |                        \
        ivex.l    << 2 |                        \
        ivex.pp                                 \
    )

/**********************
 * C library routines.
 * See callclib().
 */

enum CLIB
{
        CLIBlcmp,
        CLIBlmul,
        CLIBldiv,
        CLIBlmod,
        CLIBuldiv,
        CLIBulmod,

#if TARGET_WINDOS
        CLIBdmul,CLIBddiv,CLIBdtst0,CLIBdtst0exc,CLIBdcmp,CLIBdcmpexc,CLIBdneg,CLIBdadd,CLIBdsub,
        CLIBfmul,CLIBfdiv,CLIBftst0,CLIBftst0exc,CLIBfcmp,CLIBfcmpexc,CLIBfneg,CLIBfadd,CLIBfsub,
#endif

        CLIBdbllng,CLIBlngdbl,CLIBdblint,CLIBintdbl,
        CLIBdbluns,CLIBunsdbl,
        CLIBdblulng,
#if TARGET_WINDOS
        // used the GNU way of converting unsigned long long to signed
        CLIBulngdbl,
#endif
        CLIBdblflt,CLIBfltdbl,
        CLIBdblllng,
        CLIBllngdbl,
        CLIBdblullng,
        CLIBullngdbl,
        CLIBdtst,
        CLIBvptrfptr,CLIBcvptrfptr,

        CLIB87topsw,CLIBfltto87,CLIBdblto87,CLIBdblint87,CLIBdbllng87,
        CLIBftst,
        CLIBfcompp,
        CLIBftest,
        CLIBftest0,
        CLIBfdiv87,

        // Complex numbers
        CLIBcmul,
        CLIBcdiv,
        CLIBccmp,

        CLIBu64_ldbl,
        CLIBld_u64,

        CLIBMAX
};

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

struct code
{
    code *next;
    unsigned Iflags;
#define CFes              1     // generate an ES: segment override for this instr
#define CFjmp16           2     // need 16 bit jump offset (long branch)
#define CFtarg            4     // this code is the target of a jump
#define CFseg             8     // get segment of immediate value
#define CFoff          0x10     // get offset of immediate value
#define CFss           0x20     // generate an SS: segment override (not with
                                // CFes at the same time, though!)
#define CFpsw          0x40     // we need the flags result after this instruction
#define CFopsize       0x80     // prefix with operand size
#define CFaddrsize    0x100     // prefix with address size
#define CFds          0x200     // need DS override (not with es, ss, or cs )
#define CFcs          0x400     // need CS override
#define CFfs          0x800     // need FS override
#define CFgs    (CFcs | CFfs)   // need GS override
#define CFwait       0x1000     // If I32 it indicates when to output a WAIT
#define CFselfrel    0x2000     // if self-relative
#define CFunambig    0x4000     // indicates cannot be accessed by other addressing
                                // modes
#define CFtarg2      0x8000     // like CFtarg, but we can't optimize this away
#define CFvolatile  0x10000     // volatile reference, do not schedule
#define CFclassinit 0x20000     // class init code
#define CFoffset64  0x40000     // offset is 64 bits
#define CFpc32      0x80000     // I64: PC relative 32 bit fixup

#define CFvex       0x100000    // vex prefix
#define CFvex3      0x200000    // 3 byte vex prefix

#define CFPREFIX (CFSEG | CFopsize | CFaddrsize)
#define CFSEG   (CFes | CFss | CFds | CFcs | CFfs | CFgs)

    union {
        unsigned _Iop;
        struct {
#pragma pack(1)
            unsigned char  op;
            unsigned short   pp : 2;
            unsigned short    l : 1;
            unsigned short vvvv : 4;
            unsigned short    w : 1;
            unsigned short mmmm : 5;
            unsigned short    b : 1;
            unsigned short    x : 1;
            unsigned short    r : 1;
            unsigned char pfx; // always 0xC4
#pragma pack()
        } _Ivex;
    } _OP;

    /* The _EA is the "effective address" for the instruction, and consists of the modregrm byte,
     * the sib byte, and the REX prefix byte. The 16 bit code generator just used the modregrm,
     * the 32 bit x86 added the sib, and the 64 bit one added the rex.
     */
    union
    {   unsigned _Iea;
        struct
        {
            unsigned char _Irm;          // reg/mode
            unsigned char _Isib;         // SIB byte
            unsigned char _Irex;         // REX prefix
        } _ea;
    } _EA;

#define Iop  _OP._Iop
#define Ivex _OP._Ivex
#define Iea  _EA._Iea
#define Irm  _EA._ea._Irm
#define Isib _EA._ea._Isib
#define Irex _EA._ea._Irex


    /* IFL1 and IEV1 are the first operand, which usually winds up being the offset to the Effective
     * Address. IFL1 is the tag saying which variant type is in IEV1. IFL2 and IEV2 is the second
     * operand, usually for immediate instructions.
     */

    unsigned char IFL1,IFL2;    // FLavors of 1st, 2nd operands
    union evc IEV1;             // 1st operand, if any
      #define IEVpointer1 IEV1._EP.Vpointer
      #define IEVseg1     IEV1._EP.Vseg
      #define IEVsym1     IEV1.sp.Vsym
      #define IEVdsym1    IEV1.dsp.Vsym
      #define IEVoffset1  IEV1.sp.Voffset
      #define IEVlsym1    IEV1.lab.Vsym
      #define IEVint1     IEV1.Vint
    union evc IEV2;             // 2nd operand, if any
      #define IEVpointer2 IEV2._EP.Vpointer
      #define IEVseg2     IEV2._EP.Vseg
      #define IEVsym2     IEV2.sp.Vsym
      #define IEVdsym2    IEV2.dsp.Vsym
      #define IEVoffset2  IEV2.sp.Voffset
      #define IEVlsym2    IEV2.lab.Vsym
      #define IEVint2     IEV2.Vint
      #define IEVllong2   IEV2.Vllong
    void print();               // pretty-printer

    code() { Irex = 0; Isib = 0; }      // constructor

    void orReg(unsigned reg)
    {   if (reg & 8)
            Irex |= REX_R;
        Irm |= modregrm(0, reg & 7, 0);
    }

    void setReg(unsigned reg)
    {
        Irex &= ~REX_R;
        Irm &= ~modregrm(0, 7, 0);
        orReg(reg);
    }
};

// !=0 if we have to add FWAIT to floating point ops
#define ADDFWAIT()      (config.target_cpu <= TARGET_80286)

/********************** PUBLIC FUNCTIONS *******************/

code *code_calloc(void);
void code_free (code *);
void code_term(void);

#define code_next(c)    ((c)->next)

//#define code_calloc() ((code *) mem_calloc(sizeof(code)))

typedef code *code_p;

/**********************************
 * Set value in regimmed for reg.
 * NOTE: For 16 bit generator, this is always a (targ_short) sign-extended
 *      value.
 */

#define regimmed_set(reg,e) \
        (regcon.immed.value[reg] = (e),regcon.immed.mval |= 1 << (reg))

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
 */

#if TX86
struct NDP
{
    elem *e;                    // which elem is stored here (NULL if none)
    unsigned offset;            // offset from e (used for complex numbers)

    static NDP *save;
    static int savemax;         // # of entries in save[]
    static int savetop;         // # of entries used in save[]
};

extern NDP _8087elems[8];
#endif

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

/*long cxmalloc,cxcalloc,cx1;*/

typedef code *cd_t (elem *e , regm_t *pretregs );

extern  int BPRM;
extern  regm_t FLOATREGS;
extern  regm_t FLOATREGS2;
extern  regm_t DOUBLEREGS;
extern  const char datafl[],stackfl[],segfl[],flinsymtab[];
extern  char needframe,usedalloca,gotref;
extern  targ_size_t localsize,Toff,Poff,Aoff,
        Poffset,funcoffset,
        framehandleroffset,
        Aoffset,Toffset,EEoffset;
extern  int Aalign;
extern  int cseg;
extern  int STACKALIGN;
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
extern  targ_size_t retoffset;
extern  unsigned stackpush;
extern  int stackchanged;
extern  int refparam;
extern  int reflocal;
extern  char anyiasm;
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
void cssave (elem *e , regm_t regm , unsigned opsflag );
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
void gensaverestore(regm_t, code **, code **);
void gensaverestore2(regm_t regm,code **csave,code **crestore);
code *genstackclean(code *c,unsigned numpara,regm_t keepmsk);
code *logexp (elem *e , int jcond , unsigned fltarg , code *targ );
code *loadea (elem *e , code *cs , unsigned op , unsigned reg , targ_size_t offset , regm_t keepmsk , regm_t desmsk );
unsigned getaddrmode (regm_t idxregs );
void setaddrmode(code *c, regm_t idxregs);
void getlvalue_msw(code *);
void getlvalue_lsw(code *);
code *getlvalue (code *pcs , elem *e , regm_t keepmsk );
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
extern int BPoff;

int cod3_EA(code *c);
regm_t cod3_useBP();
void cod3_set32 (void );
void cod3_set64 (void );
void cod3_align (void );
regm_t regmask(tym_t tym, tym_t tyf);
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
void jmpaddr (code *c );
int code_match(code *c1,code *c2);
unsigned calcblksize (code *c);
unsigned calccodsize(code *c);
unsigned codout (code *c );
void addtofixlist (symbol *s , targ_size_t soffset , int seg , targ_size_t val , int flags );
void searchfixlist (symbol *s );
void outfixlist (void );
void code_hydrate(code **pc);
void code_dehydrate(code **pc);

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
cd_t cdbt;
cd_t cdbscan;
cd_t cdpair;
code *longcmp (elem *,bool,unsigned,code *);

/* cod5.c */
void cod5_prol_epi();
void cod5_noprol();

/* cgxmm.c */
code *movxmmconst(unsigned reg, unsigned sz, targ_size_t value, regm_t flags);
code *orthxmm(elem *e, regm_t *pretregs);
code *xmmeq(elem *e, regm_t *pretregs);
code *xmmcnvt(elem *e,regm_t *pretregs);
code *xmmopass(elem *e, regm_t *pretregs);
code *xmmneg(elem *e, regm_t *pretregs);
unsigned xmmload(tym_t tym);
unsigned xmmstore(tym_t tym);
code *cdvector(elem *e, regm_t *pretregs);

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

#if OMFOBJ

struct Ledatarec;

struct seg_data
{
    int                  SDseg;         // index into SegData[]
    targ_size_t          SDoffset;      // starting offset for data

    bool isfarseg;
    int segidx;                         // internal object file segment number
    int lnameidx;                       // lname idx of segment name
    int classidx;                       // lname idx of class name
    unsigned attr;                      // segment attribute
    targ_size_t origsize;               // original size
    long seek;                          // seek position in output file
    Ledatarec *ledata;                  // current one we're filling in
};

//extern  targ_size_t Coffset;

#endif

#if ELFOBJ || MACHOBJ

typedef unsigned int IDXSTR;
typedef unsigned int IDXSEC;
typedef unsigned int IDXSYM;

struct linnum_data
{
    const char *filename;
    unsigned filenumber;        // corresponding file number for DW_LNS_set_file

    unsigned linoff_count;
    unsigned linoff_max;
    unsigned (*linoff)[2];      // [0] = line number, [1] = offset
};

struct seg_data
{
    int                  SDseg;         // segment index into SegData[]
    IDXSEC               SDshtidx;      // section header table index
    targ_size_t          SDoffset;      // starting offset for data
    Outbuffer           *SDbuf;         // buffer to hold data
    Outbuffer           *SDrel;         // buffer to hold relocation info
#if ELFOBJ
    IDXSYM               SDsymidx;      // each section is in the symbol table
    IDXSEC               SDrelidx;      // section header for relocation info
    targ_size_t          SDrelmaxoff;   // maximum offset encountered
    int                  SDrelindex;    // maximum offset encountered
    int                  SDrelcnt;      // number of relocations added
    IDXSEC               SDshtidxout;   // final section header table index
    Symbol              *SDsym;         // if !=NULL, comdat symbol
#endif

    unsigned            SDaranges_offset;       // if !=0, offset in .debug_aranges

    unsigned             SDlinnum_count;
    unsigned             SDlinnum_max;
    linnum_data         *SDlinnum_data; // array of line number / offset data

    int isCode();
};


#endif

extern seg_data **SegData;
#define Offset(seg) SegData[seg]->SDoffset
#define Doffset SegData[DATA]->SDoffset
#define CDoffset SegData[CDATA]->SDoffset
#define Coffset SegData[cseg]->SDoffset

#if __cplusplus && TX86
}
#endif

