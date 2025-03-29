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
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm/cod3.d, backend/cod3.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_arm_cod3.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/arm/cod3.d
 */

module dmd.backend.arm.cod3;

import core.bitop;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcse;
import dmd.backend.code;
import dmd.backend.arm.disasmarm : encodeHFD;
import dmd.backend.x86.cgcod : disassemble;
import dmd.backend.x86.code_x86;
import dmd.backend.x86.cod3;
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

import dmd.backend.arm.instr;

nothrow:
@safe:


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
    // TODO AArch64 floating point registers
    if (!regsave.alignment)
        regsave.alignment = REGSIZE;
    idx = regsave.idx;
    regsave.idx += REGSIZE;

    // STR reg, [BP, #idx]
    code cs;
    cs.reg = reg;
    cs.base = cgstate.BP;
    cs.index = NOREG;
    cs.IFL1 = FL.regsave;
    cs.Iop = INSTR.str_imm_gen(1,reg,cs.base,idx);
    cdb.gen(&cs);

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
    // TODO AArch64 floating point registers
    // LDR reg,[BP, #idx]
    code cs;
    cs.reg = reg;
    cs.base = cgstate.BP;
    cs.index = NOREG;
    cs.IFL1 = FL.regsave;
    cs.Iop = INSTR.ldr_imm_gen(1,reg,cs.base,idx);
    cdb.gen(&cs);
}


// https://www.scs.stanford.edu/~zyedidia/arm64/b_cond.html
bool isBranch(uint ins) { return (ins & ((0xFF << 24) | (1 << 4))) == ((0x54 << 24) | (0 << 4)); }

enum MARS = true;

// outswitab

/* AArch64 condition codes
 */
enum COND : ubyte
{
    eq,ne,cs,cc,mi,pl,vs,vc,
    hi,ls,ge,lt,gt,le,al,nv,
}

/*****************************
 * Equivalent to x86/cod3/jmpopcode
 * Returns: a condition code relevant to the elem for a JMP true.
 */
@trusted
COND conditionCode(elem* e)
{
    //printf("conditionCode()\n"); elem_print(e);

    assert(e);
    while (e.Eoper == OPcomma ||
        /* The OTleaf(e.E1.Eoper) is to line up with the case in cdeq() where  */
        /* we decide if mPSW is passed on when evaluating E2 or not.    */
         (e.Eoper == OPeq && OTleaf(e.E1.Eoper)))
    {
        e = e.E2;                      /* right operand determines it  */
    }

    OPER op = e.Eoper;
    tym_t tymx = tybasic(e.Ety);

    if (e.Ecount != e.Ecomsub)          // comsubs just get Z bit set
    {
        return COND.ne;
    }
    if (!OTrel(op))                       // not relational operator
    {
        if (op == OPu32_64) { e = e.E1; op = e.Eoper; }
        if (op == OPu16_32) { e = e.E1; op = e.Eoper; }
        if (op == OPu8_16) op = e.E1.Eoper;
        return ((op >= OPbt && op <= OPbts) || op == OPbtst) ? COND.cs : COND.ne;
    }

    int zero;
    if (e.E2.Eoper == OPconst)
        zero = !boolres(e.E2);
    else
        zero = 0;

    const tym = e.E1.Ety;
    int i;
    if (tyfloating(tym))
    {
        i = 0;
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

    COND jp;
    with (COND)
    {
        immutable COND[6][2][2] jops =
        [   /* <=   >   <   >=  ==  !=    <=0   >0  <0  >=0 ==0 !=0    */
           [ [ le, gt, lt,  ge, eq, ne], [ le,  gt, mi,  pl, eq, ne] ], /* signed   */
           [ [ ls, hi, cc,  cs, eq, ne], [ ls,  ne, nv,  al, eq, ne] ], /* uint */
        ];

        jp = jops[i][zero][op - OPle];        /* table starts with OPle       */
    }

    /* Try to rewrite uint comparisons so they rely on just the Carry flag
     */
    if (i == 1 && (jp == COND.hi || jp == COND.ls) &&
        (e.E2.Eoper != OPconst && e.E2.Eoper != OPrelconst))
    {
        jp = (jp == COND.hi) ? COND.cs : COND.cc;
    }

    //debug printf("%s i %d zero %d op x%x jp x%x\n",oper_str(op),i,zero,op,jp);
    return jp;
}


// cod3_ptrchk
// cod3_useBP
// cse_simple
// gen_storecse
// gen_testcse
// gen_loadcse
// cdframeptr
// cdgot
// load_localgot
// obj_namestring
// genregs
// gentstreg
// genpush
// genpop
// genmovreg
// genmulimm
// genshift

/**************************
 * Generate a jump instruction.
 */

@trusted
void genBranch(ref CodeBuilder cdb, COND cond, FL fltarg, block* targ)
{
    code cs;
    cs.Iop = ((0x54 << 24) | cond);
    cs.Iflags = 0;
    cs.IFL1 = fltarg;                   // FL.block (or FL.code)
    cs.IEV1.Vblock = targ;              // target block (or code)
    if (fltarg == FL.code)
        (cast(code*)targ).Iflags |= CFtarg;
    cdb.gen(&cs);
}

// prolog_ifunc
// prolog_ifunc2
// prolog_16bit_windows_farfunc
// prolog_frame
// prolog_stackalign
// prolog_frameadj
// prolog_frameadj2
// prolog_setupalloca
// prolog_saveregs
// epilog_restoreregs

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
    printf("prolog_genvarargs()\n");
    /* Generate code to move any arguments passed in registers into
     * the stack variable __va_argsave,
     * so we can reference it via pointers through va_arg().
     *   struct __va_argsave_t {
     *     ulong[8] regs;      // 8 byte
     *     ldouble[8] fpregs;  // 16 byte
     *     struct __va_list_tag // embedded within __va_argsave_t
     *     {
     *         void* stack;  // next stack param
     *         void* gr_top; // end of GP arg reg save area
     *         void* vr_top; // end of FP/SIMD arg reg save area
     *         int gr_offs;  // offset from gr_top to next GP register arg
     *         int vr_offs;  // offset from vr_top to next FP/SIMD register arg
     *     }
     *     void* stack_args_save; // set by prolog_genvarargs()
     *   }
     * The instructions seg fault if data is not aligned on
     * 16 bytes, so this gives us a nice check to ensure no mistakes.
        STR     x0,[sp, #voff+0*8]
        STR     x1,[sp, #voff+1*8]
        STR     x2,[sp, #voff+2*8]
        STR     x3,[sp, #voff+3*8]
        STR     x4,[sp, #voff+4*8]
        STR     x5,[sp, #voff+5*8]
        STR     x6,[sp, #voff+6*8]
        STR     x7,[sp, #voff+7*8]

        STR     q0,[sp, #voff+8*8+0*16]
        STR     q1,[sp, #voff+8*8+1*16]
        STR     q2,[sp, #voff+8*8+2*16]
        STR     q3,[sp, #voff+8*8+3*16]
        STR     q4,[sp, #voff+8*8+4*16]
        STR     q5,[sp, #voff+8*8+5*16]
        STR     q6,[sp, #voff+8*8+6*16]
        STR     q7,[sp, #voff+8*8+7*16]

        ADD     reg,sp,Para.size+Para.offset
        STR     reg,[sp,#voff+8*8+8*16+8*4]         // set __va_argsave.stack_args
    */

    /* Save registers into the voff area on the stack
     */
    targ_size_t voff = cg.Auto.size + cg.BPoff + sv.Soffset;  // EBP offset of start of sv

    if (!cg.hasframe || cg.enforcealign)
        voff += cg.EBPtoESP;

    regm_t namedargs = prolog_namedArgs();
    printf("voff: %llx\n", voff);
    foreach (reg_t x; 0 .. 8)
    {
        if (!(mask(x) & namedargs))  // unnamed arguments would be the ... ones
        {
            //printf("offset: x%x %lld\n", cast(uint)voff + x * 8, voff + x * 8);
            uint offset = cast(uint)voff + x * 8;
            if (!cg.hasframe || cg.enforcealign)
                cdb.gen1(INSTR.str_imm_gen(1,x,31,offset)); // STR x,[sp,#offset]
            else
                cdb.gen1(INSTR.str_imm_gen(1,x,29,offset)); // STR x,[bp,#offset]
        }
    }

    foreach (reg_t q; 32 + 0 .. 32 + 8)
    {
        if (!(mask(q) & namedargs))  // unnamed arguments would be the ... ones
        {
            uint offset = cast(uint)voff + 8 * 8 + (q & 31) * 16;
            if (!cg.hasframe || cg.enforcealign)
                cdb.gen1(INSTR.str_imm_fpsimd(0,2,offset,31,q));  // STR q,[sp,#offset]
            else
                cdb.gen1(INSTR.str_imm_fpsimd(0,2,offset,29,q));
        }
    }

    reg_t reg = 11;
    uint imm12 = cast(uint)(cg.Para.size + cg.Para.offset);
    assert(imm12 < 0x1000);
    cdb.gen1(INSTR.addsub_imm(1,0,0,0,imm12,31,reg));   // ADD reg,sp,imm12
    uint offset = cast(uint)voff+8*8+8*16+8*4;
    printf("voff: %llx offset: %x\n", voff, offset);
offset &= 0xFFF; // TODO AArch64
    assert(offset < 0x1000);
    cdb.gen1(INSTR.str_imm_gen(1,reg,31,offset));       // STR reg,[sp,#voff+8*8+8*16+8*4]
    useregs(mask(reg));
}

/********************************
 * Generate elems that implement va_start()
 * Params:
 *      sv = symbol for __va_argsave
 *      parmn = last named parameter
 */
@trusted
elem* prolog_genva_start(Symbol* sv, Symbol* parmn)
{
    printf("prolog_genva_start()\n");

    /* the stack variable __va_argsave points to an instance of:
     *   struct __va_argsave_t {
     *     ulong[8] regs;        // 8 bytes each
     *     float128[8] fpregs;   // 16 bytes each
     *     // AArch64 Procedure Call Standard 12.2
     *     struct __va_list_tag // embedded within __va_argsave_t
     *     {
     *         void* stack;  // next stack param
     *         void* gr_top; // end of GP arg reg save area
     *         void* vr_top; // end of FP/SIMD arg reg save area
     *         int gr_offs;  // offset from gr_top to next GP register arg
     *         int vr_offs;  // offset from vr_top to next FP/SIMD register arg
     *     }
     *     void* stack_args_save; // set by prolog_genvarargs()
     *   }
     */

    enum OFF // offsets into __va_argsave_t
    {
        stack   = 8 * 8 + 16 * 8,
        gr_top  = stack + 8,
        vr_top  = gr_top + 8,
        gr_offs = vr_top + 8,
        vr_offs = gr_offs + 4,
        stack_args_save = vr_offs + 4,
    }

    regm_t namedargs = prolog_namedArgs(); // mask of named arguments

    // AArch64 Procedure Call Standard 12.3
    uint named_gr;      // number of general registers known to hold named incoming arguments
    foreach (reg_t x; 0 .. 8)
    {
        if (!namedargs)
            break;
        regm_t m = mask(x);
        if (m & namedargs)
        {
            ++named_gr;
            namedargs &= ~m;
        }
    }

    uint named_vr;      // number of FP/SIMD registers known to hold named incoming arguments
    foreach (reg_t q; 32 + 0 .. 32 + 8)
    {
        if (!namedargs)
            break;
        regm_t m = mask(q);
        if (m & namedargs)
        {
            ++named_vr;
            namedargs &= ~m;
        }
    }

    // set stack to address following the last named incoming argument on the stack
    // rounded upwards to a multiple of 8 bytes, or if there are no named arguments on the stack, then
    // the value of the stack pointer when the function was entered.
    /* set stack_args
     * which is a pointer to the first variadic argument on the stack.
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
    elem* e1 = el_bin(OPeq, TYnptr, el_var(sv), el_var(sv)); // stack = stack_args_save
    e1.E1.Ety = TYnptr;
    e1.E1.Voffset = OFF.stack;
    e1.E2.Ety = TYnptr;
    e1.E2.Voffset = OFF.stack_args_save;

    // set gr_top to address following the general register save area
    elem* e2 = el_bin(OPeq, TYptr, el_var(sv), el_ptr(sv));
    e2.E1.Voffset = OFF.vr_offs;

    // set vr_top to address following the FP/SIMD register save area
    elem* ex3 = el_bin(OPadd, TYptr, el_ptr(sv), el_long(TYlong, 8 * 8));
    elem* e3 = el_bin(OPeq,TYptr,el_var(sv),ex3);
    e3.E1.Ety = TYptr;
    e3.E1.Voffset = OFF.vr_offs;

    // set gr_offs
    elem* e4 = el_bin(OPeq, TYint, el_var(sv), el_long(TYint, 0 - ((8 - named_gr) * 8)));
    e4.E1.Ety = TYint;
    e4.E1.Voffset = OFF.gr_offs;

    // set vr_offs
    elem* e5 = el_bin(OPeq, TYint, el_var(sv), el_long(TYint, 0 - ((8 - named_vr) * 16)));
    e5.E1.Ety = TYint;
    e5.E1.Voffset = OFF.vr_offs;

    elem* e = el_combine(e1, el_combine(e2, el_combine(e3, el_combine(e4, e5))));
    return e;
}

// prolog_gen_win64_varargs
// prolog_namedArgs
// prolog_loadparams

/*******************************
 * Generate and return function epilog.
 * Params:
 *      b = block that returns
 * Output:
 *      cgstate.retsize         Size of function epilog
 */

@trusted
void epilog(block* b)
{
    enum log = false;
    if (log) printf("arm.epilog()\n");
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
        code_orflag(cdbx.last(),CFoff | CFselfrel);
        useregs((ALLREGS | mBP | mES) & ~s.Sregsaved);
    }

    if (cgstate.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru) && (config.exe == EX_WIN32 || MARS))
    {
        nteh_epilog(cdbx);
    }

    cpopds = null;

    /* Pop all the general purpose registers saved on the stack
     * by the prolog code. Remember to do them in the reverse
     * order they were pushed.
     */
    topop = fregsaved & ~cgstate.mfuncreg;
//    epilog_restoreregs(cdbx, topop); // implement

    if (cgstate.usednteh & NTEHjmonitor)
    {
        regm_t retregs = 0;
        if (b.bc == BC.retexp)
            retregs = regmask(b.Belem.Ety, tym);
        nteh_monitor_epilog(cdbx,retregs);
        xlocalsize += 8;
    }

    if (cgstate.needframe || (xlocalsize && cgstate.hasframe))
    {
        if (log) printf("epilog: needframe %d xlocalsize x%x hasframe %d\n", cgstate.needframe, cast(int)xlocalsize, cgstate.hasframe);
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
                cdbx.gen1(0x58 + BP);                                 // POP BP
            }
            else if (config.exe == EX_WIN64)
            {   // See https://msdn.microsoft.com/en-us/library/tawsa7cb%28v=vs.100%29.aspx
                // LEA RSP,0[RBP]
                cdbx.genc1(LEA,(REX_W<<16)|modregrm(2,SP,BPRM),FL.const_,0);
                cdbx.gen1(0x58 + BP);      // POP RBP
            }
            else
            {
                if (log) printf("epilog: mov sp,bp\n");
                cdbx.gen1(INSTR.ldstpair_post(2, 0, 1, cast(uint)(16 + localsize) / 8, 30, 31, 29)); // LDP x29,x30,[sp],#16 + localsize
            }
        }
        else
        {
            if (log) printf("epilog: LDP\n");
            cdbx.gen1(INSTR.ldstpair_post(2, 0, 1, 16 / 8, 30, 31, 29));     // LDP x29,x30,[sp],#16
        }
    }
    else if (xlocalsize == REGSIZE)
    {
        if (log) printf("epilog: REGSIZE\n");
        cgstate.mfuncreg &= ~mask(regx);
        cdbx.gen1(0x58 + regx);                    // POP regx
    }
    else if (xlocalsize)
    {
        if (log) printf("epilog: xlocalsize %d\n", cast(int)xlocalsize);
        cod3_stackadj(cdbx, cast(int)-xlocalsize);
    }

    if (b.bc == BC.ret || b.bc == BC.retexp)
    {
Lret:
        if (log) printf("epilog: Lret\n");
        opcode_t op = INSTR.ret;
        if (!typfunc(tym) ||                       // if caller cleans the stack
            config.exe == EX_WIN64 ||
            cgstate.Para.offset == 0)                      // or nothing pushed on the stack anyway
        {
            if (log) printf("epilog: RET\n");
            cdbx.gen1(INSTR.ret);       // RET
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
                cdbx.gen1(0x58+regx);
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

    // If last instruction in ce is ADD SP,imm, and first instruction
    // in c sets SP, we can dump the ADD.
    CodeBuilder cdb; cdb.ctor();
    cdb.append(b.Bcode);
    code* cr = cdb.last();
    code* c = cdbx.peek();

    //pinholeopt(c, null);
    cgstate.retsize += calcblksize(c);          // compute size of function epilog
    cdb.append(cdbx);
    b.Bcode = cdb.finish();
}

// cod3_spoff
// gen_spill_reg
// cod3_thunk
// makeitextern

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
    int bytesaved;
    code* c,cn,ct;
    targ_size_t offset,disp;
    targ_size_t csize;

    if (!flag)
        bl.Bflags |= BFL.jmpoptdone;      // assume this will be all
    c = bl.Bcode;
    if (!c)
        return 0;
    //for (code* cx = c; cx; cx = code_next(cx)) printf("branch cx.Iop = x%08x\n", cx.Iop);
    bytesaved = 0;
    offset = bl.Boffset;                 /* offset of start of block     */
    while (1)
    {
        csize = calccodsize(c);
        cn = code_next(c);
        uint op = c.Iop;
        if (isBranch(op))
        {
          L1:
            switch (c.IFL1)
            {
                case FL.block:
                    if (flag)           // no offsets yet, don't optimize
                        goto L3;
                    disp = c.IEV1.Vblock.Boffset - offset - csize;

                    /* If this is a forward branch, and there is an aligned
                     * block intervening, it is possible that shrinking
                     * the jump instruction will cause it to be out of
                     * range of the target. This happens if the alignment
                     * prevents the target block from moving correspondingly
                     * closer.
                     */
                    if (disp >= (1 << 22) - 5 && c.IEV1.Vblock.Boffset > offset)
                    {   /* Look for intervening alignment
                         */
                        for (block* b = bl.Bnext; b; b = b.Bnext)
                        {
                            if (b.Balign)
                            {
                                bl.Bflags = cast(BFL)(bl.Bflags & ~cast(uint)BFL.jmpoptdone); // some JMPs left
                                goto L3;
                            }
                            if (b == c.IEV1.Vblock)
                                break;
                        }
                    }

                    break;

                case FL.code:
                {
                    code* cr;

                    disp = 0;

                    ct = c.IEV1.Vcode;         /* target of branch     */
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
                            if (ct.Iop == INSTR.nop ||
                                ct.Iop == PSOP.linnum)
                            {
                                ct = code_next(ct);
                                if (!ct)
                                    goto L2;
                            }
                            else
                            {
                                c.IEV1.Vcode = ct;
                                ct.Iflags |= CFtarg;
                                break;
                            }
                        }

                        /* And eliminate jmps to jmps   */
                        if (isBranch(ct.Iop) &&
                            ((op & 0x0F) == (ct.Iop & 0xF) || (ct.Iop & 0xF) == COND.al))
                        {
                            c.IFL1 = ct.IFL1;
                            c.IEV1.Vcode = ct.IEV1.Vcode;
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
                c.Iop = INSTR.nop;              // del branch instruction
                c.IEV1.Vcode = null;
                c = cn;
                if (!c)
                    break;
                continue;
            }
            else if (0 && cast(targ_size_t)cast(targ_schar)(disp - 2) == (disp - 2) &&
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
                        cn.IFL1 == FL.func &&
                        cn.IEV1.Vsym.Sflags & SFLexit &&
                        !(cn.Iflags & (CFtarg | CFtarg2))
                       )
                    {
                        cn.Iop = 0x0F00 | ((c.Iop & 0x0F) ^ 0x81);
                        c.Iop = INSTR.nop;
                        c.IEV1.Vcode = null;
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
                                if (cx.IEV1.Vcode == ct)
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


/*******************************
 * Set flags for register contents
 * Params:
 *      cdb = code sink
 *      reg = register to test
 *      sf = true for 64 bits
 */
void gentstreg(ref CodeBuilder cdb, reg_t reg, uint sf)
{
    // CMP reg,#0
    cdb.gen1(INSTR.cmp_imm(sf, 0, 0, reg));
    code_orflag(cdb.last(),CFpsw);
}


/**************************
 * Generate a MOV to,from register instruction.
 * Smart enough to dump redundant register moves, and segment
 * register moves.
 */

@trusted
void genmovreg(ref CodeBuilder cdb, reg_t to, reg_t from, tym_t ty = TYMAX)
{
    // TODO ftype and TYMAX ?
    if (to <= 31)
    {
        // integer
        uint sf = ty == TYMAX || _tysize[ty] == 8;
        cdb.gen1(INSTR.mov_register(sf, from, to));
    }
    else
    {
        // floating point
        uint ftype = (ty == TYMAX || _tysize[ty] == 8)
            ? 1
            : (_tysize[ty] == 4 ? 0 : 3);
        cdb.gen1(INSTR.fmov(ftype, from & 31, to & 31));
    }
}

/*************************************
 * Load constant floating point value into vreg.
 * Params:
 *      cdb = code sink for generated output
 *      vreg = target floating point register
 *      value = value to move into register
 *      sz = 4 for float, 8 for double
 */
@trusted
void loadFloatRegConst(ref CodeBuilder cdb, reg_t vreg, double value, uint sz)
{
    assert(vreg & 32);
    ubyte imm8;
    if (encodeHFD(value, imm8))
    {
        uint ftype = INSTR.szToFtype(sz);
        cdb.gen1(INSTR.fmov_float_imm(ftype,imm8,vreg)); // FMOV <Vd>,#<imm8>
    }
    else if (sz == 4)
    {
        float f = value;
        uint i = *cast(uint*)&f;
        regm_t retregs = ALLREGS;                       // TODO cg.allregs?
        reg_t reg = allocreg(cdb, retregs, TYfloat);
        movregconst(cdb,reg,i,0);                         // MOV reg,i
        cdb.gen1(INSTR.fmov_float_gen(0,0,0,7,reg,vreg)); // FMOV Sd,Wn
    }
    else if (sz == 8)
    {
        ulong i = *cast(ulong*)&value;
        regm_t retregs = ALLREGS;                       // TODO cg.allregs?
        reg_t reg = allocreg(cdb, retregs, TYdouble);
        movregconst(cdb,reg,i,64);                        // MOV reg,i
        cdb.gen1(INSTR.fmov_float_gen(1,1,0,7,reg,vreg)); // FMOV Dd,Xn
    }
    else
        assert(0);
    //cgstate.regimmed_set(vreg,value); // TODO
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
 * Params:
 *      cdb = code sink for generated output
 *      reg = target register
 *      value = value to move into register
 *      flags = options
 */

@trusted
void movregconst(ref CodeBuilder cdb,reg_t reg,targ_size_t value,regm_t flags)
{
    if (!(flags & 64))
        value &= 0xFFFF_FFFF;
    //printf("movregconst(reg=%s, value= %lld (%llx), flags=%llx)\n", regm_str(mask(reg)), value, value, flags);
    assert(!(flags & (4 | 16)));

    regm_t regm = cgstate.regcon.immed.mval & mask(reg);
    targ_size_t regv = cgstate.regcon.immed.value[reg];

    // If we already have the right value in the right register
    if (regm && (regv & 0xFFFFFFFF) == (value & 0xFFFFFFFF) && !(flags & 64))
    {
        if (flags & mPSW)
            gentstreg(cdb,reg,(flags & 64) != 0);
        return;
    }
    else if (flags & 64 && regm && regv == value)
    {   // Look at the full 64 bits
        if (flags & mPSW)
            gentstreg(cdb,reg,(flags & 64) != 0);
        return;
    }
    else
    {

        // See if another register has the right value
        reg_t r = 0;
        for (regm_t mreg = cgstate.regcon.immed.mval; mreg; mreg >>= 1)
        {
            if (mreg & 1 && cgstate.regcon.immed.value[r] == value)
            {
                genmovreg(cdb,reg,r);
                goto done;
            }
            r++;
        }

        uint sf = (flags & 64) != 0;
        uint opc = 2;               // MOVZ
        uint hw = 0;
        uint imm16 = value & 0xFFFF;
        reg_t Rd = reg;
        ulong value2 = value;

        // Look for shortcuts using ORR
        // Either ORR for the whole thing,
        // or ORR to OR set the high 32 bits same as the low 32
        // (not implemented)

        // Look for shortcuts using MOVN
        if (sf)
        {
            if ((value & 0xFFFF_FFFF_FFFF_0000) == 0xFFFF_FFFF_FFFF_0000)
            {
                imm16 = ~imm16 & 0xFFFF;
                opc = 0;            // MOVN
                value2 = 0;
            }
            else if ((value & 0xFFFF_FFFF_0000_FFFF) == 0xFFFF_FFFF_0000_FFFF)
            {
                imm16 = ~(value >> 16) & 0xFFFF;
                opc = 0;            // MOVN
                value2 = 0;
                hw = 1;
            }
            else if ((value & 0xFFFF_0000_FFFF_FFFF) == 0xFFFF_0000_FFFF_FFFF)
            {
                imm16 = ~(value >> 32) & 0xFFFF;
                opc = 0;            // MOVN
                value2 = 0;
                hw = 2;
            }
            else if ((value & 0x0000_FFFF_FFFF_FFFF) == 0x0000_FFFF_FFFF_FFFF)
            {
                imm16 = ~(value >> 48) & 0xFFFF;
                opc = 0;            // MOVN
                value2 = 0;
                hw = 3;
            }
        }
        else
        {
            if ((value & 0xFFFF_0000) == 0xFFFF_0000)
            {
                imm16 = ~imm16 & 0xFFFF;
                opc = 0;            // MOVN
                value2 = 0;
            }
            else if ((value & 0x0000_FFFF) == 0x0000_FFFF)
            {
                imm16 = ~(value >> 16) & 0xFFFF;
                opc = 0;            // MOVN
                value2 = 0;
                hw = 1;
            }
        }

        if ((value2 >> (hw * 16)) & 0xFFFF_FFFF_FFFF_0000)
        {
            // Check for ORR one instruction solution
            uint N, immr, imms;
            if (orr_solution(value2, N, immr, imms))
            {
                // MOV Rd,#imm
                // http://www.scs.stanford.edu/~zyedidia/arm64/mov_orr_log_imm.html
                cdb.gen1(INSTR.log_imm(sf, 1, N, immr, imms, 31, Rd));
                goto done;
            }
        }

        while (1)
        {
            if (imm16 || value2 == 0)
            {
                cdb.gen1(INSTR.movewide(sf, opc, hw, imm16, Rd));
                opc = 3;            // MOVK
            }
            value2 >>= 16;
            if (!value2)
                break;
            imm16 = value2 & 0xFFFF;
            ++hw;
        }
    }
done:
    if (flags & mPSW)
        gentstreg(cdb,reg,(flags & 64) != 0);
    //printf("set reg %d to %lld\n", reg, value);
    cgstate.regimmed_set(reg,value);
}

/**********************************
 * See if we can do MOV (bitmask, immediate) out of value.
 * Params:
 *      value = value to set register to
 *      N = N field
 *      immr = immr field
 *      imms = imms field
 * Returns:
 *      true if we can do it, and set N, immr, imms
 * References:
 *      . http://www.scs.stanford.edu/~zyedidia/arm64/mov_orr_log_imm.html
 *      . https://devblogs.microsoft.com/oldnewthing/20220802-00/?p=106927
 *      . https://dinfuehr.github.io/blog/encoding-of-immediate-values-on-aarch64/
 *      . https://gist.github.com/dinfuehr/51a01ac58c0b23e4de9aac313ed6a06a
 */
bool orr_solution(ulong value, out uint N, out uint immr, out uint imms)
{
    return false;
}

/********************************************
 * Replace symbolic references with values
 */
@trusted
void assignaddrc(code* c)
{
    int sn;
    Symbol* s;
    ubyte rm;
    uint sectionOff;
    ulong offset;
    reg_t Rn, Rt;
    uint base = cgstate.EBPtoESP;

    for (; c; c = code_next(c))
    {
        debug
        {
            if (0)
            {   printf("assignaddrc()\n");
                code_print(c);
            }
            if (code_next(c) && code_next(code_next(c)) == c)
                assert(0);
        }

        if ((c.Iop & PSOP.mask) == PSOP.root)
        {
            switch (c.Iop & PSOP.operator)
            {
                case PSOP.adjesp:
                    //printf("adjusting EBPtoESP (%d) by %ld\n",cgstate.EBPtoESP,cast(long)c.IEV1.Vint);
                    cgstate.EBPtoESP += c.IEV1.Vint;
                    c.Iop = INSTR.nop;
                    continue;

                case PSOP.fixesp:
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
                    continue;

                case PSOP.frameptr:
                    // Convert to load of frame pointer
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
                    continue;

                case PSOP.ldr:
    //printf("assignaddr: ldr\n");
                    break;

                default:
                    continue;
            }
        }

        s = c.IEV1.Vsym;
        uint sz = 8;
        uint ins = c.Iop;
//      if (c.IFL1 != FL.unde)
        {
            printf("FL: %s  ", fl_str(c.IFL1));
            disassemble(ins);
        }
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
                break;

            case FL.udata:
                if (config.objfmt == OBJ_OMF)
                {
                    c.IEV1.Vseg = s.Sseg;
                    c.IEV1.Vpointer += s.Soffset;
                    c.IFL1 = FL.datseg;
                }
                else
                    c.IFL1 = FL.extern_;
                break;

            case FL.tlsdata:
                if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                    c.IFL1 = FL.extern_;
                break;

            case FL.datseg:
                //c.IEV1.Vseg = DATA;
                break;

            case FL.fardata:
            case FL.csdata:
            case FL.pseudo:
                break;

            case FL.stack:       // for EE
                //printf("Soffset = %d, EBPtoESP = %d, base = %d, pointer = %d\n",
                //s.Soffset,cgstate.EBPtoESP,base,c.IEV1.Vpointer);
                c.IEV1.Vpointer += s.Soffset + cgstate.EBPtoESP - base - cgstate.EEStack.offset;
                c.IFL1 = FL.const_;
                assert(0); //break;

            case FL.reg:
                if (Symbol_Sisdead(*s, cgstate.anyiasm))
                {
                    c.Iop = INSTR.nop;               // remove references to it
                    break;
                }
                assert(field(ins,29,27) == 7 && field(ins,25,24) == 1);
                Rt = cast(reg_t)field(ins,4,0);
                Rn = s.Sreglsw;
                //assert(!c.Voffset);  // fix later
                c.Iop = INSTR.mov_register(sz > 4, Rn, Rt);
                c.IFL1 = FL.const_;
                break;

            case FL.fast:
                //printf("Fast.size: %d\n", cast(int)cgstate.Fast.size);
                sectionOff = cast(uint)cgstate.Fast.size;
                goto L1;

            case FL.auto_:
                sectionOff = cast(uint)cgstate.Auto.size;
                goto L1;

            case FL.para:
                sectionOff = cast(uint)cgstate.Para.size - cgstate.BPoff;    // cancel out add of BPoff
                goto L1;

            L1:
                if (Symbol_Sisdead(*s, cgstate.anyiasm))
                {
                    c.Iop = INSTR.nop;               // remove references to it
                    break;
                }
                static if (1)
                {
                    symbol_print(*s);
                    printf("c: %p, x%08x\n", c, c.Iop);
                    printf("s = %s, Soffset = %d, Para.size = %d, BPoff = %d, EBPtoESP = %d, Voffset = %d\n",
                        s.Sident.ptr, cast(int)s.Soffset, cast(int)cgstate.Para.size, cast(int)cgstate.BPoff,
                        cast(int)cgstate.EBPtoESP, cast(int)c.IEV1.Voffset);
                }
                if (s.Sflags & SFLunambig)
                    c.Iflags |= CFunambig;
                offset = c.IEV1.Voffset + s.Soffset + sectionOff + cgstate.BPoff;
                sz = tysize(s.ty());
                goto L2;

            case FL.fltreg:
                offset = c.IEV1.Vpointer + cgstate.Foff + cgstate.BPoff;
                c.Iflags |= CFunambig;
                goto L2;

            case FL.allocatmp:
                offset = c.IEV1.Vpointer + cgstate.Alloca.offset + cgstate.BPoff;
                assert(0); //goto L2;

            case FL.funcarg:
                offset = c.IEV1.Vpointer + cgstate.funcarg.offset + cgstate.BPoff;
                goto L2;

            case FL.bprel:                       // at fixed offset from frame pointer (nteh only)
                offset = c.IEV1.Vpointer + s.Soffset;
                c.IFL1 = FL.const_;
                goto L2;

            case FL.cs:                          // common subexpressions
                sn = c.IEV1.Vuns;
                if (!CSE.loaded(sn))            // if never loaded
                {
                    c.Iop = INSTR.nop;
                    break;
                }
                offset = CSE.offset(sn) + cgstate.CSoff + cgstate.BPoff;
                c.Iflags |= CFunambig;
                goto L2;

            case FL.regsave:
                c.Iflags |= CFunambig;
                offset = cgstate.regsave.off + cgstate.BPoff;

            L2:
                offset = cast(int)offset;       // sign extend
                // Load/store register (unsigned immediate) https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_pos
                assert(field(ins,29,27) == 7);
                uint opc   = field(ins,23,22);
                uint shift = field(ins,31,30);        // 0:1 1:2 2:4 3:8 shift for imm12
                uint op24  = field(ins,25,24);
printf("offset: %lld localsize: %lld REGSIZE*2: %d\n", offset, localsize, REGSIZE*2);
                if (cgstate.hasframe)
                    offset += REGSIZE * 2;
                offset += localsize;
                if (op24 == 1)
                {
                    uint imm12 = field(ins,21,10); // unsigned 12 bits
                    offset += imm12 << shift;      // add in imm
                    assert((offset & ((1 << shift) - 1)) == 0); // no misaligned access
                    imm12 = cast(uint)(offset >> shift);
                    assert(imm12 < 0x1000);
                    ins = setField(ins,21,10,imm12);
                }
                else if (op24 == 0)
                {
                    if (opc == 2 && shift == 0)
                        shift = 4;
                    uint imm9 = field(ins,20,12); // signed 9 bits
                    imm9 += 0x100;                // bias to being unsigned
                    offset += imm9 << shift;      // add in imm9
                    assert((offset & ((1 << shift) - 1)) == 0); // no misaligned access
                    imm9 = cast(uint)(offset >> shift);
                    assert(imm9 < 0x200);
                    imm9 = (imm9 - 0x100) & 0x1FF;
                    ins = setField(ins,20,12,imm9);
                }
                else
                    assert(0);

                Rn = cast(reg_t)field(ins,9,5);
                Rt = cast(reg_t)field(ins,4,0);
                if (!cgstate.hasframe || (cgstate.enforcealign && c.IFL1 != FL.para))
                {   /* Convert to SP relative address instead of BP */
                    assert(Rn == 29);                 // BP
                    offset += cgstate.EBPtoESP;       // add difference in offset
                    ins = setField(ins,9,5,31);       // set Rn to SP
                }
                c.Iop = ins;

                static if (0)
                    printf("is64(%d) offset(%d) = Fast.size(%d) + BPoff(%d) + EBPtoESP(%d)\n",
                        is64,imm12,cast(int)cgstate.Fast.size,cast(int)cgstate.BPoff,cast(int)cgstate.EBPtoESP);

                break;

            case FL.ndp:                                 // no 87 FPU
                assert(0);

            case FL.offset:
                c.IFL1 = FL.const_;
                break;

            case FL.localsize:                           // used by inline assembler
                c.IEV1.Vpointer += localsize;
                assert(0);                              // no inline assembler yet

            case FL.const_:
            case FL.extern_:
            case FL.func:
            case FL.code:
            case FL.unde:
                break;

            default:
                printf("FL: %s\n", fl_str(c.IFL1));
                assert(0);
        }
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
    code* ci,cn,ctarg,cstart;
    targ_size_t ad;

    //printf("jmpaddr()\n");
    cstart = c;                           /* remember start of code       */
    while (c)
    {
        const op = c.Iop;
        if (isBranch(op)) // or CALL?
        {
            ci = code_next(c);
            ctarg = c.IEV1.Vcode;  /* target code                  */
            ad = 4;                /* IP displacement              */
            while (ci && ci != ctarg)
            {
                ad += calccodsize(ci);
                ci = code_next(ci);
            }
            if (!ci)
                goto Lbackjmp;      // couldn't find it
            c.Iop |= cast(uint)(ad >> 2) << 5;
            c.IFL1 = FL.unde;
        }
        if (op == LOOP && c.IFL1 == FL.code)    /* backwards refs       */
        {
          Lbackjmp:
            ctarg = c.IEV1.Vcode;
            for (ci = cstart; ci != ctarg; ci = code_next(ci))
                if (!ci || ci == c)
                    assert(0);
            ad = 4;                 /* - IP displacement            */
            while (ci != c)
            {
                assert(ci);
                ad += calccodsize(ci);
                ci = code_next(ci);
            }
            c.Iop = cast(uint)(-(ad >> 2)) << 5;
            c.IFL1 = FL.unde;
        }
        c = code_next(c);
    }
}

/*******************************
 * Calculate bl.Bsize.
 */

uint calcblksize(code* c)
{
    uint size = 0;
    for (; c; c = code_next(c))
        size += 4;
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
    if (c.Iop == INSTR.nop)
        return 0;
    return 4;
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
    code* cn;
    uint flags;

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
        //printf("codout: %08x\n", op);
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

            assert(calccodsize(c) == 0);
            continue;
        }

        switch (op)
        {
            case INSTR.nop:                   /* don't send them out          */
                debug
                assert(calccodsize(c) == 0);
                continue;

            case ASM:
                if (op != ASM)
                    break;
                ggen.flush();
                if (c.Iflags == CFaddrsize)    // kludge for DA inline asm
                {
                    //do32bit(ggen, FL.blockoff,c.IEV1,0,0);
                    assert(0);
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
        if (ggen.available() < 4)
            ggen.flush();

        //printf("op: %08x\n", op);
        //if ((op & 0xFC00_0000) == 0x9400_0000) // BL <label>
        if (Symbol* s = c.IEV1.Vsym)
        {
            switch (s.Sclass)
            {
                case SC.locstat:
                case SC.comdat:
                case SC.static_:
                case SC.extern_:
                case SC.comdef:
                case SC.global:
                case SC.sinline:
                case SC.einline:
                case SC.inline:
                    ggen.flush();
                    ggen.gen32(op);
                    objmod.reftoident(ggen.seg,ggen.offset,s,0,flags);
                    break;

                default:
                    ggen.gen32(op);
                    break;
            }
        }
        else
            ggen.gen32(op);
    }
    ggen.flush();
    Offset(seg) = ggen.offset;
    framehandleroffset = ggen.framehandleroffset;
    //printf("-codout(), Coffset = x%x\n", Offset(seg));
    return cast(uint)ggen.offset;                      /* ending address               */
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
    if (c == null)
    {
        printf("code 0\n");
        return;
    }

    printf("code %p: nxt=%p op=%08x",c,code_next(c),c.Iop);

    if ((c.Iop & PSOP.mask) == PSOP.root)
    {
        if (c.Iop == PSOP.linnum)
        {
            printf(" linnum = %d\n",c.IEV1.Vsrcpos.Slinnum);
            return;
        }
        printf(" PSOP");
    }

    if (c.Iflags)
        printf(" flg=%x",c.Iflags);
    if (0)
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
                printf(" %s", fl_str(c.IFL1));
                break;
        }
    }
    printf("\n");
}
