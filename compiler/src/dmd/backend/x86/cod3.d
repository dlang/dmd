/**
 * Code generation 3
 *
 * Includes:
 * - generating a function prolog (pushing return address, loading paramters)
 * - generating a function epilog (restoring registers, returning)
 * - generation / peephole optimizations of jump / branch instructions
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/x86/cod3.d, backend/cod3.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_x86_cod3.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/x86/cod3.d
 */

module dmd.backend.x86.cod3;

import core.bitop;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcse;
import dmd.backend.code;
import dmd.backend.arm.cod3;
import dmd.backend.arm.instr;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.melf;
import dmd.backend.mem;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.x86.xmm;

nothrow:
@safe:

enum MARS = true;

//private void genorreg(ref CodeBuilder c, uint t, uint f) { genregs(c, 0x09, f, t); }

enum JMPJMPTABLE = false;               // benchmarking shows it's slower

/*************
 * Size in bytes of each instruction.
 * 0 means illegal instruction.
 * bit  M:      if there is a modregrm field (EV1 is reserved for modregrm)
 * bit  T:      if there is a second operand (EV2)
 * bit  E:      if second operand is only 8 bits
 * bit  A:      a short version exists for the AX reg
 * bit  R:      a short version exists for regs
 * bits 2..0:   size of instruction (excluding optional bytes)
 */

enum
{
    M = 0x80,
    T = 0x40,
    E = 0x20,
    A = 0x10,
    R = 0x08,
    W = 0,
}

private __gshared ubyte[256] inssize =
[       M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 00 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 08 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 10 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 18 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 20 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 28 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 30 */
        M|2,M|2,M|2,M|2,        T|E|2,T|3,1,1,          /* 38 */
        1,1,1,1,                1,1,1,1,                /* 40 */
        1,1,1,1,                1,1,1,1,                /* 48 */
        1,1,1,1,                1,1,1,1,                /* 50 */
        1,1,1,1,                1,1,1,1,                /* 58 */
        1,1,M|2,M|2,            1,1,1,1,                /* 60 */
        T|3,M|T|4,T|E|2,M|T|E|3, 1,1,1,1,               /* 68 */
        T|E|2,T|E|2,T|E|2,T|E|2, T|E|2,T|E|2,T|E|2,T|E|2,       /* 70 */
        T|E|2,T|E|2,T|E|2,T|E|2, T|E|2,T|E|2,T|E|2,T|E|2,       /* 78 */
        M|T|E|A|3,M|T|A|4,M|T|E|3,M|T|E|3,      M|2,M|2,M|2,M|A|R|2, /* 80 */
        M|A|2,M|A|2,M|A|2,M|A|2,        M|2,M|2,M|2,M|R|2,      /* 88 */
        1,1,1,1,                1,1,1,1,                /* 90 */
        1,1,T|5,1,              1,1,1,1,                /* 98 */

     // cod3_set32() patches this
    //  T|5,T|5,T|5,T|5,        1,1,1,1,                /* A0 */
        T|3,T|3,T|3,T|3,        1,1,1,1,                /* A0 */

        T|E|2,T|3,1,1,          1,1,1,1,                /* A8 */
        T|E|2,T|E|2,T|E|2,T|E|2, T|E|2,T|E|2,T|E|2,T|E|2,       /* B0 */
        T|3,T|3,T|3,T|3,        T|3,T|3,T|3,T|3,                /* B8 */
        M|T|E|3,M|T|E|3,T|3,1,  M|2,M|2,M|T|E|R|3,M|T|R|4,      /* C0 */
        T|E|4,1,T|3,1,          1,T|E|2,1,1,            /* C8 */
        M|2,M|2,M|2,M|2,        T|E|2,T|E|2,0,1,        /* D0 */
        /* For the floating instructions, allow room for the FWAIT      */
        M|2,M|2,M|2,M|2,        M|2,M|2,M|2,M|2,        /* D8 */
        T|E|2,T|E|2,T|E|2,T|E|2, T|E|2,T|E|2,T|E|2,T|E|2,       /* E0 */
        T|3,T|3,T|5,T|E|2,              1,1,1,1,                /* E8 */
        1,0,1,1,                1,1,M|A|2,M|A|2,                /* F0 */
        1,1,1,1,                1,1,M|2,M|R|2                   /* F8 */
];

private __gshared const ubyte[256] inssize32 =
[       2,2,2,2,        2,5,1,1,                /* 00 */
        2,2,2,2,        2,5,1,1,                /* 08 */
        2,2,2,2,        2,5,1,1,                /* 10 */
        2,2,2,2,        2,5,1,1,                /* 18 */
        2,2,2,2,        2,5,1,1,                /* 20 */
        2,2,2,2,        2,5,1,1,                /* 28 */
        2,2,2,2,        2,5,1,1,                /* 30 */
        2,2,2,2,        2,5,1,1,                /* 38 */
        1,1,1,1,        1,1,1,1,                /* 40 */
        1,1,1,1,        1,1,1,1,                /* 48 */
        1,1,1,1,        1,1,1,1,                /* 50 */
        1,1,1,1,        1,1,1,1,                /* 58 */
        1,1,2,2,        1,1,1,1,                /* 60 */
        5,6,2,3,        1,1,1,1,                /* 68 */
        2,2,2,2,        2,2,2,2,                /* 70 */
        2,2,2,2,        2,2,2,2,                /* 78 */
        3,6,3,3,        2,2,2,2,                /* 80 */
        2,2,2,2,        2,2,2,2,                /* 88 */
        1,1,1,1,        1,1,1,1,                /* 90 */
        1,1,7,1,        1,1,1,1,                /* 98 */
        5,5,5,5,        1,1,1,1,                /* A0 */
        2,5,1,1,        1,1,1,1,                /* A8 */
        2,2,2,2,        2,2,2,2,                /* B0 */
        5,5,5,5,        5,5,5,5,                /* B8 */
        3,3,3,1,        2,2,3,6,                /* C0 */
        4,1,3,1,        1,2,1,1,                /* C8 */
        2,2,2,2,        2,2,0,1,                /* D0 */
        /* For the floating instructions, don't need room for the FWAIT */
        2,2,2,2,        2,2,2,2,                /* D8 */

        2,2,2,2,        2,2,2,2,                /* E0 */
        5,5,7,2,        1,1,1,1,                /* E8 */
        1,0,1,1,        1,1,2,2,                /* F0 */
        1,1,1,1,        1,1,2,2                 /* F8 */
];

/* For 2 byte opcodes starting with 0x0F        */
private __gshared ubyte[256] inssize2 =
[       M|3,M|3,M|3,M|3,        2,2,2,2,                // 00
        2,2,M|3,2,              2,M|3,2,M|T|E|4,        // 08
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 10
        M|3,2,2,2,              2,2,2,2,                // 18
        M|3,M|3,M|3,M|3,        M|3,2,M|3,2,            // 20
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 28
        2,2,2,2,                2,2,2,2,                // 30
        M|4,2,M|T|E|5,2,        2,2,2,2,                // 38
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 40
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 48
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 50
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 58
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 60
        M|3,M|3,M|3,M|3,        M|3,M|3,M|3,M|3,        // 68
        M|T|E|4,M|T|E|4,M|T|E|4,M|T|E|4, M|3,M|3,M|3,2, // 70
        2,2,2,2,                M|3,M|3,M|3,M|3,        // 78
        W|T|4,W|T|4,W|T|4,W|T|4, W|T|4,W|T|4,W|T|4,W|T|4, // 80
        W|T|4,W|T|4,W|T|4,W|T|4, W|T|4,W|T|4,W|T|4,W|T|4, // 88
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // 90
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // 98
        2,2,2,M|3,      M|T|E|4,M|3,2,2,        // A0
        2,2,2,M|3,      M|T|E|4,M|3,M|3,M|3,    // A8
        M|E|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,     // B0
        M|3,2,M|T|E|4,M|3, M|3,M|3,M|3,M|3,     // B8
        M|3,M|3,M|T|E|4,M|3, M|T|E|4,M|T|E|4,M|T|E|4,M|3,       // C0
        2,2,2,2,        2,2,2,2,                // C8
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // D0
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // D8
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // E0
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // E8
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,M|3,       // F0
        M|3,M|3,M|3,M|3, M|3,M|3,M|3,2          // F8
];

/*************************************************
 * Generate code to save `reg` in `regsave` stack area.
 * Params:
 *      regsave = register save areay on stack
 *      cdb = where to write generated code
 *      reg = register to save
 *      idx = set to location in regsave for use in REGSAVE_restore()
 */

@trusted
void REGSAVE_save(ref REGSAVE regsave, ref CodeBuilder cdb, reg_t reg, out uint idx)
{
    if (isXMMreg(reg))
    {
        regsave.alignment = 16;
        regsave.idx = (regsave.idx + 15) & ~15;
        idx = regsave.idx;
        regsave.idx += 16;
        // MOVD idx[RBP],xmm
        opcode_t op = STOAPD;
        if (TARGET_LINUX && I32)
            // Haven't yet figured out why stack is not aligned to 16
            op = STOUPD;
        cdb.genc1(op,modregxrm(2, reg - XMM0, BPRM),FL.regsave,cast(targ_uns) idx);
    }
    else
    {
        if (!regsave.alignment)
            regsave.alignment = REGSIZE;
        idx = regsave.idx;
        regsave.idx += REGSIZE;
        // MOV idx[RBP],reg
        cdb.genc1(0x89,modregxrm(2, reg, BPRM),FL.regsave,cast(targ_uns) idx);
        if (I64)
            code_orrex(cdb.last(), REX_W);
    }
    cgstate.reflocal = true;
    if (regsave.idx > regsave.top)
        regsave.top = regsave.idx;              // keep high water mark
}

/*******************************
 * Restore `reg` from `regsave` area.
 * Complement REGSAVE_save().
 */

@trusted
void REGSAVE_restore(const ref REGSAVE regsave, ref CodeBuilder cdb, reg_t reg, uint idx)
{
    if (isXMMreg(reg))
    {
        assert(regsave.alignment == 16);
        // MOVD xmm,idx[RBP]
        opcode_t op = LODAPD;
        if (TARGET_LINUX && I32)
            // Haven't yet figured out why stack is not aligned to 16
            op = LODUPD;
        cdb.genc1(op,modregxrm(2, reg - XMM0, BPRM),FL.regsave,cast(targ_uns) idx);
    }
    else
    {   // MOV reg,idx[RBP]
        cdb.genc1(0x8B,modregxrm(2, reg, BPRM),FL.regsave,cast(targ_uns) idx);
        if (I64)
            code_orrex(cdb.last(), REX_W);
    }
}

/************************************
 * Size for vex encoded instruction.
 */

@trusted
ubyte vex_inssize(code* c)
{
    assert(c.Iflags & CFvex && c.Ivex.pfx == 0xC4);
    ubyte ins;
    if (c.Iflags & CFvex3)
    {
        switch (c.Ivex.mmmm)
        {
        case 0: // no prefix
        case 1: // 0F
            ins = cast(ubyte)(inssize2[c.Ivex.op] + 2);
            break;
        case 2: // 0F 38
            ins = cast(ubyte)(inssize2[0x38] + 1);
            break;
        case 3: // 0F 3A
            ins = cast(ubyte)(inssize2[0x3A] + 1);
            break;
        default:
            printf("Iop = %x mmmm = %x\n", c.Iop, c.Ivex.mmmm);
            assert(0);
        }
    }
    else
    {
        ins = cast(ubyte)(inssize2[c.Ivex.op] + 1);
    }
    return ins;
}

/************************************
 * Determine if there is a modregrm byte for instruction.
 * Params:
 *      c = instruction
 * Returns:
 *      true if has modregrm byte
 */

@trusted
bool hasModregrm(scope const code* c)
{
    uint ins;
    opcode_t op1 = c.Iop & 0xFF;
    if ((c.Iop & PSOP.mask) == PSOP.root)
        ins = 0;
    else if ((c.Iop & 0xFFFD00) == 0x0F3800)
        ins = inssize2[(c.Iop >> 8) & 0xFF];
    else if ((c.Iop & 0xFF00) == 0x0F00)
        ins = inssize2[op1];
    else
        ins = inssize[op1];
    return (ins & M) != 0;
}

/********************************
 * set initial global variable values
 */

@trusted
void cod3_setdefault()
{
    cgstate.BP = BP;
    fregsaved = mBP | mSI | mDI;
}

/********************************
 * Fix global variables for 386.
 */
@trusted
void cod3_set32()
{
    cgstate.BP = BP;

    inssize[0xA0] = T|5;
    inssize[0xA1] = T|5;
    inssize[0xA2] = T|5;
    inssize[0xA3] = T|5;
    BPRM = 5;                       /* [EBP] addressing mode        */
    fregsaved = mBP | mBX | mSI | mDI;      // saved across function calls
    FLOATREGS = FLOATREGS_32;
    FLOATREGS2 = FLOATREGS2_32;
    DOUBLEREGS = DOUBLEREGS_32;
    if (config.flags3 & CFG3eseqds)
        fregsaved |= mES;

    foreach (ref v; inssize2[0x80 .. 0x90])
        v = W|T|6;

    TARGET_STACKALIGN = config.fpxmmregs ? 16 : 4;
    cgstate.allregs = mAX|mBX|mCX|mDX|mSI|mDI;
}

/********************************
 * Fix global variables for I64.
 */

@trusted
void cod3_set64()
{
    cgstate.BP = BP;

    inssize[0xA0] = T|5;                // MOV AL,mem
    inssize[0xA1] = T|5;                // MOV RAX,mem
    inssize[0xA2] = T|5;                // MOV mem,AL
    inssize[0xA3] = T|5;                // MOV mem,RAX
    BPRM = 5;                           // [RBP] addressing mode

    fregsaved = (config.exe & EX_windos)
        ? mBP | mBX | mDI | mSI | mR12 | mR13 | mR14 | mR15 | mES | mXMM6 | mXMM7 // also XMM8..15;
        : mBP | mBX | mR12 | mR13 | mR14 | mR15 | mES;      // saved across function calls

    FLOATREGS = FLOATREGS_64;
    FLOATREGS2 = FLOATREGS2_64;
    DOUBLEREGS = DOUBLEREGS_64;

    foreach (ref v; inssize2[0x80 .. 0x90])
        v = W|T|6;

    TARGET_STACKALIGN = config.fpxmmregs ? 16 : 8;
    cgstate.allregs = mAX|mBX|mCX|mDX|mSI|mDI| mR8|mR9|mR10|mR11|mR12|mR13|mR14|mR15;
}

/********************************
 * Set read-only global variables for AArch64.
 */

@trusted
void cod3_setAArch64()
{
    cgstate.AArch64 = true;

    /* Register usage per "AArch64 Procedure Call Standard"
     * r31 SP  Stack Pointer
     * r30 LR  Link Register
     * r29 FP  Frame Pointer (BP)
     * r19-r28 Callee-saved registers (if Callee modifies them)
     * r18     Platform Register
     * r17 IP1 intra-procedure-call temporary register
     * r16 IP0 intra-procedure-call scratch register
     * r9-r15  temporary registers
     * r8      Indirect result location register
     * r0-r7   Parameter / result registers
     *
     * v0-v7   Parameter / result registers
     * v8-v15  Callee-saved registers (only bottom 64 bits need to be saved)
     * v16-31  Temporary registers
     */
    cgstate.BP = 29;

    /* Integer registers r0-r7, r9-15, r19-28, r29(?)
     */
    cgstate.allregs = 0x1FFF_FFFF & ~(1 << 8) & ~(1 << 16) & ~(1 << 17) & ~(1 << 18);

    /* Registers x19-x28, x29, v8-v15
     */
    fregsaved = (1<<19) | (1<<20) | (1<<21) | (1<<22) | (1<<23) | (1<<24) | (1<<25) | (1<<26) | (1<<27) | (1<<28) |
                (1<<29) |
                (1L<<(32+8)) | (1L<<(32+9)) | (1L<<(32+10)) | (1L<<(32+11)) | (1L<<(32+12)) | (1L<<(32+13)) | (1L<<(32+14)) | (1L<<(32+15));

    /* 32 Floating point registers
     */
    cgstate.fpregs = 0xFFFF_FFFF_0000_0000;

    /* XMM registers
     */
    cgstate.xmmregs = 0;  // implement later

    TARGET_STACKALIGN = 16;
}

/*********************************
 * Word or dword align start of function.
 * Params:
 *      seg = segment to write alignment bytes to
 *      nbytes = number of alignment bytes to write
 */
@trusted
void cod3_align_bytes(int seg, size_t nbytes)
{
    /* Table 4-2 from Intel Instruction Set Reference M-Z
     * 1 bytes NOP                                        90
     * 2 bytes 66 NOP                                     66 90
     * 3 bytes NOP DWORD ptr [EAX]                        0F 1F 00
     * 4 bytes NOP DWORD ptr [EAX + 00H]                  0F 1F 40 00
     * 5 bytes NOP DWORD ptr [EAX + EAX*1 + 00H]          0F 1F 44 00 00
     * 6 bytes 66 NOP DWORD ptr [EAX + EAX*1 + 00H]       66 0F 1F 44 00 00
     * 7 bytes NOP DWORD ptr [EAX + 00000000H]            0F 1F 80 00 00 00 00
     * 8 bytes NOP DWORD ptr [EAX + EAX*1 + 00000000H]    0F 1F 84 00 00 00 00 00
     * 9 bytes 66 NOP DWORD ptr [EAX + EAX*1 + 00000000H] 66 0F 1F 84 00 00 00 00 00
     * only for CPUs: CPUID.01H.EAX[Bytes 11:8] = 0110B or 1111B
     */

    assert(SegData[seg].SDseg == seg);

    while (nbytes)
    {   size_t n = nbytes;
        const(char)* p;

        if (nbytes > 1 && (I64 || config.fpxmmregs))
        {
            switch (n)
            {
                case 2:  p = "\x66\x90"; break;
                case 3:  p = "\x0F\x1F\x00"; break;
                case 4:  p = "\x0F\x1F\x40\x00"; break;
                case 5:  p = "\x0F\x1F\x44\x00\x00"; break;
                case 6:  p = "\x66\x0F\x1F\x44\x00\x00"; break;
                case 7:  p = "\x0F\x1F\x80\x00\x00\x00\x00"; break;
                case 8:  p = "\x0F\x1F\x84\x00\x00\x00\x00\x00"; break;
                default: p = "\x66\x0F\x1F\x84\x00\x00\x00\x00\x00"; n = 9; break;
            }
        }
        else
        {
            static immutable ubyte[15] nops = [
                0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90
            ]; // XCHG AX,AX
            if (n > nops.length)
                n = nops.length;
            p = cast(char*)nops;
        }
        objmod.write_bytes(SegData[seg],p[0 .. n]);
        nbytes -= n;
    }
}

/****************************
 * Align start of function.
 * Params:
 *      seg = segment of function
 */
@trusted
void cod3_align(int seg)
{
    if (config.exe & EX_windos)
    {
        if (config.flags4 & CFG4speed)      // if optimized for speed
        {
            // Pick alignment based on CPU target
            if (config.target_cpu == TARGET_80486 ||
                config.target_cpu >= TARGET_PentiumPro)
            {   // 486 does reads on 16 byte boundaries, so if we are near
                // such a boundary, align us to it

                const nbytes = -Offset(seg) & 15;
                if (nbytes < 8)
                    cod3_align_bytes(seg, nbytes);
            }
        }
    }
    else
    {
        const nbytes = -Offset(seg) & 7;
        cod3_align_bytes(seg, nbytes);
    }
}


/**********************************
 * Generate code to adjust the stack pointer by `nbytes`
 * Params:
 *      cdb = code builder
 *      nbytes = number of bytes to adjust stack pointer
 */
@trusted
void cod3_stackadj(ref CodeBuilder cdb, int nbytes)
{
    //printf("cod3_stackadj(%d)\n", nbytes);
    if (cgstate.AArch64)
    {
        if (nbytes == 0)
            return;

        // https://www.scs.stanford.edu/~zyedidia/arm64/sub_addsub_imm.html
        // add/sub Xd,Xn,#imm{,shift}
        uint sf = 1;
        uint op = nbytes < 0 ? 0 : 1;
        uint S = 0;
        uint sh = 0;
        uint imm12 = nbytes < 0 ? -nbytes : nbytes;
        uint Rn = 0x1F;
        uint Rd = 0x1F;
        uint ins = (sf    << 31) |
                   (op    << 30) |
                   (S     << 29) |
                   (0x22  << 23) |
                   (sh    << 22) |
                   (imm12 << 10) |
                   (Rn    <<  5) |
                    Rd;
        cdb.gen1(ins);
        assert(imm12 < (1 << 12));  // only 12 bits allowed
        assert((imm12 & 0xF) == 0); // 16 byte aligned
        return;
    }
    uint grex = I64 ? REX_W << 16 : 0;
    uint rm;
    if (nbytes > 0)
        rm = modregrm(3,5,SP); // SUB ESP,nbytes
    else
    {
        nbytes = -nbytes;
        rm = modregrm(3,0,SP); // ADD ESP,nbytes
    }
    cdb.genc2(0x81, grex | rm, nbytes);
}

/**********************************
 * Generate code to align the stack pointer at `nbytes`
 * Params:
 *      cdb = code builder
 *      nbytes = number of bytes to align stack pointer
 */
void cod3_stackalign(ref CodeBuilder cdb, int nbytes)
{
    //printf("cod3_stackalign(%d)\n", nbytes);
    const grex = I64 ? REX_W << 16 : 0;
    const rm = modregrm(3, 4, SP);             // AND ESP,-nbytes
    cdb.genc2(0x81, grex | rm, -nbytes);
}

/* Constructor that links the ModuleReference to the head of
 * the list pointed to by _Dmoduleref
 *
 * For ELF object files.
 */
static if (0)
{
void cod3_buildmodulector(OutBuffer* buf, int codeOffset, int refOffset)
{
    /*      ret
     * codeOffset:
     *      pushad
     *      mov     EAX,&ModuleReference
     *      mov     ECX,_DmoduleRef
     *      mov     EDX,[ECX]
     *      mov     [EAX],EDX
     *      mov     [ECX],EAX
     *      popad
     *      ret
     */

    const int seg = CODE;

    if (I64 && config.flags3 & CFG3pic)
    {   // LEA RAX,ModuleReference[RIP]
        buf.writeByte(REX | REX_W);
        buf.writeByte(LEA);
        buf.writeByte(modregrm(0,AX,5));
        codeOffset += 3;
        codeOffset += Obj.writerel(seg, codeOffset, R_X86_64_PC32, 3 /*STI_DATA*/, refOffset - 4);

        // MOV RCX,_DmoduleRef@GOTPCREL[RIP]
        buf.writeByte(REX | REX_W);
        buf.writeByte(0x8B);
        buf.writeByte(modregrm(0,CX,5));
        codeOffset += 3;
        codeOffset += Obj.writerel(seg, codeOffset, R_X86_64_GOTPCREL, Obj.external_def("_Dmodule_ref"), -4);
    }
    else
    {
        /* movl ModuleReference*, %eax */
        buf.writeByte(0xB8);
        codeOffset += 1;
        const uint reltype = I64 ? R_X86_64_32 : R_386_32;
        codeOffset += Obj.writerel(seg, codeOffset, reltype, 3 /*STI_DATA*/, refOffset);

        /* movl _Dmodule_ref, %ecx */
        buf.writeByte(0xB9);
        codeOffset += 1;
        codeOffset += Obj.writerel(seg, codeOffset, reltype, Obj.external_def("_Dmodule_ref"), 0);
    }

    if (I64)
        buf.writeByte(REX | REX_W);
    buf.writeByte(0x8B); buf.writeByte(0x11); /* movl (%ecx), %edx */
    if (I64)
        buf.writeByte(REX | REX_W);
    buf.writeByte(0x89); buf.writeByte(0x10); /* movl %edx, (%eax) */
    if (I64)
        buf.writeByte(REX | REX_W);
    buf.writeByte(0x89); buf.writeByte(0x01); /* movl %eax, (%ecx) */

    buf.writeByte(0xC3); /* ret */
}
}

/*****************************
 * Given a type, return a mask of
 * registers to hold that type.
 * Input:
 *      tyf     function type
 */

@trusted
regm_t regmask(tym_t tym, tym_t tyf)
{
    switch (tybasic(tym))
    {
        case TYvoid:
        case TYnoreturn:
        case TYstruct:
        case TYarray:
            return 0;

        case TYbool:
        case TYwchar_t:
        case TYchar16:
        case TYchar:
        case TYschar:
        case TYuchar:
        case TYshort:
        case TYushort:
        case TYint:
        case TYuint:
        case TYnullptr:
        case TYnptr:
        case TYnref:
        case TYsptr:
        case TYcptr:
        case TYimmutPtr:
        case TYsharePtr:
        case TYrestrictPtr:
        case TYfgPtr:
            return mAX;

        case TYfloat:
        case TYifloat:
            if (I64)
                return mXMM0;
            if (config.exe & EX_flat)
                return mST0;
            goto case TYlong;

        case TYlong:
        case TYulong:
        case TYdchar:
            if (!I16)
                return mAX;
            goto case TYfptr;

        case TYfptr:
        case TYhptr:
            return mDX | mAX;

        case TYcent:
        case TYucent:
            assert(I64);
            return mDX | mAX;

        case TYvptr:
            return mDX | mBX;

        case TYdouble:
        case TYdouble_alias:
        case TYidouble:
            if (I64)
                return mXMM0;
            if (config.exe & EX_flat)
                return mST0;
            return DOUBLEREGS;

        case TYllong:
        case TYullong:
            return I64 ? cast(regm_t) mAX : (I32 ? mDX | mAX : DOUBLEREGS);

        case TYldouble:
        case TYildouble:
            return mST0;

        case TYcfloat:
            if (config.exe & EX_posix && I32 && tybasic(tyf) == TYnfunc)
                return mDX | mAX;
            goto case TYcdouble;

        case TYcdouble:
            if (I64)
                return mXMM0 | mXMM1;
            goto case TYcldouble;

        case TYcldouble:
            return mST01;

        // SIMD vector types
        case TYfloat4:
        case TYdouble2:
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2:

        case TYfloat8:
        case TYdouble4:
        case TYschar32:
        case TYuchar32:
        case TYshort16:
        case TYushort16:
        case TYlong8:
        case TYulong8:
        case TYllong4:
        case TYullong4:
            if (!config.fpxmmregs)
            {   printf("SIMD operations not supported on this platform\n");
                exit(1);
            }
            return mXMM0;

        default:
            debug printf("%s\n", tym_str(tym));
            assert(0);
    }
}

/*******************************
 * setup register allocator parameters with platform specific data
 */
void cgreg_dst_regs(reg_t* dst_integer_reg, reg_t* dst_float_reg)
{
    *dst_integer_reg = AX;
    *dst_float_reg   = XMM0;
}

@trusted
void cgreg_set_priorities(tym_t ty, const(reg_t)** pseq, const(reg_t)** pseqmsw)
{
    //printf("cgreg_set_priorities %x\n", ty);
    const sz = tysize(ty);

    if (tyxmmreg(ty))
    {
        static immutable ubyte[9] sequence = [XMM0,XMM1,XMM2,XMM3,XMM4,XMM5,XMM6,XMM7,NOREG];
        *pseq = sequence.ptr;
    }
    else if (I64)
    {
        if (sz == REGSIZE * 2)
        {
            static immutable ubyte[3] seqmsw1 = [CX,DX,NOREG];
            static immutable ubyte[5] seqlsw1 = [AX,BX,SI,DI,NOREG];
            *pseq = seqlsw1.ptr;
            *pseqmsw = seqmsw1.ptr;
        }
        else
        {   // R10 is reserved for the static link
            static immutable ubyte[15] sequence2 = [AX,CX,DX,SI,DI,R8,R9,R11,BX,R12,R13,R14,R15,BP,NOREG];
            *pseq = cast(ubyte*)sequence2.ptr;
        }
    }
    else if (I32)
    {
        if (sz == REGSIZE * 2)
        {
            static immutable ubyte[5] seqlsw3 = [AX,BX,SI,DI,NOREG];
            static immutable ubyte[3] seqmsw3 = [CX,DX,NOREG];
            *pseq = seqlsw3.ptr;
            *pseqmsw = seqmsw3.ptr;
        }
        else
        {
            static immutable ubyte[8] sequence4 = [AX,CX,DX,BX,SI,DI,BP,NOREG];
            *pseq = sequence4.ptr;
        }
    }
    else
    {   assert(I16);
        if (typtr(ty))
        {
            // For pointer types, try to pick index register first
            static immutable ubyte[8] seqidx5 = [BX,SI,DI,AX,CX,DX,BP,NOREG];
            *pseq = seqidx5.ptr;
        }
        else
        {
            // Otherwise, try to pick index registers last
            static immutable ubyte[8] sequence6 = [AX,CX,DX,BX,SI,DI,BP,NOREG];
            *pseq = sequence6.ptr;
        }
    }
}

/*******************************************
 * Call finally block.
 * Params:
 *      bf = block to call
 *      retregs = registers to preserve across call
 * Returns:
 *      code generated
 */
@trusted
private code* callFinallyBlock(block* bf, regm_t retregs)
{
    CodeBuilder cdbs; cdbs.ctor();
    CodeBuilder cdbr; cdbr.ctor();
    int nalign = 0;

    cgstate.calledFinally = true;
    uint npush = gensaverestore(retregs,cdbs,cdbr);

    if (STACKALIGN >= 16)
    {   npush += REGSIZE;
        if (npush & (STACKALIGN - 1))
        {   nalign = STACKALIGN - (npush & (STACKALIGN - 1));
            cod3_stackadj(cdbs, nalign);
        }
    }
    cdbs.genc(0xE8,0,FL.unde,0,FL.block,cast(targ_size_t)bf);
    cgstate.regcon.immed.mval = 0;
    if (nalign)
        cod3_stackadj(cdbs, -nalign);
    cdbs.append(cdbr);
    return cdbs.finish();
}

/*******************************
 * Generate block exit code
 */
@trusted
void outblkexitcode(ref CodeBuilder cdb, block* bl, ref int anyspill, const(FL)* sflsave, Symbol** retsym, const regm_t mfuncregsave)
{
    //printf("outblkexitcode()\n");
    bool AArch64 = cgstate.AArch64;
    CodeBuilder cdb2; cdb2.ctor();
    elem* e = bl.Belem;
    block* nextb;
    regm_t retregs = 0;

    if (bl.bc != BC.asm_)
        assert(bl.Bcode == null);

    switch (bl.bc)                     /* block exit condition         */
    {
        case BC.iftrue:
        {
            bool jcond = true;
            block* bs1 = bl.nthSucc(0);
            block* bs2 = bl.nthSucc(1);
            if (bs1 == bl.Bnext)
            {   // Swap bs1 and bs2
                block* btmp;

                jcond ^= 1;
                btmp = bs1;
                bs1 = bs2;
                bs2 = btmp;
            }
            logexp(cdb,e,jcond,FL.block,cast(code*) bs1);
            nextb = bs2;
        }
        L5:
            if (configv.addlinenumbers && bl.Bsrcpos.Slinnum &&
                !(funcsym_p.ty() & mTYnaked))
            {
                //printf("BC.iftrue: %s(%u)\n", bl.Bsrcpos.Sfilename ? bl.Bsrcpos.Sfilename : "", bl.Bsrcpos.Slinnum);
                cdb.genlinnum(bl.Bsrcpos);
            }
            if (nextb != bl.Bnext)
            {
                assert(!(bl.Bflags & BFL.epilog));
                if (AArch64)
                    dmd.backend.arm.cod3.genBranch(cdb,COND.al,FL.block,nextb);
                else
                    genjmp(cdb,JMP,FL.block,nextb);
            }
            break;

        case BC.jmptab:
        case BC.ifthen:
        case BC.switch_:
        {
            assert(!(bl.Bflags & BFL.epilog));
            doswitch(cdb,bl);               // hide messy details
            break;
        }
        case BC.jcatch:          // D catch clause of try-catch
            assert(ehmethod(funcsym_p) != EHmethod.EH_NONE);
            // Mark all registers as destroyed. This will prevent
            // register assignments to variables used in catch blocks.
            getregs(cdb,lpadregs());

            if (config.ehmethod == EHmethod.EH_DWARF)
            {
                /* Each block must have ESP set to the same value it was at the end
                 * of the prolog. But the unwinder calls catch blocks with ESP set
                 * at the value it was when the throwing function was called, which
                 * may have arguments pushed on the stack.
                 * This instruction will reset ESP to the correct offset from EBP.
                 */
                cdb.gen1(PSOP.fixesp);
            }
            goto case_goto;
        case BC.goto_:
            nextb = bl.nthSucc(0);
            if ((MARS ||
                 funcsym_p.Sfunc.Fflags3 & Fnteh) &&
                ehmethod(funcsym_p) != EHmethod.EH_DWARF &&
                bl.Btry != nextb.Btry &&
                nextb.bc != BC._finally)
            {
                regm_t retregsx = 0;
                gencodelem(cdb,e,retregsx,true);
                int toindex = nextb.Btry ? nextb.Btry.Bscope_index : -1;
                assert(bl.Btry);
                int fromindex = bl.Btry.Bscope_index;
                if (toindex + 1 == fromindex)
                {   // Simply call __finally
                    if (bl.Btry &&
                        bl.Btry.nthSucc(1).bc == BC.jcatch)
                    {
                        goto L5;        // it's a try-catch, not a try-finally
                    }
                }
                if (config.ehmethod == EHmethod.EH_WIN32 && !(funcsym_p.Sfunc.Fflags3 & Feh_none) ||
                    config.ehmethod == EHmethod.EH_SEH)
                {
                    nteh_unwind(cdb,0,toindex);
                }
                else
                {
                if (toindex + 1 <= fromindex)
                {
                    //c = cat(c, linux_unwind(0, toindex));
                    block* bt;

                    //printf("B%d: fromindex = %d, toindex = %d\n", bl.Bdfoidx, fromindex, toindex);
                    bt = bl;
                    while ((bt = bt.Btry) != null && bt.Bscope_index != toindex)
                    {   block* bf;

                        //printf("\tbt.Bscope_index = %d, bt.Blast_index = %d\n", bt.Bscope_index, bt.Blast_index);
                        bf = bt.nthSucc(1);
                        // Only look at try-finally blocks
                        if (bf.bc == BC.jcatch)
                            continue;

                        if (bf == nextb)
                            continue;
                        //printf("\tbf = B%d, nextb = B%d\n", bf.Bdfoidx, nextb.Bdfoidx);
                        if (nextb.bc == BC.goto_ &&
                            !nextb.Belem &&
                            bf == nextb.nthSucc(0))
                            continue;

                        // call __finally
                        cdb.append(callFinallyBlock(bf.nthSucc(0), retregsx));
                    }
                }
                }
                goto L5;
            }
        case_goto:
        {
            regm_t retregsx = 0;
            gencodelem(cdb,e,retregsx,true);
            if (anyspill)
            {   // Add in the epilog code
                CodeBuilder cdbstore; cdbstore.ctor();
                CodeBuilder cdbload;  cdbload.ctor();

                for (int i = 0; i < anyspill; i++)
                {   Symbol* s = globsym[i];

                    if (s.Sflags & SFLspill &&
                        vec_testbit(cgstate.dfoidx,s.Srange))
                    {
                        s.Sfl = sflsave[i];    // undo block register assignments
                        cgreg_spillreg_epilog(bl,s,cdbstore,cdbload);
                    }
                }
                cdb.append(cdbstore);
                cdb.append(cdbload);
            }
            nextb = bl.nthSucc(0);
            goto L5;
        }

        case BC._try:
            if (config.ehmethod == EHmethod.EH_NONE || funcsym_p.Sfunc.Fflags3 & Feh_none)
            {
                /* Need to use frame pointer to access locals, not the stack pointer,
                 * because we'll be calling the BC._finally blocks and the stack will be off.
                 */
                cgstate.needframe = 1;
            }
            else if (config.ehmethod == EHmethod.EH_SEH || config.ehmethod == EHmethod.EH_WIN32)
            {
                cgstate.usednteh |= NTEH_try;
                nteh_usevars();
            }
            else
                cgstate.usednteh |= EHtry;
            goto case_goto;

        case BC._finally:
            if (ehmethod(funcsym_p) == EHmethod.EH_DWARF)
            {
                // Mark scratch registers as destroyed.
                getregsNoSave(lpadregs());

                regm_t retregsx = 0;
                gencodelem(cdb,bl.Belem,retregsx,true);

                // JMP bl.nthSucc(1)
                nextb = bl.nthSucc(1);

                goto L5;
            }
            else
            {
                if (config.ehmethod == EHmethod.EH_SEH ||
                    config.ehmethod == EHmethod.EH_WIN32 && !(funcsym_p.Sfunc.Fflags3 & Feh_none))
                {
                    // Mark all registers as destroyed. This will prevent
                    // register assignments to variables used in finally blocks.
                    getregsNoSave(lpadregs());
                }

                assert(!e);
                // Generate CALL to finalizer code
                cdb.append(callFinallyBlock(bl.nthSucc(0), 0));

                // JMP bl.nthSucc(1)
                nextb = bl.nthSucc(1);

                goto L5;
            }

        case BC._lpad:
        {
            assert(ehmethod(funcsym_p) == EHmethod.EH_DWARF);
            // Mark all registers as destroyed. This will prevent
            // register assignments to variables used in finally blocks.
            getregsNoSave(lpadregs());

            regm_t retregsx = 0;
            gencodelem(cdb,bl.Belem,retregsx,true);

            // JMP bl.nthSucc(0)
            nextb = bl.nthSucc(0);
            goto L5;
        }

        case BC._ret:
        {
            regm_t retregsx = 0;
            gencodelem(cdb,e,retregsx,true);
            if (ehmethod(funcsym_p) == EHmethod.EH_DWARF)
            {
            }
            else
                cdb.gen1(0xC3);   // RET
            break;
        }

static if (NTEXCEPTIONS)
{
        case BC._except:
        {
            assert(!e);
            cgstate.usednteh |= NTEH_except;
            nteh_setsp(cdb,0x8B);
            getregsNoSave(cgstate.allregs);
            nextb = bl.nthSucc(0);
            goto L5;
        }
        case BC._filter:
        {
            nteh_filter(cdb, bl);
            // Mark all registers as destroyed. This will prevent
            // register assignments to variables used in filter blocks.
            getregsNoSave(cgstate.allregs);
            regm_t retregsx = regmask(e.Ety, TYnfunc);
            gencodelem(cdb,e,retregsx,true);
            cdb.gen1(0xC3);   // RET
            break;
        }
}

        case BC.retexp:
            reg_t reg1, reg2;
            retregs = allocretregs(cgstate, e.Ety, e.ET, funcsym_p.ty(), reg1, reg2);
            //printf("reg1: %d, reg2: %d\n", reg1, reg2);
            //printf("allocretregs returns %llx %s\n", retregs, regm_str(retregs));

            reg_t lreg = NOREG;
            reg_t mreg = NOREG;
            if (reg1 == NOREG)
            {}
            else if (tybasic(e.Ety) == TYcfloat)
                lreg = ST01;
            else if (mask(reg1) & (mST0 | mST01))
                lreg = reg1;
            else if (reg2 == NOREG)
                lreg = reg1;
            else if (mask(reg1) & XMMREGS)
            {
                lreg = XMM0;
                mreg = XMM1;
            }
            else
            {
                lreg = mask(reg1) & mLSW ? reg1 : AX;
                mreg = mask(reg2) & mMSW ? reg2 : DX;
            }
            if (reg1 != NOREG)
                retregs = (mask(lreg) | mask(mreg)) & ~mask(NOREG);

            // For the final load into the return regs, don't set cgstate.regcon.used,
            // so that the optimizer can potentially use retregs for register
            // variable assignments.

            if (config.flags4 & CFG4optimized)
            {   regm_t usedsave;

                docommas(cdb,e);
                usedsave = cgstate.regcon.used;
                if (!OTleaf(e.Eoper))
                    gencodelem(cdb,e,retregs,true);
                else
                {
                    if (e.Eoper == OPconst)
                        cgstate.regcon.mvar = 0;
                    gencodelem(cdb,e,retregs,true);
                    cgstate.regcon.used = usedsave;
                    if (e.Eoper == OPvar)
                    {   Symbol* s = e.Vsym;

                        if (s.Sfl == FL.reg && s.Sregm != mAX)
                            *retsym = s;
                    }
                }
            }
            else
            {
                gencodelem(cdb,e,retregs,true);
            }

            if (reg1 == NOREG)
            {
            }
            else if ((mask(reg1) | mask(reg2)) & (mST0 | mST01))
            {
                assert(reg1 == lreg && reg2 == NOREG);
                regm_t pretregs = mask(reg1) | mask(reg2);
                fixresult87(cdb, e, retregs, pretregs, true);
            }
            // fix return registers
            else if (tybasic(e.Ety) == TYcfloat)
            {
                assert(lreg == ST01);
                if (I64)
                {
                    assert(reg2 == NOREG);
                    // spill
                    pop87();
                    pop87();
                    cdb.genfltreg(0xD9, 3, tysize(TYfloat));
                    genfwait(cdb);
                    cdb.genfltreg(0xD9, 3, 0);
                    genfwait(cdb);
                    // reload
                    if (config.exe == EX_WIN64)
                    {
                        assert(reg1 == AX);
                        cdb.genfltreg(LOD, reg1, 0);
                        code_orrex(cdb.last(), REX_W);
                    }
                    else
                    {
                        assert(reg1 == XMM0);
                        cdb.genxmmreg(xmmload(TYdouble), reg1, 0, TYdouble);
                    }
                }
                else
                {
                    assert(reg1 == AX && reg2 == DX);
                    regm_t pretregs = mask(reg1) | mask(reg2);
                    fixresult_complex87(cdb, e, retregs, pretregs, true);
                }
            }
            else if (reg2 == NOREG)
                assert(lreg == reg1);
            else for (int v = 0; v < 2; v++)
            {
                if (v ^ (reg1 != mreg))
                    genmovreg(cdb, reg1, lreg);
                else
                    genmovreg(cdb, reg2, mreg);
            }
            if (reg1 != NOREG)
                retregs = (mask(reg1) | mask(reg2)) & ~mask(NOREG);
            goto L4;

        case BC.ret:
            retregs = 0;
            gencodelem(cdb,e,retregs,true);
        L4:
            if (retregs == mST0)
            {   assert(global87.stackused == 1);
                pop87();                // account for return value
            }
            else if (retregs == mST01)
            {   assert(global87.stackused == 2);
                pop87();
                pop87();                // account for return value
            }

            if (MARS || cgstate.usednteh & NTEH_try)
            {
                block* bt = bl;
                while ((bt = bt.Btry) != null)
                {
                    block* bf = bt.nthSucc(1);
                    // Only look at try-finally blocks
                    if (bf.bc == BC.jcatch)
                    {
                        continue;
                    }
                    if (config.ehmethod == EHmethod.EH_WIN32 && !(funcsym_p.Sfunc.Fflags3 & Feh_none) ||
                        config.ehmethod == EHmethod.EH_SEH)
                    {
                        if (bt.Bscope_index == 0)
                        {
                            // call __finally
                            CodeBuilder cdbs; cdbs.ctor();
                            CodeBuilder cdbr; cdbr.ctor();

                            nteh_gensindex(cdb,-1);
                            gensaverestore(retregs,cdbs,cdbr);
                            cdb.append(cdbs);
                            cdb.genc(0xE8,0,FL.unde,0,FL.block,cast(targ_size_t)bf.nthSucc(0));
                            cgstate.regcon.immed.mval = 0;
                            cdb.append(cdbr);
                        }
                        else
                        {
                            nteh_unwind(cdb,retregs,~0);
                        }
                        break;
                    }
                    else
                    {
                        // call __finally
                        cdb.append(callFinallyBlock(bf.nthSucc(0), retregs));
                    }
                }
            }
            break;

        case BC.exit:
            retregs = 0;
            gencodelem(cdb,e,retregs,true);
            if (config.flags4 & CFG4optimized)
                cgstate.mfuncreg = mfuncregsave;
            break;

        case BC.asm_:
        {
            assert(!e);
            // Mark destroyed registers
            CodeBuilder cdbx; cdbx.ctor();
            cgstate.refparam |= bl.bIasmrefparam;
            getregs(cdbx, iasm_regs(bl));         // mark destroyed registers
            code* c = cdbx.finish();
            if (bl.Bsucc)
            {   nextb = bl.nthSucc(0);
                if (!bl.Bnext)
                {
                    cdb.append(bl.Bcode);
                    cdb.append(c);
                    goto L5;
                }
                if (nextb != bl.Bnext &&
                    bl.Bnext &&
                    !(bl.Bnext.bc == BC.goto_ &&
                     !bl.Bnext.Belem &&
                     nextb == bl.Bnext.nthSucc(0)))
                {
                    // See if already have JMP at end of block
                    code* cl = code_last(bl.Bcode);
                    if (!cl || cl.Iop != JMP)
                    {
                        cdb.append(bl.Bcode);
                        cdb.append(c);
                        goto L5;        // add JMP at end of block
                    }
                }
            }
            cdb.append(bl.Bcode);
            break;
        }

        default:
            debug
            printf("bl.bc = %d\n",bl.bc);
            assert(0);
    }
}

/***************************
 * Allocate registers for function return values.
 *
 * Params:
 *    cgstate = code generator state
 *    ty    = return type
 *    t     = return type extended info
 *    tyf   = function type
 *    reg1  = set to the first part register, else NOREG
 *    reg2  = set to the second part register, else NOREG
 *
 * Returns:
 *    a bit mask of return registers.
 *    0 if function returns on the stack or returns void.
 */
@trusted
regm_t allocretregs(ref CGstate cgstate, const tym_t ty, type* t, const tym_t tyf, out reg_t reg1, out reg_t reg2)
{
    //printf("allocretregs() ty: %s\n", tym_str(ty));
    reg1 = reg2 = NOREG;
    auto AArch64 = cgstate.AArch64;

    if (!(config.exe & EX_posix))
        return regmask(ty, tyf);    // for non-Posix ABI

    /* The rest is for the Itanium ABI
     */

    const tyb = tybasic(ty);
    if (tyb == TYvoid || tyb == TYnoreturn)
        return 0;

    tym_t ty1 = tyb;
    tym_t ty2 = TYMAX;  // stays TYMAX if only one register is needed

    if (ty & mTYxmmgpr)
    {
        ty1 = TYdouble;
        ty2 = TYllong;
    }
    else if (ty & mTYgprxmm)
    {
        ty1 = TYllong;
        ty2 = TYdouble;
    }

    if (tyb == TYstruct)
    {
        assert(t);
        ty1 = t.Tty;
    }

    const tyfb = tybasic(tyf);
    switch (tyrelax(ty1))
    {
        case TYcent:
            if (I32)
                return 0;
            ty1 = ty2 = TYllong;
            break;

        case TYcdouble:
            if (tyfb == TYjfunc && I32)
                break;
            if (I32)
                return 0;
            ty1 = ty2 = TYdouble;
            break;

        case TYcfloat:
            if (tyfb == TYjfunc && I32)
                break;
            if (I32)
                goto case TYllong;
            ty1 = TYdouble;
            break;

        case TYcldouble:
            if (tyfb == TYjfunc && I32)
                break;
            if (I32)
                return 0;
            break;

        case TYllong:
            if (I32)
                ty1 = ty2 = TYlong;
            break;

        case TYarray:
            type* targ1, targ2;
            argtypes(t, targ1, targ2);
            if (targ1)
                ty1 = targ1.Tty;
            else
                return 0;
            if (targ2)
                ty2 = targ2.Tty;
            break;

        case TYstruct:
            assert(t);
            if (I64)
            {
                assert(tybasic(t.Tty) == TYstruct);
                if (const targ1 = t.Ttag.Sstruct.Sarg1type)
                    ty1 = targ1.Tty;
                else
                    return 0;
                if (const targ2 = t.Ttag.Sstruct.Sarg2type)
                    ty2 = targ2.Tty;
                break;
            }
            return 0;

        default:
            break;
    }

    /* now we have ty1 and ty2, use that to determine which register
     * is used for ty1 and which for ty2
     */

    static struct RetRegsAllocator
    {
    nothrow:
        static immutable reg_t[2] gpr_regs = [AX, DX];
        static immutable reg_t[2] xmm_regs = [XMM0, XMM1];
        static immutable reg_t[2] fpt_regs = [32, 33]; // AArch64 V0, V1

        uint cntgpr = 0,
             cntxmm = 0,
             cntfpt = 0;

        reg_t gpr() { return gpr_regs[cntgpr++]; }
        reg_t xmm() { return xmm_regs[cntxmm++]; }
        reg_t fpt() { return fpt_regs[cntfpt++]; }
    }

    RetRegsAllocator rralloc;

    reg_t allocreg(tym_t tym)
    {
        if (tym == TYMAX)
            return NOREG;
        switch (tysize(tym))
        {
        case 1:
        case 2:
        case 4:
            if (tyfloating(tym))
            {
                if (AArch64)
                    return rralloc.fpt();
                return I64 ? rralloc.xmm() : ST0;
            }
            else
                return rralloc.gpr();

        case 8:
            if (tycomplex(tym))
            {
                assert(!AArch64);
                assert(tyfb == TYjfunc && I32);
                return ST01;
            }
            else if (AArch64 && tyfloating(tym))
                return rralloc.fpt();
            else if (tysimd(tym))
            {
                return rralloc.xmm();
            }
            assert(I64 || tyfloating(tym));
            goto case 4;

        default:
            assert(!AArch64);
            if (tybasic(tym) == TYldouble || tybasic(tym) == TYildouble)
            {
                return ST0;
            }
            else if (tybasic(tym) == TYcldouble)
            {
                return ST01;
            }
            else if (tycomplex(tym) && tyfb == TYjfunc && I32)
            {
                return ST01;
            }
            else if (tysimd(tym))
            {
                return rralloc.xmm();
            }

            debug printf("%s\n", tym_str(tym));
            assert(0);
        }
    }

    reg1 = allocreg(ty1);
    reg2 = allocreg(ty2);

    //printf("reg1: %d reg2: %d NOREG: %d\n", reg1, reg2, NOREG);
    //printf("reg1: %llx reg2: %llx ~NOREG: %llx\n", mask(reg1), mask(reg2), ~mask(NOREG));
    return (mask(reg1) | mask(reg2)) & ~mask(NOREG);
}

/***********************************************
 * Struct necessary for sorting switch cases.
 */

private alias _compare_fp_t = extern(C) nothrow int function(const void*, const void*);
extern(C) void qsort(void* base, size_t nmemb, size_t size, _compare_fp_t compar);

struct CaseVal
{
    targ_ullong val;
    block* target;

    /* Sort function for qsort() */
    @trusted
    extern (C) static nothrow pure @nogc int cmp(scope const(void*) p, scope const(void*) q)
    {
        const(CaseVal)* c1 = cast(const(CaseVal)*)p;
        const(CaseVal)* c2 = cast(const(CaseVal)*)q;
        return (c1.val < c2.val) ? -1 : ((c1.val == c2.val) ? 0 : 1);
    }
}

/***
 * Generate comparison of [reg2,reg] with val
 */
@trusted
private void cmpval(ref CodeBuilder cdb, targ_llong val, uint sz, reg_t reg, reg_t reg2, reg_t sreg)
{
    if (I64 && sz == 8)
    {
        assert(reg2 == NOREG);
        if (val == cast(int)val)    // if val is a 64 bit value sign-extended from 32 bits
        {
            cdb.genc2(0x81,modregrmx(3,7,reg),cast(targ_size_t)val);     // CMP reg,value32
            cdb.last().Irex |= REX_W;                  // 64 bit operand
        }
        else
        {
            assert(sreg != NOREG);
            movregconst(cdb,sreg,cast(targ_size_t)val,64);  // MOV sreg,val64
            genregs(cdb,0x3B,reg,sreg);    // CMP reg,sreg
            code_orrex(cdb.last(), REX_W);
            getregsNoSave(mask(sreg));                  // don't remember we loaded this constant
        }
    }
    else if (reg2 == NOREG)
        cdb.genc2(0x81,modregrmx(3,7,reg),cast(targ_size_t)val);         // CMP reg,casevalue
    else
    {
        cdb.genc2(0x81,modregrm(3,7,reg2),cast(targ_size_t)MSREG(val));  // CMP reg2,MSREG(casevalue)
        code* cnext = gennop(null);
        genjmp(cdb,JNE,FL.code,cast(block*) cnext);  // JNE cnext
        cdb.genc2(0x81,modregrm(3,7,reg),cast(targ_size_t)val);          // CMP reg,casevalue
        cdb.append(cnext);
    }
}

@trusted extern (D)
private void ifthen(ref CodeBuilder cdb, scope CaseVal[] casevals,
        uint sz, reg_t reg, reg_t reg2, reg_t sreg, block* bdefault, bool last)
{
    const ncases = casevals.length;
    if (ncases >= 4 && config.flags4 & CFG4speed)
    {
        size_t pivot = ncases >> 1;

        // Compares for casevals[0..pivot]
        CodeBuilder cdb1; cdb1.ctor();
        ifthen(cdb1, casevals[0 .. pivot], sz, reg, reg2, sreg, bdefault, true);

        // Compares for casevals[pivot+1..ncases]
        CodeBuilder cdb2; cdb2.ctor();
        ifthen(cdb2, casevals[pivot + 1 .. $], sz, reg, reg2, sreg, bdefault, last);
        code* c2 = gennop(null);

        // Compare for caseval[pivot]
        cmpval(cdb, casevals[pivot].val, sz, reg, reg2, sreg);
        genjmp(cdb,JE,FL.block,casevals[pivot].target); // JE target
        // Note uint jump here, as cases were sorted using uint comparisons
        genjmp(cdb,JA,FL.code,cast(block*) c2);           // JG c2

        cdb.append(cdb1);
        cdb.append(c2);
        cdb.append(cdb2);
    }
    else
    {   // Not worth doing a binary search, just do a sequence of CMP/JE
        foreach (size_t n; 0 .. ncases)
        {
            targ_llong val = casevals[n].val;
            cmpval(cdb, val, sz, reg, reg2, sreg);
            code* cnext = null;
            if (reg2 != NOREG)
            {
                cnext = gennop(null);
                genjmp(cdb,JNE,FL.code,cast(block*) cnext);  // JNE cnext
                cdb.genc2(0x81,modregrm(3,7,reg2),cast(targ_size_t)MSREG(val));   // CMP reg2,MSREG(casevalue)
            }
            genjmp(cdb,JE,FL.block,casevals[n].target);   // JE caseaddr
            cdb.append(cnext);
        }

        if (last)       // if default is not next block
            genjmp(cdb,JMP,FL.block,bdefault);
    }
}

/*******************************
 * Generate code for blocks ending in a switch statement.
 * Take BC.switch_ and decide on
 *      BC.ifthen        use if - then code
 *      BC.jmptab        index into jump table
 *      BC.switch_        search table for match
 */

@trusted
void doswitch(ref CodeBuilder cdb, block* b)
{
    // If switch tables are in code segment and we need a CS: override to get at them
    bool csseg = cast(bool)(config.flags & CFGromable);

    //printf("doswitch(%d)\n", b.bc);
    elem* e = b.Belem;
    elem_debug(e);
    docommas(cdb,e);
    cgstate.stackclean++;
    tym_t tys = tybasic(e.Ety);
    int sz = _tysize[tys];
    bool dword = (sz == 2 * REGSIZE);
    targ_ulong msw;
    bool mswsame = true;                // assume all msw's are the same

    targ_llong vmax = long.min;         // smallest possible llong
    targ_llong vmin = long.max;         // largest possible llong
    foreach (n, val; b.Bswitch)         // find max and min case values
    {
        if (val > vmax) vmax = val;
        if (val < vmin) vmin = val;
        if (REGSIZE == 2)
        {
            ushort ms = (val >> 16) & 0xFFFF;
            if (n == 0)
                msw = ms;
            else if (msw != ms)
                mswsame = false;
        }
        else // REGSIZE == 4
        {
            targ_ulong ms = (val >> 32) & 0xFFFFFFFF;
            if (n == 0)
                msw = ms;
            else if (msw != ms)
                mswsame = false;
        }
    }
    //dbg_printf("vmax = x%lx, vmin = x%lx, vmax-vmin = x%lx\n",vmax,vmin,vmax - vmin);

    /* Three kinds of switch strategies - pick one
     */
    const ncases = b.Bswitch.length;
    if (ncases <= 3)
        goto Lifthen;
    else if (I16 && cast(targ_ullong)(vmax - vmin) <= ncases * 2)
        goto Ljmptab;           // >=50% of the table is case values, rest is default
    else if (config.flags3 & CFG3ibt)
        goto Lifthen;           // no jump table for ENDBR
    else if (cast(targ_ullong)(vmax - vmin) <= ncases * 3)
        goto Ljmptab;           // >= 33% of the table is case values, rest is default
    else if (I16)
        goto Lswitch;
    else
        goto Lifthen;

    /*************************************************************************/
    {   // generate if-then sequence
    Lifthen:
        regm_t retregs = ALLREGS;
        b.bc = BC.ifthen;
        scodelem(cgstate,cdb,e,retregs,0,true);
        reg_t reg, reg2;
        if (dword)
        {   reg = findreglsw(retregs);
            reg2 = findregmsw(retregs);
        }
        else
        {
            reg = findreg(retregs);     // reg that result is in
            reg2 = NOREG;
        }
        list_t bl = b.Bsucc;
        block* bdefault = b.nthSucc(0);
        if (dword && mswsame)
        {
            cdb.genc2(0x81,modregrm(3,7,reg2),msw);   // CMP reg2,MSW
            genjmp(cdb,JNE,FL.block,bdefault);  // JNE default
            reg2 = NOREG;
        }

        reg_t sreg = NOREG;                          // may need a scratch register

        // Put into casevals[0..ncases] so we can sort then slice

        import dmd.common.smallbuffer : SmallBuffer;
        CaseVal[10] tmp = void;
        auto sb = SmallBuffer!(CaseVal)(ncases, tmp[]);
        CaseVal[] casevals = sb[];

        foreach (n, val; b.Bswitch)
        {
            casevals[n].val = val;
            bl = list_next(bl);
            casevals[n].target = list_block(bl);

            // See if we need a scratch register
            if (sreg == NOREG && I64 && sz == 8 && val != cast(int)val)
            {   regm_t regm = ALLREGS & ~mask(reg);
                sreg = allocreg(cdb,regm, TYint);
            }
        }

        // Sort cases so we can do a runtime binary search
        qsort(casevals.ptr, casevals.length, CaseVal.sizeof, &CaseVal.cmp);

        //for (uint n = 0; n < ncases; n++)
            //printf("casevals[%lld] = x%x\n", n, casevals[n].val);

        // Generate binary tree of comparisons
        ifthen(cdb, casevals, sz, reg, reg2, sreg, bdefault, bdefault != b.Bnext);

        cgstate.stackclean--;
        return;
    }

    /*************************************************************************/
    {
        // Use switch value to index into jump table
    Ljmptab:
        //printf("Ljmptab:\n");

        b.bc = BC.jmptab;

        /* If vmin is small enough, we can just set it to 0 and the jump
         * table entries from 0..vmin-1 can be set with the default target.
         * This saves the SUB instruction.
         * Must be same computation as used in outjmptab().
         */
        if (vmin > 0 && vmin <= _tysize[TYint])
            vmin = 0;

        b.Btablesize = cast(int) (vmax - vmin + 1) * tysize(TYnptr);
        regm_t retregs = IDXREGS;
        if (dword)
            retregs |= mMSW;
        if (config.exe & EX_posix && I32 && config.flags3 & CFG3pic)
            retregs &= ~mBX;                            // need EBX for GOT
        bool modify = (I16 || I64 || vmin);
        scodelem(cgstate,cdb,e,retregs,0,!modify);
        reg_t reg = findreg(retregs & IDXREGS); // reg that result is in
        reg_t reg2;
        if (dword)
            reg2 = findregmsw(retregs);
        if (modify)
        {
            assert(!(retregs & cgstate.regcon.mvar));
            getregs(cdb,retregs);
        }
        if (vmin)                       // if there is a minimum
        {
            cdb.genc2(0x81,modregrm(3,5,reg),cast(targ_size_t)vmin); // SUB reg,vmin
            if (dword)
            {   cdb.genc2(0x81,modregrm(3,3,reg2),cast(targ_size_t)MSREG(vmin)); // SBB reg2,vmin
                genjmp(cdb,JNE,FL.block,b.nthSucc(0)); // JNE default
            }
        }
        else if (dword)
        {   gentstreg(cdb,reg2);              // TEST reg2,reg2
            genjmp(cdb,JNE,FL.block,b.nthSucc(0)); // JNE default
        }
        if (vmax - vmin != REGMASK)     // if there is a maximum
        {                               // CMP reg,vmax-vmin
            cdb.genc2(0x81,modregrm(3,7,reg),cast(targ_size_t)(vmax-vmin));
            if (I64 && sz == 8)
                code_orrex(cdb.last(), REX_W);
            genjmp(cdb,JA,FL.block,b.nthSucc(0));  // JA default
        }
        if (I64)
        {
            if (!vmin)
            {   // Need to clear out high 32 bits of reg
                // Use 8B instead of 89, as 89 will be optimized away as a NOP
                genregs(cdb,0x8B,reg,reg);                 // MOV reg,reg
            }
            if (config.flags3 & CFG3pic || config.exe == EX_WIN64)
            {
                /* LEA    R1,disp[RIP]          48 8D 05 00 00 00 00
                 * MOVSXD R2,[reg*4][R1]        48 63 14 B8
                 * LEA    R1,[R1][R2]           48 8D 04 02
                 * JMP    R1                    FF E0
                 */
                regm_t scratchm = ALLREGS & ~mask(reg);
                const r1 = allocreg(cdb,scratchm,TYint);
                scratchm = ALLREGS & ~(mask(reg) | mask(r1));
                const r2 = allocreg(cdb,scratchm,TYint);

                CodeBuilder cdbe; cdbe.ctor();
                cdbe.genc1(LEA,(REX_W << 16) | modregxrm(0,r1,5),FL.switch_,0);        // LEA R1,disp[RIP]
                cdbe.last().IEV1.Vswitch = b;
                cdbe.gen2sib(0x63,(REX_W << 16) | modregxrm(0,r2,4), modregxrmx(2,reg,r1)); // MOVSXD R2,[reg*4][R1]
                cdbe.gen2sib(LEA,(REX_W << 16) | modregxrm(0,r1,4),modregxrmx(0,r1,r2));    // LEA R1,[R1][R2]
                cdbe.gen2(0xFF,modregrmx(3,4,r1));                                          // JMP R1

                b.Btablesize = cast(int) (vmax - vmin + 1) * 4;
                code* ce = cdbe.finish();
                pinholeopt(ce, null);

                cdb.append(cdbe);
            }
            else
            {
                cdb.genc1(0xFF,modregrm(0,4,4),FL.switch_,0);   // JMP disp[reg*8]
                cdb.last().IEV1.Vswitch = b;
                cdb.last().Isib = modregrm(3,reg & 7,5);
                if (reg & 8)
                    cdb.last().Irex |= REX_X;
            }
        }
        else if (I32)
        {
static if (JMPJMPTABLE)
{
            /* LEA jreg,offset ctable[reg][reg * 4]
               JMP jreg
              ctable:
               JMP case0
               JMP case1
               ...
             */
            CodeBuilder ctable; ctable.ctor();
            block* bdef = b.nthSucc(0);
            targ_llong u;
            for (u = vmin; ; u++)
            {   block* targ = bdef;
                foreach (n, val; b.Bswitch)
                {
                    if (val == u)
                    {   targ = b.nthSucc(n + 1);
                        break;
                    }
                }
                genjmp(ctable,JMP,FL.block,targ);
                ctable.last().Iflags |= CFjmp5;           // don't shrink these
                if (u == vmax)
                    break;
            }

            // Allocate scratch register jreg
            regm_t scratchm = ALLREGS & ~mask(reg);
            const jreg = allocreg(cdb,scratchm,TYint);

            // LEA jreg, offset ctable[reg][reg*4]
            cdb.genc1(LEA,modregrm(2,jreg,4),FL.code,6);
            cdb.last().Isib = modregrm(2,reg,reg);
            cdb.gen2(0xFF,modregrm(3,4,jreg));      // JMP jreg
            cdb.append(ctable);
            b.Btablesize = 0;
            cgstate.stackclean--;
            return;
}
else
{
        if (config.exe & (EX_OSX | EX_OSX64))
        {
            /*     CALL L1
             * L1: POP  R1
             *     ADD  R1,disp[reg*4][R1]
             *     JMP  R1
             */
            // Allocate scratch register r1
            regm_t scratchm = ALLREGS & ~mask(reg);
            const r1 = allocreg(cdb,scratchm,TYint);

            cdb.genc2(CALL,0,0);                           //     CALL L1
            cdb.genpop(r1);                                // L1: POP R1
            cdb.genc1(0x03,modregrm(2,r1,4),FL.switch_,0);   // ADD R1,disp[reg*4][EBX]
            cdb.last().IEV1.Vswitch = b;
            cdb.last().Isib = modregrm(2,reg,r1);
            cdb.gen2(0xFF,modregrm(3,4,r1));               // JMP R1
        }
        else
        {
            if (config.flags3 & CFG3pic)
            {
                /* MOV  R1,EBX
                 * SUB  R1,funcsym_p@GOTOFF[offset][reg*4][EBX]
                 * JMP  R1
                 */

                // Load GOT in EBX
                load_localgot(cdb);

                // Allocate scratch register r1
                regm_t scratchm = ALLREGS & ~(mask(reg) | mBX);
                const r1 = allocreg(cdb,scratchm,TYint);

                genmovreg(cdb,r1,BX);              // MOV R1,EBX
                cdb.genc1(0x2B,modregxrm(2,r1,4),FL.switch_,0);   // SUB R1,disp[reg*4][EBX]
                cdb.last().IEV1.Vswitch = b;
                cdb.last().Isib = modregrm(2,reg,BX);
                cdb.gen2(0xFF,modregrmx(3,4,r1));               // JMP R1
            }
            else
            {
                cdb.genc1(0xFF,modregrm(0,4,4),FL.switch_,0);     // JMP disp[idxreg*4]
                cdb.last().IEV1.Vswitch = b;
                cdb.last().Isib = modregrm(2,reg,5);
            }
        }
}
        }
        else if (I16)
        {
            cdb.gen2(0xD1,modregrm(3,4,reg));                   // SHL reg,1
            uint rm = getaddrmode(retregs) | modregrm(0,4,0);
            cdb.genc1(0xFF,rm,FL.switch_,0);                  // JMP [CS:]disp[idxreg]
            cdb.last().IEV1.Vswitch = b;
            cdb.last().Iflags |= csseg ? CFcs : 0;                       // segment override
        }
        else
            assert(0);
        cgstate.stackclean--;
        return;
    }

    /*************************************************************************/
    {
        /* Scan a table of case values, and jump to corresponding address.
         * Since it relies on REPNE SCASW, it has really nothing to recommend it
         * over Lifthen for 32 and 64 bit code.
         * Note that it has not been tested with MACHOBJ (OSX).
         */
    Lswitch:
        regm_t retregs = mAX;                  // SCASW requires AX
        if (dword)
            retregs |= mDX;
        else if (ncases <= 6 || config.flags4 & CFG4speed)
            goto Lifthen;
        scodelem(cgstate,cdb,e,retregs,0,true);
        if (dword && mswsame)
        {   /* CMP DX,MSW       */
            cdb.genc2(0x81,modregrm(3,7,DX),msw);
            genjmp(cdb,JNE,FL.block,b.nthSucc(0)); // JNE default
        }
        getregs(cdb,mCX|mDI);

        if (config.flags3 & CFG3pic && config.exe & EX_posix)
        {   // Add in GOT
            getregs(cdb,mDX);
            cdb.genc2(CALL,0,0);        //     CALL L1
            cdb.genpop(DI);             // L1: POP EDI

                                        //     ADD EDI,_GLOBAL_OFFSET_TABLE_+3
            Symbol* gotsym = Obj.getGOTsym();
            cdb.gencs(0x81,modregrm(3,0,DI),FL.extern_,gotsym);
            cdb.last().Iflags = CFoff;
            cdb.last().IEV2.Voffset = 3;

            makeitextern(gotsym);

            genmovreg(cdb, DX, DI);    // MOV EDX, EDI
                                        // ADD EDI,offset of switch table
            cdb.gencs(0x81,modregrm(3,0,DI),FL.switch_,null);
            cdb.last().IEV2.Vswitch = b;
        }

        if (!(config.flags3 & CFG3pic))
        {
                                        // MOV DI,offset of switch table
            cdb.gencs(0xC7,modregrm(3,0,DI),FL.switch_,null);
            cdb.last().IEV2.Vswitch = b;
        }
        movregconst(cdb,CX,ncases,0);    // MOV CX,ncases

        /* The switch table will be accessed through ES:DI.
         * Therefore, load ES with proper segment value.
         */
        if (config.flags3 & CFG3eseqds)
        {
            assert(!csseg);
            getregs(cdb,mCX);           // allocate CX
        }
        else
        {
            getregs(cdb,mES|mCX);       // allocate ES and CX
            cdb.gen1(csseg ? 0x0E : 0x1E);      // PUSH CS/DS
            cdb.gen1(0x07);                     // POP  ES
        }

        targ_size_t disp = (ncases - 1) * _tysize[TYint];  // displacement to jump table
        if (dword && !mswsame)
        {

            /* Build the following:
                L1:     SCASW
                        JNE     L2
                        CMP     DX,[CS:]disp[DI]
                L2:     LOOPNE  L1
             */

            const int mod = (disp > 127) ? 2 : 1;         // displacement size
            code* cloop = genc2(null,0xE0,0,-7 - mod - csseg);   // LOOPNE scasw
            cdb.gen1(0xAF);                                      // SCASW
            code_orflag(cdb.last(),CFtarg2);                     // target of jump
            genjmp(cdb,JNE,FL.code,cast(block*) cloop); // JNE loop
                                                                 // CMP DX,[CS:]disp[DI]
            cdb.genc1(0x39,modregrm(mod,DX,5),FL.const_,disp);
            cdb.last().Iflags |= csseg ? CFcs : 0;              // possible seg override
            cdb.append(cloop);
            disp += ncases * _tysize[TYint];           // skip over msw table
        }
        else
        {
            cdb.gen1(0xF2);              // REPNE
            cdb.gen1(0xAF);              // SCASW
        }
        genjmp(cdb,JNE,FL.block,b.nthSucc(0)); // JNE default
        const int mod = (disp > 127) ? 2 : 1;     // 1 or 2 byte displacement
        if (csseg)
            cdb.gen1(SEGCS);            // table is in code segment

        if (config.flags3 & CFG3pic &&
            config.exe & EX_posix)
        {                               // ADD EDX,(ncases-1)*2[EDI]
            cdb.genc1(0x03,modregrm(mod,DX,7),FL.const_,disp);
                                        // JMP EDX
            cdb.gen2(0xFF,modregrm(3,4,DX));
        }

        if (!(config.flags3 & CFG3pic))
        {                               // JMP (ncases-1)*2[DI]
            cdb.genc1(0xFF,modregrm(mod,4,(I32 ? 7 : 5)),FL.const_,disp);
            cdb.last().Iflags |= csseg ? CFcs : 0;
        }
        b.Btablesize = disp + _tysize[TYint] + ncases * tysize(TYnptr);
        //assert(b.Bcode);
        cgstate.stackclean--;
        return;
    }
}

/******************************
 * Output data block for a jump table (BC.jmptab).
 * The 'holes' in the table get filled with the
 * default label.
 */

@trusted
void outjmptab(block* b)
{
    if (JMPJMPTABLE && I32)
        return;

    const ncases = b.Bswitch.length;        // number of cases

    /* Find vmin and vmax, the range of the table will be [vmin .. vmax + 1]
     * Must be same computation as used in doswitch().
     */
    targ_llong vmax = long.min;              // smallest possible llong
    targ_llong vmin = long.max;              // largest possible llong
    foreach (val; b.Bswitch)                 // find min case value
    {
        if (val > vmax) vmax = val;
        if (val < vmin) vmin = val;
    }
    if (vmin > 0 && vmin <= _tysize[TYint])
        vmin = 0;
    assert(vmin <= vmax);

    /* Segment and offset into which the jump table will be emitted
     */
    int jmpseg = objmod.jmpTableSegment(funcsym_p);
    targ_size_t* poffset = &Offset(jmpseg);

    /* Align start of jump table
     */
    targ_size_t alignbytes = _align(0,*poffset) - *poffset;
    objmod.lidata(jmpseg,*poffset,alignbytes);
    assert(*poffset == b.Btableoffset);        // should match precomputed value

    Symbol* gotsym = null;
    targ_size_t def = b.nthSucc(0).Boffset;  // default address
    for (targ_llong u = vmin; ; u++)
    {   targ_size_t targ = def;                     // default
        foreach (n; 0 .. ncases)
        {
            if (b.Bswitch[n] == u)
            {
                targ = b.nthSucc(cast(int)(n + 1)).Boffset;
                break;
            }
        }
        if (config.exe & (EX_LINUX64 | EX_FREEBSD64 | EX_OPENBSD64 | EX_DRAGONFLYBSD64 | EX_SOLARIS64))
        {
            if (config.flags3 & CFG3pic)
            {
                objmod.reftodatseg(jmpseg,*poffset,cast(targ_size_t)(targ + (u - vmin) * 4),funcsym_p.Sseg,CFswitch);
                *poffset += 4;
            }
            else
            {
                objmod.reftodatseg(jmpseg,*poffset,targ,funcsym_p.Sxtrnnum,CFoffset64 | CFswitch);
                *poffset += 8;
            }
        }
        else if (config.exe & (EX_LINUX | EX_FREEBSD | EX_OPENBSD | EX_SOLARIS))
        {
            if (config.flags3 & CFG3pic)
            {
                assert(config.flags & CFGromable);
                // Want a GOTPC fixup to _GLOBAL_OFFSET_TABLE_
                if (!gotsym)
                    gotsym = Obj.getGOTsym();
                objmod.reftoident(jmpseg,*poffset,gotsym,*poffset - targ,CFswitch);
            }
            else
                objmod.reftocodeseg(jmpseg,*poffset,targ);
            *poffset += 4;
        }
        else if (config.exe & (EX_OSX | EX_OSX64) || I64)
        {
            const val = cast(uint)(targ - (I64 ? b.Btableoffset : b.Btablebase));
            objmod.write_bytes(SegData[jmpseg],(&val)[0 .. 1]);
        }
        else
        {
            objmod.reftocodeseg(jmpseg,*poffset,targ);
            *poffset += tysize(TYnptr);
        }

        if (u == vmax)                  // for case that (vmax == ~0)
            break;
    }
}


/******************************
 * Output data block for a switch table.
 * Two consecutive tables, the first is the case value table, the
 * second is the address table.
 */

@trusted
void outswitab(block* b)
{
    //printf("outswitab()\n");
    const ncases = b.Bswitch.length;     // number of cases

    const int seg = objmod.jmpTableSegment(funcsym_p);
    targ_size_t* poffset = &Offset(seg);
    targ_size_t offset = *poffset;
    targ_size_t alignbytes = _align(0,*poffset) - *poffset;
    objmod.lidata(seg,*poffset,alignbytes);  // any alignment bytes necessary
    assert(*poffset == offset + alignbytes);

    uint sz = _tysize[TYint];
    assert(SegData[seg].SDseg == seg);
    foreach (val; b.Bswitch)          // send out value table
    {
        //printf("\tcase %d, offset = x%x\n", n, *poffset);
        objmod.write_bytes(SegData[seg],(cast(void*)&val)[0 .. sz]);
    }
    offset += alignbytes + sz * ncases;
    assert(*poffset == offset);

    if (b.Btablesize == ncases * (REGSIZE * 2 + tysize(TYnptr)))
    {
        // Send out MSW table
        foreach (val; b.Bswitch)
        {
            auto msval = cast(targ_size_t)MSREG(val);
            objmod.write_bytes(SegData[seg],(cast(void*)&msval)[0 .. REGSIZE]);
        }
        offset += REGSIZE * ncases;
        assert(*poffset == offset);
    }

    list_t bl = b.Bsucc;
    foreach (n; 0 .. ncases)          // send out address table
    {
        bl = list_next(bl);
        objmod.reftocodeseg(seg,*poffset,list_block(bl).Boffset);
        *poffset += tysize(TYnptr);
    }
    assert(*poffset == offset + ncases * tysize(TYnptr));
}

/*****************************
 * Return a jump opcode relevant to the elem for a JMP true.
 */

@trusted
int jmpopcode(elem* e)
{
    //printf("jmpopcode()\n"); elem_print(e);
    tym_t tym;
    int zero,i,jp,op;
    static immutable ubyte[6][2][2] jops =
    [   /* <=  >   <   >=  ==  !=    <=0 >0  <0  >=0 ==0 !=0    */
       [ [JLE,JG ,JL ,JGE,JE ,JNE],[JLE,JG ,JS ,JNS,JE ,JNE] ], /* signed   */
       [ [JBE,JA ,JB ,JAE,JE ,JNE],[JE ,JNE,JB ,JAE,JE ,JNE] ], /* uint */
/+
       [ [JLE,JG ,JL ,JGE,JE ,JNE],[JLE,JG ,JL ,JGE,JE ,JNE] ], /* real     */
       [ [JBE,JA ,JB ,JAE,JE ,JNE],[JBE,JA ,JB ,JAE,JE ,JNE] ], /* 8087     */
       [ [JA ,JBE,JAE,JB ,JE ,JNE],[JBE,JA ,JB ,JAE,JE ,JNE] ], /* 8087 R   */
+/
    ];

    enum
    {
        XP     = (JP  << 8),
        XNP    = (JNP << 8),
    }
    static immutable uint[26][1] jfops =
    /*   le     gt lt     ge  eqeq    ne     unord lg  leg  ule ul uge  */
    [
      [ XNP|JBE,JA,XNP|JB,JAE,XNP|JE, XP|JNE,JP,   JNE,JNP, JBE,JC,XP|JAE,

    /*  ug    ue ngt nge nlt    nle    ord nlg nleg nule nul nuge    nug     nue */
        XP|JA,JE,JBE,JB, XP|JAE,XP|JA, JNP,JE, JP,  JA,  JNC,XNP|JB, XNP|JBE,JNE        ], /* 8087     */
    ];

    assert(e);
    while (e.Eoper == OPcomma ||
        /* The OTleaf(e.E1.Eoper) is to line up with the case in cdeq() where  */
        /* we decide if mPSW is passed on when evaluating E2 or not.    */
         (e.Eoper == OPeq && OTleaf(e.E1.Eoper)))
    {
        e = e.E2;                      /* right operand determines it  */
    }

    op = e.Eoper;
    tym_t tymx = tybasic(e.Ety);
    bool needsNanCheck = tyfloating(tymx) && config.inline8087 &&
        (tymx == TYldouble || tymx == TYildouble || tymx == TYcldouble ||
         tymx == TYcdouble || tymx == TYcfloat ||
         (tyxmmreg(tymx) && config.fpxmmregs && e.Ecount != e.Ecomsub) ||
         op == OPind ||
         (OTcall(op) && (regmask(tymx, tybasic(e.E1.Eoper)) & (mST0 | XMMREGS))));

    if (!needsNanCheck)
    {
        /* If e is in an XMM register, need to use XP.
         * Match same test in loaddata()
         */
        Symbol* s;
        needsNanCheck = e.Eoper == OPvar &&
            (s = e.Vsym).Sfl == FL.reg &&
             s.Sregm & XMMREGS &&
             (tymx == TYfloat || tymx == TYifloat || tymx == TYdouble || tymx ==TYidouble);
    }

    if (e.Ecount != e.Ecomsub)          // comsubs just get Z bit set
    {
        if (needsNanCheck) // except for floating point values that need a NaN check
            return XP|JNE;
        else
            return JNE;
    }
    if (!OTrel(op))                       // not relational operator
    {
        if (needsNanCheck)
            return XP|JNE;

        if (op == OPu32_64) { e = e.E1; op = e.Eoper; }
        if (op == OPu16_32) { e = e.E1; op = e.Eoper; }
        if (op == OPu8_16) op = e.E1.Eoper;
        return ((op >= OPbt && op <= OPbts) || op == OPbtst) ? JC : JNE;
    }

    if (e.E2.Eoper == OPconst)
        zero = !boolres(e.E2);
    else
        zero = 0;

    tym = e.E1.Ety;
    if (tyfloating(tym))
    {
static if (1)
{
        i = 0;
        if (config.inline8087)
        {   i = 1;

static if (1)
{
            if (rel_exception(op) || config.flags4 & CFG4fastfloat)
            {
                const bool NOSAHF = (I64 || config.fpxmmregs);
                if (zero)
                {
                    if (NOSAHF)
                        op = swaprel(op);
                }
                else if (NOSAHF)
                    op = swaprel(op);
                else if (cmporder87(e.E2))
                    op = swaprel(op);
                else
                { }
            }
            else
            {
                if (zero && config.target_cpu < TARGET_80386)
                { }
                else
                    op = swaprel(op);
            }
}
else
{
            if (zero && !rel_exception(op) && config.target_cpu >= TARGET_80386)
                op = swaprel(op);
            else if (!zero &&
                (cmporder87(e.E2) || !(rel_exception(op) || config.flags4 & CFG4fastfloat)))
                /* compare is reversed */
                op = swaprel(op);
}
        }
        jp = jfops[0][op - OPle];
        goto L1;
}
else
{
        i = (config.inline8087) ? (3 + cmporder87(e.E2)) : 2;
}
    }
    else if (tyuns(tym) || tyuns(e.E2.Ety))
        i = 1;
    else if (tyintegral(tym) || typtr(tym))
        i = 0;
    else
    {
        debug
        elem_print(e);
        printf("%s\n", tym_str(tym));
        assert(0);
    }

    jp = jops[i][zero][op - OPle];        /* table starts with OPle       */

    /* Try to rewrite uint comparisons so they rely on just the Carry flag
     */
    if (i == 1 && (jp == JA || jp == JBE) &&
        (e.E2.Eoper != OPconst && e.E2.Eoper != OPrelconst))
    {
        jp = (jp == JA) ? JC : JNC;
    }

L1:
    debug
    if ((jp & 0xF0) != 0x70)
    {
        printf("%s i %d zero %d op x%x jp x%x\n",oper_str(op),i,zero,op,jp);
    }

    assert((jp & 0xF0) == 0x70);
    return jp;
}

/**********************************
 * Append code to cdb which validates pointer described by
 * addressing mode in *pcs. Modify addressing mode in *pcs.
 * Params:
 *    cdb = append generated code to this
 *    pcs = original addressing mode to be updated
 *    keepmsk = mask of registers we must not destroy or use
 */

@trusted
void cod3_ptrchk(ref CodeBuilder cdb,ref code pcs,regm_t keepmsk)
{
    ubyte sib;
    reg_t reg;
    uint flagsave;

    assert(!I64);
    if (!I16 && pcs.Iflags & (CFes | CFss | CFcs | CFds | CFfs | CFgs))
        return;         // not designed to deal with 48 bit far pointers

    ubyte rm = pcs.Irm;
    assert(!(rm & 0x40));       // no disp8 or reg addressing modes

    // If the addressing mode is already a register
    reg = rm & 7;
    if (I16)
    {   static immutable ubyte[8] imode = [ BP,BP,BP,BP,SI,DI,BP,BX ];

        reg = imode[reg];               // convert [SI] to SI, etc.
    }
    regm_t idxregs = mask(reg);
    if ((rm & 0x80 && (pcs.IFL1 != FL.offset || pcs.IEV1.Vuns)) ||
        !(idxregs & ALLREGS)
       )
    {
        // Load the offset into a register, so we can push the address
        regm_t idxregs2 = (I16 ? IDXREGS : ALLREGS) & ~keepmsk; // only these can be index regs
        assert(idxregs2);
        reg = allocreg(cdb,idxregs2,TYoffset);

        const opsave = pcs.Iop;
        flagsave = pcs.Iflags;
        pcs.Iop = LEA;
        pcs.Irm |= modregrm(0,reg,0);
        pcs.Iflags &= ~(CFopsize | CFss | CFes | CFcs);        // no prefix bytes needed
        cdb.gen(&pcs);                 // LEA reg,EA

        pcs.Iflags = flagsave;
        pcs.Iop = opsave;
    }

    // registers destroyed by the function call
    //used = (mBP | ALLREGS | mES) & ~fregsaved;
    regm_t used = 0;                           // much less code generated this way

    code* cs2 = null;
    regm_t tosave = used & (keepmsk | idxregs);
    for (int i = 0; tosave; i++)
    {
        regm_t mi = mask(i);

        assert(i < REGMAX);
        if (mi & tosave)        /* i = register to save                 */
        {
            int push,pop;

            cgstate.stackchanged = 1;
            if (i == ES)
            {   push = 0x06;
                pop = 0x07;
            }
            else
            {   push = 0x50 | i;
                pop  = 0x58 | i;
            }
            cdb.gen1(push);                     // PUSH i
            cs2 = cat(gen1(null,pop),cs2);      // POP i
            tosave &= ~mi;
        }
    }

    // For 16 bit models, push a far pointer
    if (I16)
    {
        int segreg;

        switch (pcs.Iflags & (CFes | CFss | CFcs | CFds | CFfs | CFgs))
        {   case CFes:  segreg = 0x06;  break;
            case CFss:  segreg = 0x16;  break;
            case CFcs:  segreg = 0x0E;  break;
            case 0:     segreg = 0x1E;  break;  // DS
            default:
                assert(0);
        }

        // See if we should default to SS:
        // (Happens when BP is part of the addressing mode)
        if (segreg == 0x1E && (rm & 0xC0) != 0xC0 &&
            rm & 2 && (rm & 7) != 7)
        {
            segreg = 0x16;
            if (config.wflags & WFssneds)
                pcs.Iflags |= CFss;    // because BP won't be there anymore
        }
        cdb.gen1(segreg);               // PUSH segreg
    }

    cdb.genpush(reg);               // PUSH reg

    // Rewrite the addressing mode in *pcs so it is just 0[reg]
    setaddrmode(pcs, idxregs);
    pcs.IFL1 = FL.offset;
    pcs.IEV1.Vuns = 0;

    // Call the validation function
    {
        makeitextern(getRtlsym(RTLSYM.PTRCHK));

        used &= ~(keepmsk | idxregs);           // regs destroyed by this exercise
        getregs(cdb,used);
                                                // CALL __ptrchk
        cdb.gencs((LARGECODE) ? 0x9A : CALL,0,FL.func,getRtlsym(RTLSYM.PTRCHK));
    }

    cdb.append(cs2);
}

/***********************************
 * Determine if BP can be used as a general purpose register.
 * Note parallels between this routine and prolog().
 * Returns:
 *      0       cannot be used, needed for frame
 *      mBP     can be used
 */

@trusted
regm_t cod3_useBP()
{
    tym_t tym;
    tym_t tyf;

    // Note that DOSX memory model cannot use EBP as a general purpose
    // register, as SS != DS.
    if (!(config.exe & EX_flat) || config.flags & (CFGalwaysframe | CFGnoebp))
        goto Lcant;

    if (cgstate.anyiasm)
        goto Lcant;

    tyf = funcsym_p.ty();
    if (tyf & mTYnaked)                 // if no prolog/epilog for function
        goto Lcant;

    if (funcsym_p.Sfunc.Fflags3 & Ffakeeh)
    {
        goto Lcant;                     // need consistent stack frame
    }

    tym = tybasic(tyf);
    if (tym == TYifunc)
        goto Lcant;

    stackoffsets(cgstate, globsym, true);  // estimate stack offsets
    localsize = cgstate.Auto.offset + cgstate.Fast.offset;                // an estimate only
//    if (localsize)
    {
        if (!(config.flags4 & CFG4speed) ||
            config.target_cpu < TARGET_Pentium ||
            tyfarfunc(tym) ||
            config.flags & CFGstack ||
            localsize >= 0x100 ||       // arbitrary value < 0x1000
            (cgstate.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru)) ||
            cgstate.calledFinally ||
            cgstate.Alloca.size
           )
            goto Lcant;
    }
    return mBP;

Lcant:
    return 0;
}

/*************************************************
 * Generate instruction to be used later to restore a cse
 * Params:
 *      c = fill in with instruction
 *      e = examined to see if it can be restored with a simple instruction
 * Returns:
 *      true means it can be so used and c is filled in
 */

@trusted
bool cse_simple(code* c, elem* e)
{
    if (cgstate.AArch64)
        return false;           // TODO AArch64

    regm_t regm;
    reg_t reg;
    int sz = tysize(e.Ety);

    if (!I16 &&                                  // don't bother with 16 bit code
        e.Eoper == OPadd &&
        sz == REGSIZE &&
        e.E2.Eoper == OPconst &&
        e.E1.Eoper == OPvar &&
        isregvar(e.E1,regm,reg) &&
        !(e.E1.Vsym.Sflags & SFLspill)
       )
    {
        memset(c,0,(*c).sizeof);

        // Make this an LEA instruction
        c.Iop = LEA;
        buildEA(c,reg,-1,1,e.E2.Vuns);
        if (I64)
        {   if (sz == 8)
                c.Irex |= REX_W;
        }

        return true;
    }
    else if (e.Eoper == OPind &&
        sz <= REGSIZE &&
        e.E1.Eoper == OPvar &&
        isregvar(e.E1,regm,reg) &&
        (I32 || I64 || regm & IDXREGS) &&
        !(e.E1.Vsym.Sflags & SFLspill)
       )
    {
        memset(c,0,(*c).sizeof);

        // Make this a MOV instruction
        c.Iop = (sz == 1) ? 0x8A : 0x8B;       // MOV reg,EA
        buildEA(c,reg,-1,1,0);
        if (sz == 2 && I32)
            c.Iflags |= CFopsize;
        else if (I64)
        {   if (sz == 8)
                c.Irex |= REX_W;
        }

        return true;
    }
    return false;
}

/**************************
 * Store `reg` to the common subexpression save area in index `slot`.
 * Params:
 *      cdb = where to write code to
 *      tym = type of value that's in `reg`
 *      reg = register to save
 *      slot = index into common subexpression save area
 */
@trusted
void gen_storecse(ref CodeBuilder cdb, tym_t tym, reg_t reg, size_t slot)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.gen_storecse(cdb,tym,reg,slot);

    //printf("gen_storecse()\n");
    // MOV slot[BP],reg
    if (isXMMreg(reg) && config.fpxmmregs) // watch out for ES
    {
        const aligned = tyvector(tym) ? STACKALIGN >= 16 : true;
        const op = xmmstore(tym, aligned);
        cdb.genc1(op,modregxrm(2, reg - XMM0, BPRM),FL.cs,cast(targ_size_t)slot);
        return;
    }
    opcode_t op = STO;              // normal mov
    if (reg == ES)
    {
        reg = 0;            // the real reg number
        op = 0x8C;          // segment reg mov
    }
    cdb.genc1(op,modregxrm(2, reg, BPRM),FL.cs,cast(targ_uns)slot);
    if (I64)
        code_orrex(cdb.last(), REX_W);
}

@trusted
void gen_testcse(ref CodeBuilder cdb, tym_t tym, uint sz, size_t slot)
{
    //printf("gen_testcse()\n");
    // CMP slot[BP],0
    cdb.genc(sz == 1 ? 0x80 : 0x81,modregrm(2,7,BPRM),
                FL.cs,cast(targ_uns)slot, FL.const_,cast(targ_uns) 0);
    if ((I64 || I32) && sz == 2)
        cdb.last().Iflags |= CFopsize;
    if (I64 && sz == 8)
        code_orrex(cdb.last(), REX_W);
}

@trusted
void gen_loadcse(ref CodeBuilder cdb, tym_t tym, reg_t reg, size_t slot)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.gen_loadcse(cdb,tym,reg,slot);

    //printf("gen_loadcse()\n");
    // MOV reg,slot[BP]
    if (isXMMreg(reg) && config.fpxmmregs)
    {
        const aligned = tyvector(tym) ? STACKALIGN >= 16 : true;
        const op = xmmload(tym, aligned);
        cdb.genc1(op,modregxrm(2, reg - XMM0, BPRM),FL.cs,cast(targ_size_t)slot);
        return;
    }
    opcode_t op = LOD;
    if (reg == ES)
    {
        op = 0x8E;
        reg = 0;
    }
    cdb.genc1(op,modregxrm(2,reg,BPRM),FL.cs,cast(targ_uns)slot);
    if (I64)
        code_orrex(cdb.last(), REX_W);
}

/***************************************
 * Gen code for OPframeptr
 */

@trusted
void cdframeptr(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    regm_t retregs = pretregs & cgstate.allregs;
    if  (!retregs)
        retregs = cgstate.allregs;
    const reg = allocreg(cdb,retregs, TYint);

    code cs;
    cs.Iop = PSOP.frameptr;
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.Irm = cast(ubyte)reg;
    cdb.gen(&cs);
    fixresult(cdb,e,retregs,pretregs);
}

/***************************************
 * Gen code for load of _GLOBAL_OFFSET_TABLE_.
 * This value gets cached in the local variable 'localgot'.
 */

@trusted
void cdgot(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    if (config.exe & (EX_OSX | EX_OSX64))
    {
        regm_t retregs = pretregs & cgstate.allregs;
        if  (!retregs)
            retregs = cgstate.allregs;
        const reg = allocreg(cdb,retregs, TYnptr);

        cdb.genc(CALL,0,FL.unde,0,FL.got,0);     //     CALL L1
        cdb.genpop(reg);                  // L1: POP reg

        fixresult(cdb,e,retregs,pretregs);
    }
    else if (config.exe & EX_posix)
    {
        regm_t retregs = pretregs & cgstate.allregs;
        if  (!retregs)
            retregs = cgstate.allregs;
        const reg = allocreg(cdb,retregs, TYnptr);

        cdb.genc2(CALL,0,0);        //     CALL L1
        cdb.genpop(reg);            // L1: POP reg

                                    //     ADD reg,_GLOBAL_OFFSET_TABLE_+3
        Symbol* gotsym = Obj.getGOTsym();
        cdb.gencs(0x81,modregrm(3,0,reg),FL.extern_,gotsym);
        /* Because the 2:3 offset from L1: is hardcoded,
         * this sequence of instructions must not
         * have any instructions in between,
         * so set CFvolatile to prevent the scheduler from rearranging it.
         */
        code* cgot = cdb.last();
        cgot.Iflags = CFoff | CFvolatile;
        cgot.IEV2.Voffset = (reg == AX) ? 2 : 3;

        makeitextern(gotsym);
        fixresult(cdb,e,retregs,pretregs);
    }
    else
        assert(0);
}

/**************************************************
 * Load contents of localgot into EBX.
 */

@trusted
void load_localgot(ref CodeBuilder cdb)
{
    if (config.exe & (EX_LINUX | EX_FREEBSD | EX_OPENBSD | EX_SOLARIS)) // note: I32 only
    {
        if (config.flags3 & CFG3pic)
        {
            if (localgot && !(localgot.Sflags & SFLdead))
            {
                localgot.Sflags &= ~GTregcand;     // because this hack doesn't work with reg allocator
                elem* e = el_var(localgot);
                regm_t retregs = mBX;
                codelem(cgstate,cdb,e,retregs,false);
                el_free(e);
            }
            else
            {
                elem* e = el_long(TYnptr, 0);
                e.Eoper = OPgot;
                regm_t retregs = mBX;
                codelem(cgstate,cdb,e,retregs,false);
                el_free(e);
            }
        }
    }
}

/*****************************
 * Returns:
 *      # of bytes stored
 */


@trusted
int obj_namestring(char* p,const(char)* name)
{
    size_t len = strlen(name);
    if (len > 255)
    {
        short* ps = cast(short*)p;
        p[0] = 0xFF;
        p[1] = 0;
        ps[1] = cast(short)len;
        memcpy(p + 4,name,len);
        const int ONS_OHD = 4;           // max # of extra bytes added by obj_namestring()
        len += ONS_OHD;
    }
    else
    {
        p[0] = cast(char)len;
        memcpy(p + 1,name,len);
        len++;
    }
    return cast(int)len;
}

void genregs(ref CodeBuilder cdb,opcode_t op,uint dstreg,uint srcreg)
{
    return cdb.gen2(op,modregxrmx(3,dstreg,srcreg));
}

void gentstreg(ref CodeBuilder cdb, uint t)
{
    cdb.gen2(0x85,modregxrmx(3,t,t));   // TEST t,t
    code_orflag(cdb.last(),CFpsw);
}

void genpush(ref CodeBuilder cdb, reg_t reg)
{
    cdb.gen1(0x50 + (reg & 7));
    if (reg & 8)
        code_orrex(cdb.last(), REX_B);
}

void genpop(ref CodeBuilder cdb, reg_t reg)
{
    cdb.gen1(0x58 + (reg & 7));
    if (reg & 8)
        code_orrex(cdb.last(), REX_B);
}

/**************************
 * Generate a MOV to,from register instruction.
 * Smart enough to dump redundant register moves, and segment
 * register moves.
 */

@trusted
void genmovreg(ref CodeBuilder cdb, reg_t to, reg_t from, tym_t tym = TYMAX)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.genmovreg(cdb, cast(reg_t)to, cast(reg_t)from, tym);

    // register kind. ex: GPR,XMM,SEG
    static uint _K(uint reg)
    {
        switch (reg)
        {
        case ES:                   return ES;
        case XMM15:
        case XMM0: .. case XMM7:   return XMM0;
        case AX:   .. case R15:    return AX;
        default:                   return reg;
        }
    }

    // kind combination (order kept)
    static uint _X(uint to, uint from) { return (_K(to) << 8) + _K(from); }

    if (to != from)
    {
        if (tym == TYMAX) tym = TYsize_t; // avoid register slicing
        switch (_X(to, from))
        {
            case _X(AX, AX):
                genregs(cdb, 0x89, from, to);    // MOV to,from
                if (I64 && tysize(tym) >= 8)
                    code_orrex(cdb.last(), REX_W);
                break;

            case _X(XMM0, XMM0):             // MOVD/Q to,from
                genregs(cdb, xmmload(tym), to-XMM0, from-XMM0);
                checkSetVex(cdb.last(), tym);
                break;

            case _X(AX, XMM0):               // MOVD/Q to,from
                genregs(cdb, STOD, from-XMM0, to);
                if (I64 && tysize(tym) >= 8)
                    code_orrex(cdb.last(), REX_W);
                checkSetVex(cdb.last(), tym);
                break;

            case _X(XMM0, AX):               // MOVD/Q to,from
                genregs(cdb, LODD, to-XMM0, from);
                if (I64 && tysize(tym) >= 8)
                    code_orrex(cdb.last(),  REX_W);
                checkSetVex(cdb.last(), tym);
                break;

            case _X(ES, AX):
                assert(tysize(tym) <= REGSIZE);
                genregs(cdb, 0x8E, 0, from);
                break;

            case _X(AX, ES):
                assert(tysize(tym) <= REGSIZE);
                genregs(cdb, 0x8C, 0, to);
                break;

            default:
                debug printf("genmovreg(to = %s, from = %s)\n"
                    , regm_str(mask(to)), regm_str(mask(from)));
                assert(0);
        }
    }
}

/***************************************
 * Generate immediate multiply instruction for r1=r2*imm.
 * Optimize it into LEA's if we can.
 */

@trusted
void genmulimm(ref CodeBuilder cdb,reg_t r1,reg_t r2,targ_int imm)
{
    // These optimizations should probably be put into pinholeopt()
    switch (imm)
    {
        case 1:
            genmovreg(cdb,r1,r2);
            break;

        case 5:
        {
            code cs;
            cs.Iop = LEA;
            cs.Iflags = 0;
            cs.Irex = 0;
            buildEA(&cs,r2,r2,4,0);
            cs.orReg(r1);
            cdb.gen(&cs);
            break;
        }

        default:
            cdb.genc2(0x69,modregxrmx(3,r1,r2),imm);    // IMUL r1,r2,imm
            break;
    }
}

/******************************
 * Load CX with the value of _AHSHIFT.
 */

void genshift(ref CodeBuilder cdb)
{
    assert(0);
}

/******************************
 * Move constant value into reg.
 * Take advantage of existing values in registers.
 * If flags & mPSW
 *      set flags based on result
 * Else if flags & 8
 *      do not disturb flags
 * Else
 *      don't care about flags
 * If flags & 1 then byte move
 * If flags & 2 then short move (for I32 and I64)
 * If flags & 4 then don't disturb unused portion of register
 * If flags & 16 then reg is a byte register AL..BH
 * If flags & 64 (0x40) then 64 bit move (I64 only)
 * Returns:
 *      code (if any) generated
 */

@trusted
void movregconst(ref CodeBuilder cdb,reg_t reg,targ_size_t value,regm_t flags)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.movregconst(cdb, reg, value, flags);

    reg_t r;
    regm_t mreg;

    //printf("movregconst(reg=%s, value= %lld (%llx), flags=%x)\n", regm_str(mask(reg)), value, value, flags);

    regm_t regm = cgstate.regcon.immed.mval & mask(reg);
    targ_size_t regv = cgstate.regcon.immed.value[reg];

    if (flags & 1)      // 8 bits
    {
        value &= 0xFF;
        regm &= BYTEREGS;

        // If we already have the right value in the right register
        if (regm && (regv & 0xFF) == value)
            goto L2;

        if (flags & 16 && reg & 4 &&    // if an H byte register
            cgstate.regcon.immed.mval & mask(reg & 3) &&
            (((regv = cgstate.regcon.immed.value[reg & 3]) >> 8) & 0xFF) == value)
            goto L2;

        /* Avoid byte register loads to avoid dependency stalls.
         */
        if ((I32 || I64) &&
            config.target_cpu >= TARGET_PentiumPro && !(flags & 4))
            goto L3;

        // See if another register has the right value
        r = 0;
        for (mreg = (cgstate.regcon.immed.mval & BYTEREGS); mreg; mreg >>= 1)
        {
            if (mreg & 1)
            {
                if ((cgstate.regcon.immed.value[r] & 0xFF) == value)
                {
                    genregs(cdb,0x8A,reg,r);          // MOV regL,rL
                    if (I64 && reg >= 4 || r >= 4)
                        code_orrex(cdb.last(), REX);
                    goto L2;
                }
                if (!(I64 && reg >= 4) &&
                    r < 4 && ((cgstate.regcon.immed.value[r] >> 8) & 0xFF) == value)
                {
                    genregs(cdb,0x8A,reg,r | 4);      // MOV regL,rH
                    goto L2;
                }
            }
            r++;
        }

        if (value == 0 && !(flags & 8))
        {
            if (!(flags & 4) &&                 // if we can set the whole register
                !(flags & 16 && reg & 4))       // and reg is not an H register
            {
                genregs(cdb,0x31,reg,reg);      // XOR reg,reg
                cgstate.regimmed_set(reg,value);
                regv = 0;
            }
            else
                genregs(cdb,0x30,reg,reg);      // XOR regL,regL
            flags &= ~mPSW;                     // flags already set by XOR
        }
        else
        {
            cdb.genc2(0xC6,modregrmx(3,0,reg),value);  // MOV regL,value
            if (reg >= 4 && I64)
            {
                code_orrex(cdb.last(), REX);
            }
        }
    L2:
        if (flags & mPSW)
            genregs(cdb,0x84,reg,reg);            // TEST regL,regL

        if (regm)
            // Set just the 'L' part of the register value
            cgstate.regimmed_set(reg,(regv & ~cast(targ_size_t)0xFF) | value);
        else if (flags & 16 && reg & 4 && cgstate.regcon.immed.mval & mask(reg & 3))
            // Set just the 'H' part of the register value
            cgstate.regimmed_set((reg & 3),(regv & ~cast(targ_size_t)0xFF00) | (value << 8));
        return;
    }
L3:
    if (I16)
        value = cast(targ_short) value;             // sign-extend MSW
    else if (I32)
        value = cast(targ_int) value;

    if (!I16 && flags & 2)                      // load 16 bit value
    {
        value &= 0xFFFF;
        if (value && !(flags & mPSW))
        {
            cdb.genc2(0xC7,modregrmx(3,0,reg),value); // MOV reg,value
            cgstate.regimmed_set(reg, value);
            return;
        }
    }

    // If we already have the right value in the right register
    if (regm && (regv & 0xFFFFFFFF) == (value & 0xFFFFFFFF) && !(flags & 64))
    {
        if (flags & mPSW)
            gentstreg(cdb,reg);
    }
    else if (flags & 64 && regm && regv == value)
    {   // Look at the full 64 bits
        if (flags & mPSW)
        {
            gentstreg(cdb,reg);
            code_orrex(cdb.last(), REX_W);
        }
    }
    else
    {
        if (flags & mPSW)
        {
            switch (value)
            {
                case 0:
                    genregs(cdb,0x31,reg,reg);
                    break;

                case 1:
                    if (I64)
                        goto L4;
                    genregs(cdb,0x31,reg,reg);
                    goto inc;

                case ~cast(targ_size_t)0:
                    if (I64)
                        goto L4;
                    genregs(cdb,0x31,reg,reg);
                    goto dec;

                default:
                L4:
                    if (flags & 64)
                    {
                        cdb.genc2(0xB8 + (reg&7),REX_W << 16 | (reg&8) << 13,value); // MOV reg,value64
                        gentstreg(cdb,reg);
                        code_orrex(cdb.last(), REX_W);
                    }
                    else
                    {
                        value &= 0xFFFFFFFF;
                        cdb.genc2(0xB8 + (reg&7),(reg&8) << 13,value); // MOV reg,value
                        gentstreg(cdb,reg);
                    }
                    break;
            }
        }
        else
        {
            // Look for single byte conversion
            if (cgstate.regcon.immed.mval & mAX)
            {
                if (I32)
                {
                    if (reg == AX && value == cast(targ_short) regv)
                    {
                        cdb.gen1(0x98);               // CWDE
                        goto done;
                    }
                    if (reg == DX &&
                        value == (cgstate.regcon.immed.value[AX] & 0x80000000 ? 0xFFFFFFFF : 0) &&
                        !(config.flags4 & CFG4speed && config.target_cpu >= TARGET_Pentium)
                       )
                    {
                        cdb.gen1(0x99);               // CDQ
                        goto done;
                    }
                }
                else if (I16)
                {
                    if (reg == AX &&
                        cast(targ_short) value == cast(byte) regv)
                    {
                        cdb.gen1(0x98);               // CBW
                        goto done;
                    }

                    if (reg == DX &&
                        cast(targ_short) value == (cgstate.regcon.immed.value[AX] & 0x8000 ? cast(targ_short) 0xFFFF : cast(targ_short) 0) &&
                        !(config.flags4 & CFG4speed && config.target_cpu >= TARGET_Pentium)
                       )
                    {
                        cdb.gen1(0x99);               // CWD
                        goto done;
                    }
                }
            }
            if (value == 0 && !(flags & 8) && config.target_cpu >= TARGET_80486)
            {
                genregs(cdb,0x31,reg,reg);              // XOR reg,reg
                goto done;
            }

            if (!I64 && regm && !(flags & 8))
            {
                if (regv + 1 == value ||
                    // Catch case of (0xFFFF+1 == 0) for 16 bit compiles
                    (I16 && cast(targ_short)(regv + 1) == cast(targ_short)value))
                {
                inc:
                    cdb.gen1(0x40 + reg);     // INC reg
                    goto done;
                }
                if (regv - 1 == value)
                {
                dec:
                    cdb.gen1(0x48 + reg);     // DEC reg
                    goto done;
                }
            }

            // See if another register has the right value
            r = 0;
            for (mreg = cgstate.regcon.immed.mval; mreg; mreg >>= 1)
            {
                debug
                assert(!I16 || cgstate.regcon.immed.value[r] == cast(targ_short)cgstate.regcon.immed.value[r]);

                if (mreg & 1 && cgstate.regcon.immed.value[r] == value)
                {
                    genmovreg(cdb,reg,r);
                    goto done;
                }
                r++;
            }

            if (value == 0 && !(flags & 8))
            {
                genregs(cdb,0x31,reg,reg);              // XOR reg,reg
            }
            else
            {   // See if we can just load a byte
                if (regm & BYTEREGS &&
                    !(config.flags4 & CFG4speed && config.target_cpu >= TARGET_PentiumPro)
                   )
                {
                    if ((regv & ~cast(targ_size_t)0xFF) == (value & ~cast(targ_size_t)0xFF))
                    {
                        movregconst(cdb,reg,value,(flags & 8) |4|1);  // load regL
                        return;
                    }
                    if (regm & (mAX|mBX|mCX|mDX) &&
                        (regv & ~cast(targ_size_t)0xFF00) == (value & ~cast(targ_size_t)0xFF00) &&
                        !I64)
                    {
                        movregconst(cdb,4|reg,value >> 8,(flags & 8) |4|1|16); // load regH
                        return;
                    }
                }
                if (flags & 64)
                    cdb.genc2(0xB8 + (reg&7),REX_W << 16 | (reg&8) << 13,value); // MOV reg,value64
                else
                {
                    value &= 0xFFFFFFFF;
                    cdb.genc2(0xB8 + (reg&7),(reg&8) << 13,value); // MOV reg,value
                }
            }
        }
    done:
        cgstate.regimmed_set(reg,value);
    }
}

/**************************
 * Generate a jump instruction.
 */

@trusted
void genjmp(ref CodeBuilder cdb, opcode_t op, FL fltarg, block* targ)
{
    code cs;
    cs.Iop = op & 0xFF;
    cs.Iflags = 0;
    cs.Irex = 0;
    if (op != JMP && op != 0xE8)        // if not already long branch
          cs.Iflags = CFjmp16;          // assume long branch for op = 0x7x
    cs.IFL2 = fltarg;                   // FL.block (or FL.code)
    cs.IEV2.Vblock = targ;              // target block (or code)
    if (fltarg == FL.code)
        (cast(code*)targ).Iflags |= CFtarg;

    if (config.flags4 & CFG4fastfloat)  // if fast floating point
    {
        cdb.gen(&cs);
        return;
    }

    switch (op & 0xFF00)                // look at second jump opcode
    {
        // The JP and JNP come from floating point comparisons
        case JP << 8:
            cdb.gen(&cs);
            cs.Iop = JP;
            cdb.gen(&cs);
            break;

        case JNP << 8:
        {
            // Do a JP around the jump instruction
            code* cnop = gennop(null);
            genjmp(cdb,JP,FL.code,cast(block*) cnop);
            cdb.gen(&cs);
            cdb.append(cnop);
            break;
        }

        case 1 << 8:                    // toggled no jump
        case 0 << 8:
            cdb.gen(&cs);
            break;

        default:
            debug
            printf("jop = x%x\n",op);
            assert(0);
    }
}

/*********************************************
 * Generate first part of prolog for interrupt function.
 */
@trusted
void prolog_ifunc(ref CodeBuilder cdb, tym_t* tyf)
{
    static immutable ubyte[4] ops2 = [ 0x60,0x1E,0x06,0 ];
    static immutable ubyte[11] ops0 = [ 0x50,0x51,0x52,0x53,
                                    0x54,0x55,0x56,0x57,
                                    0x1E,0x06,0 ];

    immutable(ubyte)* p = (config.target_cpu >= TARGET_80286) ? ops2.ptr : ops0.ptr;
    do
        cdb.gen1(*p);
    while (*++p);

    genregs(cdb,0x8B,BP,SP);     // MOV BP,SP
    if (localsize)
        cod3_stackadj(cdb, cast(int)localsize);

    *tyf |= mTYloadds;
}

@trusted
void prolog_ifunc2(ref CodeBuilder cdb, tym_t tyf, tym_t tym, bool pushds)
{
    /* Determine if we need to reload DS        */
    if (tyf & mTYloadds)
    {
        if (!pushds)                           // if not already pushed
            cdb.gen1(0x1E);                    // PUSH DS
        cgstate.spoff += _tysize[TYint];
        cdb.genc(0xC7, modregrm(3,0,AX), FL.unde, 0, FL.datseg, cast(targ_uns) 0); // MOV  AX,DGROUP
        code* c = cdb.last();
        c.IEV2.Vseg = DATA;
        c.Iflags ^= CFseg | CFoff;            // turn off CFoff, on CFseg
        cdb.gen2(0x8E,modregrm(3,3,AX));       // MOV  DS,AX
        useregs(mAX);
    }

    if (tym == TYifunc)
        cdb.gen1(0xFC);                        // CLD
}

@trusted
void prolog_16bit_windows_farfunc(ref CodeBuilder cdb, tym_t* tyf, bool* pushds)
{
    int wflags = config.wflags;
    if (wflags & WFreduced && !(*tyf & mTYexport))
    {   // reduced prolog/epilog for non-exported functions
        wflags &= ~(WFdgroup | WFds | WFss);
    }

    getregsNoSave(mAX);                     // should not have any value in AX

    int segreg;
    switch (wflags & (WFdgroup | WFds | WFss))
    {
        case WFdgroup:                      // MOV  AX,DGROUP
        {
            if (wflags & WFreduced)
                *tyf &= ~mTYloadds;          // remove redundancy
            cdb.genc(0xC7, modregrm(3, 0, AX), FL.unde, 0, FL.datseg, cast(targ_uns) 0);
            code* c = cdb.last();
            c.IEV2.Vseg = DATA;
            c.Iflags ^= CFseg | CFoff;     // turn off CFoff, on CFseg
            break;
        }

        case WFss:
            segreg = 2;                     // SS
            goto Lmovax;

        case WFds:
            segreg = 3;                     // DS
        Lmovax:
            cdb.gen2(0x8C,modregrm(3,segreg,AX)); // MOV AX,segreg
            if (wflags & WFds)
                cdb.gen1(0x90);             // NOP
            break;

        case 0:
            break;

        default:
            debug
            printf("config.wflags = x%x\n",config.wflags);
            assert(0);
    }
    if (wflags & WFincbp)
        cdb.gen1(0x40 + BP);              // INC  BP
    cdb.genpush(BP);                      // PUSH BP
    genregs(cdb,0x8B,BP,SP);              // MOV  BP,SP
    if (wflags & (WFsaveds | WFds | WFss | WFdgroup))
    {
        cdb.gen1(0x1E);                       // PUSH DS
        *pushds = true;
        cgstate.BPoff = -REGSIZE;
    }
    if (wflags & (WFds | WFss | WFdgroup))
        cdb.gen2(0x8E,modregrm(3,3,AX));      // MOV  DS,AX
}

/**********************************************
 * Set up frame register.
 * Params:
 *      cg         = code generator state
 *      cdb        = write generated code here
 *      farfunc    = true if a far function
 *      enter      = set to true if ENTER instruction can be used, false otherwise
 *      xlocalsize = amount of local variables, set to amount to be subtracted from stack pointer
 *      cfa_offset = set to frame pointer's offset from the CFA
 * Returns:
 *      generated code
 */
@trusted
void prolog_frame(ref CGstate cg, ref CodeBuilder cdb, bool farfunc, ref uint xlocalsize, out bool enter, out int cfa_offset)
{
    enum log = false;
    if (log) printf("prolog_frame localsize: x%x\n", xlocalsize);
    cfa_offset = 0;

    if (0 && config.exe == EX_WIN64)
    {
        // PUSH RBP
        // LEA RBP,0[RSP]
        cdb.genpush(BP);
        cdb.genc1(LEA,(REX_W<<16) | (modregrm(0,4,SP)<<8) | modregrm(2,BP,4),FL.const_,0);
        enter = false;
        return;
    }

    if (config.wflags & WFincbp && farfunc)
        cdb.gen1(0x40 + BP);      // INC  BP
    if (config.target_cpu < TARGET_80286 ||
        config.exe & (EX_posix | EX_WIN64) ||
        !localsize ||
        config.flags & CFGstack ||
        (xlocalsize >= 0x1000 && config.exe & EX_flat) ||
        localsize >= 0x10000 ||
        (NTEXCEPTIONS == 2 &&
         (cg.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru) && (config.ehmethod == EHmethod.EH_WIN32 && !(funcsym_p.Sfunc.Fflags3 & Feh_none) || config.ehmethod == EHmethod.EH_SEH))) ||
        (config.target_cpu >= TARGET_80386 &&
         config.flags4 & CFG4speed)
       )
    {
        if (cgstate.AArch64)
        {
            if (log) printf("prolog_frame: stp\n");
            if (16 + xlocalsize <= 512)
                // STP x29,x30,[sp,#-(16+localsize)]!
                cdb.gen1(INSTR.ldstpair_pre(2, 0, 0, (-(16 + xlocalsize) / 8) & 127, 30, 31, 29));
            else
            {
                /* SUB sp,sp,#16+xlocalsize
                   STP x29,x30,[sp]
                 */
                cod3_stackadj(cdb, 16 + xlocalsize);

                assert((xlocalsize & 0xF) == 0); // 16 byte aligned

                // https://www.scs.stanford.edu/~zyedidia/arm64/stp_gen.html
                // STP x29,x30,[sp,#xlocalsize]
                {
                    uint opc = 2;
                    uint VR = 0;
                    uint L = 0;
                    uint imm7 = xlocalsize >> 3;
                    assert(imm7 < (1 << 7)); // only 7 bits allowed
                    imm7 = 0;
                    ubyte Rt2 = 30;
                    ubyte Rn = 0x1F;
                    ubyte Rt = 29;
                    cdb.gen1(INSTR.ldstpair_off(opc, VR, L, imm7, Rt2, Rn, Rt));
                }
            }

            // https://www.scs.stanford.edu/~zyedidia/arm64/sub_addsub_imm.html
            // ADD Xd,Xn,#imm{,shift}
            {
                uint sf = 1;
                uint op = 0;
                uint S = 0;
                uint sh = 0;
                uint imm12 = 0; //xlocalsize;
                assert(imm12 < (1 << 12));  // only 12 bits allowed
                ubyte Rn = 0x1F;
                ubyte Rd = 29;
                cdb.gen1(INSTR.addsub_imm(sf, op, S, sh, imm12, Rn, Rd)); // mov x29,sp // x29 points to previous x29
            }
        }
        else
        {
            cdb.genpush(BP);      // PUSH BP
            genregs(cdb,0x8B,BP,SP);      // MOV  BP,SP
            if (I64)
                code_orrex(cdb.last(), REX_W);   // MOV RBP,RSP
        }
        if ((config.objfmt & (OBJ_ELF | OBJ_MACH)) && config.fulltypes)
            // Don't reorder instructions, as dwarf CFA relies on it
            code_orflag(cdb.last(), CFvolatile);
static if (NTEXCEPTIONS == 2)
{
        if (cg.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru) && (config.ehmethod == EHmethod.EH_WIN32 && !(funcsym_p.Sfunc.Fflags3 & Feh_none) || config.ehmethod == EHmethod.EH_SEH))
        {
            nteh_prolog(cdb);
            int sz = nteh_contextsym_size();
            assert(sz != 0);        // should be 5*4, not 0
            xlocalsize -= sz;      // sz is already subtracted from ESP
                                    // by nteh_prolog()
        }
}
        if (config.fulltypes == CVDWARF_C || config.fulltypes == CVDWARF_D ||
            config.ehmethod == EHmethod.EH_DWARF)
        {
            int off = 2 * REGSIZE;      // 1 for the return address + 1 for the PUSH EBP
            dwarf_CFA_set_loc(1);           // address after PUSH EBP
            dwarf_CFA_set_reg_offset(SP, off); // CFA is now 8[ESP]
            dwarf_CFA_offset(BP, -off);       // EBP is at 0[ESP]
            dwarf_CFA_set_loc(I64 ? 4 : 3);   // address after MOV EBP,ESP
            /* Oddly, the CFA is not the same as the frame pointer,
             * which is why the offset of BP is set to 8
             */
            dwarf_CFA_set_reg_offset(BP, off);        // CFA is now 0[EBP]
            cfa_offset = off;  // remember the difference between the CFA and the frame pointer
        }
        enter = false;              /* do not use ENTER instruction */
    }
    else
        enter = true;
}

/**********************************************
 * Enforce stack alignment.
 * Input:
 *      cdb     code builder.
 * Returns:
 *      generated code
 */
@trusted
void prolog_stackalign(ref CGstate cg, ref CodeBuilder cdb)
{
    if (!cg.enforcealign)
        return;

    const offset = (cg.hasframe ? 2 : 1) * REGSIZE;   // 1 for the return address + 1 for the PUSH EBP
    if (offset & (STACKALIGN - 1) || TARGET_STACKALIGN < STACKALIGN)
        cod3_stackalign(cdb, STACKALIGN);
}

@trusted
void prolog_frameadj(ref CGstate cg, ref CodeBuilder cdb, tym_t tyf, uint xlocalsize, bool enter, bool* pushalloc)
{
    enum log = false;
    if (log) printf("prolog_frameadj()\n");
    reg_t pushallocreg = (tyf == TYmfunc) ? CX : AX;

    bool check;
    if (config.exe & (EX_LINUX | EX_LINUX64))
        check = false;               // seems that Linux doesn't need to fault in stack pages
    else
        check = (config.flags & CFGstack && !(I32 && xlocalsize < 0x1000)) // if stack overflow check
            || (config.exe & (EX_windos & EX_flat) && xlocalsize >= 0x1000);

    if (check)
    {
        if (I16)
        {
            // BUG: Won't work if parameter is passed in AX
            movregconst(cdb,AX,xlocalsize,false); // MOV AX,localsize
            makeitextern(getRtlsym(RTLSYM.CHKSTK));
                                                    // CALL _chkstk
            cdb.gencs((LARGECODE) ? 0x9A : CALL,0,FL.func,getRtlsym(RTLSYM.CHKSTK));
            useregs((ALLREGS | mBP | mES) & ~getRtlsym(RTLSYM.CHKSTK).Sregsaved);
        }
        else
        {
            /* Watch out for 64 bit code where EDX is passed as a register parameter
             */
            reg_t reg = I64 ? R11 : DX;  // scratch register

            /*      MOV     EDX, xlocalsize/0x1000
             *  L1: SUB     ESP, 0x1000
             *      TEST    [ESP],ESP
             *      DEC     EDX
             *      JNE     L1
             *      SUB     ESP, xlocalsize % 0x1000
             */
            movregconst(cdb, reg, xlocalsize / 0x1000, false);
            cod3_stackadj(cdb, 0x1000);
            code_orflag(cdb.last(), CFtarg2);
            cdb.gen2sib(0x85, modregrm(0,SP,4),modregrm(0,4,SP));
            if (I64)
            {   cdb.gen2(0xFF, modregrmx(3,1,R11));   // DEC R11D
                cdb.genc2(JNE,0,cast(targ_uns)-15);
            }
            else
            {   cdb.gen1(0x48 + DX);                  // DEC EDX
                cdb.genc2(JNE,0,cast(targ_uns)-12);
            }
            cg.regimmed_set(reg,0);             // reg is now 0
            cod3_stackadj(cdb, xlocalsize & 0xFFF);
            useregs(mask(reg));
        }
    }
    else if (cgstate.AArch64)
    {
static if (0)
{
        if (log) printf("prolog_frameadj: sub/stp/add\n");
        /* sub sp,sp,#16+xlocalsize
           stp x29,x30,[sp,#xlocalsize]
           add x29,sp,#xlocalsize
         */
        cod3_stackadj(cdb, 16 + xlocalsize);

        assert((xlocalsize & 0xF) == 0); // 16 byte aligned

        // https://www.scs.stanford.edu/~zyedidia/arm64/stp_gen.html
        // stp x29,x30,[sp,#xlocalsize]
        {
            uint opc = 2;
            uint VR = 0;
            uint L = 0;
            uint imm7 = xlocalsize >> 3;
            assert(imm7 < (1 << 7)); // only 7 bits allowed
            ubyte Rt2 = 30;
            ubyte Rn = 0x1F;
            ubyte Rt = 29;
            cdb.gen1(INSTR.ldstpair_off(opc, VR, L, imm7, Rt2, Rn, Rt));
        }

        // https://www.scs.stanford.edu/~zyedidia/arm64/sub_addsub_imm.html
        // add Xd,Xn,#imm{,shift}
        {
            uint sf = 1;
            uint op = 0;
            uint S = 0;
            uint sh = 0;
            uint imm12 = xlocalsize;
            assert(imm12 < (1 << 12));  // only 12 bits allowed
            ubyte Rn = 0x1F;
            ubyte Rd = 29;
            cdb.gen1(INSTR.addsub_imm(sf, op, S, sh, imm12, Rn, Rd));
        }
}
    }
    else
    {
        if (enter)
        {   // ENTER xlocalsize,0
            cdb.genc(ENTER,0,FL.const_,xlocalsize,FL.const_,cast(targ_uns) 0);
            assert(!(config.fulltypes == CVDWARF_C || config.fulltypes == CVDWARF_D)); // didn't emit Dwarf data
        }
        else if (xlocalsize == REGSIZE && config.flags4 & CFG4optimized)
        {
            cdb.genpush(pushallocreg);    // PUSH AX
            // Do this to prevent an -x[EBP] to be moved in
            // front of the push.
            code_orflag(cdb.last(),CFvolatile);
            *pushalloc = true;
        }
        else
            cod3_stackadj(cdb, xlocalsize);
    }
}

void prolog_frameadj2(ref CGstate cg, ref CodeBuilder cdb, tym_t tyf, uint xlocalsize, bool* pushalloc)
{
    enum log = false;
    if (log) debug printf("prolog_frameadj2() xlocalsize: x%x\n", xlocalsize);
    if (cg.AArch64)
    {
        /* sub sp,sp,#xlocalsize
         */
        cod3_stackadj(cdb, xlocalsize);
        return;
    }

    reg_t pushallocreg = (tyf == TYmfunc) ? CX : AX;
    if (xlocalsize == REGSIZE)
    {
        cdb.genpush(pushallocreg);      // PUSH AX
        *pushalloc = true;
    }
    else if (xlocalsize == 2 * REGSIZE)
    {
        cdb.genpush(pushallocreg);      // PUSH AX
        cdb.genpush(pushallocreg);      // PUSH AX
        *pushalloc = true;
    }
    else
        cod3_stackadj(cdb, xlocalsize);
}

@trusted
void prolog_setupalloca(ref CodeBuilder cdb)
{
    //printf("prolog_setupalloca() offset x%x size x%x alignment x%x\n",
        //cast(int)cgstate.Alloca.offset, cast(int)cgstate.Alloca.size, cast(int)cgstate.Alloca.alignment);
    // Set up magic parameter for alloca()
    // MOV -REGSIZE[BP],localsize - BPoff
    cdb.genc(0xC7,modregrm(2,0,BPRM),
            FL.const_,cgstate.Alloca.offset + cgstate.BPoff,
            FL.const_,localsize - cgstate.BPoff);
    if (I64)
        code_orrex(cdb.last(), REX_W);
}

/**************************************
 * Save registers that the function destroys,
 * but that the ABI says should be preserved across
 * function calls.
 *
 * Emit Dwarf info for these saves.
 * Params:
 *      cdb = append generated instructions to this
 *      topush = mask of registers to push
 *      cfa_offset = offset of frame pointer from CFA
 */

@trusted
void prolog_saveregs(ref CGstate cg, ref CodeBuilder cdb, regm_t topush, int cfa_offset)
{
    if (cg.pushoffuse)
    {
        // Save to preallocated section in the stack frame
        int xmmtopush = popcnt(topush & XMMREGS);   // XMM regs take 16 bytes
        int gptopush = popcnt(topush) - xmmtopush;  // general purpose registers to save
        targ_size_t xmmoffset = cg.pushoff + cg.BPoff;
        if (!cg.hasframe || cg.enforcealign)
            xmmoffset += cg.EBPtoESP;
        targ_size_t gpoffset = xmmoffset + xmmtopush * 16;
        while (topush)
        {
            reg_t reg = findreg(topush);
            topush &= ~mask(reg);
            if (isXMMreg(reg))
            {
                if (cg.hasframe && !cg.enforcealign)
                {
                    // MOVUPD xmmoffset[EBP],xmm
                    cdb.genc1(STOUPD,modregxrm(2,reg-XMM0,BPRM),FL.const_,xmmoffset);
                }
                else
                {
                    // MOVUPD xmmoffset[ESP],xmm
                    cdb.genc1(STOUPD,modregxrm(2,reg-XMM0,4) + 256*modregrm(0,4,SP),FL.const_,xmmoffset);
                }
                xmmoffset += 16;
            }
            else
            {
                if (cg.hasframe && !cg.enforcealign)
                {
                    // MOV gpoffset[EBP],reg
                    cdb.genc1(0x89,modregxrm(2,reg,BPRM),FL.const_,gpoffset);
                }
                else
                {
                    // MOV gpoffset[ESP],reg
                    cdb.genc1(0x89,modregxrm(2,reg,4) + 256*modregrm(0,4,SP),FL.const_,gpoffset);
                }
                if (I64)
                    code_orrex(cdb.last(), REX_W);
                if (config.fulltypes == CVDWARF_C || config.fulltypes == CVDWARF_D ||
                    config.ehmethod == EHmethod.EH_DWARF)
                {   // Emit debug_frame data giving location of saved register
                    code* c = cdb.finish();
                    pinholeopt(c, null);
                    dwarf_CFA_set_loc(calcblksize(c));  // address after save
                    dwarf_CFA_offset(reg, cast(int)(gpoffset - cfa_offset));
                    cdb.reset();
                    cdb.append(c);
                }
                gpoffset += REGSIZE;
            }
        }
    }
    else
    {
        while (topush)                      /* while registers to push      */
        {
            reg_t reg = findreg(topush);
            topush &= ~mask(reg);
            if (isXMMreg(reg))
            {
                // SUB RSP,16
                cod3_stackadj(cdb, 16);
                // MOVUPD 0[RSP],xmm
                cdb.genc1(STOUPD,modregxrm(2,reg-XMM0,4) + 256*modregrm(0,4,SP),FL.const_,0);
                cg.EBPtoESP += 16;
                cg.spoff += 16;
            }
            else
            {
                genpush(cdb, reg);
                cg.EBPtoESP += REGSIZE;
                cg.spoff += REGSIZE;
                if (config.fulltypes == CVDWARF_C || config.fulltypes == CVDWARF_D ||
                    config.ehmethod == EHmethod.EH_DWARF)
                {   // Emit debug_frame data giving location of saved register
                    // relative to 0[EBP]
                    code* c = cdb.finish();
                    pinholeopt(c, null);
                    dwarf_CFA_set_loc(calcblksize(c));  // address after PUSH reg
                    dwarf_CFA_offset(reg, -cg.EBPtoESP - cfa_offset);
                    cdb.reset();
                    cdb.append(c);
                }
            }
        }
    }
}

/**************************************
 * Undo prolog_saveregs()
 */

@trusted
private void epilog_restoreregs(ref CGstate cg, ref CodeBuilder cdb, regm_t topop)
{
    debug
    if (topop & ~(XMMREGS | 0xFFFF))
        printf("fregsaved = %s, mfuncreg = %s\n",regm_str(fregsaved),regm_str(cg.mfuncreg));

    assert(!(topop & ~(XMMREGS | 0xFFFF)));
    if (cg.pushoffuse)
    {
        // Save to preallocated section in the stack frame
        int xmmtopop = popcnt(topop & XMMREGS);   // XMM regs take 16 bytes
        int gptopop = popcnt(topop) - xmmtopop;   // general purpose registers to save
        targ_size_t xmmoffset = cg.pushoff + cg.BPoff;
        if (!cg.hasframe || cg.enforcealign)
            xmmoffset += cg.EBPtoESP;
        targ_size_t gpoffset = xmmoffset + xmmtopop * 16;
        while (topop)
        {
            reg_t reg = findreg(topop);
            topop &= ~mask(reg);
            if (isXMMreg(reg))
            {
                if (cg.hasframe && !cg.enforcealign)
                {
                    // MOVUPD xmm,xmmoffset[EBP]
                    cdb.genc1(LODUPD,modregxrm(2,reg-XMM0,BPRM),FL.const_,xmmoffset);
                }
                else
                {
                    // MOVUPD xmm,xmmoffset[ESP]
                    cdb.genc1(LODUPD,modregxrm(2,reg-XMM0,4) + 256*modregrm(0,4,SP),FL.const_,xmmoffset);
                }
                xmmoffset += 16;
            }
            else
            {
                if (cg.hasframe && !cg.enforcealign)
                {
                    // MOV reg,gpoffset[EBP]
                    cdb.genc1(0x8B,modregxrm(2,reg,BPRM),FL.const_,gpoffset);
                }
                else
                {
                    // MOV reg,gpoffset[ESP]
                    cdb.genc1(0x8B,modregxrm(2,reg,4) + 256*modregrm(0,4,SP),FL.const_,gpoffset);
                }
                if (I64)
                    code_orrex(cdb.last(), REX_W);
                gpoffset += REGSIZE;
            }
        }
    }
    else
    {
        reg_t reg = I64 ? XMM7 : DI;
        if (!(topop & XMMREGS))
            reg = R15;
        regm_t regm = 1UL << reg;

        while (topop)
        {   if (topop & regm)
            {
                if (isXMMreg(reg))
                {
                    // MOVUPD xmm,0[RSP]
                    cdb.genc1(LODUPD,modregxrm(2,reg-XMM0,4) + 256*modregrm(0,4,SP),FL.const_,0);
                    // ADD RSP,16
                    cod3_stackadj(cdb, -16);
                }
                else
                {
                    cdb.genpop(reg);         // POP reg
                }
                topop &= ~regm;
            }
            regm >>= 1;
            reg--;
        }
    }
}

/******************************
 * Generate special varargs prolog for Posix 64 bit systems.
 * Params:
 *      cg = code generator state
 *      cdb = sink for generated code
 *      sv = symbol for __va_argsave
 */
@trusted
void prolog_genvarargs(ref CGstate cg, ref CodeBuilder cdb, Symbol* sv)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod3.prolog_genvarargs(cg, cdb, sv);

    /* Generate code to move any arguments passed in registers into
     * the stack variable __va_argsave,
     * so we can reference it via pointers through va_arg().
     *   struct __va_argsave_t {
     *     size_t[6] regs;
     *     real[8] fpregs;
     *     uint offset_regs;
     *     uint offset_fpregs;
     *     void* stack_args;
     *     void* reg_args;
     *   }
     * The MOVAPS instructions seg fault if data is not aligned on
     * 16 bytes, so this gives us a nice check to ensure no mistakes.
        MOV     voff+0*8[RBP],EDI
        MOV     voff+1*8[RBP],ESI
        MOV     voff+2*8[RBP],RDX
        MOV     voff+3*8[RBP],RCX
        MOV     voff+4*8[RBP],R8
        MOV     voff+5*8[RBP],R9
        TEST    AL,AL
        LEA     RAX,voff+6*8+0x7F[RBP]
        JE      L2

        MOVAPS  -0x0F[RAX],XMM7             // only save XMM registers if actually used
        MOVAPS  -0x1F[RAX],XMM6
        MOVAPS  -0x2F[RAX],XMM5
        MOVAPS  -0x3F[RAX],XMM4
        MOVAPS  -0x4F[RAX],XMM3
        MOVAPS  -0x5F[RAX],XMM2
        MOVAPS  -0x6F[RAX],XMM1
        MOVAPS  -0x7F[RAX],XMM0

      L2:
        LEA     R11, Para.size+Para.offset[RBP]
        MOV     9+16[RAX],R11                // set __va_argsave.stack_args
    * RAX and R11 are destroyed.
    */

    /* Save registers into the voff area on the stack
     */
    targ_size_t voff = cg.Auto.size + cg.BPoff + sv.Soffset;  // EBP offset of start of sv
    const int vregnum = 6;
    const uint vsize = vregnum * 8 + 8 * 16;

    static immutable reg_t[vregnum] regs = [ DI,SI,DX,CX,R8,R9 ];

    if (!cg.hasframe || cg.enforcealign)
        voff += cg.EBPtoESP;

    regm_t namedargs = prolog_namedArgs();
    foreach (i, r; regs)
    {
        if (!(mask(r) & namedargs))  // unnamed arguments would be the ... ones
        {
            uint ea = (REX_W << 16) | modregxrm(2,r,BPRM);
            if (!cg.hasframe || cg.enforcealign)
                ea = (REX_W << 16) | (modregrm(0,4,SP) << 8) | modregxrm(2,r,4);
            cdb.genc1(0x89,ea,FL.const_,voff + i*8);  // MOV voff+i*8[RBP],r
        }
    }

    code* cnop = gennop(null);
    genregs(cdb,0x84,AX,AX);                   // TEST AL,AL

    uint ea = (REX_W << 16) | modregrm(2,AX,BPRM);
    if (!cg.hasframe || cg.enforcealign)
        // add sib byte for [RSP] addressing
        ea = (REX_W << 16) | (modregrm(0,4,SP) << 8) | modregxrm(2,AX,4);
    int raxoff = cast(int)(voff+6*8+0x7F);
    cdb.genc1(LEA,ea,FL.const_,raxoff);          // LEA RAX,voff+vsize-6*8-16+0x7F[RBP]

    genjmp(cdb,JE,FL.code, cast(block*)cnop);  // JE L2

    foreach (i; 0 .. 8)
    {
        // MOVAPS -15-16*i[RAX],XMM7-i
        cdb.genc1(0x0F29,modregrm(0,XMM7-i,0),FL.const_,-15-16*i);
    }
    cdb.append(cnop);

    // LEA R11, Para.size+Para.offset[RBP]
    uint ea2 = modregxrm(2,R11,BPRM);
    if (!cg.hasframe)
        ea2 = (modregrm(0,4,SP) << 8) | modregrm(2,DX,4);
    cg.Para.offset = (cg.Para.offset + (REGSIZE - 1)) & ~(REGSIZE - 1);
    cdb.genc1(LEA,(REX_W << 16) | ea2,FL.const_,cg.Para.size + cg.Para.offset);

    // MOV 9+16[RAX],R11
    cdb.genc1(0x89,(REX_W << 16) | modregxrm(2,R11,AX),FL.const_,9 + 16);   // into stack_args_save

    pinholeopt(cdb.peek(), null);
    useregs(mAX|mR11);
}

/********************************
 * Generate elems for va_start()
 * Params:
 *      sv = symbol for __va_argsave
 *      parmn = last named parameter
 */
@trusted
elem* prolog_genva_start(Symbol* sv, Symbol* parmn)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.prolog_genva_start(sv, parmn);

    enum Vregnum = 6;

    /* the stack variable __va_argsave points to an instance of:
     *   struct __va_argsave_t {
     *     size_t[Vregnum] regs;
     *     real[8] fpregs;
     *     struct __va_list_tag {
     *         uint offset_regs;
     *         uint offset_fpregs;
     *         void* stack_args;
     *         void* reg_args;
     *     }
     *     void* stack_args_save;
     *   }
     */

    enum OFF // offsets into __va_argsave_t
    {
        Offset_regs   = Vregnum*8 + 8*16,
        Offset_fpregs = Offset_regs + 4,
        Stack_args    = Offset_fpregs + 4,
        Reg_args      = Stack_args + 8,
        Stack_args_save = Reg_args + 8,
    }

    /* Compute offset_regs and offset_fpregs
     */
    regm_t namedargs = prolog_namedArgs();
    uint offset_regs = 0;
    uint offset_fpregs = Vregnum * 8;
    for (int i = AX; i <= XMM7; i++)
    {
        regm_t m = mask(i);
        if (m & namedargs)
        {
            if (m & (mDI|mSI|mDX|mCX|mR8|mR9))
                offset_regs += 8;
            else if (m & XMMREGS)
                offset_fpregs += 16;
            namedargs &= ~m;
            if (!namedargs)
                break;
        }
    }

    // set offset_regs
    elem* e1 = el_bin(OPeq, TYint, el_var(sv), el_long(TYint, offset_regs));
    e1.E1.Ety = TYint;
    e1.E1.Voffset = OFF.Offset_regs;

    // set offset_fpregs
    elem* e2 = el_bin(OPeq, TYint, el_var(sv), el_long(TYint, offset_fpregs));
    e2.E1.Ety = TYint;
    e2.E1.Voffset = OFF.Offset_fpregs;

    // set reg_args
    elem* e4 = el_bin(OPeq, TYnptr, el_var(sv), el_ptr(sv));
    e4.E1.Ety = TYnptr;
    e4.E1.Voffset = OFF.Reg_args;

    // set stack_args
    /* which is a pointer to the first variadic argument on the stack.
     * Normally, we could set it by taking the address of the last named parameter
     * (parmn) and then skipping past it. The trouble, though, is it fails
     * when all the named parameters get passed in a register.
     *    elem* e3 = el_bin(OPeq, TYnptr, el_var(sv), el_ptr(parmn));
     *    e3.E1.Ety = TYnptr;
     *    e3.E1.Voffset = OFF.Stack_args;
     *    auto sz = type_size(parmn.Stype);
     *    sz = (sz + (REGSIZE - 1)) & ~(REGSIZE - 1);
     *    e3.E2.Voffset += sz;
     * The next possibility is to do it the way prolog_genvarargs() does:
     *    LEA R11, Para.size+Para.offset[RBP]
     * The trouble there is Para.size and Para.offset is not available when
     * this function is called. It might be possible to compute this earlier.(1)
     * Another possibility is creating a special operand type that gets filled
     * in after the prolog_genvarargs() is called.
     * Or do it this simpler way - compute the needed value in prolog_genvarargs(),
     * and save it in a slot just after va_argsave, called `stack_args_save`.
     * Then, just copy from `stack_args_save` to `stack_args`.
     * Although, doing (1) might be optimal.
     */
    elem* e3 = el_bin(OPeq, TYnptr, el_var(sv), el_var(sv));
    e3.E1.Ety = TYnptr;
    e3.E1.Voffset = OFF.Stack_args;
    e3.E2.Ety = TYnptr;
    e3.E2.Voffset = OFF.Stack_args_save;

    elem* e = el_combine(e1, el_combine(e2, el_combine(e3, e4)));
    return e;
}

void prolog_gen_win64_varargs(ref CodeBuilder cdb)
{
    /* The Microsoft scheme.
     * https://msdn.microsoft.com/en-US/library/dd2wa36c%28v=vs.100%29
     * Copy registers onto stack.
         mov     8[RSP],RCX
         mov     010h[RSP],RDX
         mov     018h[RSP],R8
         mov     020h[RSP],R9
     */
}

/************************************
 * Get mask of registers that named parameters (not ... variadic arguments) were passed in.
 * Returns:
 *      the mask
 */
@trusted regm_t prolog_namedArgs()
{
    regm_t namedargs;
    foreach (s; globsym[])
    {
        if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
            namedargs |= s.Spregm();
    }
    return namedargs;
}

/************************************
 * Take the parameters passed in registers, and put them into the function's local
 * symbol table.
 * Params:
 *      cdb = generated code sink
 *      tf = what's the type of the function
 *      pushalloc = use PUSH to allocate on the stack rather than subtracting from SP
 */
@trusted
void prolog_loadparams(ref CodeBuilder cdb, tym_t tyf, bool pushalloc)
{
    //printf("prolog_loadparams() %s\n", funcsym_p.Sident.ptr);
    debug
    foreach (s; globsym[])
    {
        if (debugr)
        if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
        {
            printf("symbol '%s' is fastpar in register [l %s, m %s]\n", s.Sident.ptr,
                regm_str(mask(s.Spreg)),
                (s.Spreg2 == NOREG ? "NOREG" : regm_str(mask(s.Spreg2))));
            if (s.Sfl == FL.reg)
                printf("\tassigned to register %s\n", regm_str(mask(s.Sreglsw)));
        }
    }

    bool AArch64 = cgstate.AArch64;
    uint pushallocreg = (tyf == TYmfunc) ? CX : AX;

    /* Copy SCfastpar and SCshadowreg (parameters passed in registers) that were not assigned
     * registers into their stack locations.
     */
    regm_t shadowregm = 0;
    foreach (s; globsym[])
    {
        uint sz = cast(uint)type_size(s.Stype);

        if (!((s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg) && s.Sfl != FL.reg))
            continue;
        // Argument is passed in a register

        type* t = s.Stype;
        type* t2 = null;

        tym_t tyb = tybasic(t.Tty);

        // This logic is same as FuncParamRegs_alloc function at src/dmd/backend/cod1.d
        //
        // Find suitable SROA based on the element type
        // (Don't put volatile parameters in registers on Windows)
        if (tyb == TYarray && (config.exe != EX_WIN64 || !(t.Tty & mTYvolatile)))
        {
            type* targ1;
            argtypes(t, targ1, t2);
            if (targ1)
                t = targ1;
        }

        // If struct just wraps another type
        if (tyb == TYstruct)
        {
            // On windows 64 bits, structs occupy a general purpose register,
            // regardless of the struct size or the number & types of its fields.
            if (config.exe != EX_WIN64)
            {
                type* targ1 = t.Ttag.Sstruct.Sarg1type;
                t2 = t.Ttag.Sstruct.Sarg2type;
                if (targ1)
                    t = targ1;
            }
        }

        if (Symbol_Sisdead(*s, cgstate.anyiasm))
        {
            // Ignore it, as it is never referenced
            continue;
        }

        targ_size_t offset = cgstate.Fast.size + cgstate.BPoff;
        if (s.Sclass == SC.shadowreg)
            offset = cgstate.Para.size;
        offset += s.Soffset;
        if (!cgstate.hasframe || (cgstate.enforcealign && s.Sclass != SC.shadowreg))
            offset += cgstate.EBPtoESP;

        reg_t preg = s.Spreg;
        foreach (i; 0 .. 2)     // twice, once for each possible parameter register
        {
            static type* type_arrayBase(type* ta)
            {
                while (tybasic(ta.Tty) == TYarray)
                    ta = ta.Tnext;
                return ta;
            }
            shadowregm |= mask(preg);
            const opcode_t op = isXMMreg(preg)
                ? xmmstore(type_arrayBase(t).Tty)
                : 0x89;    // MOV x[EBP],preg
            if (!(pushalloc && preg == pushallocreg) || s.Sclass == SC.shadowreg)
            {
                if (cgstate.hasframe && (!cgstate.enforcealign || s.Sclass == SC.shadowreg))
                {
                    if (AArch64)
                    {
                        uint imm = cast(uint)(offset + localsize + 16);
                        if (tyfloating(t.Tty))
                        {
                            // STR preg,[bp,#offset]
                            if (sz == 8)
                                imm >>= 3;
                            else if (sz == 4)
                                imm >>= 2;
                            cdb.gen1(INSTR.str_imm_fpsimd(2 + (sz == 8),0,imm,29,preg));
                        }
                        else
                            // STR preg,bp,#offset
                            cdb.gen1(INSTR.str_imm_gen(sz > 4, preg, 29, imm));
                    }
                    else
                    {
                        // MOV x[EBP],preg
                        cdb.genc1(op,modregxrm(2,preg,BPRM),FL.const_,offset);
                        if (isXMMreg(preg))
                        {
                            checkSetVex(cdb.last(), t.Tty);
                        }
                        else
                        {
                            //printf("%s Fast.size = %d, BPoff = %d, Soffset = %d, sz = %d\n",
                            //         s.Sident, (int)cgstate.Fast.size, (int)cgstate.BPoff, (int)s.Soffset, (int)sz);
                            if (I64 && sz > 4)
                                code_orrex(cdb.last(), REX_W);
                        }
                    }
                }
                else
                {
                    if (AArch64)
                    {
                        // STR preg,[sp,#offset]
//printf("prolog_loadparams sz=%d\n", sz);
//printf("offset(%d) = Fast.size(%d) + BPoff(%d) + EBPtoESP(%d)\n",cast(int)offset,cast(int)cgstate.Fast.size,cast(int)cgstate.BPoff,cast(int)cgstate.EBPtoESP);
                        cdb.gen1(INSTR.str_imm_gen(sz > 4, preg, 31, offset + localsize + 16));
                    }
                    else
                    {
                        // MOV offset[ESP],preg
                        // BUG: byte size?
                        cdb.genc1(op,
                                  (modregrm(0,4,SP) << 8) |
                                   modregxrm(2,preg,4),FL.const_,offset);
                        if (isXMMreg(preg))
                        {
                            checkSetVex(cdb.last(), t.Tty);
                        }
                        else
                        {
                            if (I64 && sz > 4)
                                cdb.last().Irex |= REX_W;
                        }
                    }
                }
            }
            preg = s.Spreg2;
            if (preg == NOREG)
                break;
            if (t2)
                t = t2;
            offset += REGSIZE;
        }
    }

    if (config.exe == EX_WIN64 && variadic(funcsym_p.Stype))
    {
        /* The Microsoft scheme.
         * https://msdn.microsoft.com/en-US/library/dd2wa36c%28v=vs.100%29
         * Copy registers onto stack.
             mov     8[RSP],RCX or XMM0
             mov     010h[RSP],RDX or XMM1
             mov     018h[RSP],R8 or XMM2
             mov     020h[RSP],R9 or XMM3
         */
        static immutable reg_t[4] vregs = [ CX,DX,R8,R9 ];
        for (int i = 0; i < vregs.length; ++i)
        {
            uint preg = vregs[i];
            uint offset = cast(uint)(cgstate.Para.size + i * REGSIZE);
            if (!(shadowregm & (mask(preg) | mask(XMM0 + i))))
            {
                if (cgstate.hasframe)
                {
                    // MOV x[EBP],preg
                    cdb.genc1(0x89,
                                     modregxrm(2,preg,BPRM),FL.const_, offset);
                    code_orrex(cdb.last(), REX_W);
                }
                else
                {
                    // MOV offset[ESP],preg
                    cdb.genc1(0x89,
                                     (modregrm(0,4,SP) << 8) |
                                     modregxrm(2,preg,4),FL.const_,offset + cgstate.EBPtoESP);
                }
                cdb.last().Irex |= REX_W;
            }
        }
    }

    /* Copy SCfastpar and SCshadowreg (parameters passed in registers) that were assigned registers
     * into their assigned registers.
     * Note that we have a big problem if Pa is passed in R1 and assigned to R2,
     * and Pb is passed in R2 but assigned to R1. Detect it and assert.
     */
    regm_t assignregs = 0;
    foreach (s; globsym[])
    {
        uint sz = cast(uint)type_size(s.Stype);

        if (!((s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg) && s.Sfl == FL.reg))
        {
            // Argument is passed in a register
            continue;
        }

        type* t = s.Stype;
        type* t2 = null;
        if (tybasic(t.Tty) == TYstruct && config.exe != EX_WIN64)
        {   type* targ1 = t.Ttag.Sstruct.Sarg1type;
            t2 = t.Ttag.Sstruct.Sarg2type;
            if (targ1)
                t = targ1;
        }

        reg_t preg = s.Spreg;
        reg_t r = s.Sreglsw;
        for (int i = 0; i < 2; ++i)
        {
            if (preg == NOREG)
                break;
            assert(!(mask(preg) & assignregs));         // not already stepped on
            assignregs |= mask(r);

            // MOV reg,preg
            if (r == preg)
            {
            }
            else if (mask(preg) & XMMREGS)
            {
                const op = xmmload(t.Tty);      // MOVSS/D xreg,preg
                uint xreg = r - XMM0;
                cdb.gen2(op,modregxrmx(3,xreg,preg - XMM0));
            }
            else
            {
                //printf("test1 mov %s, %s\n", regstring[r], regstring[preg]);
                genmovreg(cdb,r,preg);
                if (I64 && sz == 8)
                    code_orrex(cdb.last(), REX_W);
            }
            preg = s.Spreg2;
            r = s.Sregmsw;
            if (t2)
                t = t2;
        }
    }

    /* For parameters that were passed on the stack, but are enregistered by the function,
     * initialize the registers with the parameter stack values.
     * Do not use assignaddr(), as it will replace the stack reference with
     * the register.
     */
    foreach (s; globsym[])
    {
        uint sz = cast(uint)type_size(s.Stype);

        if (!((s.Sclass == SC.regpar || s.Sclass == SC.parameter) &&
            s.Sfl == FL.reg &&
            (cgstate.refparam
                // This variable has been reference by a nested function
                || MARS && s.Stype.Tty & mTYvolatile
                )))
        {
            continue;
        }
        // MOV reg,param[BP]
        //assert(refparam);
        if (mask(s.Sreglsw) & XMMREGS)
        {
            const op = xmmload(s.Stype.Tty);  // MOVSS/D xreg,mem
            uint xreg = s.Sreglsw - XMM0;
            cdb.genc1(op,modregxrm(2,xreg,BPRM),FL.const_,cgstate.Para.size + s.Soffset);
            if (!cgstate.hasframe)
            {   // Convert to ESP relative address rather than EBP
                code* c = cdb.last();
                c.Irm = cast(ubyte)modregxrm(2,xreg,4);
                c.Isib = modregrm(0,4,SP);
                c.IEV1.Vpointer += cgstate.EBPtoESP;
            }
            continue;
        }

        cdb.genc1(sz == 1 ? 0x8A : 0x8B,
            modregxrm(2,s.Sreglsw,BPRM),FL.const_,cgstate.Para.size + s.Soffset);
        code* c = cdb.last();
        if (!I16 && sz == SHORTSIZE)
            c.Iflags |= CFopsize; // operand size
        if (I64 && sz >= REGSIZE)
            c.Irex |= REX_W;
        if (I64 && sz == 1 && s.Sreglsw >= 4)
            c.Irex |= REX;
        if (!cgstate.hasframe)
        {   // Convert to ESP relative address rather than EBP
            assert(!I16);
            c.Irm = cast(ubyte)modregxrm(2,s.Sreglsw,4);
            c.Isib = modregrm(0,4,SP);
            c.IEV1.Vpointer += cgstate.EBPtoESP;
        }
        if (sz > REGSIZE)
        {
            cdb.genc1(0x8B,
                modregxrm(2,s.Sregmsw,BPRM),FL.const_,cgstate.Para.size + s.Soffset + REGSIZE);
            code* cx = cdb.last();
            if (I64)
                cx.Irex |= REX_W;
            if (!cgstate.hasframe)
            {   // Convert to ESP relative address rather than EBP
                assert(!I16);
                cx.Irm = cast(ubyte)modregxrm(2,s.Sregmsw,4);
                cx.Isib = modregrm(0,4,SP);
                cx.IEV1.Vpointer += cgstate.EBPtoESP;
            }
        }
    }
}

/*******************************
 * Generate and return function epilog.
 * Output:
 *      retsize         Size of function epilog
 */

@trusted
void epilog(block* b)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.epilog(b);

    code* cpopds;
    reg_t reg;
    reg_t regx;                      // register that's not a return reg
    regm_t topop,regm;
    targ_size_t xlocalsize = localsize;

    CodeBuilder cdbx; cdbx.ctor();
    tym_t tyf = funcsym_p.ty();
    tym_t tym = tybasic(tyf);
    bool farfunc = tyfarfunc(tym) != 0;
    if (!(b.Bflags & BFL.epilog))       // if no epilog code
        goto Lret;                      // just generate RET
    regx = (b.bc == BC.ret) ? AX : CX;

    cgstate.retsize = 0;

    if (tyf & mTYnaked)                 // if no prolog/epilog
        return;

    if (tym == TYifunc)
    {
        static immutable ubyte[5] ops2 = [ 0x07,0x1F,0x61,0xCF,0 ];
        static immutable ubyte[12] ops0 = [ 0x07,0x1F,0x5F,0x5E,
                                        0x5D,0x5B,0x5B,0x5A,
                                        0x59,0x58,0xCF,0 ];

        genregs(cdbx,0x8B,SP,BP);              // MOV SP,BP
        auto p = (config.target_cpu >= TARGET_80286) ? ops2.ptr : ops0.ptr;
        do
            cdbx.gen1(*p);
        while (*++p);
        goto Lopt;
    }

    if (config.flags & CFGtrace &&
        (!(config.flags4 & CFG4allcomdat) ||
         funcsym_p.Sclass == SC.comdat ||
         funcsym_p.Sclass == SC.global ||
         (config.flags2 & CFG2comdat && SymInline(funcsym_p))
        )
       )
    {
        Symbol* s = getRtlsym(farfunc ? RTLSYM.TRACE_EPI_F : RTLSYM.TRACE_EPI_N);
        makeitextern(s);
        cdbx.gencs(I16 ? 0x9A : CALL,0,FL.func,s);      // CALLF _trace
        if (!I16)
            code_orflag(cdbx.last(),CFoff | CFselfrel);
        useregs((ALLREGS | mBP | mES) & ~s.Sregsaved);
    }

    if (cgstate.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru) && (config.exe == EX_WIN32 || MARS))
    {
        nteh_epilog(cdbx);
    }

    cpopds = null;
    if (tyf & mTYloadds)
    {
        cdbx.gen1(0x1F);             // POP DS
        cpopds = cdbx.last();
    }

    /* Pop all the general purpose registers saved on the stack
     * by the prolog code. Remember to do them in the reverse
     * order they were pushed.
     */
    topop = fregsaved & ~cgstate.mfuncreg;
    epilog_restoreregs(cgstate, cdbx, topop);

    if (cgstate.usednteh & NTEHjmonitor)
    {
        regm_t retregs = 0;
        if (b.bc == BC.retexp)
            retregs = regmask(b.Belem.Ety, tym);
        nteh_monitor_epilog(cdbx,retregs);
        xlocalsize += 8;
    }

    if (config.wflags & WFwindows && farfunc)
    {
        int wflags = config.wflags;
        if (wflags & WFreduced && !(tyf & mTYexport))
        {   // reduced prolog/epilog for non-exported functions
            wflags &= ~(WFdgroup | WFds | WFss);
            if (!(wflags & WFsaveds))
                goto L4;
        }

        if (localsize)
        {
            cdbx.genc1(LEA,modregrm(1,SP,6),FL.const_,cast(targ_uns)-2); /* LEA SP,-2[BP] */
        }
        if (wflags & (WFsaveds | WFds | WFss | WFdgroup))
        {
            if (cpopds)
                cpopds.Iop = NOP;              // don't need previous one
            cdbx.gen1(0x1F);                    // POP DS
        }
        cdbx.genpop(BP);                        // POP BP
        if (config.wflags & WFincbp)
            cdbx.gen1(0x48 + BP);               // DEC BP
        assert(cgstate.hasframe);
    }
    else
    {
        if (cgstate.needframe || (xlocalsize && cgstate.hasframe))
        {
        L4:
            assert(cgstate.hasframe);
            if (xlocalsize || cgstate.enforcealign)
            {
                if (config.flags2 & CFG2stomp)
                {   /*   MOV  ECX,0xBEAF
                     * L1:
                     *   MOV  [ESP],ECX
                     *   ADD  ESP,4
                     *   CMP  EBP,ESP
                     *   JNE  L1
                     *   POP  EBP
                     */
                    /* Value should be:
                     * 1. != 0 (code checks for null pointers)
                     * 2. be odd (to mess up alignment)
                     * 3. fall in first 64K (likely marked as inaccessible)
                     * 4. be a value that stands out in the debugger
                     */
                    assert(I32 || I64);
                    targ_size_t value = 0x0000BEAF;
                    reg_t regcx = CX;
                    cgstate.mfuncreg &= ~mask(regcx);
                    uint grex = I64 ? REX_W << 16 : 0;
                    cdbx.genc2(0xC7,grex | modregrmx(3,0,regcx),value);   // MOV regcx,value
                    cdbx.gen2sib(0x89,grex | modregrm(0,regcx,4),modregrm(0,4,SP)); // MOV [ESP],regcx
                    code* c1 = cdbx.last();
                    cdbx.genc2(0x81,grex | modregrm(3,0,SP),REGSIZE);     // ADD ESP,REGSIZE
                    genregs(cdbx,0x39,SP,BP);                             // CMP EBP,ESP
                    if (I64)
                        code_orrex(cdbx.last(),REX_W);
                    genjmp(cdbx,JNE,FL.code,cast(block*)c1);                  // JNE L1
                    // explicitly mark as short jump, needed for correct retsize calculation (Bugzilla 15779)
                    cdbx.last().Iflags &= ~CFjmp16;
                    cdbx.genpop(BP);                                      // POP BP
                }
                else if (config.exe == EX_WIN64)
                {   // See https://msdn.microsoft.com/en-us/library/tawsa7cb%28v=vs.100%29.aspx
                    // LEA RSP,0[RBP]
                    cdbx.genc1(LEA,(REX_W<<16)|modregrm(2,SP,BPRM),FL.const_,0);
                    cdbx.genpop(BP);           // POP RBP
                }
                else if (config.target_cpu >= TARGET_80286 &&
                    !(config.target_cpu >= TARGET_80386 && config.flags4 & CFG4speed)
                   )
                    cdbx.gen1(LEAVE);          // LEAVE
                else if (0 && xlocalsize == REGSIZE && cgstate.Alloca.size == 0 && I32)
                {   // This doesn't work - I should figure out why
                    cgstate.mfuncreg &= ~mask(regx);
                    cdbx.genpop(regx);    // POP regx
                    cdbx.genpop(BP);      // POP BP
                }
                else
                {
                    genregs(cdbx,0x8B,SP,BP);  // MOV SP,BP
                    if (I64)
                        code_orrex(cdbx.last(), REX_W);   // MOV RSP,RBP
                    cdbx.genpop(BP);           // POP BP
                }
            }
            else
                cdbx.genpop(BP);               // POP BP
            if (config.wflags & WFincbp && farfunc)
                cdbx.gen1(0x48 + BP);              // DEC BP
        }
        else if (xlocalsize == REGSIZE && (!I16 || b.bc == BC.ret))
        {
            cgstate.mfuncreg &= ~mask(regx);
            cdbx.genpop(regx);                     // POP regx
        }
        else if (xlocalsize)
            cod3_stackadj(cdbx, cast(int)-xlocalsize);
    }
    if (b.bc == BC.ret || b.bc == BC.retexp)
    {
Lret:
        opcode_t op = tyfarfunc(tym) ? 0xCA : 0xC2;
        if (tym == TYhfunc)
        {
            cdbx.genc2(0xC2,0,4);                       // RET 4
        }
        else if (!typfunc(tym) ||                       // if caller cleans the stack
                 config.exe == EX_WIN64 ||
                 cgstate.Para.offset == 0)                      // or nothing pushed on the stack anyway
        {
            op++;                                       // to a regular RET
            cdbx.gen1(op);
        }
        else
        {   // Stack is always aligned on register size boundary
            cgstate.Para.offset = (cgstate.Para.offset + (REGSIZE - 1)) & ~(REGSIZE - 1);
            if (cgstate.Para.offset >= 0x10000)
            {
                /*
                    POP REG
                    ADD ESP, Para.offset
                    JMP REG
                */
                cdbx.genpop(regx);
                cdbx.genc2(0x81, modregrm(3,0,SP), cgstate.Para.offset);
                if (I64)
                    code_orrex(cdbx.last(), REX_W);
                cdbx.genc2(0xFF, modregrm(3,4,regx), 0);
                if (I64)
                    code_orrex(cdbx.last(), REX_W);
            }
            else
                cdbx.genc2(op,0,cgstate.Para.offset);          // RET Para.offset
        }
    }

Lopt:
    // If last instruction in ce is ADD SP,imm, and first instruction
    // in c sets SP, we can dump the ADD.
    CodeBuilder cdb; cdb.ctor();
    cdb.append(b.Bcode);
    code* cr = cdb.last();
    code* c = cdbx.peek();
    if (cr && c && !I64)
    {
        if (cr.Iop == 0x81 && cr.Irm == modregrm(3,0,SP))     // if ADD SP,imm
        {
            if (
                c.Iop == LEAVE ||                                // LEAVE
                (c.Iop == 0x8B && c.Irm == modregrm(3,SP,BP)) || // MOV SP,BP
                (c.Iop == LEA && c.Irm == modregrm(1,SP,6))     // LEA SP,-imm[BP]
               )
                cr.Iop = NOP;
            else if (c.Iop == 0x58 + BP)                       // if POP BP
            {
                cr.Iop = 0x8B;
                cr.Irm = modregrm(3,SP,BP);                    // MOV SP,BP
            }
        }
        else
        {
static if (0)
{
        // These optimizations don't work if the called function
        // cleans off the stack.
        if (c.Iop == 0xC3 && cr.Iop == CALL)     // CALL near
        {
            cr.Iop = 0xE9;                             // JMP near
            c.Iop = NOP;
        }
        else if (c.Iop == 0xCB && cr.Iop == 0x9A)     // CALL far
        {
            cr.Iop = 0xEA;                             // JMP far
            c.Iop = NOP;
        }
}
        }
    }

    pinholeopt(c, null);
    cgstate.retsize += calcblksize(c);          // compute size of function epilog
    cdb.append(cdbx);
    b.Bcode = cdb.finish();
}

/*******************************
 * Return offset of SP from BP.
 */

@trusted
targ_size_t cod3_spoff()
{
    //printf("spoff = x%x, localsize = x%x\n", cast(int)cgstate.spoff, cast(int)localsize);
    return cgstate.spoff + localsize;
}

@trusted
void gen_spill_reg(ref CodeBuilder cdb, Symbol* s, bool toreg)
{
    code cs;
    const regm_t keepmsk = 0;
    const RM rm = toreg ? RM.load : RM.store;

    elem* e = el_var(s); // so we can trick getlvalue() into working for us

    if (mask(s.Sreglsw) & XMMREGS)
    {   // Convert to save/restore of XMM register
        if (toreg)
            cs.Iop = xmmload(s.Stype.Tty);        // MOVSS/D xreg,mem
        else
            cs.Iop = xmmstore(s.Stype.Tty);       // MOVSS/D mem,xreg
        getlvalue(cdb,cs,e,keepmsk,rm);
        cs.orReg(s.Sreglsw - XMM0);
        cdb.gen(&cs);
    }
    else
    {
        const int sz = cast(int)type_size(s.Stype);
        cs.Iop = toreg ? 0x8B : 0x89; // MOV reg,mem[ESP] : MOV mem[ESP],reg
        cs.Iop ^= (sz == 1);
        getlvalue(cdb,cs,e,keepmsk,rm);
        cs.orReg(s.Sreglsw);
        if (I64 && sz == 1 && s.Sreglsw >= 4)
            cs.Irex |= REX;
        if ((cs.Irm & 0xC0) == 0xC0 &&                  // reg,reg
            (((cs.Irm >> 3) ^ cs.Irm) & 7) == 0 &&      // registers match
            (((cs.Irex >> 2) ^ cs.Irex) & 1) == 0)      // REX_R and REX_B match
        { }                                             // skip MOV reg,reg
        else
            cdb.gen(&cs);
        if (sz > REGSIZE)
        {
            cs.setReg(s.Sregmsw);
            getlvalue_msw(cs);
            if ((cs.Irm & 0xC0) == 0xC0 &&              // reg,reg
                (((cs.Irm >> 3) ^ cs.Irm) & 7) == 0 &&  // registers match
                (((cs.Irex >> 2) ^ cs.Irex) & 1) == 0)  // REX_R and REX_B match
            { }                                         // skip MOV reg,reg
            else
                cdb.gen(&cs);
        }
    }

    el_free(e);
}

/****************************
 * Generate code for, and output a thunk.
 * Params:
 *      sthunk =  Symbol of thunk
 *      sfunc =   Symbol of thunk's target function
 *      thisty =  Type of this pointer
 *      p =       ESP parameter offset to this pointer
 *      d =       offset to add to 'this' pointer
 *      d2 =      offset from 'this' to vptr
 *      i =       offset into vtbl[]
 */

@trusted
void cod3_thunk(Symbol* sthunk,Symbol* sfunc,uint p,tym_t thisty,
        uint d,int i,uint d2)
{
    targ_size_t thunkoffset;

    int seg = sthunk.Sseg;
    cod3_align(seg);

    // Skip over return address
    tym_t thunkty = tybasic(sthunk.ty());
    if (tyfarfunc(thunkty))
        p += I32 ? 8 : tysize(TYfptr);          // far function
    else
        p += tysize(TYnptr);
    if (tybasic(sfunc.ty()) == TYhfunc)
        p += tysize(TYnptr);                    // skip over hidden pointer

    CodeBuilder cdb; cdb.ctor();
    if (!I16)
    {
        /*
           Generate:
            ADD p[ESP],d
           For direct call:
            JMP sfunc
           For virtual call:
            MOV EAX, p[ESP]                     EAX = this
            MOV EAX, d2[EAX]                    EAX = this.vptr
            JMP i[EAX]                          jump to virtual function
         */
        if (config.flags3 & CFG3ibt)
            cdb.gen1(I32 ? ENDBR32 : ENDBR64);

        reg_t reg = 0;
        if (cast(int)d < 0)
        {
            d = -d;
            reg = 5;                            // switch from ADD to SUB
        }
        if (thunkty == TYmfunc)
        {                                       // ADD ECX,d
            if (d)
                cdb.genc2(0x81,modregrm(3,reg,CX),d);
        }
        else if (thunkty == TYjfunc || (I64 && thunkty == TYnfunc))
        {                                       // ADD EAX,d
            int rm = AX;
            if (config.exe == EX_WIN64)
                rm = CX;
            else if (I64)
                rm = (thunkty == TYnfunc && (sfunc.Sfunc.Fflags3 & F3hiddenPtr)) ? SI : DI;
            if (d)
                cdb.genc2(0x81,modregrm(3,reg,rm),d);
        }
        else
        {
            cdb.genc(0x81,modregrm(2,reg,4),
                FL.const_,p,                      // to this
                FL.const_,d);                     // ADD p[ESP],d
            cdb.last().Isib = modregrm(0,4,SP);
        }
        if (I64 && cdb.peek())
            cdb.last().Irex |= REX_W;
    }
    else
    {
        /*
           Generate:
            MOV BX,SP
            ADD [SS:] p[BX],d
           For direct call:
            JMP sfunc
           For virtual call:
            MOV BX, p[BX]                       BX = this
            MOV BX, d2[BX]                      BX = this.vptr
            JMP i[BX]                           jump to virtual function
         */

        genregs(cdb,0x89,SP,BX);           // MOV BX,SP
        cdb.genc(0x81,modregrm(2,0,7),
            FL.const_,p,                                  // to this
            FL.const_,d);                                 // ADD p[BX],d
        if (config.wflags & WFssneds ||
            // If DS needs reloading from SS,
            // then assume SS != DS on thunk entry
            (LARGEDATA && config.wflags & WFss))
            cdb.last().Iflags |= CFss;                 // SS:
    }

    if ((i & 0xFFFF) != 0xFFFF)                 // if virtual call
    {
        const bool FARTHIS = (tysize(thisty) > REGSIZE);
        const bool FARVPTR = FARTHIS;

        assert(thisty != TYvptr);               // can't handle this case

        if (!I16)
        {
            assert(!FARTHIS && !LARGECODE);
            if (thunkty == TYmfunc)     // if 'this' is in ECX
            {
                // MOV EAX,d2[ECX]
                cdb.genc1(0x8B,modregrm(2,AX,CX),FL.const_,d2);
            }
            else if (thunkty == TYjfunc)        // if 'this' is in EAX
            {
                // MOV EAX,d2[EAX]
                cdb.genc1(0x8B,modregrm(2,AX,AX),FL.const_,d2);
            }
            else
            {
                // MOV EAX,p[ESP]
                cdb.genc1(0x8B,(modregrm(0,4,SP) << 8) | modregrm(2,AX,4),FL.const_,cast(targ_uns) p);
                if (I64)
                    cdb.last().Irex |= REX_W;

                // MOV EAX,d2[EAX]
                cdb.genc1(0x8B,modregrm(2,AX,AX),FL.const_,d2);
            }
            if (I64)
                code_orrex(cdb.last(), REX_W);
                                                        // JMP i[EAX]
            cdb.genc1(0xFF,modregrm(2,4,0),FL.const_,cast(targ_uns) i);
        }
        else
        {
            // MOV/LES BX,[SS:] p[BX]
            cdb.genc1((FARTHIS ? 0xC4 : 0x8B),modregrm(2,BX,7),FL.const_,cast(targ_uns) p);
            if (config.wflags & WFssneds ||
                // If DS needs reloading from SS,
                // then assume SS != DS on thunk entry
                (LARGEDATA && config.wflags & WFss))
                cdb.last().Iflags |= CFss;             // SS:

            // MOV/LES BX,[ES:]d2[BX]
            cdb.genc1((FARVPTR ? 0xC4 : 0x8B),modregrm(2,BX,7),FL.const_,d2);
            if (FARTHIS)
                cdb.last().Iflags |= CFes;             // ES:

                                                        // JMP i[BX]
            cdb.genc1(0xFF,modregrm(2,(LARGECODE ? 5 : 4),7),FL.const_,cast(targ_uns) i);
            if (FARVPTR)
                cdb.last().Iflags |= CFes;             // ES:
        }
    }
    else
    {
        if (config.flags3 & CFG3pic)
        {
            localgot = null;                // no local variables
            CodeBuilder cdbgot; cdbgot.ctor();
            load_localgot(cdbgot);          // load GOT in EBX
            code* c1 = cdbgot.finish();
            if (c1)
            {
                assignaddrc(c1);
                cdb.append(c1);
            }
        }
        cdb.gencs((LARGECODE ? 0xEA : 0xE9),0,FL.func,sfunc); // JMP sfunc
        cdb.last().Iflags |= LARGECODE ? (CFseg | CFoff) : (CFselfrel | CFoff);
    }

    thunkoffset = Offset(seg);
    code* c = cdb.finish();
    pinholeopt(c,null);
    targ_size_t framehandleroffset;
    codout(seg,c,null,framehandleroffset);
    code_free(c);

    sthunk.Soffset = thunkoffset;
    sthunk.Ssize = Offset(seg) - thunkoffset; // size of thunk
    sthunk.Sseg = seg;
    if (config.exe & EX_posix ||
       config.objfmt == OBJ_MSCOFF)
    {
        objmod.pubdef(seg,sthunk,sthunk.Soffset);
    }
}

/*****************************
 * Assume symbol s is extern.
 */

@trusted
void makeitextern(Symbol* s)
{
    if (s.Sxtrnnum == 0)
    {
        s.Sclass = SC.extern_;           /* external             */
        /*printf("makeitextern(x%x)\n",s);*/
        objmod.external(s);
    }
}


/*******************************
 * Replace JMPs in Bgotocode with JMP SHORTs whereever possible.
 * This routine depends on FL.code jumps to only be forward
 * referenced.
 * BFL.jmpoptdone is set to true if nothing more can be done
 * with this block.
 * Input:
 *      flag    !=0 means don't have correct Boffsets yet
 * Returns:
 *      number of bytes saved
 */

@trusted
int branch(block* bl,int flag)
{
    if (cgstate.AArch64)
    {
        import dmd.backend.arm.cod3 : branch;
        return branch(bl, flag);
    }

    int bytesaved;
    code* c,cn,ct;
    targ_size_t offset,disp;
    targ_size_t csize;

    if (!flag)
        bl.Bflags |= BFL.jmpoptdone;      // assume this will be all
    c = bl.Bcode;
    if (!c)
        return 0;
    bytesaved = 0;
    offset = bl.Boffset;                 /* offset of start of block     */
    while (1)
    {
        ubyte op;

        csize = calccodsize(c);
        cn = code_next(c);
        op = cast(ubyte)c.Iop;
        if ((op & ~0x0F) == 0x70 && c.Iflags & CFjmp16 ||
            (op == JMP && !(c.Iflags & CFjmp5)))
        {
          L1:
            switch (c.IFL2)
            {
                case FL.block:
                    if (flag)           // no offsets yet, don't optimize
                        goto L3;
                    disp = c.IEV2.Vblock.Boffset - offset - csize;

                    /* If this is a forward branch, and there is an aligned
                     * block intervening, it is possible that shrinking
                     * the jump instruction will cause it to be out of
                     * range of the target. This happens if the alignment
                     * prevents the target block from moving correspondingly
                     * closer.
                     */
                    if (disp >= 0x7F-4 && c.IEV2.Vblock.Boffset > offset)
                    {   /* Look for intervening alignment
                         */
                        for (block* b = bl.Bnext; b; b = b.Bnext)
                        {
                            if (b.Balign)
                            {
                                bl.Bflags = cast(BFL)(bl.Bflags & ~cast(uint)BFL.jmpoptdone); // some JMPs left
                                goto L3;
                            }
                            if (b == c.IEV2.Vblock)
                                break;
                        }
                    }

                    break;

                case FL.code:
                {
                    code* cr;

                    disp = 0;

                    ct = c.IEV2.Vcode;         /* target of branch     */
                    assert(ct.Iflags & (CFtarg | CFtarg2));
                    for (cr = cn; cr; cr = code_next(cr))
                    {
                        if (cr == ct)
                            break;
                        disp += calccodsize(cr);
                    }

                    if (!cr)
                    {   // Didn't find it in forward search. Try backwards jump
                        int s = 0;
                        disp = 0;
                        for (cr = bl.Bcode; cr != cn; cr = code_next(cr))
                        {
                            assert(cr != null); // must have found it
                            if (cr == ct)
                                s = 1;
                            if (s)
                                disp += calccodsize(cr);
                        }
                    }

                    if (config.flags4 & CFG4optimized && !flag)
                    {
                        /* Propagate branch forward past junk   */
                        while (1)
                        {
                            if (ct.Iop == NOP ||
                                ct.Iop == PSOP.linnum)
                            {
                                ct = code_next(ct);
                                if (!ct)
                                    goto L2;
                            }
                            else
                            {
                                c.IEV2.Vcode = ct;
                                ct.Iflags |= CFtarg;
                                break;
                            }
                        }

                        /* And eliminate jmps to jmps   */
                        if ((op == ct.Iop || ct.Iop == JMP) &&
                            (op == JMP || c.Iflags & CFjmp16))
                        {
                            c.IFL2 = ct.IFL2;
                            c.IEV2.Vcode = ct.IEV2.Vcode;
                            /*printf("eliminating branch\n");*/
                            goto L1;
                        }
                     L2:
                        { }
                    }
                }
                    break;

                default:
                    goto L3;
            }

            if (disp == 0)                      // bra to next instruction
            {
                bytesaved += csize;
                c.Iop = NOP;                   // del branch instruction
                c.IEV2.Vcode = null;
                c = cn;
                if (!c)
                    break;
                continue;
            }
            else if (cast(targ_size_t)cast(targ_schar)(disp - 2) == (disp - 2) &&
                     cast(targ_size_t)cast(targ_schar)disp == disp)
            {
                if (op == JMP)
                {
                    c.Iop = JMPS;              // JMP SHORT
                    bytesaved += I16 ? 1 : 3;
                }
                else                            // else Jcond
                {
                    c.Iflags &= ~CFjmp16;      // a branch is ok
                    bytesaved += I16 ? 3 : 4;

                    // Replace a cond jump around a call to a function that
                    // never returns with a cond jump to that function.
                    if (config.flags4 & CFG4optimized &&
                        config.target_cpu >= TARGET_80386 &&
                        disp == (I16 ? 3 : 5) &&
                        cn &&
                        cn.Iop == CALL &&
                        cn.IFL2 == FL.func &&
                        cn.IEV2.Vsym.Sflags & SFLexit &&
                        !(cn.Iflags & (CFtarg | CFtarg2))
                       )
                    {
                        cn.Iop = 0x0F00 | ((c.Iop & 0x0F) ^ 0x81);
                        c.Iop = NOP;
                        c.IEV2.Vcode = null;
                        bytesaved++;

                        // If nobody else points to ct, we can remove the CFtarg
                        if (flag && ct)
                        {
                            code* cx;
                            for (cx = bl.Bcode; 1; cx = code_next(cx))
                            {
                                if (!cx)
                                {
                                    ct.Iflags &= ~CFtarg;
                                    break;
                                }
                                if (cx.IEV2.Vcode == ct)
                                    break;
                            }
                        }
                    }
                }
                csize = calccodsize(c);
            }
            else
                bl.Bflags = cast(BFL)(bl.Bflags & ~cast(uint)BFL.jmpoptdone); // some JMPs left
        }
L3:
        if (cn)
        {
            offset += csize;
            c = cn;
        }
        else
            break;
    }
    //printf("bytesaved = x%x\n",bytesaved);
    return bytesaved;
}


/************************************************
 * Adjust all Soffset's of stack variables so they
 * are all relative to the frame pointer.
 */

@trusted
void cod3_adjSymOffsets()
{
    SYMIDX si;

    //printf("cod3_adjSymOffsets()\n");
    foreach (s; globsym[])
    {
        //printf("\tglobsym[%d] = %p\n",si,globsym[si]);

        switch (s.Sclass)
        {
            case SC.parameter:
            case SC.regpar:
            case SC.shadowreg:
//printf("s = '%s', Soffset = x%x, Para.size = x%x, EBPtoESP = x%x\n", s.Sident, s.Soffset, cgstate.Para.size, cgstate.EBPtoESP);
                s.Soffset += cgstate.Para.size;
                if (0 && !(funcsym_p.Sfunc.Fflags3 & Fmember))
                {
                    if (!cgstate.hasframe)
                        s.Soffset += cgstate.EBPtoESP;
                    if (funcsym_p.Sfunc.Fflags3 & Fnested)
                        s.Soffset += REGSIZE;
                }
                break;

            case SC.fastpar:
//printf("\tfastpar %s %p Soffset %x Fast.size %x BPoff %x\n", s.Sident, s, cast(int)s.Soffset, cast(int)cgstate.Fast.size, cast(int)cgstate.BPoff);
                s.Soffset += cgstate.Fast.size + cgstate.BPoff;
                break;

            case SC.auto_:
            case SC.register:
                if (s.Sfl == FL.fast)
                    s.Soffset += cgstate.Fast.size + cgstate.BPoff;
                else
//printf("s = '%s', Soffset = x%x, Auto.size = x%x, BPoff = x%x EBPtoESP = x%x\n", s.Sident, cast(int)s.Soffset, cast(int)cgstate.Auto.size, cast(int)cgstate.BPoff, cast(int)cgstate.EBPtoESP);
//              if (!(funcsym_p.Sfunc.Fflags3 & Fnested))
                    s.Soffset += cgstate.Auto.size + cgstate.BPoff;
                break;

            case SC.bprel:
                break;

            default:
                continue;
        }
        static if (0)
        {
            if (!cgstate.hasframe)
                s.Soffset += cgstate.EBPtoESP;
        }
    }
}

/*******************************
 * Take symbol info in union ev and replace it with a real address
 * in Vpointer.
 */

@trusted
void assignaddr(block* bl)
{
    int EBPtoESPsave = cgstate.EBPtoESP;
    const hasframesave = cgstate.hasframe;

    if (bl.Bflags & BFL.outsideprolog)
    {
        cgstate.EBPtoESP = -REGSIZE;
        cgstate.hasframe = false;
    }
    assignaddrc(bl.Bcode);
    cgstate.hasframe = hasframesave;
    cgstate.EBPtoESP = EBPtoESPsave;
}

@trusted
void assignaddrc(code* c)
{
    if (cgstate.AArch64)
    {
        import dmd.backend.arm.cod3 : assignaddrc;
        return assignaddrc(c);
    }

    int sn;
    Symbol* s;
    ubyte ins,rm;
    targ_size_t soff;
    targ_size_t base;

    base = cgstate.EBPtoESP;
    for (; c; c = code_next(c))
    {
        debug
        {
        if (0)
        {       printf("assignaddrc()\n");
                code_print(c);
        }
        if (code_next(c) && code_next(code_next(c)) == c)
            assert(0);
        }

        if (c.Iflags & CFvex && c.Ivex.pfx == 0xC4)
            ins = vex_inssize(c);
        else if ((c.Iop & 0xFFFD00) == 0x0F3800)
            ins = inssize2[(c.Iop >> 8) & 0xFF];
        else if ((c.Iop & 0xFF00) == 0x0F00)
            ins = inssize2[c.Iop & 0xFF];
        else if ((c.Iop & PSOP.mask) == PSOP.root)
        {
            if (c.Iop == PSOP.adjesp)
            {
                //printf("adjusting EBPtoESP (%d) by %ld\n",cgstate.EBPtoESP,cast(long)c.IEV1.Vint);
                cgstate.EBPtoESP += c.IEV1.Vint;
                c.Iop = NOP;
            }
            else if (c.Iop == PSOP.fixesp)
            {
                //printf("fix ESP\n");
                if (cgstate.hasframe)
                {
                    // LEA ESP,-EBPtoESP[EBP]
                    c.Iop = LEA;
                    if (c.Irm & 8)
                        c.Irex |= REX_R;
                    c.Irm = modregrm(2,SP,BP);
                    c.Iflags = CFoff;
                    c.IFL1 = FL.const_;
                    c.IEV1.Vuns = -cgstate.EBPtoESP;
                    if (cgstate.enforcealign)
                    {
                        // AND ESP, -STACKALIGN
                        code* cn = code_calloc();
                        cn.Iop = 0x81;
                        cn.Irm = modregrm(3, 4, SP);
                        cn.Iflags = CFoff;
                        cn.IFL2 = FL.const_;
                        cn.IEV2.Vsize_t = -STACKALIGN;
                        if (I64)
                            c.Irex |= REX_W;
                        cn.next = c.next;
                        c.next = cn;
                    }
                }
            }
            else if (c.Iop == PSOP.frameptr)
            {   // Convert to load of frame pointer
                // c.Irm is the register to use
                if (cgstate.hasframe && !cgstate.enforcealign)
                {   // MOV reg,EBP
                    c.Iop = 0x89;
                    if (c.Irm & 8)
                        c.Irex |= REX_B;
                    c.Irm = modregrm(3,BP,c.Irm & 7);
                }
                else
                {   // LEA reg,EBPtoESP[ESP]
                    c.Iop = LEA;
                    if (c.Irm & 8)
                        c.Irex |= REX_R;
                    c.Irm = modregrm(2,c.Irm & 7,4);
                    c.Isib = modregrm(0,4,SP);
                    c.Iflags = CFoff;
                    c.IFL1 = FL.const_;
                    c.IEV1.Vuns = cgstate.EBPtoESP;
                }
            }
            if (I64)
                c.Irex |= REX_W;
            continue;
        }
        else
            ins = inssize[c.Iop & 0xFF];
        if (!(ins & M) ||
            ((rm = c.Irm) & 0xC0) == 0xC0)
            goto do2;           /* if no first operand          */
        if (is32bitaddr(I32,c.Iflags))
        {

            if (
                ((rm & 0xC0) == 0 && !((rm & 7) == 4 && (c.Isib & 7) == 5 || (rm & 7) == 5))
               )
                goto do2;       /* if no first operand  */
        }
        else
        {
            if (
                ((rm & 0xC0) == 0 && !((rm & 7) == 6))
               )
                goto do2;       /* if no first operand  */
        }
        s = c.IEV1.Vsym;
        switch (c.IFL1)
        {
            case FL.data:
                if (config.objfmt == OBJ_OMF && s.Sclass != SC.comdat && s.Sclass != SC.extern_)
                {
                    c.IEV1.Vseg = s.Sseg;
                    c.IEV1.Vpointer += s.Soffset;
                    c.IFL1 = FL.datseg;
                }
                else
                    c.IFL1 = FL.extern_;
                goto do2;

            case FL.udata:
                if (config.objfmt == OBJ_OMF)
                {
                    c.IEV1.Vseg = s.Sseg;
                    c.IEV1.Vpointer += s.Soffset;
                    c.IFL1 = FL.datseg;
                }
                else
                    c.IFL1 = FL.extern_;
                goto do2;

            case FL.tlsdata:
                if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                    c.IFL1 = FL.extern_;
                goto do2;

            case FL.datseg:
                //c.IEV1.Vseg = DATA;
                goto do2;

            case FL.fardata:
            case FL.csdata:
            case FL.pseudo:
                goto do2;

            case FL.stack:
                //printf("Soffset = %d, EBPtoESP = %d, base = %d, pointer = %d\n",
                //s.Soffset,cgstate.EBPtoESP,base,c.IEV1.Vpointer);
                c.IEV1.Vpointer += s.Soffset + cgstate.EBPtoESP - base - cgstate.EEStack.offset;
                break;

            case FL.fast:
                soff = cgstate.Fast.size;
                goto L1;

            case FL.reg:
            case FL.auto_:
                soff = cgstate.Auto.size;
            L1:
                if (Symbol_Sisdead(*s, cgstate.anyiasm))
                {
                    c.Iop = NOP;               // remove references to it
                    continue;
                }
                if (s.Sfl == FL.reg && c.IEV1.Vpointer < 2)
                {
                    reg_t reg = s.Sreglsw;

                    assert(!(s.Sregm & ~mask(reg)));
                    if (c.IEV1.Vpointer == 1)
                    {
                        assert(reg < 4);    /* must be a BYTEREGS   */
                        reg |= 4;           /* convert to high byte reg */
                    }
                    if (reg & 8)
                    {
                        assert(I64);
                        c.Irex |= REX_B;
                        reg &= 7;
                    }
                    c.Irm = (c.Irm & modregrm(0,7,0))
                            | modregrm(3,0,reg);
                    assert(c.Iop != LES && c.Iop != LEA);
                    goto do2;
                }
                else
                {   c.IEV1.Vpointer += s.Soffset + soff + cgstate.BPoff;
                    if (s.Sflags & SFLunambig)
                        c.Iflags |= CFunambig;
            L2:
                    if (!cgstate.hasframe || (cgstate.enforcealign && c.IFL1 != FL.para))
                    {   /* Convert to ESP relative address instead of EBP */
                        assert(!I16);
                        c.IEV1.Vpointer += cgstate.EBPtoESP;
                        ubyte crm = c.Irm;
                        if ((crm & 7) == 4)              // if SIB byte
                        {
                            assert((c.Isib & 7) == BP);
                            assert((crm & 0xC0) != 0);
                            c.Isib = (c.Isib & ~7) | modregrm(0,0,SP);
                        }
                        else
                        {
                            assert((crm & 7) == 5);
                            c.Irm = (crm & modregrm(0,7,0))
                                    | modregrm(2,0,4);
                            c.Isib = modregrm(0,4,SP);
                        }
                    }
                }
                break;

            case FL.para:
                //printf("s = %s, Soffset = %d, Para.size = %d, BPoff = %d, EBPtoESP = %d, Vpointer = %d\n",
                //s.Sident.ptr, cast(int)s.Soffset, cast(int)Para.size, cast(int)cgstate.BPoff,
                //cast(int)cgstate.EBPtoESP, cast(int)c.IEV1.Vpointer);
                soff = cgstate.Para.size - cgstate.BPoff;    // cancel out add of BPoff
                goto L1;

            case FL.fltreg:
                c.IEV1.Vpointer += cgstate.Foff + cgstate.BPoff;
                c.Iflags |= CFunambig;
                goto L2;

            case FL.allocatmp:
                c.IEV1.Vpointer += cgstate.Alloca.offset + cgstate.BPoff;
                goto L2;

            case FL.funcarg:
                c.IEV1.Vpointer += cgstate.funcarg.offset + cgstate.BPoff;
                goto L2;

            case FL.bprel:
                c.IEV1.Vpointer += s.Soffset;
                break;

            case FL.cs:
                sn = c.IEV1.Vuns;
                if (!CSE.loaded(sn))            // if never loaded
                {
                    c.Iop = NOP;
                    continue;
                }
                c.IEV1.Vpointer = CSE.offset(sn) + cgstate.CSoff + cgstate.BPoff;
                c.Iflags |= CFunambig;
                goto L2;

            case FL.regsave:
                sn = c.IEV1.Vuns;
                c.IEV1.Vpointer = sn + cgstate.regsave.off + cgstate.BPoff;
                c.Iflags |= CFunambig;
                goto L2;

            case FL.ndp:
                assert(c.IEV1.Vuns < global87.save.length);
                c.IEV1.Vpointer = c.IEV1.Vuns * tysize(TYldouble) + cgstate.NDPoff + cgstate.BPoff;
                c.Iflags |= CFunambig;
                goto L2;

            case FL.offset:
                break;

            case FL.localsize:
                c.IEV1.Vpointer += localsize;
                break;

            case FL.const_:
            default:
                goto do2;
        }
        c.IFL1 = FL.const_;
    do2:
        /* Ignore TEST (F6 and F7) opcodes      */
        if (!(ins & T)) goto done;              /* if no second operand */
        s = c.IEV2.Vsym;
        switch (c.IFL2)
        {
            case FL.data:
                if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                {
                    c.IFL2 = FL.extern_;
                    goto do2;
                }
                else
                {
                    if (s.Sclass == SC.comdat)
                    {   c.IFL2 = FL.extern_;
                        goto do2;
                    }
                    c.IEV2.Vseg = MARS ? s.Sseg : DATA;
                    c.IEV2.Vpointer += s.Soffset;
                    c.IFL2 = FL.datseg;
                    goto done;
                }

            case FL.udata:
                if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                {
                    c.IFL2 = FL.extern_;
                    goto do2;
                }
                else
                {
                    c.IEV2.Vseg = MARS ? s.Sseg : UDATA;
                    c.IEV2.Vpointer += s.Soffset;
                    c.IFL2 = FL.datseg;
                    goto done;
                }

            case FL.tlsdata:
                if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                {
                    c.IFL2 = FL.extern_;
                    goto do2;
                }
                goto done;

            case FL.datseg:
                //c.IEV2.Vseg = DATA;
                goto done;

            case FL.csdata:
            case FL.fardata:
                goto done;

            case FL.reg:
            case FL.pseudo:
                assert(0);
                /* NOTREACHED */

            case FL.fast:
                c.IEV2.Vpointer += s.Soffset + cgstate.Fast.size + cgstate.BPoff;
                break;

            case FL.auto_:
                c.IEV2.Vpointer += s.Soffset + cgstate.Auto.size + cgstate.BPoff;
            L3:
                if (!cgstate.hasframe || (cgstate.enforcealign && c.IFL2 != FL.para))
                    /* Convert to ESP relative address instead of EBP */
                    c.IEV2.Vpointer += cgstate.EBPtoESP;
                break;

            case FL.para:
                c.IEV2.Vpointer += s.Soffset + cgstate.Para.size;
                goto L3;

            case FL.fltreg:
                c.IEV2.Vpointer += cgstate.Foff + cgstate.BPoff;
                goto L3;

            case FL.allocatmp:
                c.IEV2.Vpointer += cgstate.Alloca.offset + cgstate.BPoff;
                goto L3;

            case FL.funcarg:
                c.IEV2.Vpointer += cgstate.funcarg.offset + cgstate.BPoff;
                goto L3;

            case FL.bprel:
                c.IEV2.Vpointer += s.Soffset;
                break;

            case FL.stack:
                c.IEV2.Vpointer += s.Soffset + cgstate.EBPtoESP - base;
                break;

            case FL.cs:
            case FL.ndp:
            case FL.regsave:
                assert(0);

            case FL.const_:
                break;

            case FL.localsize:
                c.IEV2.Vpointer += localsize;
                break;

            default:
                goto done;
        }
        c.IFL2 = FL.const_;
  done:
        { }
    }
}

/*******************************
 * Return offset from BP of symbol s.
 */

@trusted
targ_size_t cod3_bpoffset(Symbol* s)
{
    targ_size_t offset;

    symbol_debug(s);
    offset = s.Soffset;
    switch (s.Sfl)
    {
        case FL.para:
            offset += cgstate.Para.size;
            break;

        case FL.fast:
            offset += cgstate.Fast.size + cgstate.BPoff;
            break;

        case FL.auto_:
            offset += cgstate.Auto.size + cgstate.BPoff;
            break;

        default:
            symbol_print(*s);
            assert(0);
    }
    assert(cgstate.hasframe);
    return offset;
}


/*******************************
 * Find shorter versions of the same instructions.
 * Does these optimizations:
 *      replaces jmps to the next instruction with NOPs
 *      sign extension of modregrm displacement
 *      sign extension of immediate data (can't do it for OR, AND, XOR
 *              as the opcodes are not defined)
 *      short versions for AX EA
 *      short versions for reg EA
 * Code is neither removed nor added.
 * Params:
 *      b = block for code (or null)
 *      c = code list to optimize
 */

@trusted
void pinholeopt(code* c,block* b)
{
    if (cgstate.AArch64)
        return;

    targ_size_t a;
    uint mod;
    ubyte ins;
    int usespace;
    int useopsize;
    int space;
    block* bn;

    debug
    {
        __gshared int tested; if (!tested) { tested++; pinholeopt_unittest(); }
    }

    debug
    {
        code* cstart = c;
        if (debugc)
        {
            printf("+pinholeopt(%p)\n",c);
        }
    }

    if (b)
    {
        bn = b.Bnext;
        usespace = (config.flags4 & CFG4space && b.bc != BC.asm_);
        useopsize = (I16 || (config.flags4 & CFG4space && b.bc != BC.asm_));
    }
    else
    {
        bn = null;
        usespace = (config.flags4 & CFG4space);
        useopsize = (I16 || config.flags4 & CFG4space);
    }
    for (; c; c = code_next(c))
    {
    L1:
        opcode_t op = c.Iop;
        if (c.Iflags & CFvex && c.Ivex.pfx == 0xC4)
            ins = vex_inssize(c);
        else if ((op & 0xFFFD00) == 0x0F3800)
            ins = inssize2[(op >> 8) & 0xFF];
        else if ((op & 0xFF00) == 0x0F00)
            ins = inssize2[op & 0xFF];
        else
            ins = inssize[op & 0xFF];
        if (ins & M)            // if modregrm byte
        {
            int shortop = (c.Iflags & CFopsize) ? !I16 : I16;
            int local_BPRM = BPRM;

            if (c.Iflags & CFaddrsize)
                local_BPRM ^= 5 ^ 6;    // toggle between 5 and 6

            uint rm = c.Irm;
            reg_t reg = rm & modregrm(0,7,0);          // isolate reg field
            reg_t ereg = rm & 7;
            //printf("c = %p, op = %02x rm = %02x\n", c, op, rm);

            /* If immediate second operand      */
            if ((ins & T ||
                 ((op == 0xF6 || op == 0xF7) && (reg < modregrm(0,2,0) || reg > modregrm(0,3,0)))
                ) &&
                c.IFL2 == FL.const_)
            {
                int flags = c.Iflags & CFpsw;      /* if want result in flags */
                targ_long u = c.IEV2.Vuns;
                if (ins & E)
                    u = cast(byte) u;
                else if (shortop)
                    u = cast(short) u;

                // Replace CMP reg,0 with TEST reg,reg
                if ((op & 0xFE) == 0x80 &&              // 80 is CMP R8,imm8; 81 is CMP reg,imm
                    rm >= modregrm(3,7,AX) &&
                    u == 0)
                {
                    c.Iop = (op & 1) | 0x84;
                    c.Irm = modregrm(3,ereg,ereg);
                    if (c.Irex & REX_B)
                        c.Irex |= REX_R;
                    goto L1;
                }

                /* Optimize ANDs with an immediate constant             */
                if ((op == 0x81 || op == 0x80) && reg == modregrm(0,4,0))
                {
                    if (rm >= modregrm(3,4,AX))         // AND reg,imm
                    {
                        if (u == 0)
                        {
                            /* Replace with XOR reg,reg     */
                            c.Iop = 0x30 | (op & 1);
                            c.Irm = modregrm(3,ereg,ereg);
                            if (c.Irex & REX_B)
                                c.Irex |= REX_R;
                            goto L1;
                        }
                        if (u == 0xFFFFFFFF && !flags)
                        {
                            c.Iop = NOP;
                            goto L1;
                        }
                    }
                    if (op == 0x81 && !flags)
                    {   // If we can do the operation in one byte

                        // If EA is not SI or DI
                        if ((rm < modregrm(3,4,SP) || I64) &&
                            (config.flags4 & CFG4space ||
                             config.target_cpu < TARGET_PentiumPro)
                           )
                        {
                            if ((u & 0xFFFFFF00) == 0xFFFFFF00)
                                goto L2;
                            else if (rm < modregrm(3,0,0) || (!c.Irex && ereg < 4))
                            {
                                if (!shortop)
                                {
                                    if ((u & 0xFFFF00FF) == 0xFFFF00FF)
                                        goto L3;
                                }
                                else
                                {
                                    if ((u & 0xFF) == 0xFF)
                                        goto L3;
                                }
                            }
                        }
                        if (!shortop && useopsize)
                        {
                            if ((u & 0xFFFF0000) == 0xFFFF0000)
                            {
                                c.Iflags ^= CFopsize;
                                goto L1;
                            }
                            if ((u & 0xFFFF) == 0xFFFF && rm < modregrm(3,4,AX))
                            {
                                c.IEV1.Voffset += 2; /* address MSW      */
                                c.IEV2.Vuns >>= 16;
                                c.Iflags ^= CFopsize;
                                goto L1;
                            }
                            if (rm >= modregrm(3,4,AX))
                            {
                                if (u == 0xFF && (rm <= modregrm(3,4,BX) || I64))
                                {
                                    c.Iop = MOVZXb;     // MOVZX
                                    c.Irm = modregrm(3,ereg,ereg);
                                    if (c.Irex & REX_B)
                                        c.Irex |= REX_R;
                                    goto L1;
                                }
                                if (u == 0xFFFF)
                                {
                                    c.Iop = MOVZXw;     // MOVZX
                                    c.Irm = modregrm(3,ereg,ereg);
                                    if (c.Irex & REX_B)
                                        c.Irex |= REX_R;
                                    goto L1;
                                }
                            }
                        }
                    }
                }

                /* Look for ADD,OR,SUB,XOR with u that we can eliminate */
                if (!flags &&
                    (op == 0x81 || op == 0x80) &&
                    (reg == modregrm(0,0,0) || reg == modregrm(0,1,0) ||  // ADD,OR
                     reg == modregrm(0,5,0) || reg == modregrm(0,6,0))    // SUB, XOR
                   )
                {
                    if (u == 0)
                    {
                        c.Iop = NOP;
                        goto L1;
                    }
                    if (u == ~0 && reg == modregrm(0,6,0))  /* XOR  */
                    {
                        c.Iop = 0xF6 | (op & 1);       /* NOT  */
                        c.Irm ^= modregrm(0,6^2,0);
                        goto L1;
                    }
                    if (!shortop &&
                        useopsize &&
                        op == 0x81 &&
                        (u & 0xFFFF0000) == 0 &&
                        (reg == modregrm(0,6,0) || reg == modregrm(0,1,0)))
                    {
                        c.Iflags ^= CFopsize;
                        goto L1;
                    }
                }

                /* Look for TEST or OR or XOR with an immediate constant */
                /* that we can replace with a byte operation            */
                if (op == 0xF7 && reg == modregrm(0,0,0) ||
                    op == 0x81 && reg == modregrm(0,6,0) && !flags ||
                    op == 0x81 && reg == modregrm(0,1,0))
                {
                    // See if we can replace a dword with a word
                    // (avoid for 32 bit instructions, because CFopsize
                    //  is too slow)
                    if (!shortop && useopsize)
                    {
                        if ((u & 0xFFFF0000) == 0)
                        {
                            c.Iflags ^= CFopsize;
                            goto L1;
                        }
                        /* If memory (not register) addressing mode     */
                        if ((u & 0xFFFF) == 0 && rm < modregrm(3,0,AX))
                        {
                            c.IEV1.Voffset += 2; /* address MSW  */
                            c.IEV2.Vuns >>= 16;
                            c.Iflags ^= CFopsize;
                            goto L1;
                        }
                    }

                    // If EA is not SI or DI
                    if (rm < (modregrm(3,0,SP) | reg) &&
                        (usespace ||
                         config.target_cpu < TARGET_PentiumPro)
                       )
                    {
                        if ((u & 0xFFFFFF00) == 0)
                        {
                        L2: c.Iop--;           /* to byte instruction  */
                            c.Iflags &= ~CFopsize;
                            goto L1;
                        }
                        if (((u & 0xFFFF00FF) == 0 ||
                             (shortop && (u & 0xFF) == 0)) &&
                            (rm < modregrm(3,0,0) || (!c.Irex && ereg < 4)))
                        {
                        L3:
                            c.IEV2.Vuns >>= 8;
                            if (rm >= (modregrm(3,0,AX) | reg))
                                c.Irm |= 4;    /* AX.AH, BX.BH, etc. */
                            else
                                c.IEV1.Voffset += 1;
                            goto L2;
                        }
                    }

                    // BUG: which is right?
                    //else if ((u & 0xFFFF0000) == 0)

                    else if (0 && op == 0xF7 &&
                             rm >= modregrm(3,0,SP) &&
                             (u & 0xFFFF0000) == 0)

                        c.Iflags &= ~CFopsize;
                }

                // Try to replace TEST reg,-1 with TEST reg,reg
                if (op == 0xF6 && rm >= modregrm(3,0,AX) && rm <= modregrm(3,0,7)) // TEST regL,immed8
                {
                    if ((u & 0xFF) == 0xFF)
                    {
                      L4:
                        c.Iop = 0x84;          // TEST regL,regL
                        c.Irm = modregrm(3,ereg,ereg);
                        if (c.Irex & REX_B)
                            c.Irex |= REX_R;
                        c.Iflags &= ~CFopsize;
                        goto L1;
                    }
                }
                if (op == 0xF7 && rm >= modregrm(3,0,AX) && rm <= modregrm(3,0,7) && (I64 || ereg < 4))
                {
                    if (u == 0xFF)
                    {
                        if (ereg & 4) // SIL,DIL,BPL,SPL need REX prefix
                            c.Irex |= REX;
                        goto L4;
                    }
                    if ((u & 0xFFFF) == 0xFF00 && shortop && !c.Irex && ereg < 4)
                    {
                        ereg |= 4;                /* to regH      */
                        goto L4;
                    }
                }

                /* Look for sign extended immediate data */
                if (cast(byte) u == u)
                {
                    if (op == 0x81)
                    {
                        if (reg != 0x08 && reg != 0x20 && reg != 0x30)
                            c.Iop = op = 0x83;         /* 8 bit sgn ext */
                    }
                    else if (op == 0x69)                /* IMUL rw,ew,dw */
                        c.Iop = op = 0x6B;             /* IMUL rw,ew,db */
                }

                // Look for SHIFT EA,imm8 we can replace with short form
                if (u == 1 && ((op & 0xFE) == 0xC0))
                    c.Iop |= 0xD0;

            } /* if immediate second operand */

            /* Look for AX short form */
            if (ins & A)
            {
                if (rm == modregrm(0,AX,local_BPRM) &&
                    !(c.Irex & REX_R) &&               // and it's AX, not R8
                    (op & ~3) == 0x88 &&
                    !I64)
                {
                    op = ((op & 3) + 0xA0) ^ 2;
                    /* 8A. A0 */
                    /* 8B. A1 */
                    /* 88. A2 */
                    /* 89. A3 */
                    c.Iop = op;
                    c.IFL2 = c.IFL1;
                    c.IEV2 = c.IEV1;
                }

                /* Replace MOV REG1,REG2 with MOV EREG1,EREG2   */
                else if (!I16 &&
                         (op == 0x89 || op == 0x8B) &&
                         (rm & 0xC0) == 0xC0 &&
                         (!b || b.bc != BC.asm_)
                        )
                    c.Iflags &= ~CFopsize;

                // If rm is AX
                else if ((rm & modregrm(3,0,7)) == modregrm(3,0,AX) && !(c.Irex & (REX_R | REX_B)))
                {
                    switch (op)
                    {
                        case 0x80:  op = reg | 4; break;
                        case 0x81:  op = reg | 5; break;
                        case 0x87:  op = 0x90 + (reg>>3); break;    // XCHG

                        case 0xF6:
                            if (reg == 0)
                                op = 0xA8;  /* TEST AL,immed8       */
                            break;

                        case 0xF7:
                            if (reg == 0)
                                op = 0xA9;  /* TEST AX,immed16      */
                            break;

                        default:
                            break;
                    }
                    c.Iop = op;
                }
            }

            /* Look for reg short form */
            if ((ins & R) && (rm & 0xC0) == 0xC0)
            {
                switch (op)
                {
                    case 0xC6:  op = 0xB0 + ereg; break;
                    case 0xC7: // if no sign extension
                        if (!(c.Irex & REX_W && c.IEV2.Vint < 0))
                        {
                            c.Irm = 0;
                            c.Irex &= ~REX_W;
                            op = 0xB8 + ereg;
                        }
                        break;

                    case 0xFF:
                        switch (reg)
                        {   case 6<<3: op = 0x50+ereg; break;/* PUSH*/
                            case 0<<3: if (!I64) op = 0x40+ereg; break; /* INC*/
                            case 1<<3: if (!I64) op = 0x48+ereg; break; /* DEC*/
                            default: break;
                        }
                        break;

                    case 0x8F:  op = 0x58 + ereg; break;
                    case 0x87:
                        if (reg == 0 && !(c.Irex & (REX_R | REX_B))) // Issue 12968: Needed to ensure it's referencing RAX, not R8
                            op = 0x90 + ereg;
                        break;

                    default:
                        break;
                }
                c.Iop = op;
            }

            // Look to remove redundant REX prefix on XOR
            if (c.Irex == REX_W // ignore ops involving R8..R15
                && (op == 0x31 || op == 0x33) // XOR
                && ((rm & 0xC0) == 0xC0) // register direct
                && ((reg >> 3) == ereg)) // register with itself
            {
                c.Irex = 0;
            }

            // Look to replace SHL reg,1 with ADD reg,reg
            if ((op & ~1) == 0xD0 &&
                     (rm & modregrm(3,7,0)) == modregrm(3,4,0) &&
                     config.target_cpu >= TARGET_80486)
            {
                c.Iop &= 1;
                c.Irm = cast(ubyte)((rm & modregrm(3,0,7)) | (ereg << 3));
                if (c.Irex & REX_B)
                    c.Irex |= REX_R;
                if (!(c.Iflags & CFpsw) && !I16)
                    c.Iflags &= ~CFopsize;
                goto L1;
            }

            /* Look for sign extended modregrm displacement, or 0
             * displacement.
             */

            if (((rm & 0xC0) == 0x80) && // it's a 16/32 bit disp
                c.IFL1 == FL.const_)      // and it's a constant
            {
                a = c.IEV1.Vpointer;
                if (a == 0 && (rm & 7) != local_BPRM &&         // if 0[disp]
                    !(local_BPRM == 5 && (rm & 7) == 4 && (c.Isib & 7) == BP)
                   )
                    c.Irm &= 0x3F;
                else if (!I16)
                {
                    if (cast(targ_size_t)cast(targ_schar)a == a)
                        c.Irm ^= 0xC0;                 /* do 8 sx      */
                }
                else if ((cast(targ_size_t)cast(targ_schar)a & 0xFFFF) == (a & 0xFFFF))
                    c.Irm ^= 0xC0;                     /* do 8 sx      */
            }

            /* Look for LEA reg,[ireg], replace with MOV reg,ireg       */
            if (op == LEA)
            {
                rm = c.Irm & 7;
                mod = c.Irm & modregrm(3,0,0);
                if (mod == 0)
                {
                    if (!I16)
                    {
                        switch (rm)
                        {
                            case 4:
                            case 5:
                                break;

                            default:
                                c.Irm |= modregrm(3,0,0);
                                c.Iop = 0x8B;
                                break;
                        }
                    }
                    else
                    {
                        switch (rm)
                        {
                            case 4:     rm = modregrm(3,0,SI);  goto L6;
                            case 5:     rm = modregrm(3,0,DI);  goto L6;
                            case 7:     rm = modregrm(3,0,BX);  goto L6;
                            L6:     c.Irm = cast(ubyte)(rm + reg);
                                    c.Iop = 0x8B;
                                    break;

                            default:
                                    break;
                        }
                    }
                }

                /* replace LEA reg,0[BP] with MOV reg,BP        */
                else if (mod == modregrm(1,0,0) && rm == local_BPRM &&
                        c.IFL1 == FL.const_ && c.IEV1.Vpointer == 0)
                {
                    c.Iop = 0x8B;          /* MOV reg,BP   */
                    c.Irm = cast(ubyte)(modregrm(3,0,BP) + reg);
                }
            }

            // Replace [R13] with 0[R13]
            if (c.Irex & REX_B && ((c.Irm & modregrm(3,0,7)) == modregrm(0,0,BP) ||
                                    issib(c.Irm) && (c.Irm & modregrm(3,0,0)) == 0 && (c.Isib & 7) == BP))
            {
                c.Irm |= modregrm(1,0,0);
                c.IFL1 = FL.const_;
                c.IEV1.Vpointer = 0;
            }
        }
        else if (!(c.Iflags & CFvex))
        {
            switch (op)
            {
                default:
                    // Look for MOV r64, immediate
                    if ((c.Irex & REX_W) && (op & ~7) == 0xB8)
                    {
                        /* Look for zero extended immediate data */
                        if (c.IEV2.Vsize_t == c.IEV2.Vuns)
                        {
                            c.Irex &= ~REX_W;
                        }
                        /* Look for sign extended immediate data */
                        else if (c.IEV2.Vsize_t == c.IEV2.Vint)
                        {
                            c.Irm = modregrm(3,0,op & 7);
                            c.Iop = op = 0xC7;
                            c.IEV2.Vsize_t = c.IEV2.Vuns;
                        }
                    }
                    if ((op & ~0x0F) != 0x70)
                        break;
                    goto case JMP;

                case JMP:
                    switch (c.IFL2)
                    {
                        case FL.code:
                            if (c.IEV2.Vcode == code_next(c))
                            {
                                c.Iop = NOP;
                                continue;
                            }
                            break;

                        case FL.block:
                            if (!code_next(c) && c.IEV2.Vblock == bn)
                            {
                                c.Iop = NOP;
                                continue;
                            }
                            break;

                        case FL.const_:
                        case FL.func:
                        case FL.extern_:
                            break;

                        default:
                            printf("c.fl = %s\n", fl_str(c.IFL2));
                            assert(0);
                    }
                    break;

                case 0x68:                      // PUSH immed16
                    if (c.IFL2 == FL.const_)
                    {
                        targ_long u = c.IEV2.Vuns;
                        if (I64 ||
                            ((c.Iflags & CFopsize) ? I16 : I32))
                        {   // PUSH 32/64 bit operand
                            if (u == cast(byte) u)
                                c.Iop = 0x6A;          // PUSH immed8
                        }
                        else // PUSH 16 bit operand
                        {
                            if (cast(short)u == cast(byte) u)
                                c.Iop = 0x6A;          // PUSH immed8
                        }
                    }
                    break;
            }
        }
    }

    debug
    if (debugc)
    {
        printf("-pinholeopt(%p)\n",cstart);
        for (c = cstart; c; c = code_next(c))
            code_print(c);
    }
}


debug
{
@trusted
private void pinholeopt_unittest()
{
    //printf("pinholeopt_unittest()\n");
    static struct CS
    {
        uint model,op,ea;
        targ_size_t ev1,ev2;
        uint flags;
    }
    __gshared CS[2][22] tests =
    [
        // XOR reg,immed                            NOT regL
        [ { 16,0x81,modregrm(3,6,BX),0,0xFF,0 },    { 0,0xF6,modregrm(3,2,BX),0,0xFF } ],

        // MOV 0[BX],3                               MOV [BX],3
        [ { 16,0xC7,modregrm(2,0,7),0,3 },          { 0,0xC7,modregrm(0,0,7),0,3 } ],

/+      // only if config.flags4 & CFG4space
        // TEST regL,immed8
        [ { 0,0xF6,modregrm(3,0,BX),0,0xFF,0 },    { 0,0x84,modregrm(3,BX,BX),0,0xFF }],
        [ { 0,0xF7,modregrm(3,0,BX),0,0xFF,0 },    { 0,0x84,modregrm(3,BX,BX),0,0xFF }],
        [ { 64,0xF6,modregrmx(3,0,R8),0,0xFF,0 },  { 0,0x84,modregxrmx(3,R8,R8),0,0xFF }],
        [ { 64,0xF7,modregrmx(3,0,R8),0,0xFF,0 },  { 0,0x84,modregxrmx(3,R8,R8),0,0xFF }],
+/

        // PUSH immed => PUSH immed8
        [ { 0,0x68,0,0,0 },    { 0,0x6A,0,0,0 }],
        [ { 0,0x68,0,0,0x7F }, { 0,0x6A,0,0,0x7F }],
        [ { 0,0x68,0,0,0x80 }, { 0,0x68,0,0,0x80 }],
        [ { 16,0x68,0,0,0,CFopsize },    { 0,0x6A,0,0,0,CFopsize }],
        [ { 16,0x68,0,0,0x7F,CFopsize }, { 0,0x6A,0,0,0x7F,CFopsize }],
        [ { 16,0x68,0,0,0x80,CFopsize }, { 0,0x68,0,0,0x80,CFopsize }],
        [ { 16,0x68,0,0,0x10000,0 },     { 0,0x6A,0,0,0x10000,0 }],
        [ { 16,0x68,0,0,0x10000,CFopsize }, { 0,0x68,0,0,0x10000,CFopsize }],
        [ { 32,0x68,0,0,0,CFopsize },    { 0,0x6A,0,0,0,CFopsize }],
        [ { 32,0x68,0,0,0x7F,CFopsize }, { 0,0x6A,0,0,0x7F,CFopsize }],
        [ { 32,0x68,0,0,0x80,CFopsize }, { 0,0x68,0,0,0x80,CFopsize }],
        [ { 32,0x68,0,0,0x10000,CFopsize },    { 0,0x6A,0,0,0x10000,CFopsize }],
        [ { 32,0x68,0,0,0x8000,CFopsize }, { 0,0x68,0,0,0x8000,CFopsize }],

        // clear r64, for r64 != R8..R15
        [ { 64,0x31,0x800C0,0,0,0 }, { 0,0x31,0xC0,0,0,0}],
        [ { 64,0x33,0x800C0,0,0,0 }, { 0,0x33,0xC0,0,0,0}],

        // MOV r64, immed
        [ { 64,0xC7,0x800C0,0,0xFFFFFFFF,0 }, { 0,0xC7,0x800C0,0,0xFFFFFFFF,0}],
        [ { 64,0xC7,0x800C0,0,0x7FFFFFFF,0 }, { 0,0xB8,0,0,0x7FFFFFFF,0}],
        [ { 64,0xB8,0x80000,0,0xFFFFFFFF,0 }, { 0,0xB8,0,0,0xFFFFFFFF,0 }],
        [ { 64,0xB8,0x80000,0,cast(targ_size_t)0x1FFFFFFFF,0 }, { 0,0xB8,0x80000,0,cast(targ_size_t)0x1FFFFFFFF,0 }],
        [ { 64,0xB8,0x80000,0,cast(targ_size_t)0xFFFFFFFFFFFFFFFF,0 }, { 0,0xC7,0x800C0,0,cast(targ_size_t)0xFFFFFFFF,0}],
    ];

    //config.flags4 |= CFG4space;
    for (int i = 0; i < tests.length; i++)
    {   CS* pin  = &tests[i][0];
        CS* pout = &tests[i][1];
        code cs = void;
        memset(&cs, 0, cs.sizeof);
        if (pin.model)
        {
            if (I16 && pin.model != 16)
                continue;
            if (I32 && pin.model != 32)
                continue;
            if (I64 && pin.model != 64)
                continue;
        }
        //printf("[%d]\n", i);
        cs.Iop = pin.op;
        cs.Iea = pin.ea;
        cs.IFL1 = FL.const_;
        cs.IFL2 = FL.const_;
        cs.IEV1.Vsize_t = pin.ev1;
        cs.IEV2.Vsize_t = pin.ev2;
        cs.Iflags = pin.flags;
        pinholeopt(&cs, null);
        if (cs.Iop != pout.op)
        {   printf("[%d] Iop = x%02x, pout = x%02x\n", i, cs.Iop, pout.op);
            assert(0);
        }
        assert(cs.Iea == pout.ea);
        assert(cs.IEV1.Vsize_t == pout.ev1);
        assert(cs.IEV2.Vsize_t == pout.ev2);
        assert(cs.Iflags == pout.flags);
    }
}
}

@trusted
void simplify_code(code* c)
{
    reg_t reg;
    if (config.flags4 & CFG4optimized &&
        (c.Iop == 0x81 || c.Iop == 0x80) &&
        c.IFL2 == FL.const_ &&
        reghasvalue((c.Iop == 0x80) ? BYTEREGS : ALLREGS,I64 ? c.IEV2.Vsize_t : c.IEV2.Vlong,reg) &&
        !(I16 && c.Iflags & CFopsize)
       )
    {
        // See if we can replace immediate instruction with register instruction
        static immutable ubyte[8] regop =
                [ 0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x38 ];

        //printf("replacing 0x%02x, val = x%lx\n",c.Iop,c.IEV2.Vlong);
        c.Iop = regop[(c.Irm & modregrm(0,7,0)) >> 3] | (c.Iop & 1);
        code_newreg(c, reg);
        if (I64 && !(c.Iop & 1) && (reg & 4))
            c.Irex |= REX;
    }
}

/**************************
 * Compute jump addresses for FL.code.
 * Note: only works for forward referenced code.
 *       only direct jumps and branches are detected.
 *       LOOP instructions only work for backward refs.
 */

@trusted
void jmpaddr(code* c)
{
    if (cgstate.AArch64)
    {
        import dmd.backend.arm.cod3 : jmpaddr;
        return jmpaddr(c);
    }

    code* ci,cn,ctarg,cstart;
    targ_size_t ad;

    //printf("jmpaddr()\n");
    cstart = c;                           /* remember start of code       */
    while (c)
    {
        const op = c.Iop;
        if (op <= 0xEB &&
            inssize[op] & T &&   // if second operand
            c.IFL2 == FL.code &&
            ((op & ~0x0F) == 0x70 || op == JMP || op == JMPS || op == JCXZ || op == CALL))
        {
            ci = code_next(c);
            ctarg = c.IEV2.Vcode;  /* target code                  */
            ad = 0;                 /* IP displacement              */
            while (ci && ci != ctarg)
            {
                ad += calccodsize(ci);
                ci = code_next(ci);
            }
            if (!ci)
                goto Lbackjmp;      // couldn't find it
            if (!I16 || op == JMP || op == JMPS || op == JCXZ || op == CALL)
                c.IEV2.Vpointer = ad;
            else                    /* else conditional             */
            {
                if (!(c.Iflags & CFjmp16))     /* if branch    */
                    c.IEV2.Vpointer = ad;
                else            /* branch around a long jump    */
                {
                    cn = code_next(c);
                    c.next = code_calloc();
                    code_next(c).next = cn;
                    c.Iop = op ^ 1;        /* converse jmp */
                    c.Iflags &= ~CFjmp16;
                    c.IEV2.Vpointer = I16 ? 3 : 5;
                    cn = code_next(c);
                    cn.Iop = JMP;          /* long jump    */
                    cn.IFL2 = FL.const_;
                    cn.IEV2.Vpointer = ad;
                }
            }
            c.IFL2 = FL.const_;
        }
        if (op == LOOP && c.IFL2 == FL.code)    /* backwards refs       */
        {
          Lbackjmp:
            ctarg = c.IEV2.Vcode;
            for (ci = cstart; ci != ctarg; ci = code_next(ci))
                if (!ci || ci == c)
                    assert(0);
            ad = 2;                 /* - IP displacement            */
            while (ci != c)
            {
                assert(ci);
                ad += calccodsize(ci);
                ci = code_next(ci);
            }
            c.IEV2.Vpointer = (-ad) & 0xFF;
            c.IFL2 = FL.const_;
        }
        c = code_next(c);
    }
}

/*******************************
 * Calculate bl.Bsize.
 */

uint calcblksize(code* c)
{
    uint size;
    for (size = 0; c; c = code_next(c))
    {
        uint sz = calccodsize(c);
        //printf("off=%02x, sz = %d, code %p: op=%02x\n", size, sz, c, c.Iop);
        size += sz;
    }
    //printf("calcblksize(c = x%x) = %d\n", c, size);
    return size;
}

/*****************************
 * Calculate and return code size of a code.
 * Note that NOPs are sometimes used as markers, but are
 * never output. LINNUMs are never output.
 * Note: This routine must be fast. Profiling shows it is significant.
 */

@trusted
uint calccodsize(code* c)
{
    if (cgstate.AArch64)
    {
        import dmd.backend.arm.cod3 : calccodsize;
        return calccodsize(c);
    }

    uint size;
    ubyte rm,mod,ins;
    uint iflags;
    uint i32 = I32 || I64;
    uint a32 = i32;

    debug
    assert((a32 & ~1) == 0);

    iflags = c.Iflags;
    opcode_t op = c.Iop;
    //printf("calccodsize(x%08x), Iflags = x%x\n", op, iflags);
    if ((op & PSOP.mask) == PSOP.root)
        return 0;

    if (iflags & CFvex && c.Ivex.pfx == 0xC4)
    {
        ins = vex_inssize(c);
        size = ins & 7;
        goto Lmodrm;
    }
    else if ((op & 0xFF00) == 0x0F00 || (op & 0xFFFD00) == 0x0F3800)
        op = 0x0F;
    else
        op &= 0xFF;
    switch (op)
    {
        case 0x0F:
            if ((c.Iop & 0xFFFD00) == 0x0F3800)
            {   // 3 byte op ( 0F38-- or 0F3A-- )
                ins = inssize2[(c.Iop >> 8) & 0xFF];
                size = ins & 7;
                if (c.Iop & 0xFF000000)
                  size++;
            }
            else
            {   // 2 byte op ( 0F-- )
                ins = inssize2[c.Iop & 0xFF];
                size = ins & 7;
                if (c.Iop & 0xFF0000)
                  size++;
            }
            break;

        case 0x90:
            size = (c.Iop == PAUSE) ? 2 : 1;
            goto Lret2;

        case NOP:
            size = 0;                   // since these won't be output
            goto Lret2;

        case ASM:
            if (c.Iflags == CFaddrsize)        // kludge for DA inline asm
                size = _tysize[TYnptr];
            else
                size = cast(uint)c.IEV1.len;
            goto Lret2;

        case 0xA1:
        case 0xA3:
            if (c.Irex)
            {
                size = 9;               // 64 bit immediate value for MOV to/from RAX
                goto Lret;
            }
            goto default;

        case 0xF6:                      /* TEST mem8,immed8             */
            ins = inssize[op];
            size = ins & 7;
            if (i32)
                size = inssize32[op];
            if ((c.Irm & (7<<3)) == 0)
                size++;                 /* size of immed8               */
            break;

        case 0xF7:
            ins = inssize[op];
            size = ins & 7;
            if (i32)
                size = inssize32[op];
            if ((c.Irm & (7<<3)) == 0)
                size += (i32 ^ ((iflags & CFopsize) !=0)) ? 4 : 2;
            break;

        case 0xFA:
        case 0xFB:
            if (c.Iop == ENDBR32 || c.Iop == ENDBR64)
            {
                size = 4;
                break;
            }
            goto default;

        default:
            ins = inssize[op];
            size = ins & 7;
            if (i32)
                size = inssize32[op];
    }

    if (iflags & (CFwait | CFopsize | CFaddrsize | CFSEG))
    {
        if (iflags & CFwait)    // if add FWAIT prefix
            size++;
        if (iflags & CFSEG)     // if segment override
            size++;

        // If the instruction has a second operand that is not an 8 bit,
        // and the operand size prefix is present, then fix the size computation
        // because the operand size will be different.
        // Walter, I had problems with this bit at the end.  There can still be
        // an ADDRSIZE prefix for these and it does indeed change the operand size.

        if (iflags & (CFopsize | CFaddrsize))
        {
            if ((ins & (T|E)) == T)
            {
                if ((op & 0xAC) == 0xA0)
                {
                    if (iflags & CFaddrsize && !I64)
                    {   if (I32)
                            size -= 2;
                        else
                            size += 2;
                    }
                }
                else if (iflags & CFopsize)
                {   if (I16)
                        size += 2;
                    else
                        size -= 2;
                }
            }
            if (iflags & CFaddrsize)
            {   if (!I64)
                    a32 ^= 1;
                size++;
            }
            if (iflags & CFopsize)
                size++;                         /* +1 for OPSIZE prefix         */
        }
    }

Lmodrm:
    if ((op & ~0x0F) == 0x70)
    {
        if (iflags & CFjmp16)           // if long branch
            size += I16 ? 3 : 4;        // + 3(4) bytes for JMP
    }
    else if (ins & M)                   // if modregrm byte
    {
        rm = c.Irm;
        mod = rm & 0xC0;
        if (a32 || I64)
        {   // 32 bit addressing
            if (issib(rm))
                size++;
            switch (mod)
            {   case 0:
                    if (issib(rm) && (c.Isib & 7) == 5 ||
                        (rm & 7) == 5)
                        size += 4;      /* disp32                       */
                    if (c.Irex & REX_B && (rm & 7) == 5)
                        /* Instead of selecting R13, this mode is an [RIP] relative
                         * address. Although valid, it's redundant, and should not
                         * be generated. Instead, generate 0[R13] instead of [R13].
                         */
                        assert(0);
                    break;

                case 0x40:
                    size++;             /* disp8                        */
                    break;

                case 0x80:
                    size += 4;          /* disp32                       */
                    break;

                default:
                    break;
            }
        }
        else
        {   // 16 bit addressing
            if (mod == 0x40)            /* 01: 8 bit displacement       */
                size++;
            else if (mod == 0x80 || (mod == 0 && (rm & 7) == 6))
                size += 2;
        }
    }

Lret:
    if (!(iflags & CFvex) && c.Irex)
    {
        size++;
        if (c.Irex & REX_W && (op & ~7) == 0xB8)
            size += 4;
    }
Lret2:
    //printf("op = x%02x, size = %d\n",op,size);
    return size;
}

/********************************
 * Return !=0 if codes match.
 */

static if (0)
{

int code_match(code* c1,code* c2)
{
    code cs1,cs2;
    ubyte ins;

    if (c1 == c2)
        goto match;
    cs1 = *c1;
    cs2 = *c2;
    if (cs1.Iop != cs2.Iop)
        goto nomatch;
    switch (cs1.Iop)
    {
        case PSOP.ctor:
        case PSOP.dtor:
            goto nomatch;

        case NOP:
            goto match;

        case ASM:
            if (cs1.IEV1.len == cs2.IEV1.len &&
                memcmp(cs1.IEV1.bytes,cs2.IEV1.bytes,cs1.EV1.len) == 0)
                goto match;
            else
                goto nomatch;

        default:
            if ((cs1.Iop & PSOP.mask) == PSOP.root)
                goto match;
            break;
    }
    if (cs1.Iflags != cs2.Iflags)
        goto nomatch;

    ins = inssize[cs1.Iop & 0xFF];
    if ((cs1.Iop & 0xFFFD00) == 0x0F3800)
    {
        ins = inssize2[(cs1.Iop >> 8) & 0xFF];
    }
    else if ((cs1.Iop & 0xFF00) == 0x0F00)
    {
        ins = inssize2[cs1.Iop & 0xFF];
    }

    if (ins & M)                // if modregrm byte
    {
        if (cs1.Irm != cs2.Irm)
            goto nomatch;
        if ((cs1.Irm & 0xC0) == 0xC0)
            goto do2;
        if (is32bitaddr(I32,cs1.Iflags))
        {
            if (issib(cs1.Irm) && cs1.Isib != cs2.Isib)
                goto nomatch;
            if (
                ((rm & 0xC0) == 0 && !((rm & 7) == 4 && (c.Isib & 7) == 5 || (rm & 7) == 5))
               )
                goto do2;       /* if no first operand  */
        }
        else
        {
            if (
                ((rm & 0xC0) == 0 && !((rm & 7) == 6))
               )
                goto do2;       /* if no first operand  */
        }
        if (cs1.IFL1 != cs2.IFL1)
            goto nomatch;
        if (flinsymtab[cs1.IFL1] && cs1.IEV1.Vsym != cs2.IEV1.Vsym)
            goto nomatch;
        if (cs1.IEV1.Voffset != cs2.IEV1.Voffset)
            goto nomatch;
    }

do2:
    if (!(ins & T))                     // if no second operand
        goto match;
    if (cs1.IFL2 != cs2.IFL2)
        goto nomatch;
    if (flinsymtab[cs1.IFL2] && cs1.IEV2.Vsym != cs2.IEV2.Vsym)
        goto nomatch;
    if (cs1.IEV2.Voffset != cs2.IEV2.Voffset)
        goto nomatch;

match:
    return 1;

nomatch:
    return 0;
}

}

/************************
 * Little buffer allocated on the stack to accumulate instruction bytes to
 * later be sent along to objmod
 */
struct MiniCodeBuf
{
nothrow:
    uint index;
    uint offset;
    int seg;
    Barray!ubyte* disasmBuf;
    targ_size_t framehandleroffset;
    ubyte[256] bytes; // = void;

    this(int seg)
    {
        index = 0;
        this.offset = cast(uint)Offset(seg);
        this.seg = seg;
    }

    @trusted
    void flushx()
    {
        // Emit accumulated bytes to code segment
        debug assert(index < bytes.length);

        if (disasmBuf)                     // write to buffer for disassembly
        {
            foreach (c; bytes[0 .. index]) // not efficient, but for verbose output anyway
                disasmBuf.push(c);
        }

        offset += objmod.bytes(seg, offset, index, bytes.ptr);
        index = 0;
    }

    void gen(ubyte c) { bytes[index++] = c; }

    @trusted
    void gen32(uint c)  { assert(index <= bytes.length - 4); *(cast(uint*)(&bytes[index])) = c; index += 4; }

    @trusted
    void genp(uint n, void* p) { memcpy(&bytes[index], p, n); index += n; }

    void flush() { if (index) flushx(); }

    uint getOffset() { return offset + index; }

    uint available() { return cast(uint)bytes.length - index; }

    /******************************
     * write64/write32/write16 write `value` to `disasmBuf`
     */
    void write64(ulong value)
    {
        if (disasmBuf)
        {
            disasmBuf.push(cast(ubyte)value);
            disasmBuf.push(cast(ubyte)(value >>  8));
            disasmBuf.push(cast(ubyte)(value >> 16));
            disasmBuf.push(cast(ubyte)(value >> 24));
            disasmBuf.push(cast(ubyte)(value >> 32));
            disasmBuf.push(cast(ubyte)(value >> 36));
            disasmBuf.push(cast(ubyte)(value >> 40));
            disasmBuf.push(cast(ubyte)(value >> 44));
        }
    }

    pragma(inline, true)
    void write32(uint value)
    {
        if (disasmBuf)
        {
            disasmBuf.push(cast(ubyte)value);
            disasmBuf.push(cast(ubyte)(value >>  8));
            disasmBuf.push(cast(ubyte)(value >> 16));
            disasmBuf.push(cast(ubyte)(value >> 24));
        }
    }

    pragma(inline, true)
    void write16(uint value)
    {
        if (disasmBuf)
        {
            disasmBuf.push(cast(ubyte)value);
            disasmBuf.push(cast(ubyte)(value >> 8));
        }
    }
}

/**************************
 * Convert instructions to object code and write them to objmod.
 * Params:
 *      seg = code segment to write to, code starts at Offset(seg)
 *      c = list of instructions to write
 *      disasmBuf = if not null, then also write object code here
 *      framehandleroffset = offset of C++ frame handler
 * Returns:
 *      offset of end of code emitted
 */

@trusted
uint codout(int seg, code* c, Barray!ubyte* disasmBuf, ref targ_size_t framehandleroffset)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.codout(seg, c, disasmBuf, framehandleroffset);

    ubyte rm,mod;
    ubyte ins;
    code* cn;
    uint flags;
    Symbol* s;

    debug
    if (debugc) printf("codout(%p), Coffset = x%llx\n",c,cast(ulong)Offset(seg));

    MiniCodeBuf ggen = void;
    ggen.index = 0;
    ggen.offset = cast(uint)Offset(seg);
    ggen.seg = seg;
    ggen.framehandleroffset = framehandleroffset;
    ggen.disasmBuf = disasmBuf;

    for (; c; c = code_next(c))
    {
        debug
        {
        if (debugc) { printf("off=%02x, sz=%d, ",cast(int)ggen.getOffset(),cast(int)calccodsize(c)); code_print(c); }
        uint startOffset = ggen.getOffset();
        }

        opcode_t op = c.Iop;
        if ((op & PSOP.mask) == PSOP.root)
        {
            switch (op)
            {   case PSOP.linnum:
                    /* put out line number stuff    */
                    objmod.linnum(c.IEV1.Vsrcpos,seg,ggen.getOffset());
                    break;
                case PSOP.adjesp:
                    //printf("adjust ESP %ld\n", cast(long)c.IEV1.Vint);
                    break;

                default:
                    break;
            }
            continue;
        }
        ins = inssize[op & 0xFF];
        switch (op & 0xFF)
        {
            case NOP:                   /* don't send them out          */
                if (op != NOP)
                    break;
                debug
                assert(calccodsize(c) == 0);

                continue;

            case ASM:
                if (op != ASM)
                    break;
                ggen.flush();
                if (c.Iflags == CFaddrsize)    // kludge for DA inline asm
                {
                    do32bit(ggen, FL.blockoff,c.IEV1,0,0);
                }
                else
                {
                    ggen.offset += objmod.bytes(seg,ggen.offset,cast(uint)c.IEV1.len,c.IEV1.bytes);
                }
                debug
                assert(calccodsize(c) == c.IEV1.len);

                continue;

            default:
                break;
        }
        flags = c.Iflags;

        // See if we need to flush (don't have room for largest code sequence)
        if (ggen.available() < (1+4+4+8+8))
            ggen.flush();

        // see if we need to put out prefix bytes
        if (flags & (CFwait | CFPREFIX | CFjmp16))
        {
            int override_;

            if (flags & CFwait)
                ggen.gen(0x9B);                      // FWAIT
                                                /* ? SEGES : SEGSS      */
            switch (flags & CFSEG)
            {   case CFes:      override_ = SEGES;       goto segover;
                case CFss:      override_ = SEGSS;       goto segover;
                case CFcs:      override_ = SEGCS;       goto segover;
                case CFds:      override_ = SEGDS;       goto segover;
                case CFfs:      override_ = SEGFS;       goto segover;
                case CFgs:      override_ = SEGGS;       goto segover;
                segover:        ggen.gen(cast(ubyte)override_);
                                break;

                default:        break;
            }

            if (flags & CFaddrsize)
                ggen.gen(0x67);

            // Do this last because of instructions like ADDPD
            if (flags & CFopsize)
                ggen.gen(0x66);                      /* operand size         */

            if ((op & ~0x0F) == 0x70 && flags & CFjmp16) /* long condit jmp */
            {
                if (!I16)
                {   // Put out 16 bit conditional jump
                    c.Iop = op = 0x0F00 | (0x80 | (op & 0x0F));
                }
                else
                {
                    cn = code_calloc();
                    /*cxcalloc++;*/
                    cn.next = code_next(c);
                    c.next= cn;          // link into code
                    cn.Iop = JMP;              // JMP block
                    cn.IFL2 = c.IFL2;
                    cn.IEV2.Vblock = c.IEV2.Vblock;
                    c.Iop = op ^= 1;           // toggle condition
                    c.IFL2 = FL.const_;
                    c.IEV2.Vpointer = I16 ? 3 : 5; // skip over JMP block
                    c.Iflags &= ~CFjmp16;
                }
            }
        }

        if (flags & CFvex)
        {
            if (flags & CFvex3)
            {
                ggen.gen(0xC4);
                ggen.gen(cast(ubyte)VEX3_B1(c.Ivex));
                ggen.gen(cast(ubyte)VEX3_B2(c.Ivex));
                ggen.gen(c.Ivex.op);
            }
            else
            {
                ggen.gen(0xC5);
                ggen.gen(cast(ubyte)VEX2_B1(c.Ivex));
                ggen.gen(c.Ivex.op);
            }
            ins = vex_inssize(c);
            goto Lmodrm;
        }

        if (op > 0xFF)
        {
            if ((op & 0xFFFD00) == 0x0F3800)
                ins = inssize2[(op >> 8) & 0xFF];
            else if ((op & 0xFF00) == 0x0F00)
                ins = inssize2[op & 0xFF];

            if (op & 0xFF_00_00_00)
            {
                ubyte op1 = op >> 24;
                if (op1 == 0xF2 || op1 == 0xF3 || op1 == 0x66)
                {
                    ggen.gen(op1);
                    if (c.Irex)
                        ggen.gen(c.Irex | REX);
                }
                else
                {
                    if (c.Irex)
                        ggen.gen(c.Irex | REX);
                    ggen.gen(op1);
                }
                ggen.gen((op >> 16) & 0xFF);
                ggen.gen((op >> 8) & 0xFF);
                ggen.gen(op & 0xFF);
            }
            else if (op & 0xFF0000)
            {
                ubyte op1 = cast(ubyte)(op >> 16);
                if (op1 == 0xF2 || op1 == 0xF3 || op1 == 0x66)
                {
                    ggen.gen(op1);
                    if (c.Irex)
                        ggen.gen(c.Irex | REX);
                }
                else
                {
                    if (c.Irex)
                        ggen.gen(c.Irex | REX);
                    ggen.gen(op1);
                }
                ggen.gen((op >> 8) & 0xFF);
                ggen.gen(op & 0xFF);
            }
            else
            {
                if (c.Irex)
                    ggen.gen(c.Irex | REX);
                ggen.gen((op >> 8) & 0xFF);
                ggen.gen(op & 0xFF);
            }
        }
        else
        {
            if (c.Irex)
                ggen.gen(c.Irex | REX);
            ggen.gen(cast(ubyte)op);
        }
  Lmodrm:
        if (ins & M)            /* if modregrm byte             */
        {
            rm = c.Irm;
            ggen.gen(rm);

            // Look for an address size override when working with the
            // MOD R/M and SIB bytes

            if (is32bitaddr( I32, flags))
            {
                if (issib(rm))
                    ggen.gen(c.Isib);
                switch (rm & 0xC0)
                {
                    case 0x40:
                        do8bit(ggen, cast(FL) c.IFL1,c.IEV1);     // 8 bit
                        break;

                    case 0:
                        if (!(issib(rm) && (c.Isib & 7) == 5 ||
                              (rm & 7) == 5))
                            break;
                        goto case 0x80;

                    case 0x80:
                    {
                        int cfflags = CFoff;
                        targ_size_t val = 0;
                        if (I64)
                        {
                            if ((rm & modregrm(3,0,7)) == modregrm(0,0,5))      // if disp32[RIP]
                            {
                                cfflags |= CFpc32;
                                val = -4;
                                reg_t reg = rm & modregrm(0,7,0);
                                if (ins & T ||
                                    ((op == 0xF6 || op == 0xF7) && (reg == modregrm(0,0,0) || reg == modregrm(0,1,0))))
                                {   if (ins & E || op == 0xF6)
                                        val = -5;
                                    else if (c.Iflags & CFopsize)
                                        val = -6;
                                    else
                                        val = -8;
                                }

                                if (config.exe & (EX_OSX64 | EX_WIN64))
                                    /* Mach-O and Win64 fixups already take the 4 byte size
                                     * into account, so bias by 4
                                     */
                                    val += 4;
                            }
                        }
                        do32bit(ggen, cast(FL)c.IFL1,c.IEV1,cfflags,cast(int)val);
                        break;
                    }

                    default:
                        break;
                }
            }
            else
            {
                switch (rm & 0xC0)
                {   case 0x40:
                        do8bit(ggen, cast(FL) c.IFL1,c.IEV1);     // 8 bit
                        break;

                    case 0:
                        if ((rm & 7) != 6)
                            break;
                        goto case 0x80;

                    case 0x80:
                        do16bit(ggen, cast(FL)c.IFL1,c.IEV1,CFoff);
                        break;

                    default:
                        break;
                }
            }
        }
        else
        {
            if (op == ENTER)
                do16bit(ggen, cast(FL)c.IFL1,c.IEV1,0);
        }
        flags &= CFseg | CFoff | CFselfrel;
        if (ins & T)                    /* if second operand            */
        {
            if (ins & E)            /* if data-8                    */
                do8bit(ggen, cast(FL) c.IFL2,c.IEV2);
            else if (!I16)
            {
                switch (op)
                {
                    case 0xC2:              /* RETN imm16           */
                    case 0xCA:              /* RETF imm16           */
                    do16:
                        do16bit(ggen, cast(FL)c.IFL2,c.IEV2,flags);
                        break;

                    case 0xA1:
                    case 0xA3:
                        if (I64 && c.Irex)
                        {
                    do64:
                            do64bit(ggen, cast(FL)c.IFL2,c.IEV2,flags);
                            break;
                        }
                        goto case 0xA0;

                    case 0xA0:              /* MOV AL,byte ptr []   */
                    case 0xA2:
                        if (c.Iflags & CFaddrsize && !I64)
                            goto do16;
                        else
                    do32:
                            do32bit(ggen, cast(FL)c.IFL2,c.IEV2,flags,0);
                        break;

                    case 0x9A:
                    case 0xEA:
                        if (c.Iflags & CFopsize)
                            goto ptr1616;
                        else
                            goto ptr1632;

                    case 0x68:              // PUSH immed32
                        if (c.IFL2 == FL.block)
                        {
                            c.IFL2 = FL.blockoff;
                            goto do32;
                        }
                        else
                            goto case_default;

                    case CALL:              // CALL rel
                    case JMP:               // JMP  rel
                        flags |= CFselfrel;
                        goto case_default;

                    default:
                        if ((op|0xF) == 0x0F8F) // Jcc rel16 rel32
                            flags |= CFselfrel;
                        if (I64 && (op & ~7) == 0xB8 && c.Irex & REX_W)
                            goto do64;
                    case_default:
                        if (c.Iflags & CFopsize)
                            goto do16;
                        else
                            goto do32;
                }
            }
            else
            {
                switch (op)
                {
                    case 0xC2:
                    case 0xCA:
                        goto do16;

                    case 0xA0:
                    case 0xA1:
                    case 0xA2:
                    case 0xA3:
                        if (c.Iflags & CFaddrsize)
                            goto do32;
                        else
                            goto do16;

                    case 0x9A:
                    case 0xEA:
                        if (c.Iflags & CFopsize)
                            goto ptr1632;
                        else
                            goto ptr1616;

                    ptr1616:
                    ptr1632:
                        //assert(c.IFL2 == FL.func);
                        ggen.flush();
                        if (c.IFL2 == FL.datseg)
                        {
                            objmod.reftodatseg(seg,ggen.offset,c.IEV2.Vpointer,
                                    c.IEV2.Vseg,flags);
                            ggen.offset += 4;
                        }
                        else
                        {
                            s = c.IEV2.Vsym;
                            ggen.offset += objmod.reftoident(seg,ggen.offset,s,0,flags);
                        }
                        break;

                    case 0x68:              // PUSH immed16
                        if (c.IFL2 == FL.block)
                        {   c.IFL2 = FL.blockoff;
                            goto do16;
                        }
                        else
                            goto case_default16;

                    case CALL:
                    case JMP:
                        flags |= CFselfrel;
                        goto default;

                    default:
                    case_default16:
                        if (c.Iflags & CFopsize)
                            goto do32;
                        else
                            goto do16;
                }
            }
        }
        else if (op == 0xF6)            /* TEST mem8,immed8             */
        {
            if ((rm & (7<<3)) == 0)
                do8bit(ggen, cast(FL)c.IFL2,c.IEV2);
        }
        else if (op == 0xF7)
        {
            if ((rm & (7<<3)) == 0)     /* TEST mem16/32,immed16/32     */
            {
                if ((I32 || I64) ^ ((c.Iflags & CFopsize) != 0))
                    do32bit(ggen, cast(FL)c.IFL2,c.IEV2,flags,0);
                else
                    do16bit(ggen, cast(FL)c.IFL2,c.IEV2,flags);
            }
        }

        debug
        if (ggen.getOffset() - startOffset != calccodsize(c))
        {
            printf("actual: %d, calc: %d\n", cast(int)(ggen.getOffset() - startOffset), cast(int)calccodsize(c));
            code_print(c);
            assert(0);
        }
    }
    ggen.flush();
    Offset(seg) = ggen.offset;
    framehandleroffset = ggen.framehandleroffset;
    //printf("-codout(), Coffset = x%llx\n", Offset(seg));
    return cast(uint)ggen.offset;                      /* ending address               */
}


@trusted
private void do64bit(ref MiniCodeBuf pbuf, FL fl, ref evc uev,int flags)
{
    char* p;
    Symbol* s;
    targ_size_t ad;

    assert(I64);
    switch (fl)
    {
        case FL.const_:
            ad = *cast(targ_size_t*) &uev;
        L1:
            pbuf.genp(8,&ad);
            return;

        case FL.datseg:
            pbuf.flush();
            pbuf.write64(uev.Vpointer);
            objmod.reftodatseg(pbuf.seg,pbuf.offset,uev.Vpointer,uev.Vseg,CFoffset64 | flags);
            break;

        case FL.framehandler:
            pbuf.framehandleroffset = pbuf.getOffset();
            ad = 0;
            goto L1;

        case FL.switch_:
            pbuf.flush();
            ad = uev.Vswitch.Btableoffset;
            pbuf.write64(ad);
            if (config.flags & CFGromable)
                    objmod.reftocodeseg(pbuf.seg,pbuf.offset,ad);
            else
                    objmod.reftodatseg(pbuf.seg,pbuf.offset,ad,objmod.jmpTableSegment(funcsym_p),CFoff);
            break;

        case FL.csdata:
        case FL.fardata:
            //symbol_print(uev.Vsym);
            // NOTE: In ELFOBJ all symbol refs have been tagged FL.extern_
            // strings and statics are treated like offsets from a
            // un-named external with is the start of .rodata or .data
        case FL.extern_:                      /* external data symbol         */
        case FL.tlsdata:
            pbuf.flush();
            s = uev.Vsym;               /* symbol pointer               */
            pbuf.write64(uev.Voffset);
            objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset,CFoffset64 | flags);
            break;

        case FL.gotoff:
            if (config.exe & (EX_OSX | EX_OSX64))
            {
                assert(0);
            }
            else if (config.exe & EX_posix)
            {
                pbuf.flush();
                s = uev.Vsym;               /* symbol pointer               */
                pbuf.write64(uev.Voffset);
                objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset,CFoffset64 | flags);
                break;
            }
            else
                assert(0);

        case FL.got:
            if (config.exe & (EX_OSX | EX_OSX64))
            {
                funcsym_p.Slocalgotoffset = pbuf.getOffset();
                ad = 0;
                goto L1;
            }
            else if (config.exe & EX_posix)
            {
                pbuf.flush();
                s = uev.Vsym;               /* symbol pointer               */
                pbuf.write64(uev.Voffset);
                objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset,CFoffset64 | flags);
                break;
            }
            else
                assert(0);

        case FL.func:                        /* function call                */
            s = uev.Vsym;               /* symbol pointer               */
            assert(TARGET_SEGMENTED || !tyfarfunc(s.ty()));
            pbuf.flush();
            pbuf.write64(0);
            objmod.reftoident(pbuf.seg,pbuf.offset,s,0,CFoffset64 | flags);
            break;

        case FL.block:                       /* displacement to another block */
            ad = uev.Vblock.Boffset - pbuf.getOffset() - 4;
            //printf("FL.block: funcoffset = %x, pbuf.getOffset = %x, Boffset = %x, ad = %x\n", cgstate.funcoffset, pbuf.getOffset(), uev.Vblock.Boffset, ad);
            goto L1;

        case FL.blockoff:
            pbuf.flush();
            assert(uev.Vblock);
            //printf("FL.blockoff: offset = %x, Boffset = %x, funcoffset = %x\n", pbuf.offset, uev.Vblock.Boffset, cgstate.funcoffset);
            pbuf.write64(uev.Vblock.Boffset);
            objmod.reftocodeseg(pbuf.seg,pbuf.offset,uev.Vblock.Boffset);
            break;

        default:
            printf("fl: %s\n", fl_str(fl));
            assert(0);
    }
    pbuf.offset += 8;
}


@trusted
private void do32bit(ref MiniCodeBuf pbuf, FL fl, ref evc uev,int flags, int val)
{
    char* p;
    Symbol* s;
    targ_size_t ad;

    //printf("do32bit(flags = x%x)\n", flags);
    switch (fl)
    {
        case FL.const_:
            assert(targ_size_t.sizeof == 4 || targ_size_t.sizeof == 8);
            ad = * cast(targ_size_t*) &uev;
        L1:
            pbuf.genp(4,&ad);
            return;

        case FL.datseg:
            pbuf.flush();
            objmod.reftodatseg(pbuf.seg,pbuf.offset,uev.Vpointer,uev.Vseg,flags);
            pbuf.write32(cast(uint)uev.Vpointer);
            break;

        case FL.framehandler:
            pbuf.framehandleroffset = pbuf.getOffset();
            ad = 0;
            goto L1;

        case FL.switch_:
            pbuf.flush();
            ad = uev.Vswitch.Btableoffset;
            if (config.flags & CFGromable)
            {
                if (config.exe & (EX_OSX | EX_OSX64))
                {
                    // These are magic values based on the exact code generated for the switch jump
                    if (I64)
                        uev.Vswitch.Btablebase = pbuf.getOffset() + 4;
                    else
                        uev.Vswitch.Btablebase = pbuf.getOffset() + 4 - 8;
                    ad -= uev.Vswitch.Btablebase;
                    goto L1;
                }
                else if (config.exe & EX_windos)
                {
                    if (I64)
                    {
                        uev.Vswitch.Btablebase = pbuf.getOffset() + 4;
                        ad -= uev.Vswitch.Btablebase;
                        goto L1;
                    }
                    else
                        objmod.reftocodeseg(pbuf.seg,pbuf.offset,ad);
                }
                else
                {
                    objmod.reftocodeseg(pbuf.seg,pbuf.offset,ad);
                }
            }
            else
                    objmod.reftodatseg(pbuf.seg,pbuf.offset,ad,objmod.jmpTableSegment(funcsym_p),CFoff);
            pbuf.write32(cast(uint)ad);
            break;

        case FL.code:
            //assert(JMPJMPTABLE);            // the only use case
            pbuf.flush();
            ad = *cast(targ_size_t*) &uev + pbuf.getOffset();
            objmod.reftocodeseg(pbuf.seg,pbuf.offset,ad);
            pbuf.write32(cast(uint)ad);
            break;

        case FL.csdata:
        case FL.fardata:
            //symbol_print(uev.Vsym);

            // NOTE: In ELFOBJ all symbol refs have been tagged FL.extern_
            // strings and statics are treated like offsets from a
            // un-named external with is the start of .rodata or .data
        case FL.extern_:                      /* external data symbol         */
        case FL.tlsdata:
            pbuf.flush();
            s = uev.Vsym;               /* symbol pointer               */
            if (config.exe & EX_windos && I64 && (flags & CFpc32))
            {
                /* This is for those funky fixups where the location to be fixed up
                 * is a 'val' amount back from the current RIP, biased by adding 4.
                 */
                assert(val >= -5 && val <= 0);
                flags |= (-val & 7) << 24;          // set CFREL value
                assert(CFREL == (7 << 24));
                objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset,flags);
                pbuf.write32(cast(uint)uev.Voffset);
            }
            else
            {
                objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset + val,flags);
                pbuf.write32(cast(uint)(uev.Voffset + val));
            }
            break;

        case FL.gotoff:
            if (config.exe & (EX_OSX | EX_OSX64))
            {
                assert(0);
            }
            else if (config.exe & EX_posix)
            {
                pbuf.flush();
                s = uev.Vsym;               /* symbol pointer               */
                objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset + val,flags);
                pbuf.write32(cast(uint)(uev.Voffset + val));
                break;
            }
            else
                assert(0);

        case FL.got:
            if (config.exe & (EX_OSX | EX_OSX64))
            {
                funcsym_p.Slocalgotoffset = pbuf.getOffset();
                ad = 0;
                goto L1;
            }
            else if (config.exe & EX_posix)
            {
                pbuf.flush();
                s = uev.Vsym;               /* symbol pointer               */
                objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset + val,flags);
                pbuf.write32(cast(uint)(uev.Voffset + val));
                break;
            }
            else
                assert(0);

        case FL.func:                        /* function call                */
            s = uev.Vsym;               /* symbol pointer               */
            if (tyfarfunc(s.ty()))
            {   /* Large code references are always absolute    */
                pbuf.flush();
                pbuf.offset += objmod.reftoident(pbuf.seg,pbuf.offset,s,0,flags) - 4;
                pbuf.write32(0);
            }
            else if (s.Sseg == pbuf.seg &&
                     (s.Sclass == SC.static_ || s.Sclass == SC.global) &&
                     s.Sxtrnnum == 0 && flags & CFselfrel)
            {   /* if we know it's relative address     */
                ad = s.Soffset - pbuf.getOffset() - 4;
                goto L1;
            }
            else
            {
                assert(TARGET_SEGMENTED || !tyfarfunc(s.ty()));
                pbuf.flush();
                objmod.reftoident(pbuf.seg,pbuf.offset,s,val,flags);
                pbuf.write32(cast(uint)(val));
            }
            break;

        case FL.block:                       /* displacement to another block */
            ad = uev.Vblock.Boffset - pbuf.getOffset() - 4;
            //printf("FL.block: funcoffset = %x, pbuf.getOffset = %x, Boffset = %x, ad = %x\n", cgstate.funcoffset, pbuf.getOffset(), uev.Vblock.Boffset, ad);
            goto L1;

        case FL.blockoff:
            pbuf.flush();
            assert(uev.Vblock);
            //printf("FL.blockoff: offset = %x, Boffset = %x, funcoffset = %x\n", pbuf.offset, uev.Vblock.Boffset, cgstate.funcoffset);
            objmod.reftocodeseg(pbuf.seg,pbuf.offset,uev.Vblock.Boffset);
            pbuf.write32(cast(uint)(uev.Vblock.Boffset));
            break;

        default:
            printf("fl: %s\n", fl_str(fl));
            assert(0);
    }
    pbuf.offset += 4;
}


@trusted
private void do16bit(ref MiniCodeBuf pbuf, FL fl, ref evc uev,int flags)
{
    char* p;
    Symbol* s;
    targ_size_t ad;

    switch (fl)
    {
        case FL.const_:
            pbuf.genp(2,cast(char*) &uev);
            return;

        case FL.datseg:
            pbuf.flush();
            objmod.reftodatseg(pbuf.seg,pbuf.offset,uev.Vpointer,uev.Vseg,flags);
            pbuf.write16(cast(uint)uev.Vpointer);
            break;

        case FL.switch_:
            pbuf.flush();
            ad = uev.Vswitch.Btableoffset;
            if (config.flags & CFGromable)
                objmod.reftocodeseg(pbuf.seg,pbuf.offset,ad);
            else
                objmod.reftodatseg(pbuf.seg,pbuf.offset,ad,objmod.jmpTableSegment(funcsym_p),CFoff);
            pbuf.write16(cast(uint)ad);
            break;

        case FL.csdata:
        case FL.fardata:
        case FL.extern_:                      /* external data symbol         */
        case FL.tlsdata:
            //assert(SIXTEENBIT || TARGET_SEGMENTED);
            pbuf.flush();
            s = uev.Vsym;               /* symbol pointer               */
            objmod.reftoident(pbuf.seg,pbuf.offset,s,uev.Voffset,flags);
            pbuf.write16(cast(uint)uev.Voffset);
            break;

        case FL.func:                        /* function call                */
            //assert(SIXTEENBIT || TARGET_SEGMENTED);
            s = uev.Vsym;               /* symbol pointer               */
            if (tyfarfunc(s.ty()))
            {   /* Large code references are always absolute    */
                pbuf.flush();
                pbuf.offset += objmod.reftoident(pbuf.seg,pbuf.offset,s,0,flags) - 2;
            }
            else if (s.Sseg == pbuf.seg &&
                     (s.Sclass == SC.static_ || s.Sclass == SC.global) &&
                     s.Sxtrnnum == 0 && flags & CFselfrel)
            {   /* if we know it's relative address     */
                ad = s.Soffset - pbuf.getOffset() - 2;
                goto L1;
            }
            else
            {
                pbuf.flush();
                objmod.reftoident(pbuf.seg,pbuf.offset,s,0,flags);
            }
            pbuf.write16(0);
            break;

        case FL.block:                       /* displacement to another block */
            ad = uev.Vblock.Boffset - pbuf.getOffset() - 2;
            debug
            {
                targ_ptrdiff_t delta = uev.Vblock.Boffset - pbuf.getOffset() - 2;
                assert(cast(short)delta == delta);
            }
        L1:
            pbuf.genp(2,&ad);                    // displacement
            return;

        case FL.blockoff:
            pbuf.flush();
            objmod.reftocodeseg(pbuf.seg,pbuf.offset,uev.Vblock.Boffset);
            pbuf.write16(cast(uint)uev.Vblock.Boffset);
            break;

        default:
            printf("fl: %s\n", fl_str(fl));
            assert(0);
    }
    pbuf.offset += 2;
}


@trusted
private void do8bit(ref MiniCodeBuf pbuf, FL fl, ref evc uev)
{
    ubyte c;

    switch (fl)
    {
        case FL.const_:
            c = cast(ubyte)uev.Vuns;
            break;

        case FL.block:
            targ_ptrdiff_t delta = uev.Vblock.Boffset - pbuf.getOffset() - 1;
            if (cast(byte)delta != delta)
            {
                if (uev.Vblock.Bsrcpos.Slinnum)
                    printf("%s(%d): ", uev.Vblock.Bsrcpos.Sfilename, uev.Vblock.Bsrcpos.Slinnum);
                printf("block displacement of %lld exceeds the maximum offset of -128 to 127.\n", cast(long)delta);
                err_exit();
            }
            c = cast(ubyte)delta;
            debug assert(uev.Vblock.Boffset > pbuf.getOffset() || c != 0x7F);
            break;

        default:
            debug printf("fl = %d\n",fl);
            assert(0);
    }
    pbuf.gen(c);
}


/***************************
 * Debug code to dump code structure.
 */

void WRcodlst(code* c)
{
    for (; c; c = code_next(c))
        code_print(c);
}

@trusted
void code_print(scope code* c)
{
    if (cgstate.AArch64)
        return dmd.backend.arm.cod3.code_print(c);

    ubyte ins;
    ubyte rexb;

    if (c == null)
    {
        printf("code 0\n");
        return;
    }

    const op = c.Iop;
    if (c.Iflags & CFvex && c.Ivex.pfx == 0xC4)
        ins = vex_inssize(c);
    else if ((c.Iop & 0xFFFD00) == 0x0F3800)
        ins = inssize2[(op >> 8) & 0xFF];
    else if ((c.Iop & 0xFF00) == 0x0F00)
        ins = inssize2[op & 0xFF];
    else
        ins = inssize[op & 0xFF];

    printf("code %p: nxt=%p ",c,code_next(c));

    if (c.Iflags & CFvex)
    {
        if (c.Iflags & CFvex3)
        {
            printf("vex=0xC4");
            printf(" 0x%02X", VEX3_B1(c.Ivex));
            printf(" 0x%02X", VEX3_B2(c.Ivex));
            rexb =
                ( c.Ivex.w ? REX_W : 0) |
                (!c.Ivex.r ? REX_R : 0) |
                (!c.Ivex.x ? REX_X : 0) |
                (!c.Ivex.b ? REX_B : 0);
        }
        else
        {
            printf("vex=0xC5");
            printf(" 0x%02X", VEX2_B1(c.Ivex));
            rexb = !c.Ivex.r ? REX_R : 0;
        }
        printf(" ");
    }
    else
        rexb = c.Irex;

    if (rexb)
    {
        printf("rex=0x%02X ", c.Irex);
        if (rexb & REX_W)
            printf("W");
        if (rexb & REX_R)
            printf("R");
        if (rexb & REX_X)
            printf("X");
        if (rexb & REX_B)
            printf("B");
        printf(" ");
    }
    printf("op=0x%02X",op);

    if ((op & PSOP.mask) == PSOP.root)
    {
        if (op == PSOP.linnum)
        {
            printf(" linnum = %d\n",c.IEV1.Vsrcpos.Slinnum);
            return;
        }
        printf(" PSOP %x", c.Iop);
    }

    if (c.Iflags)
        printf(" flg=%x",c.Iflags);
    if (ins & M)
    {
        uint rm = c.Irm;
        printf(" rm=0x%02X=%d,%d,%d",rm,(rm>>6)&3,(rm>>3)&7,rm&7);
        if (!I16 && issib(rm))
        {
            ubyte sib = c.Isib;
            printf(" sib=%02x=%d,%d,%d",sib,(sib>>6)&3,(sib>>3)&7,sib&7);
        }
        if ((rm & 0xC7) == BPRM || (rm & 0xC0) == 0x80 || (rm & 0xC0) == 0x40)
        {
            switch (c.IFL1)
            {
                case FL.const_:
                case FL.offset:
                    printf(" int = %4d",c.IEV1.Vuns);
                    break;

                case FL.block:
                    printf(" block = %p",c.IEV1.Vblock);
                    break;

                case FL.switch_:
                case FL.blockoff:
                case FL.localsize:
                case FL.framehandler:
                case 0:
                    break;

                case FL.datseg:
                    printf(" FL.datseg %d.%llx",c.IEV1.Vseg,cast(ulong)c.IEV1.Vpointer);
                    break;

                case FL.auto_:
                case FL.fast:
                case FL.reg:
                case FL.data:
                case FL.udata:
                case FL.para:
                case FL.bprel:
                case FL.tlsdata:
                case FL.extern_:
                    printf(" %s", fl_str(c.IFL1));
                    printf(" sym='%s'",c.IEV1.Vsym.Sident.ptr);
                    if (c.IEV1.Voffset)
                        printf(".%d", cast(int)c.IEV1.Voffset);
                    break;

                default:
                    printf("fl: %s\n", fl_str(c.IFL1));
                    break;
            }
        }
    }
    if (ins & T)
    {
        printf(" %s\n", fl_str(c.IFL2));
        switch (c.IFL2)
        {
            case FL.const_:
                printf(" int = %4d",c.IEV2.Vuns);
                break;

            case FL.block:
                printf(" block = %p",c.IEV2.Vblock);
                break;

            case FL.switch_:
            case FL.blockoff:
            case 0:
            case FL.localsize:
            case FL.framehandler:
                break;

            case FL.datseg:
                printf(" %d.%llx",c.IEV2.Vseg,cast(ulong)c.IEV2.Vpointer);
                break;

            case FL.auto_:
            case FL.fast:
            case FL.reg:
            case FL.para:
            case FL.bprel:
            case FL.func:
            case FL.data:
            case FL.udata:
            case FL.tlsdata:
                printf(" sym='%s'",c.IEV2.Vsym.Sident.ptr);
                break;

            case FL.code:
                printf(" code = %p",c.IEV2.Vcode);
                break;

            default:
                printf("fl: %s\n", fl_str(c.IFL2));
                break;
        }
    }
    printf("\n");
}

/**************************************
 * Pretty-print a CF mask.
 * Params:
 *      cf = CF mask
 */
@trusted
void CF_print(uint cf)
{
    void print(uint mask, const(char)* string)
    {
        if (cf & mask)
        {
            printf(string);
            cf &= ~mask;
            if (cf)
                printf("|");
        }
    }

    print(CFindirect, "CFindirect");
    print(CFswitch, "CFswitch");
    print(CFjmp5, "CFjmp5");
    print(CFvex3, "CFvex3");
    print(CFvex, "CFvex");
    print(CFpc32, "CFpc32");
    print(CFoffset64, "CFoffset64");
    print(CFclassinit, "CFclassinit");
    print(CFvolatile, "CFvolatile");
    print(CFtarg2, "CFtarg2");
    print(CFunambig, "CFunambig");
    print(CFselfrel, "CFselfrel");
    print(CFwait, "CFwait");
    print(CFfs, "CFfs");
    print(CFcs, "CFcs");
    print(CFds, "CFds");
    print(CFss, "CFss");
    print(CFes, "CFes");
    print(CFaddrsize, "CFaddrsize");
    print(CFopsize, "CFopsize");
    print(CFpsw, "CFpsw");
    print(CFoff, "CFoff");
    print(CFseg, "CFseg");
    print(CFtarg, "CFtarg");
    print(CFjmp16, "CFjmp16");
    printf("\n");
}
