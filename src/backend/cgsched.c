// Copyright (C) 1995-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "exh.h"
#include        "list.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

// If we use Pentium Pro scheduler
#if 0
#define PRO     (config.target_scheduler >= TARGET_PentiumPro)
#else
#define PRO     (config.target_cpu >= TARGET_PentiumPro)
#endif

// Struct where we gather information about an instruction
struct Cinfo
{
    code *c;            // the instruction
    unsigned char pair; // pairing information
    unsigned char sz;   // operand size
    unsigned char isz;  // instruction size

    // For floating point scheduling
    unsigned char fxch_pre;
    unsigned char fxch_post;
    unsigned char fp_op;
        #define FPfstp  1       // FSTP mem
        #define FPfld   2       // FLD mem
        #define FPfop   3       // Fop ST0,mem or Fop ST0

    unsigned char flags;
#define CIFLarraybounds 1       // this instruction is a jmp to array bounds
#define CIFLea          2       // this instruction has a memory-referencing
                                // modregrm EA byte
#define CIFLnostage     4       // don't stage these instructions
#define CIFLpush        8       // it's a push we can swap around

    unsigned r;         // read mask
    unsigned w;         // write mask
    unsigned a;         // registers used in addressing mode
    unsigned char reg;  // reg field of modregrm byte
    unsigned char uops; // Pentium Pro micro-ops
    unsigned sibmodrm;  // (sib << 8) + mod__rm byte
    unsigned spadjust;  // if !=0, then amount ESP changes as a result of this
                        // instruction being executed
    int fpuadjust;      // if !=0, then amount FPU stack changes as a result
                        // of this instruction being executed
#if DEBUG
    void print();       // pretty-printer
#endif
};

code *simpleops(code *c,regm_t scratch);
code *schedule(code *c,regm_t scratch);
code *peephole(code *c,regm_t scratch);

/*****************************************
 * Do Pentium optimizations.
 * Input:
 *      scratch         scratch registers we can use
 */

void cgsched_pentium(code **pc,regm_t scratch)
{
    //printf("scratch = x%02x\n",scratch);
    if (config.target_scheduler >= TARGET_80486)
    {
        if (!I64)
            *pc = peephole(*pc,0);
        if (I32)                        // forget about 16 bit code
        {
            if (config.target_cpu == TARGET_Pentium ||
                config.target_cpu == TARGET_PentiumMMX)
                *pc = simpleops(*pc,scratch);
            *pc = schedule(*pc,0);
        }
    }
}

void cgsched_block(block* b)
{
    if (config.flags4 & CFG4speed &&
        config.target_cpu >= TARGET_Pentium &&
        b->BC != BCasm)
    {
        regm_t scratch = allregs;

        scratch &= ~(b->Bregcon.used | b->Bregcon.params | mfuncreg);
        scratch &= ~(b->Bregcon.immed.mval | b->Bregcon.cse.mval);
        cgsched_pentium(&b->Bcode,scratch);
        //printf("after schedule:\n"); WRcodlst(b->Bcode);
    }
}

#define NP      0       // not pairable
#define PU      1       // pairable in U only, never executed in V
#define PV      2       // pairable in V only
#define UV      (PU|PV) // pairable in both U and V
#define PE      4       // register contention exception
#define PF      8       // flags contention exception
#define FX      0x10    // pairable with FXCH instruction

static unsigned char pentcycl[256] =
{
        UV,UV,UV,UV,    UV,UV,NP,NP,    // 0
        UV,UV,UV,UV,    UV,UV,NP,NP,    // 8
        PU,PU,PU,PU,    PU,PU,NP,NP,    // 10
        PU,PU,PU,PU,    PU,PU,NP,NP,    // 18
        UV,UV,UV,UV,    UV,UV,NP,NP,    // 20
        UV,UV,UV,UV,    UV,UV,NP,NP,    // 28
        UV,UV,UV,UV,    UV,UV,NP,NP,    // 30
        UV,UV,UV,UV,    UV,UV,NP,NP,    // 38

        UV,UV,UV,UV,    UV,UV,UV,UV,    // 40
        UV,UV,UV,UV,    UV,UV,UV,UV,    // 48
        PE|UV,PE|UV,PE|UV,PE|UV,        PE|UV,PE|UV,PE|UV,PE|UV, // 50  PUSH reg
        PE|UV,PE|UV,PE|UV,PE|UV,        PE|UV,PE|UV,PE|UV,PE|UV, // 58  POP reg
        NP,NP,NP,NP,    NP,NP,NP,NP,    // 60
        PE|UV,NP,PE|UV,NP,      NP,NP,NP,NP,    // 68
        PV|PF,PV|PF,PV|PF,PV|PF,        PV|PF,PV|PF,PV|PF,PV|PF,        // 70   Jcc rel8
        PV|PF,PV|PF,PV|PF,PV|PF,        PV|PF,PV|PF,PV|PF,PV|PF,        // 78   Jcc rel8

        NP,NP,NP,NP,    NP,NP,NP,NP,    // 80
        UV,UV,UV,UV,    NP,UV,NP,NP,    // 88
        NP,NP,NP,NP,    NP,NP,NP,NP,    // 90
        NP,NP,NP,NP,    NP,NP,NP,NP,    // 98
        UV,UV,UV,UV,    NP,NP,NP,NP,    // A0
        UV,UV,NP,NP,    NP,NP,NP,NP,    // A8
        UV,UV,UV,UV,    UV,UV,UV,UV,    // B0
        UV,UV,UV,UV,    UV,UV,UV,UV,    // B8

        NP,NP,NP,NP,    NP,NP,NP,NP,    // C0
        NP,NP,NP,NP,    NP,NP,NP,NP,    // C8
        PU,PU,NP,NP,    NP,NP,NP,NP,    // D0
        FX,NP,FX,FX,    NP,NP,FX,NP,    // D8   all floating point
        NP,NP,NP,NP,    NP,NP,NP,NP,    // E0
        PE|PV,PV,NP,PV, NP,NP,NP,NP,    // E8
        NP,NP,NP,NP,    NP,NP,NP,NP,    // F0
        NP,NP,NP,NP,    NP,NP,NP,NP,    // F8
};

/********************************************
 * For each opcode, determine read [0] and written [1] masks.
 */

#define EA      0x100000
#define R       0x200000        // register (reg of modregrm field)
#define N       0x400000        // other things modified, not swappable
#define B       0x800000        // it's a byte operation
#define C       0x1000000       // floating point flags
#define mMEM    0x2000000       // memory
#define S       0x4000000       // floating point stack
#define F       0x8000000       // flags

static unsigned oprw[256][2] =
{
        // 00
        EA|R|B, F|EA|B,         // ADD
        EA|R,   F|EA,
        EA|R|B, F|R|B,
        EA|R,   F|R,
        mAX,    F|mAX,
        mAX,    F|mAX,
        N,      N,              // PUSH ES
        N,      N,              // POP  ES

        // 08
        EA|R|B, F|EA|B,         // OR
        EA|R,   F|EA,
        EA|R|B, F|R|B,
        EA|R,   F|R,
        mAX,    F|mAX,
        mAX,    F|mAX,
        N,      N,              // PUSH CS
        N,      N,              // 2 byte escape

        // 10
        F|EA|R|B,F|EA|B,        // ADC
        F|EA|R, F|EA,
        F|EA|R|B,F|R|B,
        F|EA|R, F|R,
        F|mAX,  F|mAX,
        F|mAX,  F|mAX,
        N,      N,              // PUSH SS
        N,      N,              // POP  SS

        // 18
        F|EA|R|B,F|EA|B,        // SBB
        F|EA|R, F|EA,
        F|EA|R|B,F|R|B,
        F|EA|R, F|R,
        F|mAX,  F|mAX,
        F|mAX,  F|mAX,
        N,      N,              // PUSH DS
        N,      N,              // POP  DS

        // 20
        EA|R|B, F|EA|B,         // AND
        EA|R,   F|EA,
        EA|R|B, F|R|B,
        EA|R,   F|R,
        mAX,    F|mAX,
        mAX,    F|mAX,
        N,      N,              // SEG ES
        F|mAX,  F|mAX,          // DAA

        // 28
        EA|R|B, F|EA|B,         // SUB
        EA|R,   F|EA,
        EA|R|B, F|R|B,
        EA|R,   F|R,
        mAX,    F|mAX,
        mAX,    F|mAX,
        N,      N,              // SEG CS
        F|mAX,  F|mAX,          // DAS

        // 30
        EA|R|B, F|EA|B,         // XOR
        EA|R,   F|EA,
        EA|R|B, F|R|B,
        EA|R,   F|R,
        mAX,    F|mAX,
        mAX,    F|mAX,
        N,      N,              // SEG SS
        F|mAX,  F|mAX,          // AAA

        // 38
        EA|R|B, F,              // CMP
        EA|R,   F,
        EA|R|B, F,
        EA|R,   F,
        mAX,    F,              // CMP AL,imm8
        mAX,    F,              // CMP EAX,imm16/32
        N,      N,              // SEG DS
        N,      N,              // AAS

        // 40
        mAX,    F|mAX,          // INC EAX
        mCX,    F|mCX,
        mDX,    F|mDX,
        mBX,    F|mBX,
        mSP,    F|mSP,
        mBP,    F|mBP,
        mSI,    F|mSI,
        mDI,    F|mDI,

        // 48
        mAX,    F|mAX,          // DEC EAX
        mCX,    F|mCX,
        mDX,    F|mDX,
        mBX,    F|mBX,
        mSP,    F|mSP,
        mBP,    F|mBP,
        mSI,    F|mSI,
        mDI,    F|mDI,

        // 50
        mAX|mSP,        mSP|mMEM,               // PUSH EAX
        mCX|mSP,        mSP|mMEM,
        mDX|mSP,        mSP|mMEM,
        mBX|mSP,        mSP|mMEM,
        mSP|mSP,        mSP|mMEM,
        mBP|mSP,        mSP|mMEM,
        mSI|mSP,        mSP|mMEM,
        mDI|mSP,        mSP|mMEM,

        // 58
        mSP|mMEM,       mAX|mSP,                // POP EAX
        mSP|mMEM,       mCX|mSP,
        mSP|mMEM,       mDX|mSP,
        mSP|mMEM,       mBX|mSP,
        mSP|mMEM,       mSP|mSP,
        mSP|mMEM,       mBP|mSP,
        mSP|mMEM,       mSI|mSP,
        mSP|mMEM,       mDI|mSP,

        // 60
        N,      N,              // PUSHA
        N,      N,              // POPA
        N,      N,              // BOUND Gv,Ma
        N,      N,              // ARPL  Ew,Rw
        N,      N,              // SEG FS
        N,      N,              // SEG GS
        N,      N,              // operand size prefix
        N,      N,              // address size prefix

        // 68
        mSP,    mSP|mMEM,       // PUSH immed16/32
        EA,     F|R,            // IMUL Gv,Ev,lv
        mSP,    mSP|mMEM,       // PUSH immed8
        EA,     F|R,            // IMUL Gv,Ev,lb
        N,      N,              // INSB Yb,DX
        N,      N,              // INSW/D Yv,DX
        N,      N,              // OUTSB DX,Xb
        N,      N,              // OUTSW/D DX,Xv

        // 70
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,

        // 78
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,
        F|N,    N,

        // 80
        N,      N,
        N,      N,
        N,      N,
        N,      N,
        EA|R,   F,              // TEST EA,r8
        EA|R,   F,              // TEST EA,r16/32
        EA|R,   EA|R,           // XCHG EA,r8
        EA|R,   EA|R,           // XCHG EA,r16/32

        // 88
        R|B,    EA|B,           // MOV EA8,r8
        R,      EA,             // MOV EA,r16/32
        EA|B,   R|B,            // MOV r8,EA8
        EA,     R,              // MOV r16/32,EA
        N,      N,              // MOV EA,segreg
        EA,     R,              // LEA r16/32,EA
        N,      N,              // MOV segreg,EA
        mSP|mMEM, EA|mSP,       // POP mem16/32

        // 90
        0,              0,              // NOP
        mAX|mCX,        mAX|mCX,
        mAX|mDX,        mAX|mDX,
        mAX|mBX,        mAX|mBX,
        mAX|mSP,        mAX|mSP,
        mAX|mBP,        mAX|mBP,
        mAX|mSI,        mAX|mSI,
        mAX|mDI,        mAX|mDI,

        // 98
        mAX,            mAX,            // CBW
        mAX,            mDX,            // CWD
        N,              N|F,            // CALL far ptr
        N,              N,              // WAIT
        F|mSP,          mSP|mMEM,       // PUSHF
        mSP|mMEM,       F|mSP,          // POPF
        mAX,            F,              // SAHF
        F,              mAX,            // LAHF

        // A0
        mMEM,           mAX,            // MOV AL,moffs8
        mMEM,           mAX,            // MOV EAX,moffs32
        mAX,            mMEM,           // MOV moffs8,AL
        mAX,            mMEM,           // MOV moffs32,EAX
        N,              N,              // MOVSB
        N,              N,              // MOVSW/D
        N,              N,              // CMPSB
        N,              N,              // CMPSW/D

        // A8
        mAX,    F,                      // TEST AL,imm8
        mAX,    F,                      // TEST AX,imm16
        N,      N,                      // STOSB
        N,      N,                      // STOSW/D
        N,      N,                      // LODSB
        N,      N,                      // LODSW/D
        N,      N,                      // SCASB
        N,      N,                      // SCASW/D

        // B0
        0,      mAX,                    // MOV AL,imm8
        0,      mCX,
        0,      mDX,
        0,      mBX,
        0,      mAX,
        0,      mCX,
        0,      mDX,
        0,      mBX,

        // B8
        0,      mAX,                    // MOV AX,imm16
        0,      mCX,
        0,      mDX,
        0,      mBX,
        0,      mSP,
        0,      mBP,
        0,      mSI,
        0,      mDI,

        // C0
        EA,     F|EA,           // Shift Eb,Ib
        EA,     F|EA,
        N,      N,
        N,      N,
        N,      N,
        N,      N,
        0,      EA|B,           // MOV EA8,imm8
        0,      EA,             // MOV EA,imm16

        // C8
        N,      N,              // ENTER
        N,      N,              // LEAVE
        N,      N,              // RETF lw
        N,      N,              // RETF
        N,      N,              // INT 3
        N,      N,              // INT lb
        N,      N,              // INTO
        N,      N,              // IRET

        // D0
        EA,             F|EA,           // Shift EA,1
        EA,             F|EA,
        EA|mCX,         F|EA,           // Shift EA,CL
        EA|mCX,         F|EA,
        mAX,            F|mAX,          // AAM
        mAX,            F|mAX,          // AAD
        N,              N,              // reserved
        mAX|mBX|mMEM,   mAX,            // XLAT

        // D8
        N,      N,
        N,      N,
        N,      N,
        N,      N,
        N,      N,
        N,      N,
        N,      N,
        N,      N,

        // E0
        F|mCX|N,mCX|N,          // LOOPNE jb
        F|mCX|N,mCX|N,          // LOOPE  jb
        mCX|N,  mCX|N,          // LOOP   jb
        mCX|N,  N,              // JCXZ   jb
        N,      N,              // IN AL,lb
        N,      N,              // IN EAX,lb
        N,      N,              // OUT lb,AL
        N,      N,              // OUT lb,EAX

        // E8
        N,      N|F,            // CALL jv
        N,      N,              // JMP Jv
        N,      N,              // JMP Ab
        N,      N,              // JMP jb
        N|mDX,  N|mAX,          // IN AL,DX
        N|mDX,  N|mAX,          // IN AX,DX
        N|mAX|mDX,N,            // OUT DX,AL
        N|mAX|mDX,N,            // OUT DX,AX

        // F0
        N,      N,              // LOCK
        N,      N,              // reserved
        N,      N,              // REPNE
        N,      N,              // REP,REPE
        N,      N,              // HLT
        F,      F,              // CMC
        N,      N,
        N,      N,

        // F8
        0,      F,              // CLC
        0,      F,              // STC
        N,      N,              // CLI
        N,      N,              // STI
        N,      N,              // CLD
        N,      N,              // STD
        EA,     F|EA,           // INC/DEC
        N,      N,
};

/****************************************
 * Same thing, but for groups.
 */

static unsigned grprw[8][8][2] =
{
        // Grp 1
        EA,     F|EA,           // ADD
        EA,     F|EA,           // OR
        F|EA,   F|EA,           // ADC
        F|EA,   F|EA,           // SBB
        EA,     F|EA,           // AND
        EA,     F|EA,           // SUB
        EA,     F|EA,           // XOR
        EA,     F,              // CMP

        // Grp 3
        EA,     F,              // TEST EA,imm
        N,      N,              // reserved
        EA,     EA,             // NOT
        EA,     F|EA,           // NEG
        mAX|EA, F|mAX|mDX,      // MUL
        mAX|EA, F|mAX|mDX,      // IMUL
        mAX|mDX|EA,     F|mAX|mDX,      // DIV
#if 0
        // Could generate an exception we want to catch
        mAX|mDX|EA|N,   F|mAX|mDX|N,    // IDIV
#else
        mAX|mDX|EA,     F|mAX|mDX,      // IDIV
#endif

        // Grp 5
        EA,     F|EA,           // INC Ev
        EA,     F|EA,           // DEC Ev
        N|EA,   N,              // CALL Ev
        N|EA,   N,              // CALL eP
        N|EA,   N,              // JMP Ev
        N|EA,   N,              // JMP Ep
        mSP|EA, mSP|mMEM,       // PUSH Ev
        N,      N,              // reserved

        // Grp 3, byte version
        EA|B,   F,              // TEST EA,imm
        N,      N,              // reserved
        EA|B,   EA|B,           // NOT
        EA|B,   F|EA|B,         // NEG
        mAX|EA, F|mAX,          // MUL
        mAX|EA, F|mAX,          // IMUL
        mAX|EA, F|mAX,          // DIV
#if 0
        // Could generate an exception we want to catch
        mAX|EA|N,       F|mAX|N,        // IDIV
#else
        mAX|EA, F|mAX,          // IDIV
#endif

};

/********************************************
 * For floating point opcodes 0xD8..0xDF, with Irm < 0xC0.
 *      [][][0] = read
 *          [1] = write
 */

static unsigned grpf1[8][8][2] =
{
        // 0xD8
        EA|S,   S|C,    // FADD  float
        EA|S,   S|C,    // FMUL  float
        EA|S,   C,      // FCOM  float
        EA|S,   S|C,    // FCOMP float
        EA|S,   S|C,    // FSUB  float
        EA|S,   S|C,    // FSUBR float
        EA|S,   S|C,    // FDIV  float
        EA|S,   S|C,    // FDIVR float

        // 0xD9
        EA,     S|C,    // FLD  float
        N,      N,      //
        S,      EA|C,   // FST  float
        S,      EA|S|C, // FSTP float
        N,      N,      // FLDENV
        N,      N,      // FLDCW
        N,      N,      // FSTENV
        N,      N,      // FSTCW

        // 0xDA
        EA|S,   S|C,    // FIADD  long
        EA|S,   S|C,    // FIMUL  long
        EA|S,   C,      // FICOM  long
        EA|S,   S|C,    // FICOMP long
        EA|S,   S|C,    // FISUB  long
        EA|S,   S|C,    // FISUBR long
        EA|S,   S|C,    // FIDIV  long
        EA|S,   S|C,    // FIDIVR long

        // 0xDB
        EA,     S|C,    // FILD long
        S,      EA|S|C, // FISTTP int
        S,      EA|C,   // FIST long
        S,      EA|S|C, // FISTP long
        N,      N,      //
        EA,     S|C,    // FLD real80
        N,      N,      //
        S,      EA|S|C, // FSTP real80

        // 0xDC
        EA|S,   S|C,    // FADD  double
        EA|S,   S|C,    // FMUL  double
        EA|S,   C,      // FCOM  double
        EA|S,   S|C,    // FCOMP double
        EA|S,   S|C,    // FSUB  double
        EA|S,   S|C,    // FSUBR double
        EA|S,   S|C,    // FDIV  double
        EA|S,   S|C,    // FDIVR double

        // 0xDD
        EA,     S|C,    // FLD double
        S,      EA|S|C, // FISTTP long
        S,      EA|C,   // FST double
        S,      EA|S|C, // FSTP double
        N,      N,      // FRSTOR
        N,      N,      //
        N,      N,      // FSAVE
        C,      EA,     // FSTSW

        // 0xDE
        EA|S,   S|C,    // FIADD  short
        EA|S,   S|C,    // FIMUL  short
        EA|S,   C,      // FICOM  short
        EA|S,   S|C,    // FICOMP short
        EA|S,   S|C,    // FISUB  short
        EA|S,   S|C,    // FISUBR short
        EA|S,   S|C,    // FIDIV  short
        EA|S,   S|C,    // FIDIVR short

        // 0xDF
        EA,     S|C,    // FILD short
        S,      EA|S|C, // FISTTP short
        S,      EA|C,   // FIST short
        S,      EA|S|C, // FISTP short
        EA,     S|C,    // FBLD packed BCD
        EA,     S|C,    // FILD long long
        S,      EA|S|C, // FBSTP packed BCD
        S,      EA|S|C, // FISTP long long
};


/********************************************
 * Micro-ops for floating point opcodes 0xD8..0xDF, with Irm < 0xC0.
 */

static unsigned char uopsgrpf1[8][8] =
{
        // 0xD8
        2,              // FADD  float
        2,              // FMUL  float
        2,              // FCOM  float
        2,              // FCOMP float
        2,              // FSUB  float
        2,              // FSUBR float
        2,              // FDIV  float
        2,              // FDIVR float

        // 0xD9
        1,              // FLD  float
        0,              //
        2,              // FST  float
        2,              // FSTP float
        5,              // FLDENV
        3,              // FLDCW
        5,              // FSTENV
        5,              // FSTCW

        // 0xDA
        5,              // FIADD  long
        5,              // FIMUL  long
        5,              // FICOM  long
        5,              // FICOMP long
        5,              // FISUB  long
        5,              // FISUBR long
        5,              // FIDIV  long
        5,              // FIDIVR long

        // 0xDB
        4,              // FILD long
        0,              //
        4,              // FIST long
        4,              // FISTP long
        0,              //
        4,              // FLD real80
        0,              //
        5,              // FSTP real80

        // 0xDC
        2,              // FADD  double
        2,              // FMUL  double
        2,              // FCOM  double
        2,              // FCOMP double
        2,              // FSUB  double
        2,              // FSUBR double
        2,              // FDIV  double
        2,              // FDIVR double

        // 0xDD
        1,              // FLD double
        0,              //
        2,              // FST double
        2,              // FSTP double
        5,              // FRSTOR
        0,              //
        5,              // FSAVE
        5,              // FSTSW

        // 0xDE
        5,              // FIADD  short
        5,              // FIMUL  short
        5,              // FICOM  short
        5,              // FICOMP short
        5,              // FISUB  short
        5,              // FISUBR short
        5,              // FIDIV  short
        5,              // FIDIVR short

        // 0xDF
        4,              // FILD short
        0,              //
        4,              // FIST short
        4,              // FISTP short
        5,              // FBLD packed BCD
        4,              // FILD long long
        5,              // FBSTP packed BCD
        4,              // FISTP long long
};

/**************************************************
 * Determine number of micro-ops for Pentium Pro and Pentium II processors.
 * 0 means special case,
 * 5 means 'complex'
 */

static const unsigned char insuops[256] =
{       0,0,0,0,        1,1,4,5,                /* 00 */
        0,0,0,0,        1,1,4,0,                /* 08 */
        0,0,0,0,        2,2,4,5,                /* 10 */
        0,0,0,0,        2,2,4,5,                /* 18 */
        0,0,0,0,        1,1,0,1,                /* 20 */
        0,0,0,0,        1,1,0,1,                /* 28 */
        0,0,0,0,        1,1,0,1,                /* 30 */
        0,0,0,0,        1,1,0,1,                /* 38 */
        1,1,1,1,        1,1,1,1,                /* 40 */
        1,1,1,1,        1,1,1,1,                /* 48 */
        3,3,3,3,        3,3,3,3,                /* 50 */
        2,2,2,2,        3,2,2,2,                /* 58 */
        5,5,5,5,        0,0,0,0,                /* 60 */
        3,3,0,0,        5,5,5,5,                /* 68 */
        1,1,1,1,        1,1,1,1,                /* 70 */
        1,1,1,1,        1,1,1,1,                /* 78 */
        0,0,0,0,        0,0,0,0,                /* 80 */
        0,0,0,0,        0,1,4,0,                /* 88 */
        1,3,3,3,        3,3,3,3,                /* 90 */
        1,1,5,0,        5,5,1,1,                /* 98 */
        1,1,2,2,        5,5,5,5,                /* A0 */
        1,1,3,3,        2,2,3,3,                /* A8 */
        1,1,1,1,        1,1,1,1,                /* B0 */
        1,1,1,1,        1,1,1,1,                /* B8 */
        0,0,5,4,        0,0,0,0,                /* C0 */
        5,3,5,5,        5,3,5,5,                /* C8 */
        0,0,0,0,        4,3,0,2,                /* D0 */
        0,0,0,0,        0,0,0,0,                /* D8 */
        4,4,4,2,        5,5,5,5,                /* E0 */
        4,1,5,1,        5,5,5,5,                /* E8 */
        0,0,5,5,        5,1,0,0,                /* F0 */
        1,1,5,5,        4,4,0,0,                /* F8 */
};

static unsigned char uopsx[8] = { 1,1,2,5,1,1,1,5 };

/************************************************
 * Determine number of micro-ops for Pentium Pro and Pentium II processors.
 * 5 means 'complex'.
 * Doesn't currently handle:
 *      floating point
 *      MMX
 *      0F opcodes
 *      prefix bytes
 */

STATIC int uops(code *c)
{   int n;
    int op;
    int op2;

    op = c->Iop & 0xFF;
    if ((c->Iop & 0xFF00) == 0x0F00)
        op = 0x0F;
    n = insuops[op];
    if (!n)                             // if special case
    {   unsigned char irm,mod,reg,rm;

        irm = c->Irm;
        mod = (irm >> 6) & 3;
        reg = (irm >> 3) & 7;
        rm = irm & 7;

        switch (op)
        {
            case 0x10:
            case 0x11:                  // ADC rm,r
            case 0x18:
            case 0x19:                  // SBB rm,r
                n = (mod == 3) ? 2 : 4;
                break;

            case 0x12:
            case 0x13:                  // ADC r,rm
            case 0x1A:
            case 0x1B:                  // SBB r,rm
                n = (mod == 3) ? 2 : 3;
                break;

            case 0x00:
            case 0x01:                  // ADD rm,r
            case 0x08:
            case 0x09:                  // OR rm,r
            case 0x20:
            case 0x21:                  // AND rm,r
            case 0x28:
            case 0x29:                  // SUB rm,r
            case 0x30:
            case 0x31:                  // XOR rm,r
                n = (mod == 3) ? 1 : 4;
                break;

            case 0x02:
            case 0x03:                  // ADD r,rm
            case 0x0A:
            case 0x0B:                  // OR r,rm
            case 0x22:
            case 0x23:                  // AND r,rm
            case 0x2A:
            case 0x2B:                  // SUB r,rm
            case 0x32:
            case 0x33:                  // XOR r,rm
            case 0x38:
            case 0x39:                  // CMP rm,r
            case 0x3A:
            case 0x3B:                  // CMP r,rm
            case 0x69:                  // IMUL rm,r,imm
            case 0x6B:                  // IMUL rm,r,imm8
            case 0x84:
            case 0x85:                  // TEST rm,r
                n = (mod == 3) ? 1 : 2;
                break;

            case 0x80:
            case 0x81:
            case 0x82:
            case 0x83:
                if (reg == 2 || reg == 3)       // ADC/SBB rm,imm
                    n = (mod == 3) ? 2 : 4;
                else if (reg == 7)              // CMP rm,imm
                    n = (mod == 3) ? 1 : 2;
                else
                    n = (mod == 3) ? 1 : 4;
                break;

            case 0x86:
            case 0x87:                          // XCHG rm,r
                n = (mod == 3) ? 3 : 5;
                break;

            case 0x88:
            case 0x89:                          // MOV rm,r
                n = (mod == 3) ? 1 : 2;
                break;

            case 0x8A:
            case 0x8B:                          // MOV r,rm
                n = 1;
                break;

            case 0x8C:                          // MOV Sreg,rm
                n = (mod == 3) ? 1 : 3;
                break;

            case 0x8F:
                if (reg == 0)                   // POP m
                    n = 5;
                break;

            case 0xC6:
            case 0xC7:
                if (reg == 0)                   // MOV rm,imm
                    n = (mod == 3) ? 1 : 2;
                break;

            case 0xD0:
            case 0xD1:
                if (reg == 2 || reg == 3)       // RCL/RCR rm,1
                    n = (mod == 3) ? 2 : 4;
                else
                    n = (mod == 3) ? 1 : 4;
                break;

            case 0xC0:
            case 0xC1:                          // RCL/RCR rm,imm8
            case 0xD2:
            case 0xD3:
                if (reg == 2 || reg == 3)       // RCL/RCR rm,CL
                    n = 5;
                else
                    n = (mod == 3) ? 1 : 4;
                break;

            case 0xD8:
            case 0xD9:
            case 0xDA:
            case 0xDB:
            case 0xDC:
            case 0xDD:
            case 0xDE:
            case 0xDF:
                // Floating point opcodes
                if (irm < 0xC0)
                {   n = uopsgrpf1[op - 0xD8][reg];
                    break;
                }
                n = uopsx[op - 0xD8];
                switch (op)
                {
                    case 0xD9:
                        switch (irm)
                        {
                            case 0xE0:          // FCHS
                                n = 3;
                                break;
                            case 0xE8:
                            case 0xE9:
                            case 0xEA:
                            case 0xEB:
                            case 0xEC:
                            case 0xED:
                                n = 2;
                                break;
                            case 0xF0:
                            case 0xF1:
                            case 0xF2:
                            case 0xF3:
                            case 0xF4:
                            case 0xF5:
                            case 0xF8:
                            case 0xF9:
                            case 0xFB:
                            case 0xFC:
                            case 0xFD:
                            case 0xFE:
                            case 0xFF:
                                n = 5;
                                break;
                        }
                        break;
                    case 0xDE:
                        if (irm == 0xD9)        // FCOMPP
                            n = 2;
                        break;
                }
                break;

            case 0xF6:
                if (reg == 6 || reg == 7)       // DIV AL,rm8
                    n = (mod == 3) ? 3 : 4;
                else if (reg == 4 || reg == 5 || reg == 0)      // MUL/IMUL/TEST rm8
                    n = (mod == 3) ? 1 : 2;
                else if (reg == 2 || reg == 3)  // NOT/NEG rm
                    n = (mod == 3) ? 1 : 4;
                break;

            case 0xF7:
                if (reg == 6 || reg == 7)       // DIV EAX,rm
                    n = 4;
                else if (reg == 4 || reg == 5)  // MUL/IMUL rm
                    n = (mod == 3) ? 3 : 4;
                else if (reg == 2 || reg == 3)  // NOT/NEG rm
                    n = (mod == 3) ? 1 : 4;
                break;

            case 0xFF:
                if (reg == 2 || reg == 3 ||     // CALL rm, CALL m,rm
                    reg == 5)                   // JMP seg:offset
                    n = 5;
                else if (reg == 4)
                    n = (mod == 3) ? 1 : 2;
                else if (reg == 0 || reg == 1)  // INC/DEC rm
                    n = (mod == 3) ? 1 : 4;
                else if (reg == 6)              // PUSH rm
                    n = (mod == 3) ? 3 : 4;
                break;

            case 0x0F:
                op2 = c->Iop & 0xFF;
                if ((op2 & 0xF0) == 0x80)       // Jcc
                {   n = 1;
                    break;
                }
                if ((op2 & 0xF0) == 0x90)       // SETcc
                {   n = (mod == 3) ? 1 : 3;
                    break;
                }
                if (op2 == 0xB6 || op2 == 0xB7 ||       // MOVZX
                    op2 == 0xBE || op2 == 0xBF)         // MOVSX
                {   n = 1;
                    break;
                }
                if (op2 == 0xAF)                        // IMUL r,m
                {   n = (mod == 3) ? 1 : 2;
                    break;
                }
                break;
        }
    }
    if (n == 0)
        n = 5;                                  // copout for now
    return n;
}

/******************************************
 * Determine pairing classification.
 * Don't deal with floating point, just assume they are all NP (Not Pairable).
 * Returns:
 *      NP,UV,PU,PV optionally OR'd with PE
 */

STATIC int pair_class(code *c)
{   unsigned char op;
    unsigned char irm,mod,reg,rm;
    unsigned a32;
    int pc;

    // Of course, with Intel this is *never* simple, and Intel's
    // documentation is vague about the specifics.

    op = c->Iop & 0xFF;
    if ((c->Iop & 0xFF00) == 0x0F00)
        op = 0x0F;
    pc = pentcycl[op];
    a32 = I32;
    if (c->Iflags & CFaddrsize)
        a32 ^= 1;
    irm = c->Irm;
    mod = (irm >> 6) & 3;
    reg = (irm >> 3) & 7;
    rm = irm & 7;
    switch (op)
    {
        case 0x0F:                              // 2 byte opcode
            if ((c->Iop & 0xF0) == 0x80)        // if Jcc
                pc = PV | PF;
            break;

        case 0x80:
        case 0x81:
        case 0x83:
            if (reg == 2 ||                     // ADC EA,immed
                reg == 3)                       // SBB EA,immed
            {   pc = PU;
                goto L2;
            }
            goto L1;                            // AND/OR/XOR/ADD/SUB/CMP EA,immed

        case 0x84:
        case 0x85:                              // TEST EA,reg
            if (mod == 3)                       // TEST reg,reg
                pc = UV;
            break;

        case 0xC0:
        case 0xC1:
            if (reg >= 4)
                pc = PU;
            break;

        case 0xC6:
        case 0xC7:
            if (reg == 0)                       // MOV EA,immed
            {
        L1:
                pc = UV;
        L2:
                // if EA contains a displacement then
                // can't execute in V, or pair in U
                switch (mod)
                {   case 0:
                        if (a32)
                        {   if (rm == 5 ||
                                (rm == 4 && (c->Isib & 7) == 5)
                               )
                                pc = NP;
                        }
                        else if (rm == 6)
                            pc = NP;
                        break;
                    case 1:
                    case 2:
                        pc = NP;
                        break;
                }
            }
            break;

        case 0xD9:
            if (irm < 0xC0)
            {
                if (reg == 0)
                    pc = FX;
            }
            else if (irm < 0xC8)
                pc = FX;
            else if (irm < 0xD0)
                pc = PV;
            else
            {
                switch (irm)
                {
                    case 0xE0:
                    case 0xE1:
                    case 0xE4:
                        pc = FX;
                        break;
                }
            }
            break;

        case 0xDB:
            if (irm < 0xC0 && (reg == 0 || reg == 5))
                pc = FX;
            break;

        case 0xDD:
            if (irm < 0xC0)
            {
                if (reg == 0)
                    pc = FX;
            }
            else if (irm >= 0xE0 && irm < 0xF0)
                pc = FX;
            break;

        case 0xDF:
            if (irm < 0xC0 && (reg == 0 || reg == 5))
                pc = FX;
            break;

        case 0xFE:
            if (reg == 0 || reg == 1)           // INC/DEC EA
                pc = UV;
            break;
        case 0xFF:
            if (reg == 0 || reg == 1)           // INC/DEC EA
                pc = UV;
            else if (reg == 2 || reg == 4)      // CALL/JMP near ptr EA
                pc = PE|PV;
            else if (reg == 6 && mod == 3)      // PUSH reg
                pc = PE | UV;
            break;
    }
    if (c->Iflags & CFPREFIX && pc == UV)       // if prefix byte
        pc = PU;
    return pc;
}

/******************************************
 * For an instruction, determine what is read
 * and what is written, and what is used for addressing.
 * Determine operand size if EA (larger is ok).
 */

STATIC void getinfo(Cinfo *ci,code *c)
{
    memset(ci,0,sizeof(Cinfo));
    if (!c)
        return;
    ci->c = c;

    if (PRO)
    {
        ci->uops = uops(c);
        ci->isz = calccodsize(c);
    }
    else
        ci->pair = pair_class(c);

    unsigned char op;
    unsigned char op2;
    unsigned char irm,mod,reg,rm;
    unsigned a32;
    int pc;
    unsigned r,w;
    int sz = I32 ? 4 : 2;

    ci->r = 0;
    ci->w = 0;
    ci->a = 0;
    op = c->Iop & 0xFF;
    if ((c->Iop & 0xFF00) == 0x0F00)
        op = 0x0F;
    //printf("\tgetinfo %x, op %x \n",c,op);
    pc = pentcycl[op];
    a32 = I32;
    if (c->Iflags & CFaddrsize)
        a32 ^= 1;
    if (c->Iflags & CFopsize)
        sz ^= 2 | 4;
    irm = c->Irm;
    mod = (irm >> 6) & 3;
    reg = (irm >> 3) & 7;
    rm = irm & 7;

    r = oprw[op][0];
    w = oprw[op][1];

    switch (op)
    {
        case 0x50:
        case 0x51:
        case 0x52:
        case 0x53:
        case 0x55:
        case 0x56:
        case 0x57:                              // PUSH reg
            ci->flags |= CIFLpush;
        case 0x54:                              // PUSH ESP
        case 0x6A:                              // PUSH imm8
        case 0x68:                              // PUSH imm
        case 0x0E:
        case 0x16:
        case 0x1E:
        case 0x06:
        case 0x9C:
        Lpush:
            ci->spadjust = -sz;
            ci->a |= mSP;
            break;

        case 0x58:
        case 0x59:
        case 0x5A:
        case 0x5B:
        case 0x5C:
        case 0x5D:
        case 0x5E:
        case 0x5F:                              // POP reg
        case 0x1F:
        case 0x07:
        case 0x17:
        case 0x9D:                              // POPF
        Lpop:
            ci->spadjust = sz;
            ci->a |= mSP;
            break;

        case 0x80:
            if (reg == 7)                       // CMP
                c->Iflags |= CFpsw;
            r = B | grprw[0][reg][0];           // Grp 1 (byte)
            w = B | grprw[0][reg][1];
            break;

        case 0x81:
        case 0x83:
            if (reg == 7)                       // CMP
                c->Iflags |= CFpsw;
            else if (irm == modregrm(3,0,SP))   // ADD ESP,imm
            {
                assert(c->IFL2 == FLconst);
                ci->spadjust = (op == 0x81) ? c->IEV2.Vint : (signed char)c->IEV2.Vint;
            }
            else if (irm == modregrm(3,5,SP))   // SUB ESP,imm
            {
                assert(c->IFL2 == FLconst);
                ci->spadjust = (op == 0x81) ? -c->IEV2.Vint : -(signed char)c->IEV2.Vint;
            }
            r = grprw[0][reg][0];               // Grp 1
            w = grprw[0][reg][1];
            break;

        case 0x8F:
            if (reg == 0)                       // POP rm
                goto Lpop;
            break;

        case 0xA0:
        case 0xA1:
        case 0xA2:
        case 0xA3:
            // Fake having an EA to simplify code in conflict()
            ci->flags |= CIFLea;
            ci->reg = 0;
            ci->sibmodrm = a32 ? modregrm(0,0,5) : modregrm(0,0,6);
            c->IFL1 = c->IFL2;
            c->IEV1 = c->IEV2;
            break;

        case 0xC2:
        case 0xC3:
        case 0xCA:
        case 0xCB:                              // RET
            ci->a |= mSP;
            break;

        case 0xE8:
            if (c->Iflags & CFclassinit)        // call to __j_classinit
            {   r = 0;
                w = F;
#if CLASSINIT2
                ci->pair = UV;                  // it is patched to CMP EAX,0
#else
                ci->pair = NP;
#endif
            }
            break;

        case 0xF6:
            r = grprw[3][reg][0];               // Grp 3, byte version
            w = grprw[3][reg][1];
            break;

        case 0xF7:
            r = grprw[1][reg][0];               // Grp 3
            w = grprw[1][reg][1];
            break;

        case 0x0F:
            op2 = c->Iop & 0xFF;
            if ((op2 & 0xF0) == 0x80)           // if Jxx instructions
            {
                ci->r = F | N;
                ci->w = N;
                goto Lret;
            }
            ci->r = N;
            ci->w = N;          // copout for now
            goto Lret;

        case 0xD7:                              // XLAT
            ci->a = mAX | mBX;
            break;

        case 0xFF:
            r = grprw[2][reg][0];               // Grp 5
            w = grprw[2][reg][1];
            if (reg == 6)                       // PUSH rm
                goto Lpush;
            break;

        case 0x38:
        case 0x39:
        case 0x3A:
        case 0x3B:
        case 0x3C:                              // CMP AL,imm8
        case 0x3D:                              // CMP EAX,imm32
            // For CMP opcodes, always test for flags
            c->Iflags |= CFpsw;
            break;

        case ESCAPE:
            if (c->Iop == (ESCAPE | ESCadjfpu))
                ci->fpuadjust = c->IEV1.Vint;
            break;

        case 0xD0:
        case 0xD1:
        case 0xD2:
        case 0xD3:
        case 0xC0:
        case 0xC1:
            if (reg == 2 || reg == 3)           // if RCL or RCR
                c->Iflags |= CFpsw;             // always test for flags
            break;

        case 0xD8:
        case 0xD9:
        case 0xDA:
        case 0xDB:
        case 0xDC:
        case 0xDD:
        case 0xDE:
        case 0xDF:
            if (irm < 0xC0)
            {   r = grpf1[op - 0xD8][reg][0];
                w = grpf1[op - 0xD8][reg][1];
                switch (op)
                {
                    case 0xD8:
                        if (reg == 3)           // if FCOMP
                            ci->fpuadjust = -1;
                        else
                            ci->fp_op = FPfop;
                        break;

                    case 0xD9:
                        if (reg == 0)           // if FLD float
                        {   ci->fpuadjust = 1;
                            ci->fp_op = FPfld;
                        }
                        else if (reg == 3)      // if FSTP float
                        {   ci->fpuadjust = -1;
                            ci->fp_op = FPfstp;
                        }
                        else if (reg == 5 || reg == 7)
                            sz = 2;
                        else if (reg == 4 || reg == 6)
                            sz = 28;
                        break;
                    case 0xDA:
                        if (reg == 3)           // if FICOMP
                            ci->fpuadjust = -1;
                        break;
                    case 0xDB:
                        if (reg == 0 || reg == 5)
                        {   ci->fpuadjust = 1;
                            ci->fp_op = FPfld;  // FILD / FLD long double
                        }
                        if (reg == 3 || reg == 7)
                            ci->fpuadjust = -1;
                        if (reg == 7)
                            ci->fp_op = FPfstp; // FSTP long double
                        if (reg == 5 || reg == 7)
                            sz = 10;
                        break;
                    case 0xDC:
                        sz = 8;
                        if (reg == 3)           // if FCOMP
                            ci->fpuadjust = -1;
                        else
                            ci->fp_op = FPfop;
                        break;
                    case 0xDD:
                        if (reg == 0)           // if FLD double
                        {   ci->fpuadjust = 1;
                            ci->fp_op = FPfld;
                        }
                        if (reg == 3)           // if FSTP double
                        {   ci->fpuadjust = -1;
                            ci->fp_op = FPfstp;
                        }
                        if (reg == 7)
                            sz = 2;
                        else if (reg == 4 || reg == 6)
                            sz = 108;
                        else
                            sz = 8;
                        break;
                    case 0xDE:
                        sz = 2;
                        if (reg == 3)           // if FICOMP
                            ci->fpuadjust = -1;
                        break;
                    case 0xDF:
                        sz = 2;
                        if (reg == 4 || reg == 6)
                            sz = 10;
                        else if (reg == 5 || reg == 7)
                            sz = 8;
                        if (reg == 0 || reg == 4 || reg == 5)
                            ci->fpuadjust = 1;
                        else if (reg == 3 || reg == 6 || reg == 7)
                            ci->fpuadjust = -1;
                        break;
                }
                break;
            }
            else if (op == 0xDE)
            {   ci->fpuadjust = -1;             // pop versions of Fop's
                if (irm == 0xD9)
                    ci->fpuadjust = -2;         // FCOMPP
            }

            // Most floating point opcodes aren't staged, but are
            // sent right through, in order to make use of the large
            // latencies with floating point instructions.
            if (ci->fp_op == FPfld ||
                (op == 0xD9 && (irm & 0xF8) == 0xC0))
                ;                               // FLD ST(i)
            else
                ci->flags |= CIFLnostage;

            switch (op)
            {
                case 0xD8:
                    r = S;
                    w = C;
                    if ((irm & ~7) == 0xD0)
                        w |= S;
                    break;
                case 0xD9:
                    // FCHS or FABS or FSQRT
                    if (irm == 0xE0 || irm == 0xE1 || irm == 0xFA)
                        ci->fp_op = FPfop;
                    r = S;
                    w = S|C;
                    break;
                case 0xDA:
                    if (irm == 0xE9)    // FUCOMPP
                    {   r = S;
                        w = S|C;
                        break;
                    }
                    break;
                case 0xDB:
                    if (irm == 0xE2)    // FCLEX
                    {   r = 0;
                        w = C;
                        break;
                    }
                    if (irm == 0xE3)    // FINIT
                    {   r = 0;
                        w = S|C;
                        break;
                    }
                    break;
                case 0xDC:
                case 0xDE:
                    if ((irm & 0xF0) != 0xD0)
                    {   r = S;
                        w = S|C;
                        break;
                    }
                    break;
                case 0xDD:
                    // Not entirely correct, but conservative
                    r = S;
                    w = S|C;
                    break;
                case 0xDF:
                    if (irm == 0xE0)    // FSTSW AX
                    {   r = C;
                        w = mAX;
                        break;
                    }
                    break;
            }
            break;
#if DEBUG
        default:
            //printf("\t\tNo special case\n");
            break;
#endif
    }

    if ((r | w) & B)                            // if byte operation
        sz = 1;                                 // operand size is 1

    ci->r = r & ~(R | EA);
    ci->w = w & ~(R | EA);
    if (r & R)
        ci->r |= mask[(r & B) ? (reg & 3) : reg];
    if (w & R)
        ci->w |= mask[(w & B) ? (reg & 3) : reg];

    // OR in bits for EA addressing mode
    if ((r | w) & EA)
    {   unsigned char sib;

        sib = 0;
        switch (mod)
        {
            case 0:
                if (a32)
                {
                    if (rm == 4)
                    {   sib = c->Isib;
                        if ((sib & modregrm(0,7,0)) != modregrm(0,4,0))
                            ci->a |= mask[(sib >> 3) & 7];      // index register
                        if ((sib & 7) != 5)
                            ci->a |= mask[sib & 7];             // base register
                    }
                    else if (rm != 5)
                        ci->a |= mask[rm];
                }
                else
                {   static unsigned char ea16[8] = {mBX|mSI,mBX|mDI,mBP|mSI,mBP|mDI,mSI,mDI,0,mBX};
                    ci->a |= ea16[rm];
                }
                goto Lmem;

            case 1:
            case 2:
                if (a32)
                {
                    if (rm == 4)
                    {   sib = c->Isib;
                        if ((sib & modregrm(0,7,0)) != modregrm(0,4,0))
                            ci->a |= mask[(sib >> 3) & 7];      // index register
                        ci->a |= mask[sib & 7];                 // base register
                    }
                    else
                        ci->a |= mask[rm];
                }
                else
                {   static unsigned char ea16[8] = {mBX|mSI,mBX|mDI,mBP|mSI,mBP|mDI,mSI,mDI,mBP,mBX};
                    ci->a |= ea16[rm];
                }

            Lmem:
                if (r & EA)
                    ci->r |= mMEM;
                if (w & EA)
                    ci->w |= mMEM;
                ci->flags |= CIFLea;
                break;

            case 3:
                if (r & EA)
                    ci->r |= mask[(r & B) ? (rm & 3) : rm];
                if (w & EA)
                    ci->w |= mask[(w & B) ? (rm & 3) : rm];
                break;
        }
        // Adjust sibmodrm so that addressing modes can be compared simply
        irm &= modregrm(3,0,7);
        if (a32)
        {
            if (irm != modregrm(0,0,5))
            {
                switch (mod)
                {   case 0:
                        if ((sib & 7) != 5)     // if not disp32[index]
                        {   c->IFL1 = FLconst;
                            c->IEVpointer1 = 0;
                            irm |= 0x80;
                        }
                        break;
                    case 1:
                        c->IEVpointer1 = (signed char) c->IEVpointer1;
                        irm = modregrm(2,0,rm);
                        break;
                }
            }
        }
        else
        {
            if (irm != modregrm(0,0,6))
            {
                switch (mod)
                {   case 0:
                        c->IFL1 = FLconst;
                        c->IEVpointer1 = 0;
                        irm |= 0x80;
                        break;
                    case 1:
                        c->IEVpointer1 = (signed char) c->IEVpointer1;
                        irm = modregrm(2,0,rm);
                        break;
                }
            }
        }

        ci->r |= ci->a;
        ci->reg = reg;
        ci->sibmodrm = (sib << 8) | irm;
    }
Lret:
    if (ci->w & mSP)                    // if stack pointer is modified
        ci->w |= mMEM;                  // then we are implicitly writing to memory
    if (op == 0x8D)                     // if LEA
        ci->r &= ~mMEM;                 // memory is not actually read
    ci->sz = sz;
#if DEBUG
    //printf("\t\t"); ci->print();
#endif
}

/******************************************
 * Determine if two instructions can pair.
 * Assume that in general, cu can pair in the U pipe and cv in the V.
 * Look for things like register contentions.
 * Input:
 *      cu      instruction for U pipe
 *      cv      instruction for V pipe
 * Returns:
 *      !=0 if they can pair
 */

STATIC int pair_test(Cinfo *cu,Cinfo *cv)
{   unsigned pcu;
    unsigned pcv;
    unsigned r1,w1;
    unsigned r2,w2;
    unsigned x;

    pcu = cu->pair;
    if (!(pcu & PU))
    {
        // See if pairs with FXCH and cv is FXCH
        if (pcu & FX && cv->c->Iop == 0xD9 && (cv->c->Irm & ~7) == 0xC8)
            goto Lpair;
        goto Lnopair;
    }
    pcv = cv->pair;
    if (!(pcv & PV))
        goto Lnopair;

    r1 = cu->r;
    w1 = cu->w;
    r2 = cv->r;
    w2 = cv->w;

    x = w1 & (r2 | w2) & ~(F|mMEM);     // register contention
    if (x &&                            // if register contention
        !(x == mSP && pcu & pcv & PE)   // and not exception
       )
        goto Lnopair;

    // Look for flags contention
    if (w1 & r2 & F && !(pcv & PF))
        goto Lnopair;

Lpair:
    return 1;

Lnopair:
    return 0;
}

/******************************************
 * Determine if two instructions have an AGI or register contention.
 * Returns:
 *      !=0 if they have an AGI
 */

STATIC int pair_agi(Cinfo *c1,Cinfo *c2)
{   unsigned x;

    x = c1->w & c2->a;
    return x && !(x == mSP && c1->pair & c2->pair & PE);
}

/********************************************
 * Determine if three instructions can decode simultaneously
 * in Pentium Pro and Pentium II.
 * Input:
 *      c0,c1,c2        candidates for decoders 0,1,2
 *                      c2 can be NULL
 * Returns:
 *      !=0 if they can decode simultaneously
 */

STATIC int triple_test(Cinfo *c0,Cinfo *c1,Cinfo *c2)
{   int c2isz;

    assert(c0);
    if (!c1)
        goto Lnopair;
    c2isz = c2 ? c2->isz : 0;
    if (c0->isz > 7 || c1->isz > 7 || c2isz > 7 ||
        c0->isz + c1->isz + c2isz > 16)
        goto Lnopair;

    // 4-1-1 decode
    if (c1->uops > 1 ||
        (c2 && c2->uops > 1))
        goto Lnopair;

Lpair:
    return 1;

Lnopair:
    return 0;
}

/********************************************
 * Get next instruction worth looking at for scheduling.
 * Returns:
 *      NULL    no more instructions
 */

STATIC code * cnext(code *c)
{
    while (1)
    {
        c = code_next(c);
        if (!c)
            break;
        if (c->Iflags & (CFtarg | CFtarg2))
            break;
        if (!(c->Iop == NOP ||
              c->Iop == (ESCAPE | ESClinnum)))
            break;
    }
    return c;
}

/******************************************
 * Instruction scheduler.
 * Input:
 *      c               list of instructions to schedule
 *      scratch         scratch registers we can use
 * Returns:
 *      revised list of scheduled instructions
 */

///////////////////////////////////
// Determine if c1 and c2 are swappable.
// c1 comes before c2.
// If they do not conflict
//      return 0
// If they do conflict
//      return 0x100 + delay_clocks
// Input:
//      fpsched         if 1, then adjust fxch_pre and fxch_post to swap,
//                      then return 0
//                      if 2, then adjust ci1 as well as ci2

STATIC int conflict(Cinfo *ci1,Cinfo *ci2,int fpsched)
{
    code *c1;
    code *c2;
    unsigned r1,w1,a1;
    unsigned r2,w2,a2;
    int sz1,sz2;
    int i = 0;
    int delay_clocks;

    c1 = ci1->c;
    c2 = ci2->c;

    //printf("conflict %x %x\n",c1,c2);

    r1 = ci1->r;
    w1 = ci1->w;
    a1 = ci1->a;
    sz1 = ci1->sz;

    r2 = ci2->r;
    w2 = ci2->w;
    a2 = ci2->a;
    sz2 = ci2->sz;

    //printf("r1 %lx w1 %lx a1 %lx sz1 %x\n",r1,w1,a1,sz1);
    //printf("r2 %lx w2 %lx a2 %lx sz2 %x\n",r2,w2,a2,sz2);

    if ((c1->Iflags | c2->Iflags) & CFvolatile)
        goto Lconflict;

    // Determine if we should handle FPU register conflicts separately
    //if (fpsched) printf("fp_op %d,%d:\n",ci1->fp_op,ci2->fp_op);
    if (fpsched && ci1->fp_op && ci2->fp_op)
    {
        w1 &= ~(S|C);
        r1 &= ~(S|C);
        w2 &= ~(S|C);
        r2 &= ~(S|C);
    }
    else
        fpsched = 0;

    if ((r1 | r2) & N)
    {
        goto Lconflict;
    }

#if 0
    if (c1->Iop == 0xFF && c2->Iop == 0x8B)
    {   c1->print(); c2->print(); i = 1;
        printf("r1=%lx, w1=%lx, a1=%lx, sz1=%d, r2=%lx, w2=%lx, a2=%lx, sz2=%d\n",r1,w1,a1,sz1,r2,w2,a2,sz2);
    }
#endif
L1:
    if (w1 & r2 || (r1 | w1) & w2)
    {   unsigned char ifl1,ifl2;

if (i) printf("test\n");

#if 0
if (c1->IFL1 != c2->IFL1) printf("t1\n");
if ((c1->Irm & modregrm(3,0,7)) != (c2->Irm & modregrm(3,0,7))) printf("t2\n");
if ((issib(c1->Irm) && c1->Isib != c2->Isib)) printf("t3\n");
if (c1->IEVpointer1 + sz1 <= c2->IEVpointer1) printf("t4\n");
if (c2->IEVpointer1 + sz2 <= c1->IEVpointer1) printf("t5\n");
#endif

#if 1   // make sure CFpsw is reliably set
        if (w1 & w2 & F &&              // if both instructions write to flags
            w1 != F &&
            w2 != F &&
            !((r1 | r2) & F) &&         // but neither instruction reads them
            !((c1->Iflags | c2->Iflags) & CFpsw))       // and we don't care about flags
        {
            w1 &= ~F;
            w2 &= ~F;                   // remove conflict
            goto L1;                    // and try again
        }
#endif
        // If other than the memory reference is a conflict
        if (w1 & r2 & ~mMEM || (r1 | w1) & w2 & ~mMEM)
        {   if (i) printf("\t1\n");
            if (i) printf("r1=%x, w1=%x, a1=%x, sz1=%d, r2=%x, w2=%x, a2=%x, sz2=%d\n",r1,w1,a1,sz1,r2,w2,a2,sz2);
            goto Lconflict;
        }

        // If referring to distinct types, then no dependency
        if (c1->Irex && c2->Irex && c1->Irex != c2->Irex)
            goto Lswap;

        ifl1 = c1->IFL1;
        ifl2 = c2->IFL1;

        // Special case: Allow indexed references using registers other than
        // ESP and EBP to be swapped with PUSH instructions
        if (((c1->Iop & ~7) == 0x50 ||          // PUSH reg
             c1->Iop == 0x6A ||                 // PUSH imm8
             c1->Iop == 0x68 ||                 // PUSH imm16/imm32
             (c1->Iop == 0xFF && ci1->reg == 6) // PUSH EA
            ) &&
            ci2->flags & CIFLea && !(a2 & mSP) &&
            !(a2 & mBP && (long)c2->IEVpointer1 < 0)
           )
        {
            if (c1->Iop == 0xFF)
            {
                if (!(w2 & mMEM))
                    goto Lswap;
            }
            else
                goto Lswap;
        }

        // Special case: Allow indexed references using registers other than
        // ESP and EBP to be swapped with PUSH instructions
        if (((c2->Iop & ~7) == 0x50 ||          // PUSH reg
             c2->Iop == 0x6A ||                 // PUSH imm8
             c2->Iop == 0x68 ||                 // PUSH imm16/imm32
             (c2->Iop == 0xFF && ci2->reg == 6) // PUSH EA
            ) &&
            ci1->flags & CIFLea && !(a1 & mSP) &&
            !(a2 & mBP && (long)c2->IEVpointer1 < 0)
           )
        {
            if (c2->Iop == 0xFF)
            {
                if (!(w1 & mMEM))
                    goto Lswap;
            }
            else
                goto Lswap;
        }

        // If not both an EA addressing mode, conflict
        if (!(ci1->flags & ci2->flags & CIFLea))
        {   if (i) printf("\t2\n");
            goto Lconflict;
        }

        if (ci1->sibmodrm == ci2->sibmodrm)
        {   if (ifl1 != ifl2)
                goto Lswap;
            switch (ifl1)
            {
                case FLconst:
                    if (c1->IEV1.Vint != c2->IEV1.Vint &&
                        (c1->IEV1.Vint + sz1 <= c2->IEV1.Vint ||
                         c2->IEV1.Vint + sz2 <= c1->IEV1.Vint))
                        goto Lswap;
                    break;
                case FLdatseg:
                    if (c1->IEVseg1 != c2->IEVseg1 ||
                        c1->IEV1.Vint + sz1 <= c2->IEV1.Vint ||
                        c2->IEV1.Vint + sz2 <= c1->IEV1.Vint)
                        goto Lswap;
                    break;
            }
        }

        if ((c1->Iflags | c2->Iflags) & CFunambig &&
            (ifl1 != ifl2 ||
             ci1->sibmodrm != ci2->sibmodrm ||
             (c1->IEV1.Vint != c2->IEV1.Vint &&
              (c1->IEV1.Vint + sz1 <= c2->IEV1.Vint ||
               c2->IEV1.Vint + sz2 <= c1->IEV1.Vint)
             )
            )
           )
        {
            // Assume that [EBP] and [ESP] can point to the same location
            if (((a1 | a2) & (mBP | mSP)) == (mBP | mSP))
                goto Lconflict;
            goto Lswap;
        }

        if (i) printf("\t3\n");
        goto Lconflict;
    }

Lswap:
    if (fpsched)
    {   unsigned char a1,b1;
        unsigned char a2,b2;

        //printf("\tfpsched %d,%d:\n",ci1->fp_op,ci2->fp_op);
        a1 = ci1->fxch_pre;
        b1 = ci1->fxch_post;
        a2 = ci2->fxch_pre;
        b2 = ci2->fxch_post;

        #define X(a,b) ((a << 8) | b)
        switch (X(ci1->fp_op,ci2->fp_op))
        {
            case X(FPfstp,FPfld):
                if (a1 || b1)
                    goto Lconflict;
                if (a2)
                    goto Lconflict;
                if (b2 == 0)
                    ci2->fxch_post++;
                else if (b2 == 1)
                {
                    ci2->fxch_pre++;
                    ci2->fxch_post++;
                }
                else
                {
                    goto Lconflict;
                }
                break;

            case X(FPfstp,FPfop):
                if (a1 || b1)
                    goto Lconflict;
                ci2->fxch_pre++;
                ci2->fxch_post++;
                break;

            case X(FPfop,FPfop):
                if (a1 == 0 && b1 == 1 && a2 == 0 && b2 == 0)
                {   ci2->fxch_pre = 1;
                    ci2->fxch_post = 1;
                    break;
                }
                if (a1 == 0 && b1 == 0 && a2 == 1 && b2 == 1)
                    break;
                goto Lconflict;

            case X(FPfop,FPfld):
                if (a1 || b1)
                    goto Lconflict;
                if (a2)
                    goto Lconflict;
                if (b2)
                    break;
                else if (fpsched == 2)
                    ci1->fxch_post = 1;
                ci2->fxch_post = 1;
                break;

            default:
                goto Lconflict;
        }
        #undef X
        //printf("\tpre = %d, post = %d\n",ci2->fxch_pre,ci2->fxch_post);
    }

    //printf("w1 = x%x, w2 = x%x\n",w1,w2);
    if (i) printf("no conflict\n\n");
    return 0;

Lconflict:
    //printf("r1=%x, w1=%x, r2=%x, w2=%x\n",r1,w1,r2,w2);
    delay_clocks = 0;

    // Determine if AGI
    if (!PRO && pair_agi(ci1,ci2))
        delay_clocks = 1;

    // Special delays for floating point
    if (fpsched)
    {   if (ci1->fp_op == FPfld && ci2->fp_op == FPfstp)
            delay_clocks = 1;
        else if (ci1->fp_op == FPfop && ci2->fp_op == FPfstp)
            delay_clocks = 3;
        else if (ci1->fp_op == FPfop && ci2->fp_op == FPfop)
            delay_clocks = 2;
    }
    else if (PRO)
    {
        // Look for partial register write stalls
        if (w1 & r2 & ALLREGS && sz1 < sz2)
            delay_clocks = 7;
    }
    else if ((w1 | r1) & (w2 | r2) & (C | S))
    {   int reg;
        int op;

        op = c1->Iop;
        reg = c1->Irm & modregrm(0,7,0);
        if (ci1->fp_op == FPfld ||
            (op == 0xD9 && (c1->Irm & 0xF8) == 0xC0)
           )
            ;                           // FLD
        else if (op == 0xD9 && (c1->Irm & 0xF8) == 0xC8)
            ;                           // FXCH
        else if (c2->Iop == 0xD9 && (c2->Irm & 0xF8) == 0xC8)
            ;                           // FXCH
        else
            delay_clocks = 3;
    }

    if (i) printf("conflict %d\n\n",delay_clocks);
    return 0x100 + delay_clocks;
}

struct Schedule
{
    #define TBLMAX      (2*3*20)        // must be divisible by both 2 and 3
                                        // (U,V pipe in Pentium, 3 decode units
                                        //  in Pentium Pro)

    Cinfo *tbl[TBLMAX];         // even numbers are U pipe, odd numbers are V
    int tblmax;                 // max number of slots used

    Cinfo cinfo[TBLMAX];
    int cinfomax;

    list_t stagelist;           // list of instructions in staging area

    int fpustackused;           // number of slots in FPU stack that are used

    void initialize(int fpustackinit);          // initialize scheduler
    int stage(code *c);         // stage instruction
    int insert(Cinfo *ci);      // insert c into schedule
    code **assemble(code **pc); // reassemble scheduled instructions
};

/******************************
 */

void Schedule::initialize(int fpustackinit)
{
    //printf("Schedule::initialize(fpustackinit = %d)\n", fpustackinit);
    memset(this,0,sizeof(Schedule));
    fpustackused = fpustackinit;
}

/******************************
 */

code **Schedule::assemble(code **pc)
{   int i;
    list_t l;
    code *c;

#ifdef DEBUG
    if (debugs) printf("assemble:\n");
#endif
    assert(!*pc);

    // Try to insert the rest of the staged instructions
    for (l = stagelist; l; l = list_next(l))
    {   Cinfo *ci;

        ci = (Cinfo *)list_ptr(l);
        if (!insert(ci))
            break;
    }

    // Get the instructions out of the schedule table
    assert((unsigned)tblmax <= TBLMAX);
    for (i = 0; i < tblmax; i++)
    {   Cinfo *ci;

        ci = tbl[i];
#ifdef DEBUG
        if (debugs)
        {
            if (PRO)
            {   static char tbl[3][4] = { "0  "," 1 ","  2" };

                if (ci)
                    printf("%s %d ",tbl[i - ((i / 3) * 3)],ci->uops);
                else
                    printf("%s   ",tbl[i - ((i / 3) * 3)]);
            }
            else
            {
                printf((i & 1) ? " V " : "U  ");
            }
            if (ci)
                ci->c->print();
            else
                printf("\n");
        }
#endif
        if (!ci)
            continue;
        fpustackused += ci->fpuadjust;
        //printf("stage()1: fpustackused = %d\n", fpustackused);
        c = ci->c;
        if (i == 0)
            c->Iflags |= CFtarg;        // by definition, first is always a jump target
        else
            c->Iflags &= ~CFtarg;       // the rest are not

        // Put in any FXCH prefix
        if (ci->fxch_pre)
        {   code *cf;
            assert(i);
            cf = gen2(NULL,0xD9,0xC8 + ci->fxch_pre);
            *pc = cf;
            pc = &code_next(cf);
        }

        *pc = c;
        do
        {
            assert(*pc != code_next(*pc));
            pc = &code_next(*pc);
        } while (*pc);

        // Put in any FXCH postfix
        if (ci->fxch_post)
        {   int j;

            for (j = i + 1; j < tblmax; j++)
            {   if (tbl[j])
                {   if (tbl[j]->fxch_pre == ci->fxch_post)
                    {
                        tbl[j]->fxch_pre = 0;           // they cancel each other out
                        goto L1;
                    }
                    break;
                }
            }
            {   code *cf;
                cf = gen2(NULL,0xD9,0xC8 + ci->fxch_post);
                *pc = cf;
                pc = &code_next(cf);
            }
        }
    L1: ;
    }

    // Just append any instructions left in the staging area
    for (; l; l = list_next(l))
    {   Cinfo *ci = (Cinfo *)list_ptr(l);
        code *c = ci->c;

#ifdef DEBUG
        if (debugs) { printf("appending: "); c->print(); }
#endif
        *pc = c;
        do
        {
            pc = &code_next(*pc);

        } while (*pc);
        fpustackused += ci->fpuadjust;
        //printf("stage()2: fpustackused = %d\n", fpustackused);
    }
    list_free(&stagelist);

    return pc;
}

/******************************
 * Insert c into scheduling table.
 * Returns:
 *      0       could not be scheduled; have to start a new one
 */

int Schedule::insert(Cinfo *ci)
{   code *c;
    int clocks;
    int i;
    int ic = 0;
    int imin;
    targ_size_t offset;
    targ_size_t vpointer;
    int movesp = 0;
    int reg2 = -1;              // avoid "may be uninitialized" warning

    //printf("insert "); ci->c->print();
    //printf("insert() %d\n", fpustackused);
    c = ci->c;
    //printf("\tc->Iop %x\n",c->Iop);
    vpointer = c->IEVpointer1;
    assert((unsigned)tblmax <= TBLMAX);
    if (tblmax == TBLMAX)               // if out of space
        goto Lnoinsert;
    if (tblmax == 0)                    // if table is empty
    {   // Just stuff it in the first slot
        i = tblmax;
        goto Linsert;
    }
    else if (c->Iflags & (CFtarg | CFtarg2))
        // Jump targets can only be first in the scheduler
        goto Lnoinsert;

    // Special case of:
    //  PUSH reg1
    //  MOV  reg2,x[ESP]
    if (c->Iop == 0x8B &&
        (c->Irm & modregrm(3,0,7)) == modregrm(1,0,4) &&
        c->Isib == modregrm(0,4,SP) &&
        c->IFL1 == FLconst &&
        ((signed char)c->IEVpointer1) >= REGSIZE
       )
    {
        movesp = 1;                     // this is a MOV reg2,offset[ESP]
        offset = (signed char)c->IEVpointer1;
        reg2 = (c->Irm >> 3) & 7;
    }


    // Start at tblmax, and back up until we get a conflict
    ic = -1;
    imin = 0;
    for (i = tblmax; i >= 0; i--)
    {   Cinfo *cit;

        cit = tbl[i];
        if (!cit)
            continue;

        // Look for special case swap
        if (movesp &&
            (cit->c->Iop & ~7) == 0x50 &&               // if PUSH reg1
            (cit->c->Iop & 7) != reg2 &&                // if reg1 != reg2
            ((signed char)c->IEVpointer1) >= -cit->spadjust
           )
        {
            c->IEVpointer1 += cit->spadjust;
            //printf("\t1, spadjust = %d, ptr = x%x\n",cit->spadjust,c->IEVpointer1);
            continue;
        }

        if (movesp &&
            cit->c->Iop == 0x83 &&
            cit->c->Irm == modregrm(3,5,SP) &&          // if SUB ESP,offset
            cit->c->IFL2 == FLconst &&
            ((signed char)c->IEVpointer1) >= -cit->spadjust
           )
        {
            //printf("\t2, spadjust = %d\n",cit->spadjust);
            c->IEVpointer1 += cit->spadjust;
            continue;
        }

        clocks = conflict(cit,ci,1);
        if (clocks)
        {   int j;

            ic = i;                     // where the conflict occurred
            clocks &= 0xFF;             // convert to delay count

            // Move forward the delay clocks
            if (clocks == 0)
                j = i + 1;
            else if (PRO)
                j = (((i + 3) / 3) * 3) + clocks * 3;
            else
            {   j = ((i + 2) & ~1) + clocks * 2;

                // It's possible we skipped over some AGI generating
                // instructions due to movesp.
                int k;
                for (k = i + 1; k < j; k++)
                {
                    if (k >= TBLMAX)
                        goto Lnoinsert;
                    if (tbl[k] && pair_agi(tbl[k],ci))
                    {
                        k = ((k + 2) & ~1) + 1;
                    }
                }
                j = k;
            }

            if (j >= TBLMAX)                    // exceed table size?
                goto Lnoinsert;
            imin = j;                           // first possible slot c can go in
            break;
        }
    }


    // Scan forward looking for a hole to put it in
    for (i = imin; i < TBLMAX; i++)
    {
        if (tbl[i])
        {
            // In case, due to movesp, we skipped over some AGI instructions
            if (!PRO && pair_agi(tbl[i],ci))
            {
                i = ((i + 2) & ~1) + 1;
                if (i >= TBLMAX)
                    goto Lnoinsert;
            }
        }
        else
        {
            if (PRO)
            {   int i0 = (i / 3) * 3;           // index of decode unit 0
                Cinfo *ci0;

                assert(((TBLMAX / 3) * 3) == TBLMAX);
                switch (i - i0)
                {
                    case 0:                     // i0 can handle any instruction
                        goto Linsert;
                    case 1:
                        ci0 = tbl[i0];
                        if (ci->uops > 1)
                        {
                            if (i0 >= imin && ci0->uops == 1)
                                goto L1;
                            i++;
                            break;
                        }
                        if (triple_test(ci0,ci,tbl[i0 + 2]))
                            goto Linsert;
                        break;
                    case 2:
                        ci0 = tbl[i0];
                        if (ci->uops > 1)
                        {
                            if (i0 >= imin && ci0->uops == 1)
                            {
                                if (i >= tblmax)
                                {   if (i + 1 >= TBLMAX)
                                        goto Lnoinsert;
                                    tblmax = i + 1;
                                }
                                tbl[i0 + 2] = tbl[i0 + 1];
                                tbl[i0 + 1] = ci0;
                                i = i0;
                                goto Linsert;
                            }
                            break;
                        }
                        if (triple_test(ci0,tbl[i0 + 1],ci))
                            goto Linsert;
                        break;
                    default:
                        assert(0);
                }
            }
            else
            {
                assert((TBLMAX & 1) == 0);
                if (i & 1)                      // if V pipe
                {
                    if (pair_test(tbl[i - 1],ci))
                    {
                        goto Linsert;
                    }
                    else if (i > imin && pair_test(ci,tbl[i - 1]))
                    {
                L1:
                        tbl[i] = tbl[i - 1];
                        if (i >= tblmax)
                            tblmax = i + 1;
                        i--;
                        //printf("\tswapping with x%02x\n",tbl[i + 1]->c->Iop);
                        goto Linsert;
                    }
                }
                else                    // will always fit in U pipe
                {
                    assert(!tbl[i + 1]);        // because V pipe should be empty
                    goto Linsert;
                }
            }
        }
    }

Lnoinsert:
    //printf("\tnoinsert\n");
    c->IEVpointer1 = vpointer;  // reset to original value
    return 0;

Linsert:
    // Insert at location i
    assert(i < TBLMAX);
    assert(tblmax <= TBLMAX);
    tbl[i] = ci;
    //printf("\tinsert at location %d\n",i);

    // If it's a scheduled floating point code, we have to adjust
    // the FXCH values
    if (ci->fp_op)
    {   int j;

        ci->fxch_pre = 0;
        ci->fxch_post = 0;                      // start over again

        int fpu = fpustackused;
        for (j = 0; j < tblmax; j++)
        {
            if (tbl[j])
            {
                fpu += tbl[j]->fpuadjust;
                if (fpu >= 8)                   // if FPU stack overflow
                {   tbl[i] = NULL;
                    //printf("fpu stack overflow\n");
                    goto Lnoinsert;
                }
            }
        }

        for (j = tblmax; j > i; j--)
        {
            if (j < TBLMAX && tbl[j])
                conflict(tbl[j],ci,2);
        }
    }

    if (movesp)
    {   // Adjust [ESP] offsets
        int j;

        //printf("\tic = %d, inserting at %d\n",ic,i);
        assert((unsigned)tblmax <= TBLMAX);
        for (j = ic + 1; j < i; j++)
        {   Cinfo *cit;

            cit = tbl[j];
            if (cit)
            {
                c->IEVpointer1 -= cit->spadjust;
                //printf("\t3, spadjust = %d, ptr = x%x\n",cit->spadjust,c->IEVpointer1);
            }
        }
    }
    if (i >= tblmax)
        tblmax = i + 1;

    // Now do a hack. Look back at immediately preceding instructions,
    // and see if we can swap with a push.
    if (0 && movesp)
    {   int j;

        while (1)
        {
            for (j = 1; i > j; j++)
                if (tbl[i - j])
                    break;

            if (i >= j && tbl[i - j] &&
                   (tbl[i - j]->c->Iop & ~7) == 0x50 &&       // if PUSH reg1
                   (tbl[i - j]->c->Iop & 7) != reg2 &&  // if reg1 != reg2
                   (signed char)c->IEVpointer1 >= REGSIZE)
            {
                //printf("\t-4 prec, i-j=%d, i=%d\n",i-j,i);
                assert((unsigned)i < TBLMAX);
                assert((unsigned)(i - j) < TBLMAX);
                tbl[i] = tbl[i - j];
                tbl[i - j] = ci;
                i -= j;
                c->IEVpointer1 -= REGSIZE;
            }
            else
                break;
        }
    }

    //printf("\tinsert\n");
    return 1;
}


/******************************
 * Insert c into staging area.
 * Returns:
 *      0       could not be scheduled; have to start a new one
 */

int Schedule::stage(code *c)
{   Cinfo *ci;
    list_t l;
    list_t ln;
    int agi;

    //printf("stage: "); c->print();
    if (cinfomax == TBLMAX)             // if out of space
        goto Lnostage;
    ci = &cinfo[cinfomax++];
    getinfo(ci,c);

    if (c->Iflags & (CFtarg | CFtarg2 | CFvolatile))
    {
        // Insert anything in stagelist
        for (l = stagelist; l; l = ln)
        {   Cinfo *cs;

            ln = list_next(l);
            cs = (Cinfo *)list_ptr(l);
            if (!insert(cs))
                return 0;
            list_subtract(&stagelist,cs);
        }
        return insert(ci);
    }

    // Look through stagelist, and insert any AGI conflicting instructions
    agi = 0;
    for (l = stagelist; l; l = ln)
    {   Cinfo *cs;

        ln = list_next(l);
        cs = (Cinfo *)list_ptr(l);
        if (pair_agi(cs,ci))
        {
            if (!insert(cs))
                goto Lnostage;
            list_subtract(&stagelist,cs);
            agi = 1;                    // we put out an AGI
        }
    }

    // Look through stagelist, and insert any other conflicting instructions
    for (l = stagelist; l; l = ln)
    {   Cinfo *cs;

        ln = list_next(l);
        cs = (Cinfo *)list_ptr(l);
        if (conflict(cs,ci,0) &&                // if conflict
            !(cs->flags & ci->flags & CIFLpush))
        {
            if (cs->spadjust)
            {
                // We need to insert all previous adjustments to ESP
                list_t la,lan;

                for (la = stagelist; la != l; la = lan)
                {   Cinfo *ca;

                    lan = list_next(la);
                    ca = (Cinfo *)list_ptr(la);
                    if (ca->spadjust)
                    {   if (!insert(ca))
                            goto Lnostage;
                        list_subtract(&stagelist,ca);
                    }
                }
            }

            if (!insert(cs))
                goto Lnostage;
            list_subtract(&stagelist,cs);
        }
    }

    // If floating point opcode, don't stage it, send it right out
    if (!agi && ci->flags & CIFLnostage)
    {
        if (!insert(ci))
            goto Lnostage;
        return 1;
    }

    list_append(&stagelist,ci);         // append to staging list
    return 1;

Lnostage:
    return 0;
}

/********************************************
 * Snip off tail of instruction sequence.
 * Returns:
 *      next instruction (the tail) or
 *      NULL for no more instructions
 */

STATIC code * csnip(code *c)
{   code **pc;
    unsigned iflags;

    if (c)
    {   iflags = c->Iflags & CFclassinit;
        while (1)
        {
            pc = &code_next(c);
            c = *pc;
            if (!c)
                break;
            if (c->Iflags & (CFtarg | CFtarg2))
                break;
            if (!(c->Iop == NOP ||
                  c->Iop == (ESCAPE | ESClinnum) ||
                  c->Iflags & iflags))
                break;
        }
        *pc = NULL;
    }
    return c;
}


/******************************
 * Schedule Pentium instructions,
 * based on Steve Russell's algorithm.
 */

code *schedule(code *c,regm_t scratch)
{
    code *cresult = NULL;
    code **pctail = &cresult;
    Schedule sch;

    sch.initialize(0);                  // initialize scheduling table
    while (c)
    {
        if ((c->Iop == NOP ||
             ((c->Iop & ESCAPEmask) == ESCAPE && c->Iop != (ESCAPE | ESCadjfpu)) ||
             c->Iflags & CFclassinit) &&
            !(c->Iflags & (CFtarg | CFtarg2)))
        {   code *cn;

            // Just append this instruction to pctail and go to the next one
            *pctail = c;
            cn = code_next(c);
            code_next(c) = NULL;
            pctail = &code_next(c);
            c = cn;
            continue;
        }

        //printf("init\n");
        sch.initialize(sch.fpustackused);       // initialize scheduling table

        while (c)
        {
            //printf("insert %p\n",c);
            if (!sch.stage(c))          // store c in scheduling table
                break;
            c = csnip(c);
        }

        //printf("assem %d\n",sch.tblmax);
        pctail = sch.assemble(pctail);  // reassemble instruction stream
    }

    return cresult;
}

/**************************************************************************/

/********************************************
 * Replace any occurrence of r1 in EA with r2.
 */

STATIC void repEA(code *c,unsigned r1,unsigned r2)
{
    unsigned mod,reg,rm;
    unsigned rmn;

    rmn = c->Irm;
    mod = rmn & 0xC0;
    reg = rmn & modregrm(0,7,0);
    rm =  rmn & 7;

    if (mod == 0xC0 && rm == r1)
        ; //c->Irm = mod | reg | r2;
    else if (is32bitaddr(I32,c->Iflags) &&
        // If not disp32
        (rmn & modregrm(3,0,7)) != modregrm(0,0,5))
    {
        if (rm == 4)
        {   // SIB byte addressing
            unsigned sib;
            unsigned base;
            unsigned index;

            sib = c->Isib;
            base = sib & 7;
            index = (sib >> 3) & 7;
            if (base == r1 &&
                !(r1 == 5 && mod == 0) &&
                !(r2 == 5 && mod == 0)
               )
                base = r2;
            if (index == r1)
                index = r2;
            c->Isib = (sib & 0xC0) | (index << 3) | base;
        }
        else if (rm == r1)
        {
            if (r1 == BP && r2 == SP)
            {   // Replace [EBP] with [ESP]
                c->Irm = mod | reg | 4;
                c->Isib = modregrm(0,4,SP);
            }
            else if (r2 == BP && mod == 0)
            {
                c->Irm = modregrm(1,0,0) | reg | r2;
                c->IFL1 = FLconst;
                c->IEV1.Vint = 0;
            }
            else
                c->Irm = mod | reg | r2;
        }
    }
}

/******************************************
 * Instruction scheduler.
 * Input:
 *      c               list of instructions to schedule
 *      scratch         scratch registers we can use
 * Returns:
 *      revised list of scheduled instructions
 */

/******************************************
 * Swap c1 and c2.
 * c1 comes before c2.
 * Swap in place to not disturb addresses of jmp targets
 */

STATIC void code_swap(code *c1,code *c2)
{   code cs;

    // Special case of:
    //  PUSH reg1
    //  MOV  reg2,x[ESP]
    //printf("code_swap(%x, %x)\n",c1,c2);
    if ((c1->Iop & ~7) == 0x50 &&
        c2->Iop == 0x8B &&
        (c2->Irm & modregrm(3,0,7)) == modregrm(1,0,4) &&
        c2->Isib == modregrm(0,4,SP) &&
        c2->IFL1 == FLconst &&
        ((signed char)c2->IEVpointer1) >= REGSIZE &&
        (c1->Iop & 7) != ((c2->Irm >> 3) & 7)
       )
        c2->IEVpointer1 -= REGSIZE;


    cs = *c2;
    *c2 = *c1;
    *c1 = cs;
    // Retain original CFtarg
    c1->Iflags = (c1->Iflags & ~(CFtarg | CFtarg2)) | (c2->Iflags & (CFtarg | CFtarg2));
    c2->Iflags = (c2->Iflags & ~(CFtarg | CFtarg2)) | (cs.Iflags & (CFtarg | CFtarg2));

    c1->next = c2->next;
    c2->next = cs.next;
}

code *peephole(code *cstart,regm_t scratch)
{
    // Look for cases of:
    //  MOV r1,r2
    //  OP ?,r1
    // we can replace with:
    //  MOV r1,r2
    //  OP ?,r2
    // to improve pairing
    code *c;
    code *c1;
    unsigned r1,r2;
    unsigned mod,reg,rm;

    //printf("peephole\n");
    for (c = cstart; c; c = c1)
    {
        unsigned char rmn;

        //c->print();
        c1 = cnext(c);
    Ln:
        if (!c1)
            break;
        if (c1->Iflags & (CFtarg | CFtarg2))
            continue;

        // Do:
        //      PUSH    reg
        if (I32 && (c->Iop & ~7) == 0x50)
        {   unsigned reg = c->Iop & 7;

            //  MOV     [ESP],reg       =>      NOP
            if (c1->Iop == 0x8B &&
                c1->Irm == modregrm(0,reg,4) &&
                c1->Isib == modregrm(0,4,SP))
            {   c1->Iop = NOP;
                continue;
            }

            //  PUSH    [ESP]           =>      PUSH    reg
            if (c1->Iop == 0xFF &&
                c1->Irm == modregrm(0,6,4) &&
                c1->Isib == modregrm(0,4,SP))
            {   c1->Iop = 0x50 + reg;
                continue;
            }

            //  CMP     [ESP],imm       =>      CMP     reg,i,,
            if (c1->Iop == 0x83 &&
                c1->Irm == modregrm(0,7,4) &&
                c1->Isib == modregrm(0,4,SP))
            {   c1->Irm = modregrm(3,7,reg);
                if (c1->IFL2 == FLconst && (signed char)c1->IEV2.Vuns == 0)
                {   // to TEST reg,reg
                    c1->Iop = (c1->Iop & 1) | 0x84;
                    c1->Irm = modregrm(3,reg,reg);
                }
                continue;
            }

        }

        // Do:
        //      MOV     reg,[ESP]       =>      PUSH    reg
        //      ADD     ESP,4           =>      NOP
        if (I32 && c->Iop == 0x8B && (c->Irm & 0xC7) == modregrm(0,0,4) &&
            c->Isib == modregrm(0,4,SP) &&
            c1->Iop == 0x83 && (c1->Irm & 0xC7) == modregrm(3,0,SP) &&
            !(c1->Iflags & CFpsw) && c1->IFL2 == FLconst && c1->IEV2.Vint == 4)
        {   unsigned reg = (c->Irm >> 3) & 7;
            c->Iop = 0x58 + reg;
            c1->Iop = NOP;
            continue;
        }

        // Combine two SUBs of the same register
        if (c->Iop == c1->Iop &&
            c->Iop == 0x83 &&
            (c->Irm & 0xC0) == 0xC0 &&
            (c->Irm & modregrm(3,0,7)) == (c1->Irm & modregrm(3,0,7)) &&
            !(c1->Iflags & CFpsw) &&
            c->IFL2 == FLconst && c1->IFL2 == FLconst
           )
        {   int i = (signed char)c->IEV2.Vint;
            int i1 = (signed char)c1->IEV2.Vint;
            switch ((c->Irm & modregrm(0,7,0)) | ((c1->Irm & modregrm(0,7,0)) >> 3))
            {
                case (0 << 3) | 0:              // ADD, ADD
                case (5 << 3) | 5:              // SUB, SUB
                    i += i1;
                    goto Laa;
                case (0 << 3) | 5:              // ADD, SUB
                case (5 << 3) | 0:              // SUB, ADD
                    i -= i1;
                    goto Laa;
                Laa:
                    if ((signed char)i != i)
                        c->Iop &= ~2;
                    c->IEV2.Vint = i;
                    c1->Iop = NOP;
                    if (i == 0)
                        c->Iop = NOP;
                    continue;
            }
        }

        if (c->Iop == 0x8B && (c->Irm & 0xC0) == 0xC0)    // MOV r1,r2
        {   r1 = (c->Irm >> 3) & 7;
            r2 = c->Irm & 7;
        }
        else if (c->Iop == 0x89 && (c->Irm & 0xC0) == 0xC0)   // MOV r1,r2
        {   r1 = c->Irm & 7;
            r2 = (c->Irm >> 3) & 7;
        }
        else
        {
            continue;
        }

        rmn = c1->Irm;
        mod = rmn & 0xC0;
        reg = rmn & modregrm(0,7,0);
        rm =  rmn & 7;
        if (cod3_EA(c1))
            repEA(c1,r1,r2);
        switch (c1->Iop)
        {
            case 0x50:
            case 0x51:
            case 0x52:
            case 0x53:
            case 0x54:
            case 0x55:
            case 0x56:
            case 0x57:                          // PUSH reg
                if ((c1->Iop & 7) == r1)
                {   c1->Iop = 0x50 | r2;
                    //printf("schedule PUSH reg\n");
                }
                break;

            case 0x81:
            case 0x83:
                // Look for CMP EA,imm
                if (reg == modregrm(0,7,0))
                {
                    if (mod == 0xC0 && rm == r1)
                        c1->Irm = mod | reg | r2;
                }
                break;

            case 0x84:                  // TEST reg,byte ptr EA
                if (r1 >= 4 || r2 >= 4) // if not a byte register
                    break;
                if ((rmn & 0xC0) == 0xC0)
                {
                    if ((rmn & 3) == r1)
                    {   c1->Irm = rmn = (rmn & modregrm(3,7,4)) | r2;
                        //printf("schedule 1\n");
                    }
                }
                if ((rmn & modregrm(0,3,0)) == modregrm(0,r1,0))
                {   c1->Irm = (rmn & modregrm(3,4,7)) | modregrm(0,r2,0);
                    //printf("schedule 2\n");
                }
                break;
            case 0x85:                  // TEST reg,word ptr EA
                if ((rmn & 0xC0) == 0xC0)
                {
                    if ((rmn & 7) == r1)
                    {   c1->Irm = rmn = (rmn & modregrm(3,7,0)) | r2;
                        //printf("schedule 3\n");
                    }
                }
                if ((rmn & modregrm(0,7,0)) == modregrm(0,r1,0))
                {   c1->Irm = (rmn & modregrm(3,0,7)) | modregrm(0,r2,0);
                    //printf("schedule 4\n");
                }
                break;

            case 0x89:                  // MOV EA,reg
                if ((rmn & modregrm(0,7,0)) == modregrm(0,r1,0))
                {   c1->Irm = (rmn & modregrm(3,0,7)) | modregrm(0,r2,0);
                    //printf("schedule 5\n");
                    if (c1->Irm == modregrm(3,r2,r2))
                        goto Lnop;
                }
                break;

            case 0x8B:                  // MOV reg,EA
                if ((rmn & 0xC0) == 0xC0 &&
                    (rmn & 7) == r1)            // if EA == r1
                {   c1->Irm = (rmn & modregrm(3,7,0)) | r2;
                    //printf("schedule 6\n");
                    if (c1->Irm == modregrm(3,r2,r2))
                        goto Lnop;
                }
                break;

            case 0x3C:                  // CMP AL,imm8
                if (r1 == AX && r2 < 4)
                {   c1->Iop = 0x80;
                    c1->Irm = modregrm(3,7,r2);
                    //printf("schedule 7, r2 = %d\n", r2);
                }
                break;

            case 0x3D:                  // CMP AX,imm16
                if (r1 == AX)
                {   c1->Iop = 0x81;
                    c1->Irm = modregrm(3,7,r2);
                    if (c1->IFL2 == FLconst &&
                        c1->IEV2.Vuns == (signed char)c1->IEV2.Vuns)
                        c1->Iop = 0x83;
                    //printf("schedule 8\n");
                }
                break;
        }
        continue;
Lnop:
        c1->Iop = NOP;
        c1 = cnext(c1);
        goto Ln;
    }
L1: ;
    return cstart;
}

/*****************************************************************/

/**********************************************
 * Replace complex instructions with simple ones more conducive
 * to scheduling.
 */

code *simpleops(code *c,regm_t scratch)
{   code *cstart;
    code **pc;
    unsigned reg;
    code *c2;

    // Worry about using registers not saved yet by prolog
    scratch &= ~fregsaved;

    if (!(scratch & (scratch - 1)))     // if 0 or 1 registers
        return c;

    reg = findreg(scratch);

    cstart = c;
    for (pc = &cstart; *pc; pc = &code_next(*pc))
    {
        c = *pc;
        if (c->Iflags & (CFtarg | CFtarg2 | CFopsize))
            continue;
        if (c->Iop == 0x83 &&
            (c->Irm & modregrm(0,7,0)) == modregrm(0,7,0) &&
            (c->Irm & modregrm(3,0,0)) != modregrm(3,0,0)
           )
        {   // Replace CMP mem,imm with:
            //  MOV reg,mem
            //  CMP reg,imm
            targ_long imm;

            //printf("replacing CMP\n");
            c->Iop = 0x8B;
            c->Irm = (c->Irm & modregrm(3,0,7)) | modregrm(0,reg,0);

            c2 = code_calloc();
            if (reg == AX)
                c2->Iop = 0x3D;
            else
            {   c2->Iop = 0x83;
                c2->Irm = modregrm(3,7,reg);
            }
            c2->IFL2 = c->IFL2;
            c2->IEV2 = c->IEV2;

            // See if c2 should be replaced by a TEST
            imm = c2->IEV2.Vuns;
            if (!(c2->Iop & 1))
                imm &= 0xFF;
            else if (I32 ? c->Iflags & CFopsize : !(c->Iflags & CFopsize))
                imm = (short) imm;
            if (imm == 0)
            {
                c2->Iop = 0x85;                 // TEST reg,reg
                c2->Irm = modregrm(3,reg,reg);
            }
            goto L1;
        }
        else if (c->Iop == 0xFF &&
            (c->Irm & modregrm(0,7,0)) == modregrm(0,6,0) &&
            (c->Irm & modregrm(3,0,0)) != modregrm(3,0,0)
           )
        {   // Replace PUSH mem with:
            //  MOV reg,mem
            //  PUSH reg

           // printf("replacing PUSH\n");
            c->Iop = 0x8B;
            c->Irm = (c->Irm & modregrm(3,0,7)) | modregrm(0,reg,0);

            c2 = gen1(NULL,0x50 + reg);
        L1:
//c->print();
//c2->print();
            c2->next = c->next;
            c->next = c2;

            // Switch to another reg
            if (scratch & ~mask[reg])
                reg = findreg(scratch & ~mask[reg]);
        }
    }
    return cstart;
}

#if DEBUG
static const char *fpops[] = {"fstp","fld","fop"};
void Cinfo::print()
{
    Cinfo *ci = this;

    if (ci == NULL)
    {
        printf("Cinfo 0\n");
        return;
    }

    printf("Cinfo %p:  c %p, pair %x, sz %d, isz %d, flags - ",
           ci,c,pair,sz,isz);
    if (ci->flags & CIFLarraybounds)
        printf("arraybounds,");
    if (ci->flags & CIFLea)
        printf("ea,");
    if (ci->flags & CIFLnostage)
        printf("nostage,");
    if (ci->flags & CIFLpush)
        printf("push,");
    if (ci->flags & ~(CIFLarraybounds|CIFLnostage|CIFLpush|CIFLea))
        printf("bad flag,");
    printf("\n\tr %lx w %lx a %lx reg %x uops %x sibmodrm %x spadjust %ld\n",
            (long)r,(long)w,(long)a,reg,uops,sibmodrm,(long)spadjust);
    if (ci->fp_op)
        printf("\tfp_op %s, fxch_pre %x, fxch_post %x\n",
                fpops[fp_op-1],fxch_pre,fxch_post);
}
#endif
#endif
