// Copyright (C) 1985-1996 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* Register definitions */

#define AX      0
#define CX      1
#define DX      2
#define BX      3
#define SP      4
#define BP      5
#define SI      6
#define DI      7

#define PICREG  BX

enum // #defining R12-R15 interfere with setjmps' _JUMP_BUFFER members
{
    R8       = 8,
    R9       = 9,
    R10      = 10,
    R11      = 11,
    R12      = 12,
    R13      = 13,
    R14      = 14,
    R15      = 15,
};

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

/* See Solaris note in optabgen.c */
#ifdef ES
#undef ES
#endif

#define ES      24

#define NUMGENREGS 16

// fishy naming as it covers XMM7 but not XMM15
// currently only used as a replacement for mES in cgcod.c
#define NUMREGS 25

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

extern regm_t ALLREGS;
extern regm_t BYTEREGS;
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    // To support positional independent code,
    // must be able to remove BX from available registers
#define ALLREGS_INIT            (mAX|mBX|mCX|mDX|mSI|mDI)
#define ALLREGS_INIT_PIC        (mAX|mCX|mDX|mSI|mDI)
#define BYTEREGS_INIT           (mAX|mBX|mCX|mDX)
#define BYTEREGS_INIT_PIC       (mAX|mCX|mDX)
#else
#define ALLREGS_INIT            (mAX|mBX|mCX|mDX|mSI|mDI)
#define BYTEREGS_INIT           (mAX|mBX|mCX|mDX)
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
#define LOCK    0xF0

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

#define ESCAPEmask 0xFF // code.Iop & ESCAPEmask ==> actual Iop
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

#if 1 || TARGET_WINDOS
        CLIBdmul,CLIBddiv,CLIBdtst0,CLIBdtst0exc,CLIBdcmp,CLIBdcmpexc,CLIBdneg,CLIBdadd,CLIBdsub,
        CLIBfmul,CLIBfdiv,CLIBftst0,CLIBftst0exc,CLIBfcmp,CLIBfcmpexc,CLIBfneg,CLIBfadd,CLIBfsub,
#endif

        CLIBdbllng,CLIBlngdbl,CLIBdblint,CLIBintdbl,
        CLIBdbluns,CLIBunsdbl,
        CLIBdblulng,
#if 1 || TARGET_WINDOS
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

#if TARGET_WINDOS
        // Win64 versions
        CLIBdblullng_win64,
        CLIBullngdbl_win64,
#endif

        CLIBMAX
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

#define CFjmp5      0x400000    // always a 5 byte jmp
#define CFswitch    0x800000    // kludge for switch table fixups

/* These are for CFpc32 fixups, they're the negative of the offset of the fixup
 * from the program counter
 */
#define CFREL       0x7000000

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

    code() { Iflags = 0; Irex = 0; Isib = 0; IFL1 = 0; IFL2 = 0; }      // constructor

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

    bool isJumpOP() { return Iop == JMP || Iop == JMPS; }
};

// !=0 if we have to add FWAIT to floating point ops
#define ADDFWAIT()      (config.target_cpu <= TARGET_80286)

/************************************
 */

struct NDP
{
    elem *e;                    // which elem is stored here (NULL if none)
    unsigned offset;            // offset from e (used for complex numbers)

    static NDP *save;
    static int savemax;         // # of entries in save[]
    static int savetop;         // # of entries used in save[]
};

extern NDP _8087elems[8];

void getlvalue_msw(code *);
void getlvalue_lsw(code *);
code *getlvalue (code *pcs , elem *e , regm_t keepmsk );
code *loadea (elem *e , code *cs , unsigned op , unsigned reg , targ_size_t offset , regm_t keepmsk , regm_t desmsk );
