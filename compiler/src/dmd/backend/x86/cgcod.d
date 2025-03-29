/**
 * Top level code for the code generator.
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/x86/cgcod.d, backend/cgcod.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_x86_cgcod.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/x86/cgcod.d
 */

module dmd.backend.x86.cgcod;

version = FRAMEPTR;

import core.bitop;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.cgcse;
import dmd.backend.codebuilder;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.melf;
import dmd.backend.mem;
import dmd.backend.eh;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.pdata : win64_pdata;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.arm.disasmarm;
import dmd.backend.arm.instr;

import dmd.backend.x86.code_x86;
import dmd.backend.x86.disasm86;
import dmd.backend.x86.xmm;

import dmd.backend.barray;


nothrow:
@safe:

alias _compare_fp_t = extern(C) nothrow int function(const void*, const void*);
extern(C) void qsort(void* base, size_t nmemb, size_t size, _compare_fp_t compar);

enum MARS = true;

import dmd.backend.dwarfdbginf : dwarf_except_gentables;

__gshared CGstate cgstate;     // state of code generator

regm_t ALLREGS()  { return I64 ? mAX|mBX|mCX|mDX|mSI|mDI| mR8|mR9|mR10|mR11|mR12|mR13|mR14|mR15
                               : ALLREGS_INIT; }

regm_t BYTEREGS() { return I64 ? ALLREGS
                               : BYTEREGS_INIT; }

/*********************************
 * Main entry point for generating code for a function.
 * Note at the end of this routine mfuncreg will contain the mask
 * of registers not affected by the function. Some minor optimization
 * possibilities are here.
 * Params:
 *      sfunc = function to generate code for
 */
@trusted
void codgen(Symbol* sfunc)
{
    //printf("codgen('%s')\n",funcsym_p.Sident.ptr);
    assert(sfunc == funcsym_p);
    assert(cseg == funcsym_p.Sseg);

    cgreg_init();
    CSE.initialize();
    cgstate.Alloca.initialize();
    cgstate.anyiasm = 0;
    cgstate.AArch64 = config.target_cpu == TARGET_AArch64;
    cgstate.BP = cgstate.AArch64 ? 29 : BP;

    /* Sadly, the dwarf and Windows unwinders relies on the function epilog to exist
     */
    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        if (b.bc == BC.exit)
            b.bc = BC.ret;
    }

    /* Generate code repeatedly until we cannot do any better. Each
     * pass can generate opportunities for enregistering more variables,
     * loop until no more registers are free'd up.
     */
    cgstate.pass = BackendPass.initial;
    while (1)
    {
        debug
        if (debugr)
            printf("------------------ PASS%s -----------------\n",
                (cgstate.pass == BackendPass.initial) ? "init".ptr : ((cgstate.pass == BackendPass.reg) ? "reg".ptr : "final".ptr));

        cgstate.lastRetregs[] = 0;

        // if no parameters, assume we don't need a stack frame
        cgstate.needframe = 0;
        cgstate.enforcealign = false;
        cgstate.gotref = 0;
        cgstate.stackchanged = 0;
        cgstate.stackpush = 0;
        cgstate.refparam = 0;
        cgstate.calledafunc = 0;
        cgstate.retsym = null;

        cgstate.stackclean = 1;
        cgstate.funcarg.initialize();
        cgstate.funcargtos = ~0;
        cgstate.accessedTLS = false;
        STACKALIGN = TARGET_STACKALIGN;

        cgstate.regsave.reset();
        memset(global87.stack.ptr,0,global87.stack.sizeof);

        cgstate.calledFinally = false;
        cgstate.usednteh = 0;

        if (sfunc.Sfunc.Fflags3 & Fjmonitor &&
            config.exe & EX_windos)
            cgstate.usednteh |= NTEHjmonitor;

        // Set on a trial basis, turning it off if anything might throw
        sfunc.Sfunc.Fflags3 |= Fnothrow;

        cgstate.floatreg = false;
        assert(global87.stackused == 0);             /* nobody in 8087 stack         */

        CSE.start();
        memset(&cgstate.regcon,0,cgstate.regcon.sizeof);
        cgstate.regcon.cse.mval = cgstate.regcon.cse.mops = 0;      // no common subs yet
        cgstate.msavereg = 0;
        uint nretblocks = 0;
        cgstate.mfuncreg = fregsaved;               // so we can see which are used
                                            // (bit is cleared each time
                                            //  we use one)
        assert(!(cgstate.needframe && cgstate.mfuncreg & mask(cgstate.BP))); // needframe needs mBP

        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            memset(&b.Bregcon,0,b.Bregcon.sizeof);       // Clear out values in registers
            if (b.Belem)
                resetEcomsub(b.Belem);     // reset all the Ecomsubs
            if (b.bc == BC.asm_)
                cgstate.anyiasm = 1;                // we have inline assembler
            if (b.bc == BC.ret || b.bc == BC.retexp)
                nretblocks++;
        }

        if (!config.fulltypes || (config.flags4 & CFG4optimized))
        {
            regm_t noparams = 0;
            foreach (s; globsym[])
            {
                s.Sflags &= ~SFLread;
                switch (s.Sclass)
                {
                    case SC.fastpar:
                    case SC.shadowreg:
                        cgstate.regcon.params |= s.Spregm();
                        goto case SC.parameter;

                    case SC.parameter:
                        if (s.Sfl == FL.reg)
                            noparams |= s.Sregm;
                        break;

                    default:
                        break;
                }
            }
            cgstate.regcon.params &= ~noparams;
        }

        if (config.flags4 & CFG4optimized)
        {
            if (nretblocks == 0 &&                  // if no return blocks in function
                !(sfunc.ty() & mTYnaked))      // naked functions may have hidden veys of returning
                sfunc.Sflags |= SFLexit;       // mark function as never returning

            assert(bo.dfo);

            cgreg_reset();
            foreach (i, b; bo.dfo[])
            {
                cgstate.dfoidx = cast(int)i;
                cgstate.regcon.used = cgstate.msavereg | cgstate.regcon.cse.mval;   // registers already in use
                assert(!(cgstate.regcon.used & mPSW));
                blcodgen(cgstate, b);                 // gen code in depth-first order
                //printf("b.Bregcon.used = %s\n", regm_str(b.Bregcon.used));
                cgreg_used(cgstate.dfoidx, b.Bregcon.used); // gather register used information
            }
        }
        else
        {
            cgstate.pass = BackendPass.final_;
            for (block* b = bo.startblock; b; b = b.Bnext)
            {
                blcodgen(cgstate, b);        // generate the code for each block
                //for (code* cx = b.Bcode; cx; cx = code_next(cx)) printf("Bcode x%08x\n", cx.Iop);
            }
        }
        cgstate.regcon.immed.mval = 0;
        assert(!cgstate.regcon.cse.mops);           // should have all been used

        if (cgstate.pass == BackendPass.final_ ||       // the final pass, so exit
            cgstate.anyiasm)                            // possible LEA or LES opcodes
        {
            break;
        }

        // See which variables we can put into registers
        cgstate.allregs |= cod3_useBP();                // use EBP as general purpose register

        // If pic code, but EBX was never needed
        if (!(cgstate.allregs & mask(PICREG)) && !cgstate.gotref)
        {
            cgstate.allregs |= mask(PICREG);            // EBX can now be used
            cgreg_assign(cgstate.retsym);
            cgstate.pass = BackendPass.reg;
        }
        else if (cgreg_assign(cgstate.retsym))          // if we found some registers
            cgstate.pass = BackendPass.reg;
        else
            cgstate.pass = BackendPass.final_;

        /* free up generated code for next pass
         */
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            code_free(b.Bcode);
            b.Bcode = null;
        }
    }
    cgreg_term();

    // See if we need to enforce a particular stack alignment
    foreach (s; globsym[])
    {
        if (Symbol_Sisdead(*s, cgstate.anyiasm))
            continue;

        switch (s.Sclass)
        {
            case SC.register:
            case SC.auto_:
            case SC.fastpar:
                if (s.Sfl == FL.reg)
                    break;

                const sz = type_alignsize(s.Stype);
                if (sz > STACKALIGN && (I64 || config.exe == EX_OSX))
                {
                    STACKALIGN = sz;
                    cgstate.enforcealign = true;
                }
                break;

            default:
                break;
        }
    }

    stackoffsets(cgstate, globsym, false); // compute final offsets of stack variables
    cod5_prol_epi(bo.startblock);    // see where to place prolog/epilog
    CSE.finish();                 // compute addresses and sizes of CSE saves

    if (configv.addlinenumbers)
        objmod.linnum(sfunc.Sfunc.Fstartline,sfunc.Sseg,Offset(sfunc.Sseg));

    // Otherwise, jmp's to startblock will execute the prolog again
    assert(!bo.startblock.Bpred);

    CodeBuilder cdbprolog; cdbprolog.ctor();
    prolog(cgstate, cdbprolog);           // gen function start code
    code* cprolog = cdbprolog.finish();
    if (cprolog)
        pinholeopt(cprolog,null);       // optimize

    cgstate.funcoffset = Offset(sfunc.Sseg);
    targ_size_t coffset = Offset(sfunc.Sseg);

    if (eecontext.EEelem)
        genEEcode();

    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        // We couldn't do this before because localsize was unknown
        switch (b.bc)
        {
            case BC.ret:
                if (configv.addlinenumbers && b.Bsrcpos.Slinnum && !(sfunc.ty() & mTYnaked))
                {
                    CodeBuilder cdb; cdb.ctor();
                    cdb.append(b.Bcode);
                    cdb.genlinnum(b.Bsrcpos);
                    b.Bcode = cdb.finish();
                }
                goto case BC.retexp;

            case BC.retexp:
                epilog(b);
                break;

            default:
                if (b.Bflags & BFL.epilog)
                    epilog(b);
                break;
        }
        assignaddr(b);                  // assign addresses
        pinholeopt(b.Bcode,b);         // do pinhole optimization
        if (b.Bflags & BFL.prolog)      // do function prolog
        {
            cgstate.startoffset = coffset + calcblksize(cprolog) - cgstate.funcoffset;
            b.Bcode = cat(cprolog,b.Bcode);
        }
        cgsched_block(b);
        b.Bsize = calcblksize(b.Bcode);       // calculate block size
        if (b.Balign)
        {
            targ_size_t u = b.Balign - 1;
            coffset = (coffset + u) & ~u;
        }
        b.Boffset = coffset;           /* offset of this block         */
        coffset += b.Bsize;            /* offset of following block    */
    }

    debug
    debugw && printf("code addr complete\n");

    // Do jump optimization
    bool flag;
    do
    {
        flag = false;
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            if (b.Bflags & BFL.jmpoptdone)      /* if no more jmp opts for this blk */
                continue;
            int i = branch(b,0);            // see if jmp => jmp short
            if (i)                          // if any bytes saved
            {
                b.Bsize -= i;
                auto offset = b.Boffset + b.Bsize;
                for (block* bn = b.Bnext; bn; bn = bn.Bnext)
                {
                    if (bn.Balign)
                    {
                        targ_size_t u = bn.Balign - 1;
                        offset = (offset + u) & ~u;
                    }
                    bn.Boffset = offset;
                    offset += bn.Bsize;
                }
                coffset = offset;
                flag = true;
            }
        }
        if (!I16 && !(config.flags4 & CFG4optimized))
            break;                      // use the long conditional jmps
    } while (flag);                     // loop till no more bytes saved

    debug
    debugw && printf("code jump optimization complete\n");

    if (cgstate.usednteh & NTEH_try)
    {
        // Do this before code is emitted because we patch some instructions
        nteh_filltables();
    }

    // Compute starting offset for switch tables
    targ_size_t swoffset;
    int jmpseg = -1;
    if (config.flags & CFGromable)
    {
        jmpseg = 0;
        swoffset = coffset;
    }

    targ_size_t framehandleroffset;     // offset of C++ frame handler

    // Emit the generated code
    if (eecontext.EEcompile == 1)
    {
        codout(sfunc.Sseg,eecontext.EEcode,null,framehandleroffset);
        code_free(eecontext.EEcode);
    }
    else
    {
        __gshared Barray!ubyte disasmBuf;
        disasmBuf.reset();

        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            if (b.bc == BC.jmptab || b.bc == BC.switch_)
            {
                if (jmpseg == -1)
                {
                    jmpseg = objmod.jmpTableSegment(sfunc);
                    swoffset = Offset(jmpseg);
                }
                swoffset = _align(0,swoffset);
                b.Btableoffset = swoffset;     /* offset of sw tab */
                swoffset += b.Btablesize;
            }
            jmpaddr(b.Bcode);          /* assign jump addresses        */

            debug
            if (debugc)
            {
                printf("Boffset = x%x, Bsize = x%x, Coffset = x%x\n",
                    cast(int)b.Boffset,cast(int)b.Bsize,cast(int)Offset(sfunc.Sseg));
                if (b.Bcode)
                    printf( "First opcode of block is: %0x\n", b.Bcode.Iop );
            }

            if (b.Balign)
            {   uint u = b.Balign;
                uint nalign = (u - cast(uint)Offset(sfunc.Sseg)) & (u - 1);

                cod3_align_bytes(sfunc.Sseg, nalign);
            }
            assert(b.Boffset == Offset(sfunc.Sseg));

            codout(sfunc.Sseg,b.Bcode,(configv.vasm ? &disasmBuf : null), framehandleroffset);   // output code
        }
static if (0)
        if (coffset != Offset(sfunc.Sseg))
        {
            debug
            printf("coffset = %d, Offset(sfunc.Sseg) = %d\n",cast(int)coffset,cast(int)Offset(sfunc.Sseg));

            assert(0);
        }
        sfunc.Ssize = Offset(sfunc.Sseg) - cgstate.funcoffset;    // size of function

        if (configv.vasm)
            disassemble(disasmBuf[]);                   // disassemble the code

        const nteh = cgstate.usednteh & NTEH_try;
        if (nteh)
        {
            assert(!(config.flags & CFGromable));
            //printf("framehandleroffset = x%x, coffset = x%x\n",framehandleroffset,coffset);
            objmod.reftocodeseg(sfunc.Sseg,framehandleroffset,coffset);
        }

        // Write out switch tables
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            switch (b.bc)
            {
                case BC.jmptab:              /* if jump table                */
                    outjmptab(b);           /* write out jump table         */
                    goto default;

                case BC.switch_:
                    outswitab(b);           /* write out switch table       */
                    goto default;

                case BC.ret:
                case BC.retexp:
                    /* Compute offset to return code from start of function */
                    cgstate.retoffset = b.Boffset + b.Bsize - cgstate.retsize - cgstate.funcoffset;

                    /* Add 3 bytes to cgstate.retoffset in case we have an exception
                     * handler. THIS PROBABLY NEEDS TO BE IN ANOTHER SPOT BUT
                     * IT FIXES THE PROBLEM HERE AS WELL.
                     */
                    if (cgstate.usednteh & NTEH_try)
                        cgstate.retoffset += 3;
                    break;

                default:
                    cgstate.retoffset = b.Boffset + b.Bsize - cgstate.funcoffset;
                    break;
            }
        }
        if (configv.addlinenumbers && !(sfunc.ty() & mTYnaked))
            /* put line number at end of function on the
               start of the last instruction
             */
            /* Instead, try offset to cleanup code  */
            if (cgstate.retoffset < sfunc.Ssize)
                objmod.linnum(sfunc.Sfunc.Fendline,sfunc.Sseg,cgstate.funcoffset + cgstate.retoffset);

        static if (MARS)
        {
            if (config.exe == EX_WIN64)
                win64_pdata(sfunc, localsize);
        }

        static if (MARS)
        {
            if (cgstate.usednteh & NTEH_try)
            {
                // Do this before code is emitted because we patch some instructions
                nteh_gentables(sfunc);
            }
            if (cgstate.usednteh & (EHtry | EHcleanup) &&   // saw BC.try_ or BC._try or OPddtor
                config.ehmethod == EHmethod.EH_DM)
            {
                except_gentables();
            }
            if (config.ehmethod == EHmethod.EH_DWARF)
            {
                sfunc.Sfunc.Fstartblock = bo.startblock;
                dwarf_except_gentables(sfunc, cast(uint)cgstate.startoffset, cast(uint)cgstate.retoffset);
                sfunc.Sfunc.Fstartblock = null;
            }
        }

        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            code_free(b.Bcode);
            b.Bcode = null;
        }
    }

    // Mask of regs saved
    // BUG: do interrupt functions save BP?
    tym_t functy = tybasic(sfunc.ty());
    sfunc.Sregsaved = (functy == TYifunc) ? cast(regm_t) mBP : (cgstate.mfuncreg | fregsaved);

    debug
    if (global87.stackused != 0)
      printf("stackused = %d\n",global87.stackused);

    assert(global87.stackused == 0);             /* nobody in 8087 stack         */

    global87.save.dtor();       // clean up ndp save array
}

/*********************************************
 * Align sections on the stack.
 *  base        negative offset of section from frame pointer
 *  alignment   alignment to use
 *  bias        difference between where frame pointer points and the STACKALIGNed
 *              part of the stack
 * Returns:
 *  base        revised downward so it is aligned
 */
@trusted
targ_size_t alignsection(targ_size_t base, uint alignment, int bias)
{
    //printf("alignsection(base: x%x, alignment: x%x, bias: x%x)\n", cast(uint)base, alignment, bias);
    assert(cast(long)base <= 0);
    if (alignment > STACKALIGN)
        alignment = STACKALIGN;
    if (alignment)
    {
        long sz = cast(long)(-base + bias);
        assert(sz >= 0);
        sz &= (alignment - 1);
        if (sz)
            base -= alignment - sz;
    }
    //printf("returns: x%x\n", cast(uint)base);
    return base;
}

/*******************************
 * Generate code for a function start.
 * Input:
 *      Offset(cseg)         address of start of code
 *      Auto.alignment
 * Output:
 *      Offset(cseg)         adjusted for size of code generated
 *      EBPtoESP
 *      hasframe
 *      BPoff
 */
private
@trusted
void prolog(ref CGstate cg, ref CodeBuilder cdb)
{
    bool enter;

    const XMMREGS = cg.AArch64 ? 0 : XMMREGS;

    //printf("x86.cgcod.prolog() %s, needframe = %d, Auto.alignment = %d\n", funcsym_p.Sident.ptr, cg.needframe, cg.Auto.alignment);
    debug debugw && printf("prolog()\n");
    cg.regcon.immed.mval = 0;                      /* no values in registers yet   */
    version (FRAMEPTR)
        cg.EBPtoESP = 0;
    else
        cg.EBPtoESP = -REGSIZE;
    cg.hasframe = false;
    bool pushds = false;
    cg.BPoff = 0;
    bool pushalloc = false;
    tym_t tyf = funcsym_p.ty();
    tym_t tym = tybasic(tyf);
    const farfunc = tyfarfunc(tym) != 0;

    if (config.flags3 & CFG3ibt && !I16)
        cdb.gen1(I32 ? ENDBR32 : ENDBR64);

    // Special Intel 64 bit ABI prolog setup for variadic functions
    Symbol* sv64 = null;                        // set to __va_argsave
    if (I64 && variadic(funcsym_p.Stype))
    {
        /* The Intel 64 bit ABI scheme.
         * abi_sysV_amd64.pdf
         * Load arguments passed in registers into the varargs save area
         * so they can be accessed by va_arg().
         */
        /* Look for __va_argsave
         */
        foreach (s; globsym[])
        {
            if (s.Sident[0] == '_' && strcmp(s.Sident.ptr, "__va_argsave") == 0)
            {
                if (!(s.Sflags & SFLdead))
                    sv64 = s;
                break;
            }
        }
    }

    if (config.flags & CFGalwaysframe ||
        funcsym_p.Sfunc.Fflags3 & Ffakeeh ||
        /* The exception stack unwinding mechanism relies on the EBP chain being intact,
         * so need frame if function can possibly throw
         */
        !(config.exe == EX_WIN32) && !(funcsym_p.Sfunc.Fflags3 & Fnothrow) ||
        cg.accessedTLS ||
        sv64 ||
        (0 && cg.calledafunc && cg.AArch64)
       )
    {
        //printf("0 prolog() needframe %d alwaysframe %d\n", cg.needframe, config.flags & CFGalwaysframe);
        cg.needframe = 1;
    }

    CodeBuilder cdbx; cdbx.ctor();

Lagain:
    cg.spoff = 0;
    char guessneedframe = cg.needframe;
    int cfa_offset = 0;
//    if (cg.needframe && config.exe & (EX_LINUX | EX_FREEBSD | EX_OPENBSD | EX_SOLARIS) && !(cg.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru)))
//      cg.usednteh |= NTEHpassthru;

    /* Compute BP offsets for variables on stack.
     * The organization is:
     *  Para.size    parameters
     * -------- stack is aligned to STACKALIGN
     *          seg of return addr      (if far function)
     *          IP of return addr
     *  BP.    caller's BP
     *          DS                      (if Windows prolog/epilog)
     *          exception handling context symbol
     *  Fast.size fastpar
     *  Auto.size    autos and regs
     *  regsave.off  any saved registers
     *  Foff    floating register
     *  Alloca.size  alloca temporary
     *  CSoff   common subs
     *  NDPoff  any 8087 saved registers
     *          monitor context record
     *          any saved registers
     */

    if (tym == TYifunc)
        cg.Para.size = 26; // how is this number derived?
    else
    {
        version (FRAMEPTR)
        {
            bool frame = cg.needframe || tyf & mTYnaked;
            cg.Para.size = ((farfunc ? 2 : 1) + frame) * REGSIZE;
            if (frame)
                cg.EBPtoESP = -REGSIZE;
            else if (cg.AArch64)
                cg.Para.size = 0;       // return address is in register, not the stack
        }
        else
            cg.Para.size = ((farfunc ? 2 : 1) + 1) * REGSIZE;
    }
    //printf("enforcealign: %d\n", cg.enforcealign);

    /* The real reason for the FAST section is because the implementation of contracts
     * requires a consistent stack frame location for the 'this' pointer. But if varying
     * stuff in Auto.offset causes different alignment for that section, the entire block can
     * shift around, causing a crash in the contracts.
     * Fortunately, the 'this' is always an SCfastpar, so we put the fastpar's in their
     * own FAST section, which is never aligned at a size bigger than REGSIZE, and so
     * its alignment never shifts around.
     * But more work needs to be done, see Bugzilla 9200. Really, each section should be aligned
     * individually rather than as a group.
     */
    cg.Fast.size = 0;
    static if (NTEXCEPTIONS == 2)
    {
        cg.Fast.size -= nteh_contextsym_size();
        if (config.exe & EX_windos)
        {
            if (funcsym_p.Sfunc.Fflags3 & Ffakeeh && nteh_contextsym_size() == 0)
                cg.Fast.size -= 5 * 4;
        }
    }

    /* Despite what the comment above says, aligning Fast section to size greater
     * than REGSIZE does not break contract implementation. Fast.offset and
     * Fast.alignment must be the same for the overriding and
     * the overridden function, since they have the same parameters. Fast.size
     * must be the same because otherwise, contract inheritance wouldn't work
     * even if we didn't align Fast section to size greater than REGSIZE. Therefore,
     * the only way aligning the section could cause problems with contract
     * inheritance is if bias (declared below) differed for the overridden
     * and the overriding function.
     *
     * Bias depends on Para.size and needframe. The value of Para.size depends on
     * whether the function is an interrupt handler and whether it is a farfunc.
     * DMD does not have _interrupt attribute and D does not make a distinction
     * between near and far functions, so Para.size should always be 2 * REGSIZE
     * for D.
     *
     * The value of needframe depends on a global setting that is only set
     * during backend's initialization and on function flag Ffakeeh. On Windows,
     * that flag is always set for virtual functions, for which contracts are
     * defined and on other platforms, it is never set. Because of that
     * the value of neadframe should always be the same for the overridden
     * and the overriding function, and so bias should be the same too.
     */

version (FRAMEPTR)
    int bias = cg.enforcealign ? 0 : cast(int)(cg.Para.size);
else
    int bias = cg.enforcealign ? 0 : cast(int)(cg.Para.size + (cg.needframe ? 0 : REGSIZE));
    if (cg.AArch64)
        bias = 0;

    if (cg.Fast.alignment < REGSIZE)
        cg.Fast.alignment = REGSIZE;

    cg.Fast.size = alignsection(cg.Fast.size - cg.Fast.offset, cg.Fast.alignment, bias);

    if (cg.Auto.alignment < REGSIZE)
        cg.Auto.alignment = REGSIZE;       // necessary because localsize must be REGSIZE aligned
    cg.Auto.size = alignsection(cg.Fast.size - cg.Auto.offset, cg.Auto.alignment, bias);

    cg.regsave.off = alignsection(cg.Auto.size - cg.regsave.top, cg.regsave.alignment, bias);
    //printf("regsave.off = x%x, size = x%x, alignment = %x\n",
        //cast(int)cg.regsave.off, cast(int)(cg.regsave.top), cast(int)cg.regsave.alignment);

    if (cg.floatreg)
    {
        uint floatregsize = config.fpxmmregs || I32 ? 16 : DOUBLESIZE;
        cg.Foff = alignsection(cg.regsave.off - floatregsize, STACKALIGN, bias);
        //printf("Foff = x%x, size = x%x\n", cast(int)cg.Foff, cast(int)floatregsize);
    }
    else
        cg.Foff = cg.regsave.off;

    cg.Alloca.alignment = REGSIZE;
    cg.Alloca.offset = alignsection(cg.Foff - cg.Alloca.size, cg.Alloca.alignment, bias);

    cg.CSoff = alignsection(cg.Alloca.offset - CSE.size(), CSE.alignment(), bias);
    //printf("CSoff = x%x, size = x%x, alignment = %x\n",
        //cast(int)cg.CSoff, CSE.size(), cast(int)CSE.alignment);

    cg.NDPoff = alignsection(cg.CSoff - global87.save.length * tysize(TYldouble), REGSIZE, bias);

    regm_t topush = fregsaved & ~cg.mfuncreg;          // mask of registers that need saving
    cg.pushoffuse = false;
    cg.pushoff = cg.NDPoff;
    /* We don't keep track of all the pushes and pops in a function. Hence,
     * using POP REG to restore registers in the epilog doesn't work, because the Dwarf unwinder
     * won't be setting ESP correctly. With pushoffuse, the registers are restored
     * from EBP, which is kept track of properly.
     */
    if ((config.flags4 & CFG4speed || config.ehmethod == EHmethod.EH_DWARF) && (I32 || I64) || cg.AArch64)
    {
        /* Instead of pushing the registers onto the stack one by one,
         * allocate space in the stack frame and copy/restore them there.
         */
        int xmmtopush = popcnt(topush & XMMREGS);   // XMM regs take 16 bytes
        int gptopush = popcnt(topush) - xmmtopush;  // general purpose registers to save
        if (cg.NDPoff || xmmtopush || cg.funcarg.size)
        {
            cg.pushoff = alignsection(cg.pushoff - (gptopush * REGSIZE + xmmtopush * 16),
                    xmmtopush ? STACKALIGN : REGSIZE, bias);
            cg.pushoffuse = true;          // tell others we're using this strategy
        }
    }

    //printf("Fast.size = x%x, Auto.size = x%x\n", cast(int)cg.Fast.size, cast(int)cg.Auto.size);

    cg.funcarg.alignment = STACKALIGN;
    /* If the function doesn't need the extra alignment, don't do it.
     * Can expand on this by allowing for locals that don't need extra alignment
     * and calling functions that don't need it.
     */
    if (cg.pushoff == 0 && !cg.calledafunc && config.fpxmmregs && (I32 || I64) && !cg.AArch64)
    {
        cg.funcarg.alignment = I64 ? 8 : 4;
    }

    //printf("pushoff = %d, size = %d, alignment = %d, bias = %d\n", cast(int)cg.pushoff, cast(int)cg.funcarg.size, cast(int)cg.funcarg.alignment, cast(int)bias);
    cg.funcarg.offset = alignsection(cg.pushoff - cg.funcarg.size, cg.funcarg.alignment, bias);

    localsize = -cg.funcarg.offset;

    static if (0)
    printf("Alloca.offset = x%llx, cstop = x%llx, CSoff = x%llx, NDPoff = x%llx, localsize = x%llx\n",
        cast(long)cg.Alloca.offset, cast(long)CSE.size(), cast(long)cg.CSoff, cast(long)cg.NDPoff, cast(long)localsize);
    assert(cast(targ_ptrdiff_t)localsize >= 0);

    // Keep the stack aligned by 8 for any subsequent function calls
    if (!I16 && cg.calledafunc &&
        (STACKALIGN >= 16 || config.flags4 & CFG4stackalign)&&
        !cg.AArch64)
    {
        int npush = popcnt(topush);            // number of registers that need saving
        npush += popcnt(topush & XMMREGS);     // XMM regs take 16 bytes, so count them twice
        if (cg.pushoffuse)
            npush = 0;

        static if (0)
        printf("npush = %d Para.size = x%x needframe = %d localsize = x%x\n",
               npush, cast(int)cg.Para.size, cg.needframe, cast(int)localsize);

        int sz = cast(int)(localsize + npush * REGSIZE);
        if (!cg.enforcealign)
        {
            version (FRAMEPTR)
                sz += cg.Para.size;
            else
                sz += cg.Para.size + (cg.needframe ? 0 : -REGSIZE);
        }
        if (sz & (STACKALIGN - 1))
            localsize += STACKALIGN - (sz & (STACKALIGN - 1));
    }
    cg.funcarg.offset = -localsize;

    static if (0)
    printf("Foff x%02x Auto.size x%02x NDPoff x%02x CSoff x%02x Para.size x%02x localsize x%02x\n",
        cast(int)cg.Foff,cast(int)cg.Auto.size,cast(int)cg.NDPoff,cast(int)cg.CSoff,cast(int)cg.Para.size,cast(int)localsize);

    uint xlocalsize = cast(uint)localsize;    // amount to subtract from ESP to make room for locals

    if (tyf & mTYnaked)                 // if no prolog/epilog for function
    {
        cg.hasframe = true;
        return;
    }

    if (tym == TYifunc)
    {
        prolog_ifunc(cdbx,&tyf);
        cg.hasframe = true;
        cdb.append(cdbx);
        goto Lcont;
    }

    /* Determine if we need BP set up   */
//printf("1 prolog() needframe %d\n", cg.needframe);
    if (cg.enforcealign)
    {
        // we need BP to reset the stack before return
        // otherwise the return address is lost
        cg.needframe = 1;
    }
    else if (config.flags & CFGalwaysframe)
        cg.needframe = 1;
    else
    {
        if (localsize)
        {
            if (I16 ||
                !(config.flags4 & CFG4speed) ||
                config.target_cpu < TARGET_Pentium ||
                farfunc ||
                config.flags & CFGstack ||
                xlocalsize >= 0x1000 ||
                (cg.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru)) ||
                cg.anyiasm ||
                cg.Alloca.size
               )
            {
                cg.needframe = 1;
            }
        }
        if (cg.refparam && (cg.anyiasm || I16))
            cg.needframe = 1;
    }

    if (cg.needframe)
    {
        //printf("cg.BP = %d\n", cg.BP);
        //printf("cg.mfuncreg = %s\n", regm_str(cg.mfuncreg));
        assert(cg.mfuncreg & mask(cg.BP)); // shouldn't have used mBP

        if (!guessneedframe)            // if guessed wrong
            goto Lagain;
    }

    if (I16 && config.wflags & WFwindows && farfunc)
    {
        prolog_16bit_windows_farfunc(cdbx, &tyf, &pushds);
        enter = false;                  // don't use ENTER instruction
        cg.hasframe = true;        // we have a stack frame
    }
    else if (cg.needframe)                 // if variables or parameters
    {
        prolog_frame(cg, cdbx, farfunc, xlocalsize, enter, cfa_offset);
        cg.hasframe = true;
    }

    /* Align the stack if necessary */
    prolog_stackalign(cg, cdbx);

    /* Subtract from stack pointer the size of the local stack frame
     */
    if (config.flags & CFGstack)        // if stack overflow check
    {
        prolog_frameadj(cg, cdbx, tyf, xlocalsize, enter, &pushalloc);
        if (cg.Alloca.size)
            prolog_setupalloca(cdbx);
    }
    else if (cg.needframe)                      /* if variables or parameters   */
    {
        if (xlocalsize)                 /* if any stack offset          */
        {
            prolog_frameadj(cg, cdbx, tyf, xlocalsize, enter, &pushalloc);
            if (cg.Alloca.size)
                prolog_setupalloca(cdbx);
        }
        else
            assert(cg.Alloca.size == 0);
    }
    else if (xlocalsize)
    {
        assert(I32 || I64);
        prolog_frameadj2(cg, cdbx, tyf, xlocalsize, &pushalloc);
        version (FRAMEPTR) { } else
            cg.BPoff += REGSIZE;
    }
    else
        assert((localsize | cg.Alloca.size) == 0 || (cg.usednteh & NTEHjmonitor));
    cg.EBPtoESP += xlocalsize;
    if (cg.hasframe)
        cg.EBPtoESP += REGSIZE;

    /* Win64 unwind needs the amount of code generated so far
     */
    if (config.exe == EX_WIN64)
    {
        code* c = cdbx.peek();
        pinholeopt(c, null);
        cg.prolog_allocoffset = calcblksize(c);
    }

    if (cg.usednteh & NTEHjmonitor)
    {   Symbol* sthis;

        for (SYMIDX si = 0; 1; si++)
        {   assert(si < globsym.length);
            sthis = globsym[si];
            if (strcmp(sthis.Sident.ptr,"this".ptr) == 0)
                break;
        }
        nteh_monitor_prolog(cdbx,sthis);
        cg.EBPtoESP += 3 * 4;
    }

    cdb.append(cdbx);
    prolog_saveregs(cg, cdb, topush, cfa_offset);

Lcont:
    //printf("2 prolog() needframe %d\n", cg.needframe);

    if (config.exe == EX_WIN64)
    {
        if (variadic(funcsym_p.Stype))
            prolog_gen_win64_varargs(cdb);
        prolog_loadparams(cdb, tyf, pushalloc);
        return;
    }

    prolog_ifunc2(cdb, tyf, tym, pushds);

    static if (NTEXCEPTIONS == 2)
    {
        if (cg.usednteh & NTEH_except)
            nteh_setsp(cdb, 0x89);            // MOV __context[EBP].esp,ESP
    }

    // Load register parameters off of the stack. Do not use
    // assignaddr(), as it will replace the stack reference with
    // the register!
    prolog_loadparams(cdb, tyf, pushalloc);

    if (sv64)
        prolog_genvarargs(cg, cdb, sv64);

    /* Alignment checks
     */
    //assert(cg.Auto.alignment <= STACKALIGN);
    //assert(((cg.Auto.size + cg.Para.size + cg.BPoff) & (cg.Auto.alignment - 1)) == 0);
    //printf("-prolog() needframe %d\n", cg.needframe);
}

/************************************
 * Predicate for sorting auto symbols for qsort().
 * Returns:
 *      < 0     s1 goes farther from frame pointer
 *      > 0     s1 goes nearer the frame pointer
 *      = 0     no difference
 */

@trusted
extern (C) int
 autosort_cmp(scope const void* ps1, scope const void* ps2)
{
    Symbol* s1 = *cast(Symbol**)ps1;
    Symbol* s2 = *cast(Symbol**)ps2;

    /* Largest align size goes furthest away from frame pointer,
     * so they get allocated first.
     */
    uint alignsize1 = Symbol_Salignsize(*s1);
    uint alignsize2 = Symbol_Salignsize(*s2);
    if (alignsize1 < alignsize2)
        return 1;
    if (alignsize1 > alignsize2)
        return -1;

    /* move variables nearer the frame pointer that have higher Sweights
     * because addressing mode is fewer bytes. Grouping together high Sweight
     * variables also may put them in the same cache
     */
    if (s1.Sweight < s2.Sweight)
        return -1;
    if (s1.Sweight > s2.Sweight)
        return 1;

    /* More:
     * 1. put static arrays nearest the frame pointer, so buffer overflows
     *    can't change other variable contents
     * 2. Do the coloring at the byte level to minimize stack usage
     */
    return 0;
}

/******************************
 * Compute stack frame offsets for local variables.
 * that did not make it into registers.
 * Params:
 *      cg = global code gen state
 *      symtab = function's symbol table
 *      estimate = true for do estimate only, false for final
 */
@trusted
void stackoffsets(ref CGstate cg, ref symtab_t symtab, bool estimate)
{
    //printf("stackoffsets() %s\n", funcsym_p.Sident.ptr);

    cg.Para.initialize();        // parameter offset
    cg.Fast.initialize();        // SCfastpar offset
    cg.Auto.initialize();        // automatic & register offset
    cg.EEStack.initialize();     // for SCstack's

    // Set if doing optimization of auto layout
    bool doAutoOpt = estimate && config.flags4 & CFG4optimized;

    // Put autos in another array so we can do optimizations on the stack layout
    Symbol*[10] autotmp = void;
    Symbol** autos = null;
    if (doAutoOpt)
    {
        if (symtab.length <= autotmp.length)
            autos = autotmp.ptr;
        else
        {   autos = cast(Symbol**)malloc(symtab.length * (*autos).sizeof);
            assert(autos);
        }
    }
    size_t autosi = 0;  // number used in autos[]

    for (int si = 0; si < symtab.length; si++)
    {   Symbol* s = symtab[si];

        /* Don't allocate space for dead or zero size parameters
         */
        switch (s.Sclass)
        {
            case SC.fastpar:
                if (!(funcsym_p.Sfunc.Fflags3 & Ffakeeh))
                    goto Ldefault;   // don't need consistent stack frame
                break;

            case SC.parameter:
                if (type_zeroSize(s.Stype, tybasic(funcsym_p.Stype.Tty)))
                {
                    cg.Para.offset = _align(REGSIZE,cg.Para.offset); // align on word stack boundary
                    s.Soffset = cg.Para.offset;
                    continue;
                }
                break;          // allocate even if it's dead

            case SC.shadowreg:
                break;          // allocate even if it's dead

            default:
            Ldefault:
                if (Symbol_Sisdead(*s, cg.anyiasm))
                    continue;       // don't allocate space
                break;
        }

        targ_size_t sz = type_size(s.Stype);
        if (sz == 0)
            sz++;               // can't handle 0 length structs

        uint alignsize = Symbol_Salignsize(*s);
        if (alignsize > STACKALIGN)
            alignsize = STACKALIGN;         // no point if the stack is less aligned

        //printf("symbol '%s', size = %d, alignsize = %d, read = %x\n",s.Sident.ptr, cast(int)sz, cast(int)alignsize, s.Sflags & SFLread);
        assert(cast(int)sz >= 0);

        switch (s.Sclass)
        {
            case SC.fastpar:
                /* Get these
                 * right next to the stack frame pointer, EBP.
                 * Needed so we can call nested contract functions
                 * frequire and fensure.
                 */
                if (s.Sfl == FL.reg)        // if allocated in register
                    continue;
                /* Needed because storing fastpar's on the stack in prolog()
                 * does the entire register
                 */
                if (sz < REGSIZE)
                    sz = REGSIZE;

                cg.Fast.offset = _align(sz,cg.Fast.offset);
                s.Soffset = cg.Fast.offset;
                cg.Fast.offset += sz;
                //printf("fastpar '%s' sz = %d, fast offset =  x%x, %p\n", s.Sident, cast(int) sz, cast(int) s.Soffset, s);

                if (alignsize > cg.Fast.alignment)
                    cg.Fast.alignment = alignsize;
                break;

            case SC.register:
            case SC.auto_:
                if (s.Sfl == FL.reg)        // if allocated in register
                    break;

                if (doAutoOpt)
                {   autos[autosi++] = s;    // deal with later
                    break;
                }

                cg.Auto.offset = _align(sz,cg.Auto.offset);
                s.Soffset = cg.Auto.offset;
                cg.Auto.offset += sz;
                //printf("auto    '%s' sz = %d, auto offset =  x%lx\n", s.Sident,sz, cast(long) s.Soffset);

                if (alignsize > cg.Auto.alignment)
                    cg.Auto.alignment = alignsize;
                break;

            case SC.stack:
                cg.EEStack.offset = _align(sz,cg.EEStack.offset);
                s.Soffset = cg.EEStack.offset;
                //printf("EEStack.offset =  x%lx\n",cast(long)s.Soffset);
                cg.EEStack.offset += sz;
                break;

            case SC.shadowreg:
            case SC.parameter:
                if (config.exe == EX_WIN64)
                {
                    assert((cg.Para.offset & 7) == 0);
                    s.Soffset = cg.Para.offset;
                    cg.Para.offset += 8;
                    break;
                }
                /* Alignment on OSX 32 is odd. reals are 16 byte aligned in general,
                 * but are 4 byte aligned on the OSX 32 stack.
                 */
                cg.Para.offset = _align(REGSIZE,cg.Para.offset); /* align on word stack boundary */
                if (alignsize >= 16 &&
                    (I64 || (config.exe == EX_OSX &&
                         (tyaggregate(s.ty()) || tyvector(s.ty())))))
                    cg.Para.offset = (cg.Para.offset + (alignsize - 1)) & ~(alignsize - 1);
                s.Soffset = cg.Para.offset;
                //printf("%s param offset =  x%lx, alignsize = %d\n", s.Sident, cast(long) s.Soffset, cast(int) alignsize);
                cg.Para.offset += (s.Sflags & SFLdouble)
                            ? type_size(tstypes[TYdouble])   // float passed as double
                            : type_size(s.Stype);
                break;

            case SC.pseudo:
            case SC.static_:
            case SC.bprel:
                break;
            default:
                symbol_print(*s);
                assert(0);
        }
    }

    if (autosi)
    {
        qsort(autos, autosi, (Symbol*).sizeof, &autosort_cmp);

        vec_t tbl = vec_calloc(autosi);

        for (size_t si = 0; si < autosi; si++)
        {
            Symbol* s = autos[si];

            targ_size_t sz = type_size(s.Stype);
            if (sz == 0)
                sz++;               // can't handle 0 length structs

            uint alignsize = Symbol_Salignsize(*s);
            if (alignsize > STACKALIGN)
                alignsize = STACKALIGN;         // no point if the stack is less aligned

            /* See if we can share storage with another variable
             * if their live ranges do not overlap.
             */
            if (// Don't share because could stomp on variables
                // used in finally blocks
                !(cg.usednteh & (NTEH_try | NTEH_except | NTEHcpp | EHcleanup | EHtry | NTEHpassthru)) &&
                s.Srange && !(s.Sflags & SFLspill))
            {
                for (size_t i = 0; i < si; i++)
                {
                    if (!vec_testbit(i,tbl))
                        continue;
                    Symbol* sp = autos[i];
//printf("auto    s = '%s', sp = '%s', %d, %d, %d\n",s.Sident,sp.Sident,dfo.length,vec_numbits(s.Srange),vec_numbits(sp.Srange));
                    if (vec_disjoint(s.Srange,sp.Srange) &&
                        !(sp.Soffset & (alignsize - 1)) &&
                        sz <= type_size(sp.Stype))
                    {
                        vec_or(sp.Srange,sp.Srange,s.Srange);
                        //printf("sharing space - '%s' onto '%s'\n",s.Sident,sp.Sident);
                        s.Soffset = sp.Soffset;
                        goto L2;
                    }
                }
            }
            cg.Auto.offset = _align(sz,cg.Auto.offset);
            s.Soffset = cg.Auto.offset;
            //printf("auto    '%s' sz = %d, auto offset =  x%lx\n", s.Sident, sz, cast(long) s.Soffset);
            cg.Auto.offset += sz;
            if (s.Srange && !(s.Sflags & SFLspill))
                vec_setbit(si,tbl);

            if (alignsize > cg.Auto.alignment)
                cg.Auto.alignment = alignsize;
        L2: { }
        }

        vec_free(tbl);

        if (autos != autotmp.ptr)
            free(autos);
    }
}

/****************************
 * Generate code for a block.
 * Params:
 *      cg = code generator state
 *      bl = block to generate code for
 */

@trusted
private void blcodgen(ref CGstate cg, block* bl)
{
    regm_t mfuncregsave = cg.mfuncreg;

    //dbg_printf("blcodgen(%p)\n",bl);

    /* Determine existing immediate values in registers by ANDing
        together the values from all the predecessors of b.
     */
    assert(bl.Bregcon.immed.mval == 0);
    cg.regcon.immed.mval = 0;      // assume no previous contents in registers
//    cg.regcon.cse.mval = 0;
    foreach (bpl; ListRange(bl.Bpred))
    {
        block* bp = list_block(bpl);

        if (bpl == bl.Bpred)
        {   cg.regcon.immed = bp.Bregcon.immed;
            cg.regcon.params = bp.Bregcon.params;
//          cg.regcon.cse = bp.Bregcon.cse;
        }
        else
        {
            int i;

            cg.regcon.params &= bp.Bregcon.params;
            if ((cg.regcon.immed.mval &= bp.Bregcon.immed.mval) != 0)
                // Actual values must match, too
                for (i = 0; i < REGMAX; i++)
                {
                    if (cg.regcon.immed.value[i] != bp.Bregcon.immed.value[i])
                        cg.regcon.immed.mval &= ~mask(i);
                }
        }
    }
    cg.regcon.cse.mops &= cg.regcon.cse.mval;

    // Set cg.regcon.mvar according to what variables are in registers for this block
    CodeBuilder cdb; cdb.ctor();
    cg.regcon.mvar = 0;
    cg.regcon.mpvar = 0;
    cg.regcon.indexregs = 1;
    int anyspill = 0;
    FL* sflsave = null;
    if (config.flags4 & CFG4optimized)
    {
        CodeBuilder cdbload; cdbload.ctor();
        CodeBuilder cdbstore; cdbstore.ctor();

        sflsave = cast(FL*) alloca(globsym.length * FL.sizeof);
        foreach (i, s; globsym[])
        {
            sflsave[i] = s.Sfl;
            if (regParamInPreg(*s) &&
                cg.regcon.params & s.Spregm() &&
                vec_testbit(cg.dfoidx,s.Srange))
            {
//                cg.regcon.used |= s.Spregm();
            }

            if (s.Sfl == FL.reg)
            {
                if (vec_testbit(cg.dfoidx,s.Srange))
                {
                    cg.regcon.mvar |= s.Sregm;
                    if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
                        cg.regcon.mpvar |= s.Sregm;
                }
            }
            else if (s.Sflags & SFLspill)
            {
                if (vec_testbit(cg.dfoidx,s.Srange))
                {
                    anyspill = cast(int)(i + 1);
                    cgreg_spillreg_prolog(bl,s,cdbstore,cdbload);
                    if (vec_testbit(cg.dfoidx,s.Slvreg))
                    {
                        s.Sfl = FL.reg;
                        cg.regcon.mvar |= s.Sregm;
                        cg.regcon.cse.mval &= ~s.Sregm;
                        cg.regcon.immed.mval &= ~s.Sregm;
                        cg.regcon.params &= ~s.Sregm;
                        if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
                            cg.regcon.mpvar |= s.Sregm;
                    }
                }
            }
        }
        if ((cg.regcon.cse.mops & cg.regcon.cse.mval) != cg.regcon.cse.mops)
        {
            cse_save(cdb,cg.regcon.cse.mops & ~cg.regcon.cse.mval);
        }
        cdb.append(cdbstore);
        cdb.append(cdbload);
        cg.mfuncreg &= ~cg.regcon.mvar;               // use these registers
        cg.regcon.used |= cg.regcon.mvar;
        assert(!(cg.regcon.used & mPSW));

        // Determine if we have more than 1 uncommitted index register
        cg.regcon.indexregs = IDXREGS & ~cg.regcon.mvar;
        cg.regcon.indexregs &= cg.regcon.indexregs - 1;
    }

    /* This doesn't work when calling the BC._finally function,
     * as it is one block calling another.
     */
    //cg.regsave.idx = 0;

    cg.reflocal = 0;
    int refparamsave = cg.refparam;
    cg.refparam = 0;
    assert((cg.regcon.cse.mops & cg.regcon.cse.mval) == cg.regcon.cse.mops);

    outblkexitcode(cdb, bl, anyspill, sflsave, &cg.retsym, mfuncregsave);
    bl.Bcode = cdb.finish();

    for (int i = 0; i < anyspill; i++)
    {
        Symbol* s = globsym[i];
        s.Sfl = sflsave[i];    // undo block register assignments
    }

    if (cg.reflocal)
        bl.Bflags |= BFL.reflocal;
    if (cg.refparam)
        bl.Bflags |= BFL.refparam;
    cg.refparam |= refparamsave;
    bl.Bregcon.immed = cg.regcon.immed;
    bl.Bregcon.cse = cg.regcon.cse;
    bl.Bregcon.used = cg.regcon.used;
    assert(!(bl.Bregcon.used & mPSW));
    bl.Bregcon.params = cg.regcon.params;

    debug
    debugw && printf("code gen complete\n");
}

/******************************
 * Given a register mask, find and return the number
 * of the first register that fits.
 */
reg_t findreg(regm_t regm)
{
    return findreg(regm, __LINE__, __FILE__);
}

reg_t findreg(regm_t regm, int line, const(char)* file)
{
    debug
    regm_t regmsave = regm;

    reg_t i = 0;
    while (1)
    {
        if (!(regm & 0xF))
        {
            regm >>= 4;
            i += 4;
            if (!regm)
                break;
        }
        if (regm & 1)
            return i;
        regm >>= 1;
        i++;
    }

    debug
    printf("findreg(%s, line=%d, file='%s', function = '%s')\n",regm_str(regmsave),line,file,funcsym_p.Sident.ptr);
    debug fflush(stdout);

//    *(char*)0=0;
    assert(0);
}

/***************
 * Free element (but not its leaves! (assume they are already freed))
 * Don't decrement Ecount! This is so we can detect if the common subexp
 * has already been evaluated.
 * If common subexpression is not required anymore, eliminate
 * references to it.
 */

@trusted
void freenode(elem* e)
{
    elem_debug(e);
    //dbg_printf("freenode(%p) : comsub = %d, count = %d\n",e,e.Ecomsub,e.Ecount);
    if (e.Ecomsub--) return;             /* usage count                  */
    if (e.Ecount)                        /* if it was a CSE              */
    {
        for (size_t i = 0; i < cgstate.regcon.cse.value.length; i++)
        {
            if (cgstate.regcon.cse.value[i] == e)       /* if a register is holding it  */
            {
                cgstate.regcon.cse.mval &= ~mask(cast(uint)i);
                cgstate.regcon.cse.mops &= ~mask(cast(uint)i);    /* free masks                   */
            }
        }
        CSE.remove(e);
    }
}

/*********************************
 * Reset Ecomsub for all elem nodes, i.e. reverse the effects of freenode().
 */

@trusted
private void resetEcomsub(elem* e)
{
    while (1)
    {
        elem_debug(e);
        e.Ecomsub = e.Ecount;
        const op = e.Eoper;
        if (!OTleaf(op))
        {
            if (OTbinary(op))
                resetEcomsub(e.E2);
            e = e.E1;
        }
        else
            break;
    }
}

/*********************************
 * Determine if elem e is a register variable.
 * Params:
 *      e = a register variable
 *      pregm = set to mask of registers that make up the variable otherwise not changed
 *      reg = the least significant register in pregm, otherwise not changed
 * Returns:
 *      true if register variable
 */

@trusted
bool isregvar(elem* e, ref regm_t pregm, ref reg_t preg)
{
    regm_t regm;
    reg_t reg;

    elem_debug(e);
    if (e.Eoper == OPvar || e.Eoper == OPrelconst)
    {
        Symbol* s = e.Vsym;
        switch (s.Sfl)
        {
            case FL.reg:
                if (s.Sclass == SC.parameter)
                {   cgstate.refparam = true;
                    cgstate.reflocal = true;
                }
                reg = e.Voffset == REGSIZE ? s.Sregmsw : s.Sreglsw;
                regm = s.Sregm;
                //assert(tyreg(s.ty()));
static if (0)
{
                // Let's just see if there is a CSE in a reg we can use
                // instead. This helps avoid AGI's.
                if (e.Ecount && e.Ecount != e.Ecomsub)
                {
                    foreach (i; 0 .. arraysize(regcon.cse.value))
                    {
                        if (regcon.cse.value[i] == e)
                        {   reg = i;
                            break;
                        }
                    }
                }
}
                assert(regm & cgstate.regcon.mvar && !(regm & ~cgstate.regcon.mvar));
                preg = reg;
                pregm = regm;
                return true;

            case FL.pseudo:
                uint u = s.Sreglsw;
                regm_t m = mask(u);
                if (m & ALLREGS && (u & ~3) != 4) // if not BP,SP,EBP,ESP,or ?H
                {
                    preg = u & 7;
                    pregm = m;
                    return true;
                }
                break;

            default:
                break;
        }
    }
    return false;
}

/*********************************
 * Allocate some registers.
 * Input:
 *      outretregs         Mask of registers to make selection from.
 *      tym             Mask of type we will store in registers.
 * Output:
 *      outretregs       Mask of allocated registers.
 *      msavereg, mfuncreg       retregs bits are cleared.
 *      regcon.cse.mval,regcon.cse.mops updated
 * Returns:
 *      Register number of first allocated register
 */
reg_t allocreg(ref CodeBuilder cdb,ref regm_t outretregs,tym_t tym){
    return allocreg(cdb, outretregs, tym, __LINE__, __FILE__);
}

@trusted
reg_t allocreg(ref CodeBuilder cdb,ref regm_t outretregs,tym_t tym ,int line,const(char)* file)
{
        reg_t reg;

static if (0)
{
        if (cgstate.pass == BackendPass.final_)
        {
            printf("allocreg %s,%d: cgstate.regcon.mvar %s regcon.cse.mval %s msavereg %s outretregs %s tym %s\n",
                file,line,regm_str(cgstate.regcon.mvar),regm_str(cgstate.regcon.cse.mval),
                regm_str(cgstate.msavereg),regm_str(outretregs),tym_str(tym));
        }
}
        tym = tybasic(tym);
        uint size = _tysize[tym];
        outretregs &= mES | cgstate.allregs | XMMREGS | INSTR.FLOATREGS;
        regm_t retregs = outretregs;
        regm_t[] lastRetregs = cgstate.lastRetregs[];

        debug if (retregs == 0)
            printf("allocreg: file %s(%d)\n", file, line);

        if ((retregs & cgstate.regcon.mvar) == retregs) // if exactly in reg vars
        {
            reg_t outreg;
            if (size <= REGSIZE || (retregs & XMMREGS) || (retregs & INSTR.FLOATREGS))
            {
                outreg = findreg(retregs);
                assert(retregs == mask(outreg)); /* no more bits are set */
            }
            else if (size <= 2 * REGSIZE)
            {
                outreg = findregmsw(retregs);
                assert(retregs & mLSW);
            }
            else
                assert(0);
            getregs(cdb,retregs);
            return outreg;
        }
        int count = 0;
L1:
        //printf("L1: allregs = %s, outretregs = %s\n", regm_str(cgstate.allregs), regm_str(outretregs));
        assert(++count < 20);           /* fail instead of hanging if blocked */
        assert(retregs);
        reg_t msreg = NOREG, lsreg = NOREG;  /* no value assigned yet        */
L3:
        //printf("L2: allregs = %s, outretregs = %s\n", regm_str(cgstate.allregs), regm_str(outretregs));
        regm_t r = retregs & ~(cgstate.msavereg | cgstate.regcon.cse.mval | cgstate.regcon.params);
        if (!r)
        {
            r = retregs & ~(cgstate.msavereg | cgstate.regcon.cse.mval);
            if (!r)
            {
                r = retregs & ~(cgstate.msavereg | cgstate.regcon.cse.mops);
                if (!r)
                {   r = retregs & ~cgstate.msavereg;
                    if (!r)
                        r = retregs;
                }
            }
        }

        if (size <= REGSIZE || retregs & XMMREGS)
        {
            if (r & ~mBP)
                r &= ~mBP;

            // If only one index register, prefer to not use LSW registers
            if (!cgstate.regcon.indexregs && r & ~mLSW)
                r &= ~mLSW;

            if (cgstate.pass == BackendPass.final_ && r & ~lastRetregs[0] && !I16)
            {   // Try not to always allocate the same register,
                // to schedule better

                foreach (lastr; lastRetregs)
                {
                    if (regm_t rx = r & ~lastr)
                        r = rx;
                    else
                        break;
                }
                if (r & ~cgstate.mfuncreg)
                    r &= ~cgstate.mfuncreg;
            }
            reg = findreg(r);
            retregs = mask(reg);
        }
        else if (size <= 2 * REGSIZE)
        {
            /* Select pair with both regs free. Failing */
            /* that, select pair with one reg free.             */

            if (r & mBP)
            {
                retregs &= ~mBP;
                goto L3;
            }

            if (r & mMSW)
            {
                if (r & mDX)
                    msreg = DX;                 /* prefer to use DX over CX */
                else
                    msreg = findregmsw(r);
                r &= mLSW;                      /* see if there's an LSW also */
                if (r)
                    lsreg = findreg(r);
                else if (lsreg == NOREG)   /* if don't have LSW yet */
                {
                    retregs &= mLSW;
                    goto L3;
                }
            }
            else
            {
                if (I64 && !(r & mLSW))
                {
                    retregs = outretregs & (mMSW | mLSW);
                    assert(retregs);
                    goto L1;
                }
                lsreg = findreglsw(r);
                if (msreg == NOREG)
                {
                    retregs &= mMSW;
                    assert(retregs);
                    goto L3;
                }
            }
            reg = (msreg == ES) ? lsreg : msreg;
            retregs = mask(msreg) | mask(lsreg);
        }
        else if (I16 && (tym == TYdouble || tym == TYdouble_alias))
        {
            debug
            if (retregs != DOUBLEREGS)
                printf("retregs = %s, outretregs = %s\n", regm_str(retregs), regm_str(outretregs));

            assert(retregs == DOUBLEREGS);
            reg = AX;
        }
        else
        {
            debug
            {
                printf("%s\nallocreg: fil %s lin %d, regcon.mvar %s msavereg %s outretregs %s, reg %d, tym x%x\n",
                    tym_str(tym),file,line,regm_str(cgstate.regcon.mvar),regm_str(cgstate.msavereg),regm_str(outretregs),reg,tym);
            }
            assert(0);
        }
        if (retregs & cgstate.regcon.mvar)              // if conflict with reg vars
        {
            if (!(size > REGSIZE && outretregs == (mAX | mDX)))
            {
                retregs = (outretregs &= ~(retregs & cgstate.regcon.mvar));
                goto L1;                // try other registers
            }
        }
        outretregs = retregs;

        //printf("Allocating %s\n",regm_str(retregs));
        // Ripple to end of array
        for (size_t i = lastRetregs.length; i > 1; --i)
        {
            lastRetregs[i - 1] = lastRetregs[i - 2];
        }
        lastRetregs[0] = retregs; // and set new beginning of array
        getregs(cdb, retregs);
        return reg;
}


/*****************************************
 * Allocate a scratch register.
 * Params:
 *      cdb = where to write any generated code to
 *      regm = mask of registers to pick one from
 * Returns:
 *      selected register
 */
reg_t allocScratchReg(ref CodeBuilder cdb, regm_t regm)
{
    return allocreg(cdb, regm, TYoffset);
}


/******************************
 * Determine registers that should be destroyed upon arrival
 * to code entry point for exception handling.
 */
@trusted
regm_t lpadregs()
{
    regm_t used;
    if (config.ehmethod == EHmethod.EH_DWARF)
        used = cgstate.allregs & ~cgstate.mfuncreg;
    else
        used = (I32 | I64) ? cgstate.allregs : (ALLREGS | mES);
    //printf("lpadregs(): used=%s, allregs=%s, mfuncreg=%s\n", regm_str(used), regm_str(cgstate.llregs), regm_str(mfuncreg));
    return used;
}


/*************************
 * Mark registers as used.
 */

@trusted
void useregs(regm_t regm)
{
    //printf("useregs(x%llx) %s\n", regm, regm_str(regm));
    assert(REGMAX < 64);
    regm &= (1UL << REGMAX) - 1;
    assert(!(regm & mPSW));
    cgstate.mfuncreg &= ~regm;
    cgstate.regcon.used |= regm;                // registers used in this block
    cgstate.regcon.params &= ~regm;
    if (regm & cgstate.regcon.mpvar)            // if modified a fastpar register variable
        cgstate.regcon.params = 0;              // toss them all out
}

/*************************
 * We are going to use the registers in mask r.
 * Generate any code necessary to save any regs.
 */

@trusted
void getregs(ref CodeBuilder cdb, regm_t r)
{
    //printf("getregs(x%x) %s\n", r, regm_str(r));
    regm_t ms = r & cgstate.regcon.cse.mops;           // mask of common subs we must save
    useregs(r);
    cgstate.regcon.cse.mval &= ~r;
    cgstate.msavereg &= ~r;                     // regs that are destroyed
    cgstate.regcon.immed.mval &= ~r;
    if (ms)
        cse_save(cdb, ms);
}

/*************************
 * We are going to use the registers in mask r.
 * Same as getregs(), but assert if code is needed to be generated.
 */
@trusted
void getregsNoSave(regm_t r)
{
    //printf("getregsNoSave(x%x) %s\n", r, regm_str(r));
    assert(!(r & cgstate.regcon.cse.mops));            // mask of common subs we must save
    useregs(r);
    cgstate.regcon.cse.mval &= ~r;
    cgstate.msavereg &= ~r;                     // regs that are destroyed
    cgstate.regcon.immed.mval &= ~r;
}

/*****************************************
 * Copy registers in cse.mops into memory.
 */

@trusted
private void cse_save(ref CodeBuilder cdb, regm_t ms)
{
    assert((ms & cgstate.regcon.cse.mops) == ms);
    cgstate.regcon.cse.mops &= ~ms;

    /* Skip CSEs that are already saved */
    for (regm_t regm = 1; regm < mask(NUMREGS); regm <<= 1)
    {
        if (regm & ms)
        {
            const e = cgstate.regcon.cse.value[findreg(regm)];
            const sz = tysize(e.Ety);
            foreach (const ref cse; CSE.filter(e))
            {
                if (sz <= REGSIZE ||
                    sz <= 2 * REGSIZE &&
                        (regm & mMSW && cse.regm & mMSW ||
                         regm & mLSW && cse.regm & mLSW) ||
                    sz == 4 * REGSIZE && regm == cse.regm
                   )
                {
                    ms &= ~regm;
                    if (!ms)
                        return;
                    break;
                }
            }
        }
    }

    while (ms)
    {
        auto cse = CSE.add();
        reg_t reg = findreg(ms);          /* the register to save         */
        cse.e = cgstate.regcon.cse.value[reg];
        cse.regm = mask(reg);

        ms &= ~mask(reg);           /* turn off reg bit in ms       */

        // If we can simply reload the CSE, we don't need to save it
        if (cse_simple(&cse.csimple, cse.e))
            cse.flags |= CSEsimple;
        else
        {
            CSE.updateSizeAndAlign(cse.e);
            gen_storecse(cdb, cse.e.Ety, reg, cse.slot);
            cgstate.reflocal = true;
        }
    }
}

/******************************************
 * Getregs without marking immediate register values as gone.
 */

@trusted
void getregs_imm(ref CodeBuilder cdb, regm_t r)
{
    regm_t save = cgstate.regcon.immed.mval;
    getregs(cdb,r);
    cgstate.regcon.immed.mval = save;
}

/******************************************
 * Flush all CSE's out of registers and into memory.
 * Input:
 *      do87    !=0 means save 87 registers too
 */

@trusted
void cse_flush(ref CodeBuilder cdb, int do87)
{
    //dbg_printf("cse_flush()\n");
    cse_save(cdb,cgstate.regcon.cse.mops);      // save any CSEs to memory
    if (do87)
        save87(cdb);    // save any 8087 temporaries
}

/*************************
 * Common subexpressions exist in registers. Note this in regcon.cse.mval.
 * Input:
 *      e       the subexpression
 *      regm    mask of registers holding it
 *      opsflag if true, then regcon.cse.mops gets set too
 * Returns:
 *      false   not saved as a CSE
 *      true    saved as a CSE
 */

@trusted
bool cssave(elem* e, regm_t regm, bool opsflag)
{
    bool result = false;

    /*if (e.Ecount && e.Ecount == e.Ecomsub)*/
    if (e.Ecount && e.Ecomsub)
    {
        if (!opsflag && cgstate.pass != BackendPass.final_ && (I32 || I64))
            return false;

        //printf("cssave(e = %p, regm = %s, opsflag = x%x)\n", e, regm_str(regm), opsflag);
        regm &= mBP | ALLREGS | mES | XMMREGS;    /* just to be sure              */

/+
        /* Do not register CSEs if they are register variables and      */
        /* are not operator nodes. This forces the register allocation  */
        /* to go through allocreg(), which will prevent using register  */
        /* variables for scratch.                                       */
        if (opsflag || !(regm & regcon.mvar))
+/
            for (uint i = 0; regm; i++)
            {
                regm_t mi = mask(i);
                if (regm & mi)
                {
                    regm &= ~mi;

                    // If we don't need this CSE, and the register already
                    // holds a CSE that we do need, don't mark the new one
                    if (cgstate.regcon.cse.mval & mi && cgstate.regcon.cse.value[i] != e &&
                        !opsflag && cgstate.regcon.cse.mops & mi)
                        continue;

                    cgstate.regcon.cse.mval |= mi;
                    if (opsflag)
                        cgstate.regcon.cse.mops |= mi;
                    //printf("cssave set: regcon.cse.value[%s] = %p\n",regstring[i],e);
                    cgstate.regcon.cse.value[i] = e;
                    result = true;
                }
            }
    }
    return result;
}

/*************************************
 * Determine if a computation should be done into a register.
 */

@trusted
bool evalinregister(elem* e)
{
    if (config.exe == EX_WIN64 && e.Eoper == OPrelconst)
        return true;

    if (e.Ecount == 0)             /* elem is not a CSE, therefore */
                                    /* we don't need to evaluate it */
                                    /* in a register                */
        return false;
    if (!OTleaf(e.Eoper))          /* operators are always in register */
        return true;

    // Need to rethink this code if float or double can be CSE'd
    uint sz = tysize(e.Ety);
    if (e.Ecount == e.Ecomsub)    /* elem is a CSE that needs     */
                                    /* to be generated              */
    {
        if ((I32 || I64) &&
            //cgstate.pass == BackendPass.final_ && // bug 8987
            sz <= REGSIZE)
        {
            // Do it only if at least 2 registers are available
            regm_t m = cgstate.allregs & ~cgstate.regcon.mvar;
            if (sz == 1)
                m &= BYTEREGS;
            if (m & (m - 1))        // if more than one register
            {   // Need to be at least 3 registers available, as
                // addressing modes can use up 2.
                while (!(m & 1))
                    m >>= 1;
                m >>= 1;
                if (m & (m - 1))
                    return true;
            }
        }
        return false;
    }

    /* Elem is now a CSE that might have been generated. If so, and */
    /* it's in a register already, the computation should be done   */
    /* using that register.                                         */
    regm_t emask = 0;
    for (uint i = 0; i < cgstate.regcon.cse.value.length; i++)
        if (cgstate.regcon.cse.value[i] == e)
            emask |= mask(i);
    emask &= cgstate.regcon.cse.mval;       // mask of available CSEs
    if (sz <= REGSIZE)
        return emask != 0;      /* the CSE is in a register     */
    if (sz <= 2 * REGSIZE)
        return (emask & mMSW) && (emask & mLSW);
    return true;                    /* cop-out for now              */
}

/*******************************************************
 * Return mask of scratch registers.
 */

@trusted
regm_t getscratch()
{
    regm_t scratch = 0;
    if (cgstate.pass == BackendPass.final_)
    {
        scratch = cgstate.allregs & ~(cgstate.regcon.mvar | cgstate.regcon.mpvar | cgstate.regcon.cse.mval |
                  cgstate.regcon.immed.mval | cgstate.regcon.params | cgstate.mfuncreg);
    }
    return scratch;
}

/******************************
 * Evaluate an elem that is a common subexp that has been encountered
 * before.
 * Look first to see if it is already in a register.
 * Params:
 *      cdb = sink for generated code
 *      e = the elem
 *      pretregs = input is mask of registers, output is result register
 */

@trusted
private void comsub(ref CodeBuilder cdb,elem* e, ref regm_t pretregs)
{
    tym_t tym;
    regm_t regm,emask;
    reg_t reg;
    uint byte_,sz;

    //printf("comsub(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    elem_debug(e);

    debug
    {
        if (e.Ecomsub > e.Ecount)
            elem_print(e);
    }

    assert(e.Ecomsub <= e.Ecount);

    if (pretregs == 0)        // no possible side effects anyway
    {
        return;
    }

    /* First construct a mask, emask, of all the registers that
     * have the right contents.
     */
    emask = 0;
    for (uint i = 0; i < cgstate.regcon.cse.value.length; i++)
    {
        //dbg_printf("regcon.cse.value[%d] = %p\n",i,cgstate.regcon.cse.value[i]);
        if (cgstate.regcon.cse.value[i] == e)   // if contents are right
                emask |= mask(i);       // turn on bit for reg
    }
    emask &= cgstate.regcon.cse.mval;                     // make sure all bits are valid

    if (emask & XMMREGS && pretregs == mPSW)
        { }
    else if (tyxmmreg(e.Ety) && config.fpxmmregs)
    {
        if (pretregs & (mST0 | mST01))
        {
            regm_t retregs = pretregs & mST0 ? XMMREGS : mXMM0 | mXMM1;
            comsub(cdb, e, retregs);
            fixresult(cdb,e,retregs,pretregs);
            return;
        }
    }
    else if (tyfloating(e.Ety) && config.inline8087)
    {
        comsub87(cdb,e,pretregs);
        return;
    }


    /* create mask of CSEs */
    regm_t csemask = CSE.mask(e);
    csemask &= ~emask;            // stuff already in registers

    debug if (debugw)
    {
        printf("comsub(e=%p): pretregs=%s, emask=%s, csemask=%s, cgstate.regcon.cse.mval=%s, cgstate.regcon.mvar=%s\n",
                e,regm_str(pretregs),regm_str(emask),regm_str(csemask),
                regm_str(cgstate.regcon.cse.mval),regm_str(cgstate.regcon.mvar));
        if (cgstate.regcon.cse.mval & 1)
            elem_print(cgstate.regcon.cse.value[0]);
    }

    tym = tybasic(e.Ety);
    sz = _tysize[tym];
    byte_ = sz == 1;

    if (sz <= REGSIZE || (tyxmmreg(tym) && config.fpxmmregs)) // if data will fit in one register
    {
        /* First see if it is already in a correct register     */

        regm = emask & pretregs;
        if (regm == 0)
            regm = emask;               /* try any other register       */
        if (regm)                       /* if it's in a register        */
        {
            if (!OTleaf(e.Eoper) || !(regm & cgstate.regcon.mvar) || (pretregs & cgstate.regcon.mvar) == pretregs)
            {
                regm = mask(findreg(regm));
                fixresult(cdb,e,regm,pretregs);
                return;
            }
        }

        if (OTleaf(e.Eoper))                  /* if not op or func            */
            goto reload;                      /* reload data                  */

        foreach (ref cse; CSE.filter(e))
        {
            regm_t retregs;

            if (cse.flags & CSEsimple)
            {
                retregs = pretregs;
                if (byte_ && !(retregs & BYTEREGS))
                    retregs = BYTEREGS;
                else if (!(retregs & cgstate.allregs))
                    retregs = cgstate.allregs;
                reg = allocreg(cdb,retregs,tym);
                code* cr = &cse.csimple;
                cr.setReg(reg);
                if (I64 && reg >= 4 && tysize(cse.e.Ety) == 1)
                    cr.Irex |= REX;
                cdb.gen(cr);
                goto L10;
            }
            else
            {
                cgstate.reflocal = true;
                cse.flags |= CSEload;
                if (pretregs == mPSW)  // if result in CCs only
                {
                    if (config.fpxmmregs && (tyxmmreg(cse.e.Ety) || tyvector(cse.e.Ety)))
                    {
                        retregs = XMMREGS;
                        reg = allocreg(cdb,retregs,tym);
                        gen_loadcse(cdb, cse.e.Ety, reg, cse.slot);
                        cgstate.regcon.cse.mval |= mask(reg); // cs is in a reg
                        cgstate.regcon.cse.value[reg] = e;
                        fixresult(cdb,e,retregs,pretregs);
                    }
                    else
                    {
                        // CMP cs[BP],0
                        gen_testcse(cdb, cse.e.Ety, sz, cse.slot);
                    }
                }
                else
                {
                    retregs = pretregs;
                    if (byte_ && !(retregs & BYTEREGS))
                        retregs = BYTEREGS;
                    reg = allocreg(cdb,retregs,tym);
                    gen_loadcse(cdb, cse.e.Ety, reg, cse.slot);
                L10:
                    cgstate.regcon.cse.mval |= mask(reg); // cs is in a reg
                    cgstate.regcon.cse.value[reg] = e;
                    fixresult(cdb,e,retregs,pretregs);
                }
            }
            return;
        }

        debug
        {
            printf("couldn't find cse e = %p, pass = %d\n",e,cgstate.pass);
            elem_print(e);
        }
        assert(0);                      /* should have found it         */
    }
    else                                  /* reg pair is req'd            */
    if (sz <= 2 * REGSIZE)
    {
        reg_t msreg,lsreg;

        /* see if we have both  */
        if (!((emask | csemask) & mMSW && (emask | csemask) & (mLSW | mBP)))
        {                               /* we don't have both           */
            debug if (!OTleaf(e.Eoper))
            {
                printf("e = %p, op = x%x, emask = %s, csemask = %s\n",
                    e,e.Eoper,regm_str(emask),regm_str(csemask));
                //printf("mMSW = x%x, mLSW = x%x\n", mMSW, mLSW);
                elem_print(e);
            }

            assert(OTleaf(e.Eoper));        /* must have both for operators */
            goto reload;
        }

        /* Look for right vals in any regs      */
        regm = pretregs & mMSW;
        if (emask & regm)
            msreg = findreg(emask & regm);
        else if (emask & mMSW)
            msreg = findregmsw(emask);
        else                    /* reload from cse array        */
        {
            if (!regm)
                regm = mMSW & ALLREGS;
            msreg = allocreg(cdb,regm,TYint);
            loadcse(cdb,e,msreg,mMSW);
        }

        regm = pretregs & (mLSW | mBP);
        if (emask & regm)
            lsreg = findreg(emask & regm);
        else if (emask & (mLSW | mBP))
            lsreg = findreglsw(emask);
        else
        {
            if (!regm)
                regm = mLSW;
            lsreg = allocreg(cdb,regm,TYint);
            loadcse(cdb,e,lsreg,mLSW | mBP);
        }

        regm = mask(msreg) | mask(lsreg);       /* mask of result       */
        fixresult(cdb,e,regm,pretregs);
        return;
    }
    else if (tym == TYdouble || tym == TYdouble_alias)    // double
    {
        assert(I16);
        if (((csemask | emask) & DOUBLEREGS_16) == DOUBLEREGS_16)
        {
            immutable reg_t[4] dblreg = [ BX,DX,NOREG,CX ];
            for (reg = 0; reg != NOREG; reg = dblreg[reg])
            {
                assert(cast(int) reg >= 0 && reg <= 7);
                if (mask(reg) & csemask)
                    loadcse(cdb,e,reg,mask(reg));
            }
            regm = DOUBLEREGS_16;
            fixresult(cdb,e,regm,pretregs);
            return;
        }
        if (OTleaf(e.Eoper)) goto reload;

        debug
        printf("e = %p, csemask = %s, emask = %s\n",e,regm_str(csemask),regm_str(emask));

        assert(0);
    }
    else
    {
        debug
        printf("e = %p, tym = x%x\n",e,tym);

        assert(0);
    }

reload:                                 /* reload result from memory    */
    switch (e.Eoper)
    {
        case OPrelconst:
            cdrelconst(cgstate, cdb,e,pretregs);
            break;

        case OPgot:
            if (config.exe & EX_posix)
            {
                cdgot(cgstate, cdb,e,pretregs);
                break;
            }
            goto default;

        default:
            if (pretregs == mPSW &&
                config.fpxmmregs &&
                (tyxmmreg(tym) || tysimd(tym)))
            {
                regm_t retregs = XMMREGS | mPSW;
                loaddata(cdb,e,retregs);
                cssave(e,retregs,false);
                return;
            }
            loaddata(cdb,e,pretregs);
            break;
    }
    cssave(e,pretregs,false);
}


/*****************************
 * Load reg from cse save area on stack.
 */

@trusted
private void loadcse(ref CodeBuilder cdb,elem* e,reg_t reg,regm_t regm)
{
    foreach (ref cse; CSE.filter(e))
    {
        //printf("CSE[%d] = %p, regm = %s\n", i, cse.e, regm_str(cse.regm));
        if (cse.regm & regm)
        {
            cgstate.reflocal = true;
            cse.flags |= CSEload;    /* it was loaded        */
            cgstate.regcon.cse.value[reg] = e;
            cgstate.regcon.cse.mval |= mask(reg);
            getregs(cdb,mask(reg));
            gen_loadcse(cdb, cse.e.Ety, reg, cse.slot);
            return;
        }
    }
    debug
    {
        printf("loadcse(e = %p, reg = %d, regm = %s)\n",e,reg,regm_str(regm));
        elem_print(e);
    }
    assert(0);
}


void callcdxxx(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs, OPER op)
{
    (*cdxxx[op])(cg, cdb, e, pretregs);
}

// jump table
private immutable nothrow void function (ref CGstate, ref CodeBuilder,elem *,ref regm_t)[OPMAX] cdxxx =
[
    OPunde:    &cderr,
    OPadd:     &cdorth,
    OPmul:     &cdmul,
    OPand:     &cdorth,
    OPmin:     &cdorth,
    OPnot:     &cdnot,
    OPcom:     &cdcom,
    OPcond:    &cdcond,
    OPcomma:   &cdcomma,
    OPremquo:  &cddiv,
    OPdiv:     &cddiv,
    OPmod:     &cddiv,
    OPxor:     &cdorth,
    OPstring:  &cderr,
    OPrelconst: &cdrelconst,
    OPinp:     &cdport,
    OPoutp:    &cdport,
    OPasm:     &cdasm,
    OPinfo:    &cdinfo,
    OPdctor:   &cddctor,
    OPddtor:   &cdddtor,
    OPctor:    &cdctor,
    OPdtor:    &cddtor,
    OPmark:    &cdmark,
    OPvoid:    &cdvoid,
    OPhalt:    &cdhalt,
    OPnullptr: &cderr,
    OPpair:    &cdpair,
    OPrpair:   &cdpair,

    OPor:      &cdorth,
    OPoror:    &cdloglog,
    OPandand:  &cdloglog,
    OProl:     &cdshift,
    OPror:     &cdshift,
    OPshl:     &cdshift,
    OPshr:     &cdshift,
    OPashr:    &cdshift,
    OPbit:     &cderr,
    OPind:     &cdind,
    OPaddr:    &cderr,
    OPneg:     &cdneg,
    OPuadd:    &cderr,
    OPabs:     &cdabs,
    OPtoprec:  &cdtoprec,
    OPsqrt:    &cdneg,
    OPsin:     &cdneg,
    OPcos:     &cdneg,
    OPscale:   &cdscale,
    OPyl2x:    &cdscale,
    OPyl2xp1:  &cdscale,
    OPcmpxchg:     &cdcmpxchg,
    OPrint:    &cdneg,
    OPrndtol:  &cdrndtol,
    OPstrlen:  &cdstrlen,
    OPstrcpy:  &cdstrcpy,
    OPmemcpy:  &cdmemcpy,
    OPmemset:  &cdmemset,
    OPstrcat:  &cderr,
    OPstrcmp:  &cdstrcmp,
    OPmemcmp:  &cdmemcmp,
    OPsetjmp:  &dmd.backend.x86.nteh.cdsetjmp,
    OPnegass:  &cdaddass,
    OPpreinc:  &cderr,
    OPpredec:  &cderr,
    OPstreq:   &cdstreq,
    OPpostinc: &cdpost,
    OPpostdec: &cdpost,
    OPeq:      &cdeq,
    OPaddass:  &cdaddass,
    OPminass:  &cdaddass,
    OPmulass:  &cdmulass,
    OPdivass:  &cddivass,
    OPmodass:  &cddivass,
    OPshrass:  &cdshass,
    OPashrass: &cdshass,
    OPshlass:  &cdshass,
    OPandass:  &cdaddass,
    OPxorass:  &cdaddass,
    OPorass:   &cdaddass,

    OPle:      &cdcmp,
    OPgt:      &cdcmp,
    OPlt:      &cdcmp,
    OPge:      &cdcmp,
    OPeqeq:    &cdcmp,
    OPne:      &cdcmp,

    OPunord:   &cdcmp,
    OPlg:      &cdcmp,
    OPleg:     &cdcmp,
    OPule:     &cdcmp,
    OPul:      &cdcmp,
    OPuge:     &cdcmp,
    OPug:      &cdcmp,
    OPue:      &cdcmp,
    OPngt:     &cdcmp,
    OPnge:     &cdcmp,
    OPnlt:     &cdcmp,
    OPnle:     &cdcmp,
    OPord:     &cdcmp,
    OPnlg:     &cdcmp,
    OPnleg:    &cdcmp,
    OPnule:    &cdcmp,
    OPnul:     &cdcmp,
    OPnuge:    &cdcmp,
    OPnug:     &cdcmp,
    OPnue:     &cdcmp,

    OPvp_fp:   &cdcnvt,
    OPcvp_fp:  &cdcnvt,
    OPoffset:  &cdlngsht,
    OPnp_fp:   &cdshtlng,
    OPnp_f16p: &cdfar16,
    OPf16p_np: &cdfar16,

    OPs16_32:  &cdshtlng,
    OPu16_32:  &cdshtlng,
    OPd_s32:   &cdcnvt,
    OPb_8:     &cdcnvt,
    OPs32_d:   &cdcnvt,
    OPd_s16:   &cdcnvt,
    OPs16_d:   &cdcnvt,
    OPd_u16:   &cdcnvt,
    OPu16_d:   &cdcnvt,
    OPd_u32:   &cdcnvt,
    OPu32_d:   &cdcnvt,
    OP32_16:   &cdlngsht,
    OPd_f:     &cdcnvt,
    OPf_d:     &cdcnvt,
    OPd_ld:    &cdcnvt,
    OPld_d:    &cdcnvt,
    OPc_r:     &cdconvt87,
    OPc_i:     &cdconvt87,
    OPu8_16:   &cdbyteint,
    OPs8_16:   &cdbyteint,
    OP16_8:    &cdlngsht,
    OPu32_64:  &cdshtlng,
    OPs32_64:  &cdshtlng,
    OP64_32:   &cdlngsht,
    OPu64_128: &cdshtlng,
    OPs64_128: &cdshtlng,
    OP128_64:  &cdlngsht,
    OPmsw:     &cdmsw,

    OPd_s64:   &cdcnvt,
    OPs64_d:   &cdcnvt,
    OPd_u64:   &cdcnvt,
    OPu64_d:   &cdcnvt,
    OPld_u64:  &cdcnvt,
    OPparam:   &cderr,
    OPsizeof:  &cderr,
    OParrow:   &cderr,
    OParrowstar: &cderr,
    OPcolon:   &cderr,
    OPcolon2:  &cderr,
    OPbool:    &cdnot,
    OPcall:    &cdfunc,
    OPucall:   &cdfunc,
    OPcallns:  &cdfunc,
    OPucallns: &cdfunc,
    OPstrpar:  &cderr,
    OPstrctor: &cderr,
    OPstrthis: &cdstrthis,
    OPconst:   &cderr,
    OPvar:     &cderr,
    OPnew:     &cderr,
    OPanew:    &cderr,
    OPdelete:  &cderr,
    OPadelete: &cderr,
    OPbrack:   &cderr,
    OPframeptr: &cdframeptr,
    OPgot:     &cdgot,

    OPbsf:     &cdbscan,
    OPbsr:     &cdbscan,
    OPbtst:    &cdbtst,
    OPbt:      &cdbt,
    OPbtc:     &cdbt,
    OPbtr:     &cdbt,
    OPbts:     &cdbt,

    OPbswap:   &cdbswap,
    OPpopcnt:  &cdpopcnt,
    OPvector:  &cdvector,
    OPvecsto:  &cdvecsto,
    OPvecfill: &cdvecfill,
    OPva_start: &cderr,
    OPprefetch: &cdprefetch,
];


/***************************
 * Generate code sequence for an elem.
 * Params:
 *      cg =            code generator global state
 *      cdb =           Code builder to write generated code to
 *      e =             Element to generate code for
 *      pretregs =      mask of possible registers to return result in
 *                      will be updated with mask of registers result is returned in
 *                      Note:   longs are in AX,BX or CX,DX or SI,DI
 *                              doubles are AX,BX,CX,DX only
 *      constflag =     1 for user of result will not modify the
 *                      registers returned in pretregs.
 *                      2 for freenode() not called.
 */
@trusted
void codelem(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs,uint constflag)
{
    Symbol* s;

    debug if (debugw)
    {
        printf("+codelem(e=%p,pretregs=%s) %s ",e,regm_str(pretregs),oper_str(e.Eoper));
        printf("msavereg=%s cg.regcon.cse.mval=%s regcon.cse.mops=%s\n",
                regm_str(cg.msavereg),regm_str(cg.regcon.cse.mval),regm_str(cg.regcon.cse.mops));
        printf("Ecount = %d, Ecomsub = %d\n", e.Ecount, e.Ecomsub);
    }

    assert(e);
    elem_debug(e);
    if ((cg.regcon.cse.mops & cg.regcon.cse.mval) != cg.regcon.cse.mops)
    {
        debug
        {
            printf("+codelem(e=%p,pretregs=%s) ", e, regm_str(pretregs));
            elem_print(e);
            printf("msavereg=%s cg.regcon.cse.mval=%s regcon.cse.mops=%s\n",
                    regm_str(cg.msavereg),regm_str(cg.regcon.cse.mval),regm_str(cg.regcon.cse.mops));
            printf("Ecount = %d, Ecomsub = %d\n", e.Ecount, e.Ecomsub);
        }
        assert(0);
    }

    if (!(constflag & 1) && pretregs & (mES | ALLREGS | mBP | XMMREGS) & ~cg.regcon.mvar)
        pretregs &= ~cg.regcon.mvar;                      /* can't use register vars */

    uint op = e.Eoper;
    if (e.Ecount && e.Ecount != e.Ecomsub)     // if common subexp
    {
        comsub(cdb,e, pretregs);
        goto L1;
    }

    if (configv.addlinenumbers && e.Esrcpos.Slinnum)
        cdb.genlinnum(e.Esrcpos);

    switch (op)
    {
        default:
            if (e.Ecount)                          /* if common subexp     */
            {
                /* if no return value       */
                if ((pretregs & (mSTACK | mES | ALLREGS | mBP | XMMREGS)) == 0)
                {
                    if (pretregs & (mST0 | mST01))
                    {
                        //printf("generate ST0 comsub for:\n");
                        //elem_print(e);

                        regm_t retregs = pretregs & mST0 ? mXMM0 : mXMM0|mXMM1;
                        (*cdxxx[op])(cg,cdb,e,retregs);
                        cssave(e,retregs,!OTleaf(op));
                        fixresult(cdb, e, retregs, pretregs);
                        goto L1;
                    }
                    if (tysize(e.Ety) == 1)
                        pretregs |= BYTEREGS;
                    else if ((tyxmmreg(e.Ety) || tysimd(e.Ety)) && config.fpxmmregs)
                        pretregs |= XMMREGS;
                    else if (tybasic(e.Ety) == TYdouble || tybasic(e.Ety) == TYdouble_alias)
                        pretregs |= DOUBLEREGS;
                    else
                        pretregs |= ALLREGS;       /* make one             */
                }

                /* BUG: For CSEs, make sure we have both an MSW             */
                /* and an LSW specified in pretregs                        */
            }
            assert(op <= OPMAX);
            (*cdxxx[op])(cg,cdb,e,pretregs);
            break;

        case OPrelconst:
            cdrelconst(cg, cdb,e,pretregs);
            break;

        case OPvar:
            if (constflag & 1 && (s = e.Vsym).Sfl == FL.reg &&
                (s.Sregm & pretregs) == s.Sregm)
            {
                if (tysize(e.Ety) <= REGSIZE && tysize(s.Stype.Tty) == 2 * REGSIZE)
                    pretregs &= mPSW | (s.Sregm & mLSW);
                else
                    pretregs &= mPSW | s.Sregm;
            }
            goto case OPconst;

        case OPconst:
            if (pretregs == 0 && (e.Ecount >= 3 || e.Ety & mTYvolatile))
            {
                switch (tybasic(e.Ety))
                {
                    case TYbool:
                    case TYchar:
                    case TYschar:
                    case TYuchar:
                        pretregs |= BYTEREGS;
                        break;

                    case TYnref:
                    case TYnptr:
                    case TYsptr:
                    case TYcptr:
                    case TYfgPtr:
                    case TYimmutPtr:
                    case TYsharePtr:
                    case TYrestrictPtr:
                        pretregs |= I16 ? IDXREGS : ALLREGS;
                        break;

                    case TYshort:
                    case TYushort:
                    case TYint:
                    case TYuint:
                    case TYlong:
                    case TYulong:
                    case TYllong:
                    case TYullong:
                    case TYcent:
                    case TYucent:
                    case TYfptr:
                    case TYhptr:
                    case TYvptr:
                        pretregs |= ALLREGS;
                        break;

                    default:
                        break;
                }
            }
            loaddata(cdb,e,pretregs);
            break;
    }
    cssave(e,pretregs,!OTleaf(op));
L1:
    if (!(constflag & 2))
        freenode(e);

    debug if (debugw)
    {
        printf("-codelem(e=%p,pretregs=%s) %s ",e,regm_str(pretregs), oper_str(op));
        printf("msavereg=%s cg.regcon.cse.mval=%s regcon.cse.mops=%s\n",
                regm_str(cg.msavereg),regm_str(cg.regcon.cse.mval),regm_str(cg.regcon.cse.mops));
    }
}

/*******************************
 * Same as codelem(), but do not destroy the registers in keepmsk.
 * Use scratch registers as much as possible, then use stack.
 * Params:
 *      cg =            code generator global state
 *      cdb =           Code builder to write generated code to
 *      e =             Element to generate code for
 *      pretregs =      mask of possible registers to return result in
 *                      will be updated with mask of registers result is returned in
 *                      Note:   longs are in AX,BX or CX,DX or SI,DI
 *                              doubles are AX,BX,CX,DX only
 *      keepmask =      mask of registers not to be changed during execution of e
 *      constflag =     true if user of result will not modify the
 *                      registers returned in pretregs.
 */
@trusted
void scodelem(ref CGstate cg, ref CodeBuilder cdb, elem* e,ref regm_t pretregs,regm_t keepmsk,bool constflag)
{
    regm_t touse;

    debug if (debugw)
        printf("+scodelem(e=%p pretregs=%s keepmsk=%s constflag=%d\n",
                e,regm_str(pretregs),regm_str(keepmsk),constflag);

    elem_debug(e);
    if (constflag)
    {
        regm_t regm;
        reg_t reg;

        if (isregvar(e, regm, reg) &&           // if e is a register variable
            (regm & pretregs) == regm &&        // in one of the right regs
            e.Voffset == 0
           )
        {
            uint sz1 = tysize(e.Ety);
            uint sz2 = tysize(e.Vsym.Stype.Tty);
            if (sz1 <= REGSIZE && sz2 > REGSIZE)
                regm &= mLSW | XMMREGS;
            fixresult(cdb,e,regm,pretregs);
            cssave(e,regm,0);
            freenode(e);

            debug if (debugw)
                printf("-scodelem(e=%p pretregs=%s keepmsk=%s constflag=%d\n",
                        e,regm_str(pretregs),regm_str(keepmsk),constflag);

            return;
        }
    }
    regm_t overlap = cg.msavereg & keepmsk;
    cg.msavereg |= keepmsk;          /* add to mask of regs to save          */
    regm_t oldregcon = cg.regcon.cse.mval;
    regm_t oldregimmed = cg.regcon.immed.mval;
    regm_t oldmfuncreg = cg.mfuncreg;       // remember old one
    if (cg.AArch64)
//        cg.mfuncreg = (XMMREGS | mask(cg.BP) | cg.allregs) & ~cg.regcon.mvar;
        cg.mfuncreg = (0xFFFF_FFFF_7FFF_FFFF) & ~cg.regcon.mvar;
    else
        cg.mfuncreg = (XMMREGS | mBP | mES | ALLREGS) & ~cg.regcon.mvar;
    uint stackpushsave = cg.stackpush;
    char calledafuncsave = cg.calledafunc;
    cg.calledafunc = 0;
    CodeBuilder cdbx; cdbx.ctor();
    codelem(cg,cdbx,e,pretregs,constflag);    // generate code for the elem

    regm_t tosave = keepmsk & ~cg.msavereg; /* registers to save                    */
    if (tosave)
    {
        cg.stackclean++;
        genstackclean(cdbx,cg.stackpush - stackpushsave,pretregs | cg.msavereg);
        cg.stackclean--;
    }

    /* Assert that no new CSEs are generated that are not reflected       */
    /* in mfuncreg.                                                       */
    debug if ((cg.mfuncreg & (cg.regcon.cse.mval & ~oldregcon)) != 0)
        printf("mfuncreg %s, cg.regcon.cse.mval %s, oldregcon %s, regcon.mvar %s\n",
                regm_str(cg.mfuncreg),regm_str(cg.regcon.cse.mval),regm_str(oldregcon),regm_str(cg.regcon.mvar));

    assert((cg.mfuncreg & (cg.regcon.cse.mval & ~oldregcon)) == 0);

    /* https://issues.dlang.org/show_bug.cgi?id=3521
     * The problem is:
     *    reg op (reg = exp)
     * where reg must be preserved (in keepregs) while the expression to be evaluated
     * must change it.
     * The only solution is to make this variable not a register.
     */
    if (cg.regcon.mvar & tosave)
    {
        //elem_print(e);
        //printf("test1: cg.regcon.mvar %s tosave %s\n", regm_str(cg.regcon.mvar), regm_str(tosave));
        cgreg_unregister(cg.regcon.mvar & tosave);
    }

    /* which registers can we use to save other registers in? */
    if (config.flags4 & CFG4space ||              // if optimize for space
        config.target_cpu >= TARGET_80486)        // PUSH/POP ops are 1 cycle
        touse = 0;                              // PUSH/POP pairs are always shorter
    else
    {
        touse = cg.mfuncreg & cg.allregs & ~(cg.msavereg | oldregcon | cg.regcon.cse.mval);
        /* Don't use registers we'll have to save/restore               */
        touse &= ~(fregsaved & oldmfuncreg);
        /* Don't use registers that have constant values in them, since
           the code generated might have used the value.
         */
        touse &= ~oldregimmed;
    }

    CodeBuilder cdbs1; cdbs1.ctor();
    code* cs2 = null;
    int adjesp = 0;

    for (reg_t i = 0; tosave; i++)
    {
        regm_t mi = mask(i);

        assert(i < REGMAX);
        if (mi & tosave)        /* i = register to save                 */
        {
            if (touse)          /* if any scratch registers             */
            {
                reg_t j;
                for (j = 0; j < 8; j++)
                {
                    regm_t mj = mask(j);

                    if (touse & mj)
                    {
                        genmovreg(cdbs1,j,i);

                        CodeBuilder cdbs2; cdbs2.ctor();
                        genmovreg(cdbs2, i, j);

                        cs2 = cat(cdbs2.finish(),cs2);

                        touse &= ~mj;
                        cg.mfuncreg &= ~mj;
                        cg.regcon.used |= mj;
                        assert(!(cg.regcon.used & mPSW));
                        break;
                    }
                }
                assert(j < 8);
            }
            else                        // else use memory
            {
                CodeBuilder cdby; cdby.ctor();
                uint size = gensaverestore(mask(i), cdbs1, cdby);
                cs2 = cat(cdby.finish(),cs2);
                if (size)
                {
                    cg.stackchanged = 1;
                    adjesp += size;
                }
            }
            getregs(cdbx,mi);
            tosave &= ~mi;
        }
    }
    CodeBuilder cdbs2; cdbs2.ctor();
    if (adjesp)
    {
        // If this is done an odd number of times, it
        // will throw off the 8 byte stack alignment.
        // We should* only* worry about this if a function
        // was called in the code generation by codelem().
        int sz = -(adjesp & (STACKALIGN - 1)) & (STACKALIGN - 1);
        if (cg.calledafunc && !I16 && sz && (STACKALIGN >= 16 || config.flags4 & CFG4stackalign))
        {
            regm_t mval_save = cg.regcon.immed.mval;
            cg.regcon.immed.mval = 0;      // prevent reghasvalue() optimizations
                                        // because c hasn't been executed yet
            cod3_stackadj(cdbs1, sz);
            cg.regcon.immed.mval = mval_save;
            cdbs1.genadjesp(sz);

            cod3_stackadj(cdbs2, -sz);
            cdbs2.genadjesp(-sz);
        }
        cdbs2.append(cs2);


        cdbs1.genadjesp(adjesp);
        cdbs2.genadjesp(-adjesp);
    }
    else
        cdbs2.append(cs2);

    cg.calledafunc |= calledafuncsave;
    cg.msavereg &= ~keepmsk | overlap; /* remove from mask of regs to save   */
    cg.mfuncreg &= oldmfuncreg;        /* update original                    */

    debug if (debugw)
        printf("-scodelem(e=%p pretregs=%s keepmsk=%s constflag=%d\n",
                e,regm_str(pretregs),regm_str(keepmsk),constflag);

    cdb.append(cdbs1);
    cdb.append(cdbx);
    cdb.append(cdbs2);
}

/*********************************************
 * Turn register mask into a string suitable for printing.
 */

@trusted
const(char)* regm_str(regm_t rm)
{
    enum NUM = 10;
    enum SMAX = 128;
    __gshared char[SMAX + 1][NUM] str;
    __gshared int i;
    bool AArch64 = cgstate.AArch64;

    if (rm == 0)
        return "0";
    if (AArch64)
    {
        if (rm == cgstate.allregs)
            return "allregs";
        if (rm == cgstate.fpregs)
            return "fpregs";
    }
    else
    {
        if (rm == ALLREGS)
            return "ALLREGS";
        if (rm == BYTEREGS)
            return "BYTEREGS";
        if (rm == XMMREGS)
            return "XMMREGS";
    }
    char* p = str[i].ptr;
    if (++i == NUM)
        i = 0;
    *p = 0;
    for (uint j = 0; j < (AArch64 ? 64 : 32); j++)
    {
        if (mask(j) & rm)
        {
            if (AArch64)
            {
                if (j == 31)
                    strcat(p, "sp");
                else if (j == 29)
                    strcat(p, "fp");
                else
                {
                    char[4] buf = void;
                    char c = j < 32 ? 'r' : 'f';
                    sprintf(buf.ptr, "%c%u", c, j);
                    strcat(p, buf.ptr);
                }
            }
            else
                strcat(p,regstring[j]);
            rm &= ~mask(j);
            if (rm)
                strcat(p,"|");
        }
    }
    if (rm)
    {
        const pstrlen = strlen(p);
        char* s = p + pstrlen;
        snprintf(s, SMAX - pstrlen, "x%02llx", cast(ulong)rm);
    }
    assert(strlen(p) <= SMAX);
    return strdup(p);
}

/*********************************
 * Scan down comma-expressions.
 * Output:
 *      pe = first elem down right side that is not an OPcomma
 * Returns:
 *      code generated for left branches of comma-expressions
 */

@trusted
void docommas(ref CodeBuilder cdb, ref elem* pe)
{
    uint stackpushsave = cgstate.stackpush;
    int stackcleansave = cgstate.stackclean;
    cgstate.stackclean = 0;
    elem* e = pe;
    while (1)
    {
        if (configv.addlinenumbers && e.Esrcpos.Slinnum)
        {
            cdb.genlinnum(e.Esrcpos);
            //e.Esrcpos.Slinnum = 0;               // don't do it twice
        }
        if (e.Eoper != OPcomma)
            break;
        regm_t retregs = 0;
        codelem(cgstate,cdb,e.E1,retregs,true);
        elem* eold = e;
        e = e.E2;
        freenode(eold);
    }
    pe = e;
    assert(cgstate.stackclean == 0);
    cgstate.stackclean = stackcleansave;
    genstackclean(cdb,cgstate.stackpush - stackpushsave,0);
}

/**************************
 * For elems in cgstate.regcon that don't match regconsave,
 * clear the corresponding bit in cgstate.regcon.cse.mval.
 * Do same for cgstate.regcon.immed.
 */

@trusted
void andregcon(const ref con_t pregconsave)
{
    regm_t m = ~1UL;
    foreach (i; 0 ..REGMAX)
    {
        if (pregconsave.cse.value[i] != cgstate.regcon.cse.value[i])
            cgstate.regcon.cse.mval &= m;
        if (pregconsave.immed.value[i] != cgstate.regcon.immed.value[i])
            cgstate.regcon.immed.mval &= m;
        m <<= 1;
        m |= 1;
    }
    //printf("regcon.cse.mval = %s, cgstate.regconsave.mval = %s ",regm_str(regcon.cse.mval),regm_str(pregconsave.cse.mval));
    cgstate.regcon.used |= pregconsave.used;
    assert(!(cgstate.regcon.used & mPSW));
    cgstate.regcon.cse.mval &= pregconsave.cse.mval;
    cgstate.regcon.immed.mval &= pregconsave.immed.mval;
    cgstate.regcon.params &= pregconsave.params;
    //printf("regcon.cse.mval&regcon.cse.mops = %s, cgstate.regcon.cse.mops = %s\n",regm_str(cgstate.regcon.cse.mval & cgstate.regcon.cse.mops), regm_str(cgstate.regcon.cse.mops));
    cgstate.regcon.cse.mops &= cgstate.regcon.cse.mval;
}


/**********************************************
 * Disassemble the code instruction bytes
 * Params:
 *    code = array of instruction bytes
 */
@trusted
extern (D)
void disassemble(ubyte[] code)
{
    printf("%s:\n", funcsym_p.Sident.ptr);

    @trusted
    void put(char c) { printf("%c", c); }

    if (cgstate.AArch64)
    {
        for (size_t i = 0; i < code.length; i += 4)
        {
            printf("%04x:", cast(int)i);
            dmd.backend.arm.disasmarm.getopstring(&put, code, cast(uint)i, 4, 64, false, true, true,
                    null, null, null, null);
            printf("\n");
        }
    }
    else
    {
        const model = I16 ? 16 : I32 ? 32 : 64;     // 16/32/64
        size_t i = 0;
        while (i < code.length)
        {
            printf("%04x:", cast(int)i);
            uint pc;
            const sz = dmd.backend.x86.disasm86.calccodsize(code, cast(uint)i, pc, model);

            dmd.backend.x86.disasm86.getopstring(&put, code, cast(uint)i, sz, model, model == 16, true, true,
                    null, null, null, null);
            printf("\n");
            i += sz;
        }
    }
}

/********************************
 * Disassemble one AArch64 instruction.
 * Params:
 *      ins = instruction to decode
 */
@trusted extern (D) void disassemble(uint ins)
{
    @trusted
    void put(char c) { printf("%c", c); }

    dmd.backend.arm.disasmarm.getopstring(&put, (cast(ubyte*)&ins)[0..4], 0, 4, 64, false, true, false,
            null, null, null, null);
    printf("\n");
}
