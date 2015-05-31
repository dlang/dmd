// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2013 by Digital Mars
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
#include        <stdlib.h>
#include        <time.h>

#if __sun || _MSC_VER
#include        <alloca.h>
#endif

#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "code.h"
#include        "global.h"
#include        "type.h"
#include        "exh.h"
#include        "xmm.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

STATIC void resetEcomsub(elem *e);
STATIC code * loadcse(elem *,unsigned,regm_t);
STATIC void blcodgen(block *);
STATIC void cgcod_eh();
STATIC code * cse_save(regm_t ms);
STATIC code * comsub(elem *,regm_t *);

bool floatreg;                  // !=0 if floating register is required

int hasframe;                   // !=0 if this function has a stack frame
targ_size_t spoff;
targ_size_t Foff;               // BP offset of floating register
targ_size_t CSoff;              // offset of common sub expressions
targ_size_t NDPoff;             // offset of saved 8087 registers
int BPoff;                      // offset from BP
int EBPtoESP;                   // add to EBP offset to get ESP offset
int AllocaOff;                  // offset of alloca temporary
LocalSection Para;              // section of function parameters
LocalSection Auto;              // section of automatics and registers
LocalSection Fast;              // section of fastpar
LocalSection EEStack;           // offset of SCstack variables from ESP

REGSAVE regsave;

CGstate cgstate;                // state of code generator

regm_t BYTEREGS = BYTEREGS_INIT;
regm_t ALLREGS = ALLREGS_INIT;


/************************************
 * # of bytes that SP is beyond BP.
 */

unsigned stackpush;

int stackchanged;               /* set to !=0 if any use of the stack
                                   other than accessing parameters. Used
                                   to see if we can address parameters
                                   with ESP rather than EBP.
                                 */
int refparam;           // !=0 if we referenced any parameters
int reflocal;           // !=0 if we referenced any locals
bool anyiasm;           // !=0 if any inline assembler
char calledafunc;       // !=0 if we called a function
char needframe;         // if TRUE, then we will need the frame
                        // pointer (BP for the 8088)
char usedalloca;        // if TRUE, then alloca() was called
char gotref;            // !=0 if the GOTsym was referenced
unsigned usednteh;              // if !=0, then used NT exception handling

/* Register contents    */
con_t regcon;

int pass;                       // PASSxxxx

static symbol *retsym;          // set to symbol that should be placed in
                                // register AX

/****************************
 * Register masks.
 */

regm_t msavereg;        // Mask of registers that we would like to save.
                        // they are temporaries (set by scodelem())
regm_t mfuncreg;        // Mask of registers preserved by a function

#if __DMC__
extern "C" {
// make sure it isn't merged with ALLREGS
regm_t __cdecl allregs;         // ALLREGS optionally including mBP
}
#else
regm_t allregs;                // ALLREGS optionally including mBP
#endif

int dfoidx;                     /* which block we are in                */
struct CSE *csextab = NULL;     /* CSE table (allocated for each function) */
unsigned cstop;                 /* # of entries in CSE table (csextab[])   */
unsigned csmax;                 /* amount of space in csextab[]         */

targ_size_t     funcoffset;     // offset of start of function
targ_size_t     prolog_allocoffset;     // offset past adj of stack allocation
targ_size_t     startoffset;    // size of function entry code
targ_size_t     retoffset;      /* offset from start of func to ret code */
targ_size_t     retsize;        /* size of function return              */

static regm_t lastretregs,last2retregs,last3retregs,last4retregs,last5retregs;

/*********************************
 * Generate code for a function.
 * Note at the end of this routine mfuncreg will contain the mask
 * of registers not affected by the function. Some minor optimization
 * possibilities are here...
 */

void codgen()
{
    bool flag;
#if SCPP
    block *btry;
#endif
    // Register usage. If a bit is on, the corresponding register is live
    // in that basic block.

    //printf("codgen('%s')\n",funcsym_p->Sident);

    cgreg_init();
    csmax = 64;
    csextab = (struct CSE *) util_calloc(sizeof(struct CSE),csmax);
    tym_t functy = tybasic(funcsym_p->ty());
    cod3_initregs();
    allregs = ALLREGS;
    pass = PASSinit;

tryagain:
    #ifdef DEBUG
    if (debugr)
        printf("------------------ PASS%s -----------------\n",
            (pass == PASSinit) ? "init" : ((pass == PASSreg) ? "reg" : "final"));
    #endif
    lastretregs = last2retregs = last3retregs = last4retregs = last5retregs = 0;

    // if no parameters, assume we don't need a stack frame
    needframe = 0;
    usedalloca = 0;
    gotref = 0;
    stackchanged = 0;
    stackpush = 0;
    refparam = 0;
    anyiasm = 0;
    calledafunc = 0;
    cgstate.stackclean = 1;
    retsym = NULL;

    regsave.reset();
#if TX86
    memset(_8087elems,0,sizeof(_8087elems));
#endif

    usednteh = 0;
#if (MARS) && TARGET_WINDOS
    if (funcsym_p->Sfunc->Fflags3 & Fjmonitor)
        usednteh |= NTEHjmonitor;
#else
    if (CPP)
    {
        if (config.flags2 & CFG2seh &&
            (funcsym_p->Stype->Tflags & TFemptyexc || funcsym_p->Stype->Texcspec))
            usednteh |= NTEHexcspec;
        except_reset();
    }
#endif

    floatreg = FALSE;
#if TX86
    assert(stackused == 0);             /* nobody in 8087 stack         */
#endif
    cstop = 0;                          /* no entries in table yet      */
    memset(&regcon,0,sizeof(regcon));
    regcon.cse.mval = regcon.cse.mops = 0;      // no common subs yet
    msavereg = 0;
    unsigned nretblocks = 0;
    mfuncreg = fregsaved;               // so we can see which are used
                                        // (bit is cleared each time
                                        //  we use one)
    for (block* b = startblock; b; b = b->Bnext)
    {   memset(&b->Bregcon,0,sizeof(b->Bregcon));       // Clear out values in registers
        if (b->Belem)
            resetEcomsub(b->Belem);     // reset all the Ecomsubs
        if (b->BC == BCasm)
            anyiasm = 1;                // we have inline assembler
        if (b->BC == BCret || b->BC == BCretexp)
            nretblocks++;
    }

    if (!config.fulltypes || (config.flags4 & CFG4optimized))
    {
        regm_t noparams = 0;
        for (int i = 0; i < globsym.top; i++)
        {
            Symbol *s = globsym.tab[i];
            s->Sflags &= ~SFLread;
            switch (s->Sclass)
            {   case SCfastpar:
                case SCshadowreg:
                    regcon.params |= s->Spregm();
                case SCparameter:
                    if (s->Sfl == FLreg)
                        noparams |= s->Sregm;
                    break;
            }
        }
        regcon.params &= ~noparams;
    }

    if (config.flags4 & CFG4optimized)
    {
        if (nretblocks == 0 &&                  // if no return blocks in function
            !(funcsym_p->ty() & mTYnaked))      // naked functions may have hidden veys of returning
            funcsym_p->Sflags |= SFLexit;       // mark function as never returning

        assert(dfo);

        cgreg_reset();
        for (dfoidx = 0; dfoidx < dfotop; dfoidx++)
        {   regcon.used = msavereg | regcon.cse.mval;   // registers already in use
            block* b = dfo[dfoidx];
            blcodgen(b);                        // gen code in depth-first order
            //printf("b->Bregcon.used = %s\n", regm_str(b->Bregcon.used));
            cgreg_used(dfoidx,b->Bregcon.used); // gather register used information
        }
    }
    else
    {   pass = PASSfinal;
        for (block* b = startblock; b; b = b->Bnext)
            blcodgen(b);                // generate the code for each block
    }
    regcon.immed.mval = 0;
    assert(!regcon.cse.mops);           // should have all been used

    // See which variables we can put into registers
    if (pass != PASSfinal &&
        !anyiasm)                               // possible LEA or LES opcodes
    {
        allregs |= cod3_useBP();                // see if we can use EBP

        // If pic code, but EBX was never needed
        if (!(allregs & mask[PICREG]) && !gotref)
        {   allregs |= mask[PICREG];            // EBX can now be used
            cgreg_assign(retsym);
            pass = PASSreg;
        }
        else if (cgreg_assign(retsym))          // if we found some registers
            pass = PASSreg;
        else
            pass = PASSfinal;
        for (block* b = startblock; b; b = b->Bnext)
        {   code_free(b->Bcode);
            b->Bcode = NULL;
        }
        goto tryagain;
    }
    cgreg_term();

#if SCPP
    if (CPP)
        cgcod_eh();
#endif

    stackoffsets(1);            // compute addresses of stack variables
    cod5_prol_epi();            // see where to place prolog/epilog

    // Get rid of unused cse temporaries
    while (cstop != 0 && (csextab[cstop - 1].flags & CSEload) == 0)
        cstop--;

    if (configv.addlinenumbers)
        objmod->linnum(funcsym_p->Sfunc->Fstartline,Coffset);

    // Otherwise, jmp's to startblock will execute the prolog again
    assert(!startblock->Bpred);

    code* cprolog = prolog();                 // gen function start code
    if (cprolog)
        pinholeopt(cprolog,NULL);       // optimize

    funcoffset = Coffset;
    targ_size_t coffset = Coffset;

    if (eecontext.EEelem)
        genEEcode();

    for (block* b = startblock; b; b = b->Bnext)
    {
        // We couldn't do this before because localsize was unknown
        switch (b->BC)
        {   case BCret:
                if (configv.addlinenumbers && b->Bsrcpos.Slinnum && !(funcsym_p->ty() & mTYnaked))
                    cgen_linnum(&b->Bcode,b->Bsrcpos);
            case BCretexp:
                epilog(b);
                break;
            default:
                if (b->Bflags & BFLepilog)
                    epilog(b);
                break;
        }
        assignaddr(b);                  // assign addresses
        pinholeopt(b->Bcode,b);         // do pinhole optimization
        if (b->Bflags & BFLprolog)      // do function prolog
        {
            startoffset = coffset + calcblksize(cprolog) - funcoffset;
            b->Bcode = cat(cprolog,b->Bcode);
        }
        cgsched_block(b);
        b->Bsize = calcblksize(b->Bcode);       // calculate block size
        if (b->Balign)
        {   targ_size_t u = b->Balign - 1;

            coffset = (coffset + u) & ~u;
        }
        b->Boffset = coffset;           /* offset of this block         */
        coffset += b->Bsize;            /* offset of following block    */
    }
#ifdef DEBUG
    debugw && printf("code addr complete\n");
#endif

    // Do jump optimization
    do
    {   flag = FALSE;
        for (block* b = startblock; b; b = b->Bnext)
        {   if (b->Bflags & BFLjmpoptdone)      /* if no more jmp opts for this blk */
                continue;
            int i = branch(b,0);            // see if jmp => jmp short
            if (i)                          // if any bytes saved
            {   targ_size_t offset;

                b->Bsize -= i;
                offset = b->Boffset + b->Bsize;
                for (block* bn = b->Bnext; bn; bn = bn->Bnext)
                {
                    if (bn->Balign)
                    {   targ_size_t u = bn->Balign - 1;

                        offset = (offset + u) & ~u;
                    }
                    bn->Boffset = offset;
                    offset += bn->Bsize;
                }
                coffset = offset;
                flag = TRUE;
            }
        }
        if (!I16 && !(config.flags4 & CFG4optimized))
            break;                      // use the long conditional jmps
    } while (flag);                     // loop till no more bytes saved
#ifdef DEBUG
    debugw && printf("code jump optimization complete\n");
#endif

#if MARS
    if (usednteh & NTEH_try)
    {
        // Do this before code is emitted because we patch some instructions
        nteh_filltables();
    }
#endif

    // Compute starting offset for switch tables
#if ELFOBJ || MACHOBJ
    targ_size_t swoffset = (config.flags & CFGromable) ? coffset : CDoffset;
#else
    targ_size_t swoffset = (config.flags & CFGromable) ? coffset : Doffset;
#endif
    swoffset = align(0,swoffset);

    // Emit the generated code
    if (eecontext.EEcompile == 1)
    {
        codout(eecontext.EEcode);
        code_free(eecontext.EEcode);
#if SCPP
        el_free(eecontext.EEelem);
#endif
    }
    else
    {
        for (block* b = startblock; b; b = b->Bnext)
        {
            if (b->BC == BCjmptab || b->BC == BCswitch)
            {
                swoffset = align(0,swoffset);
                b->Btableoffset = swoffset;     /* offset of sw tab */
                swoffset += b->Btablesize;
            }
            jmpaddr(b->Bcode);          /* assign jump addresses        */
#ifdef DEBUG
            if (debugc)
            {   printf("Boffset = x%lx, Bsize = x%lx, Coffset = x%lx\n",
                    (long)b->Boffset,(long)b->Bsize,(long)Coffset);
                if (b->Bcode)
                    printf( "First opcode of block is: %0x\n", b->Bcode->Iop );
            }
#endif
            if (b->Balign)
            {   unsigned u = b->Balign;
                unsigned nalign = (u - (unsigned)Coffset) & (u - 1);

                cod3_align_bytes(nalign);
            }
            assert(b->Boffset == Coffset);

#if SCPP
            if (CPP &&
                !(config.flags2 & CFG2seh))
            {
                //printf("b = %p, index = %d\n",b,b->Bindex);
                //except_index_set(b->Bindex);

                if (btry != b->Btry)
                {
                    btry = b->Btry;
                    except_pair_setoffset(b,Coffset - funcoffset);
                }
                if (b->BC == BCtry)
                {
                    btry = b;
                    except_pair_setoffset(b,Coffset - funcoffset);
                }
            }
#endif
            codout(b->Bcode);   // output code
    }
    if (coffset != Coffset)
    {
#ifdef DEBUG
        printf("coffset = %ld, Coffset = %ld\n",(long)coffset,(long)Coffset);
#endif
        assert(0);
    }
    funcsym_p->Ssize = Coffset - funcoffset;    // size of function

#if NTEXCEPTIONS || MARS
#if (SCPP && NTEXCEPTIONS)
    if (usednteh & NTEHcpp)
#elif MARS
        if (usednteh & NTEH_try)
#endif
    {   assert(!(config.flags & CFGromable));
        //printf("framehandleroffset = x%x, coffset = x%x\n",framehandleroffset,coffset);
        objmod->reftocodeseg(cseg,framehandleroffset,coffset);
    }
#endif


    // Write out switch tables
    flag = FALSE;                       // TRUE if last active block was a ret
    for (block* b = startblock; b; b = b->Bnext)
    {
        switch (b->BC)
        {   case BCjmptab:              /* if jump table                */
                outjmptab(b);           /* write out jump table         */
                break;
            case BCswitch:
                outswitab(b);           /* write out switch table       */
                break;
            case BCret:
            case BCretexp:
                /* Compute offset to return code from start of function */
                retoffset = b->Boffset + b->Bsize - retsize - funcoffset;
#if MARS
                /* Add 3 bytes to retoffset in case we have an exception
                 * handler. THIS PROBABLY NEEDS TO BE IN ANOTHER SPOT BUT
                 * IT FIXES THE PROBLEM HERE AS WELL.
                 */
                if (usednteh & NTEH_try)
                    retoffset += 3;
#endif
                flag = TRUE;
                break;
            case BCexit:
                // Fake it to keep debugger happy
                retoffset = b->Boffset + b->Bsize - funcoffset;
                break;
        }
    }
    if (flag && configv.addlinenumbers && !(funcsym_p->ty() & mTYnaked))
        /* put line number at end of function on the
           start of the last instruction
         */
        /* Instead, try offset to cleanup code  */
        objmod->linnum(funcsym_p->Sfunc->Fendline,funcoffset + retoffset);

#if TARGET_WINDOS && MARS
    if (config.exe == EX_WIN64)
        win64_pdata(funcsym_p);
#endif

#if MARS
    if (usednteh & NTEH_try)
    {
        // Do this before code is emitted because we patch some instructions
        nteh_gentables();
    }
    if (usednteh & EHtry)
    {
        except_gentables();
    }
#endif

#if SCPP
#if NTEXCEPTIONS
    // Write out frame handler
    if (usednteh & NTEHcpp)
        nteh_framehandler(except_gentables());
    else
#endif
    {
#if NTEXCEPTIONS
        if (usednteh & NTEH_try)
            nteh_gentables();
        else
#endif
        {
            if (CPP)
                except_gentables();
        }
        ;
    }
#endif
    for (block* b = startblock; b; b = b->Bnext)
    {
        code_free(b->Bcode);
        b->Bcode = NULL;
    }

    }

    // Mask of regs saved
    // BUG: do interrupt functions save BP?
    funcsym_p->Sregsaved = (functy == TYifunc) ? mBP : (mfuncreg | fregsaved);

    util_free(csextab);
    csextab = NULL;
#if TX86
#ifdef DEBUG
    if (stackused != 0)
          printf("stackused = %d\n",stackused);
#endif
    assert(stackused == 0);             /* nobody in 8087 stack         */

    /* Clean up ndp save array  */
    mem_free(NDP::save);
    NDP::save = NULL;
    NDP::savetop = 0;
    NDP::savemax = 0;
#endif
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
targ_size_t alignsection(targ_size_t base, unsigned alignment, int bias)
{
    assert((int)base <= 0);
    if (alignment > STACKALIGN)
        alignment = STACKALIGN;
    if (alignment)
    {
        int sz = -base + bias;
        assert(sz >= 0);
        sz &= (alignment - 1);
        if (sz)
            base -= alignment - sz;
    }
    return base;
}

/*******************************
 * Generate code for a function start.
 * Input:
 *      Coffset         address of start of code
 *      Auto.alignment
 * Output:
 *      Coffset         adjusted for size of code generated
 *      EBPtoESP
 *      hasframe
 *      BPoff
 */

code *prolog()
{
    bool enter;
    regm_t namedargs = 0;

    //printf("cod3.prolog() %s, needframe = %d, Auto.alignment = %d\n", funcsym_p->Sident, needframe, Auto.alignment);
    debugx(debugw && printf("funcstart()\n"));
    regcon.immed.mval = 0;                      /* no values in registers yet   */
    EBPtoESP = -REGSIZE;
    hasframe = 0;
    bool pushds = false;
    BPoff = 0;
    code *c = CNIL;
    bool pushalloc = false;
    tym_t tyf = funcsym_p->ty();
    tym_t tym = tybasic(tyf);
    unsigned farfunc = tyfarfunc(tym);
    if (config.flags & CFGalwaysframe || funcsym_p->Sfunc->Fflags3 & Ffakeeh)
        needframe = 1;

Lagain:
    spoff = 0;
    char guessneedframe = needframe;
//    if (needframe && config.exe & (EX_LINUX | EX_FREEBSD | EX_SOLARIS) && !(usednteh & ~NTEHjmonitor))
//      usednteh |= NTEHpassthru;

    /* Compute BP offsets for variables on stack.
     * The organization is:
     *  Para.size    parameters
     * -------- stack is aligned to STACKALIGN
     *          seg of return addr      (if far function)
     *          IP of return addr
     *  BP->    caller's BP
     *          DS                      (if Windows prolog/epilog)
     *          exception handling context symbol
     *  Fast.size fastpar
     *  Auto.size    autos and regs
     *  regsave.off  any saved registers
     *  Foff    floating register
     *  AllocaOff   alloca temporary
     *  CSoff   common subs
     *  NDPoff  any 8087 saved registers
     *          monitor context record
     *          any saved registers
     */

    if (tym == TYifunc)
        Para.size = 26; // how is this number derived?
    else
        Para.size = (farfunc ? 3 : 2) * REGSIZE;

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
    Fast.size = 0;
#if NTEXCEPTIONS == 2
    Fast.size -= nteh_contextsym_size();
#if MARS
    if (funcsym_p->Sfunc->Fflags3 & Ffakeeh && nteh_contextsym_size() == 0)
        Fast.size -= 5 * 4;
#endif
#endif

    /* Despite what the comment above says, aligning Fast section to size greater
     * than REGSIZE does not break contract implementation. Fast.offset and
     * Fast.alignment must be the same for the overriding and
     * the overriden function, since they have the same parameters. Fast.size
     * must be the same because otherwise, contract inheritance wouldn't work
     * even if we didn't align Fast section to size greater than REGSIZE. Therefore,
     * the only way aligning the section could cause problems with contract
     * inheritance is if bias (declared below) differed for the overriden
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
     * the value of neadframe should always be the same for the overriden
     * and the overriding function, and so bias should be the same too.
    */

    int bias = Para.size + (needframe ? 0 : REGSIZE);
    if (Fast.alignment < REGSIZE)
        Fast.alignment = REGSIZE;

    Fast.size = alignsection(Fast.size - Fast.offset, Fast.alignment, bias);

    if (Auto.alignment < REGSIZE)
        Auto.alignment = REGSIZE;       // necessary because localsize must be REGSIZE aligned
    Auto.size = alignsection(Fast.size - Auto.offset, Auto.alignment, bias);

    regsave.off = alignsection(Auto.size - regsave.top, regsave.alignment, bias);

    unsigned floatregsize = floatreg ? (config.fpxmmregs || I32 ? 16 : DOUBLESIZE) : 0;
    Foff = alignsection(regsave.off - floatregsize, STACKALIGN, bias);

    assert(usedalloca != 1);
    AllocaOff = alignsection(usedalloca ? (Foff - REGSIZE) : Foff, REGSIZE, bias);

    CSoff = alignsection(AllocaOff - cstop * REGSIZE, REGSIZE, bias);

#if TX86
    NDPoff = alignsection(CSoff - NDP::savetop * NDPSAVESIZE, REGSIZE, bias);
#else
    NDPoff = CSoff;
#endif

    //printf("Fast.size = x%x, Auto.size = x%x\n", (int)Fast.size, (int)Auto.size);

    localsize = -NDPoff;

    regm_t topush = fregsaved & ~mfuncreg;     // mask of registers that need saving
    int npush = numbitsset(topush);            // number of registers that need saving
    npush += numbitsset(topush & XMMREGS);     // XMM regs take 16 bytes, so count them twice

    // Keep the stack aligned by 8 for any subsequent function calls
    if (!I16 && calledafunc &&
        (STACKALIGN == 16 || config.flags4 & CFG4stackalign))
    {
        //printf("npush = %d Para.size = x%x needframe = %d localsize = x%x\n",
        //       npush, Para.size, needframe, localsize);

        int sz = Para.size + (needframe ? 0 : -REGSIZE) + localsize + npush * REGSIZE;
        if (STACKALIGN == 16)
        {
            if (sz & (8|4))
                localsize += STACKALIGN - (sz & (8|4));
        }
        else if (sz & 4)
            localsize += 4;
    }

    //printf("Foff x%02x Auto.size x%02x NDPoff x%02x CSoff x%02x Para.size x%02x localsize x%02x\n",
        //(int)Foff,(int)Auto.size,(int)NDPoff,(int)CSoff,(int)Para.size,(int)localsize);

    unsigned xlocalsize = localsize;    // amount to subtract from ESP to make room for locals

    if (tyf & mTYnaked)                 // if no prolog/epilog for function
    {
        hasframe = 1;
        return NULL;
    }

    if (tym == TYifunc)
    {
        c = cat(c, prolog_ifunc(&tyf));
        hasframe = 1;
        goto Lcont;
    }

    /* Determine if we need BP set up   */
    if (config.flags & CFGalwaysframe)
        needframe = 1;
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
                (usednteh & ~NTEHjmonitor) ||
                anyiasm ||
                usedalloca
               )
                needframe = 1;
        }
        if (refparam && (anyiasm || I16))
            needframe = 1;
    }

    if (needframe)
    {   assert(mfuncreg & mBP);         // shouldn't have used mBP

        if (!guessneedframe)            // if guessed wrong
            goto Lagain;
    }

    if (I16 && config.wflags & WFwindows && farfunc)
    {
        c = cat(c, prolog_16bit_windows_farfunc(&tyf, &pushds));
        enter = false;                  /* don't use ENTER instruction  */
        hasframe = 1;                   /* we have a stack frame        */
    }
    else if (needframe)                 // if variables or parameters
    {
        c = cat(c, prolog_frame(farfunc, &xlocalsize, &enter));
        hasframe = 1;
    }

    /* Subtract from stack pointer the size of the local stack frame
     */
    {
    code *cstackadj = CNIL;
    if (config.flags & CFGstack)        // if stack overflow check
    {
        cstackadj = prolog_frameadj(tyf, xlocalsize, enter, &pushalloc);
        if (usedalloca)
            cstackadj = cat(cstackadj, prolog_setupalloca());
    }
    else if (needframe)                      /* if variables or parameters   */
    {
        if (xlocalsize)                 /* if any stack offset          */
        {
            cstackadj = prolog_frameadj(tyf, xlocalsize, enter, &pushalloc);
            if (usedalloca)
                cstackadj = cat(cstackadj, prolog_setupalloca());
        }
        else
            assert(usedalloca == 0);
    }
    else if (xlocalsize)
    {
        assert(I32);
        cstackadj = prolog_frameadj2(tyf, xlocalsize, &pushalloc);
        BPoff += REGSIZE;
    }
    else
        assert((localsize | usedalloca) == 0 || (usednteh & NTEHjmonitor));
    EBPtoESP += xlocalsize;
    c = cat(c, cstackadj);
    }

    /* Win64 unwind needs the amount of code generated so far
     */
    if (config.exe == EX_WIN64)
    {
        pinholeopt(c, NULL);
        prolog_allocoffset = calcblksize(c);
    }

#if SCPP
    /*  The idea is to generate trace for all functions if -Nc is not thrown.
     *  If -Nc is thrown, generate trace only for global COMDATs, because those
     *  are relevant to the FUNCTIONS statement in the linker .DEF file.
     *  This same logic should be in epilog().
     */
    if (config.flags & CFGtrace &&
        (!(config.flags4 & CFG4allcomdat) ||
         funcsym_p->Sclass == SCcomdat ||
         funcsym_p->Sclass == SCglobal ||
         (config.flags2 & CFG2comdat && SymInline(funcsym_p))
        )
       )
    {
        unsigned spalign = 0;
        int sz = Para.size + (needframe ? 0 : -REGSIZE) + localsize;
        if (STACKALIGN == 16 && (sz & (STACKALIGN - 1)))
            spalign = STACKALIGN - (sz & (STACKALIGN - 1));

        if (spalign)
        {   /* This could be avoided by moving the function call to after the
             * registers are saved. But I don't remember why the call is here
             * and not there.
             */
            c = cod3_stackadj(c, spalign);
        }

        unsigned regsaved;
        c = cat(c, prolog_trace(farfunc, &regsaved));

        if (spalign)
            c = cod3_stackadj(c, -spalign);
        useregs((ALLREGS | mBP | mES) & ~regsaved);
    }
#endif

#if MARS
    if (usednteh & NTEHjmonitor)
    {   Symbol *sthis;

        for (SYMIDX si = 0; 1; si++)
        {   assert(si < globsym.top);
            sthis = globsym.tab[si];
            if (strcmp(sthis->Sident,"this") == 0)
                break;
        }
        c = cat(c,nteh_monitor_prolog(sthis));
        EBPtoESP += 3 * 4;
    }
#endif

    c = prolog_saveregs(c, topush);

Lcont:

    if (config.exe == EX_WIN64)
    {
        if (variadic(funcsym_p->Stype))
            c = cat(c, prolog_gen_win64_varargs());
        c = cat(c, prolog_loadparams(tyf, pushalloc, &namedargs));
        return c;
    }

    c = cat(c, prolog_ifunc2(tyf, tym, pushds));

#if NTEXCEPTIONS == 2
    if (usednteh & NTEH_except)
        c = cat(c,nteh_setsp(0x89));            // MOV __context[EBP].esp,ESP
#endif

    // Load register parameters off of the stack. Do not use
    // assignaddr(), as it will replace the stack reference with
    // the register!
    c = cat(c, prolog_loadparams(tyf, pushalloc, &namedargs));

    // Special Intel 64 bit ABI prolog setup for variadic functions
    if (I64 && variadic(funcsym_p->Stype))
    {
        /* The Intel 64 bit ABI scheme.
         * abi_sysV_amd64.pdf
         * Load arguments passed in registers into the varargs save area
         * so they can be accessed by va_arg().
         */
        /* Look for __va_argsave
         */
        symbol *sv = NULL;
        for (SYMIDX si = 0; si < globsym.top; si++)
        {   symbol *s = globsym.tab[si];
            if (s->Sident[0] == '_' && strcmp(s->Sident, "__va_argsave") == 0)
            {   sv = s;
                break;
            }
        }

        if (sv && !(sv->Sflags & SFLdead))
            c = cat(c, prolog_genvarargs(sv, &namedargs));
    }

    /* Alignment checks
     */
    //assert(Auto.alignment <= STACKALIGN);
    //assert(((Auto.size + Para.size + BPoff) & (Auto.alignment - 1)) == 0);

    return c;
}

/************************************
 * Predicate for sorting auto symbols for qsort().
 * Returns:
 *      < 0     s1 goes farther from frame pointer
 *      > 0     s1 goes nearer the frame pointer
 *      = 0     no difference
 */

int __cdecl autosort_cmp(const void *ps1, const void *ps2)
{
    symbol *s1 = *(symbol **)ps1;
    symbol *s2 = *(symbol **)ps2;

    /* Largest align size goes furthest away from frame pointer,
     * so they get allocated first.
     */
    unsigned alignsize1 = s1->Salignsize();
    unsigned alignsize2 = s2->Salignsize();
    if (alignsize1 < alignsize2)
        return 1;
    else if (alignsize1 > alignsize2)
        return -1;

    /* move variables nearer the frame pointer that have higher Sweights
     * because addressing mode is fewer bytes. Grouping together high Sweight
     * variables also may put them in the same cache
     */
    if (s1->Sweight < s2->Sweight)
        return -1;
    else if (s1->Sweight > s2->Sweight)
        return 1;

    /* More:
     * 1. put static arrays nearest the frame pointer, so buffer overflows
     *    can't change other variable contents
     * 2. Do the coloring at the byte level to minimize stack usage
     */
    return 0;
}

/******************************
 * Compute offsets for remaining tmp, automatic and register variables
 * that did not make it into registers.
 * Input:
 *      flags   0: do estimate only
 *              1: final
 */

void stackoffsets(int flags)
{
    //printf("stackoffsets() %s\n", funcsym_p->Sident);

    Para.init();        // parameter offset
    Fast.init();        // SCfastpar offset
    Auto.init();        // automatic & register offset
    EEStack.init();     // for SCstack's

    // Set if doing optimization of auto layout
    bool doAutoOpt = flags && config.flags4 & CFG4optimized;

    // Put autos in another array so we can do optimizations on the stack layout
    symbol *autotmp[10];
    symbol **autos = NULL;
    if (doAutoOpt)
    {
        if (globsym.top <= sizeof(autotmp)/sizeof(autotmp[0]))
            autos = autotmp;
        else
        {   autos = (symbol **)malloc(globsym.top * sizeof(*autos));
            assert(autos);
        }
    }
    size_t autosi = 0;  // number used in autos[]

    for (int si = 0; si < globsym.top; si++)
    {   symbol *s = globsym.tab[si];

        if (s->Sisdead(anyiasm))
        {
            /* The variable is dead. Don't allocate space for it if we don't
             * need to.
             */
            switch (s->Sclass)
            {
                case SCfastpar:
                case SCshadowreg:
                case SCparameter:
                    break;          // have to allocate space for parameters

                default:
                    continue;       // don't allocate space
            }
        }

        targ_size_t sz = type_size(s->Stype);
        if (sz == 0)
            sz++;               // can't handle 0 length structs

        unsigned alignsize = s->Salignsize();
        if (alignsize > STACKALIGN)
            alignsize = STACKALIGN;         // no point if the stack is less aligned

        //printf("symbol '%s', size = x%lx, alignsize = %d, read = %x\n",s->Sident,(long)sz, (int)alignsize, s->Sflags & SFLread);
        assert((int)sz >= 0);

        switch (s->Sclass)
        {
            case SCfastpar:
                /* Get these
                 * right next to the stack frame pointer, EBP.
                 * Needed so we can call nested contract functions
                 * frequire and fensure.
                 */
                if (s->Sfl == FLreg)        // if allocated in register
                    continue;
                /* Needed because storing fastpar's on the stack in prolog()
                 * does the entire register
                 */
                if (sz < REGSIZE)
                    sz = REGSIZE;

                Fast.offset = align(sz,Fast.offset);
                s->Soffset = Fast.offset;
                Fast.offset += sz;
                //printf("fastpar '%s' sz = %d, fast offset =  x%x, %p\n",s->Sident,(int)sz,(int)s->Soffset, s);

                if (alignsize > Fast.alignment)
                    Fast.alignment = alignsize;
                break;

            case SCregister:
            case SCauto:
                if (s->Sfl == FLreg)        // if allocated in register
                    break;

                if (doAutoOpt)
                {   autos[autosi++] = s;    // deal with later
                    break;
                }

                Auto.offset = align(sz,Auto.offset);
                s->Soffset = Auto.offset;
                Auto.offset += sz;
                //printf("auto    '%s' sz = %d, auto offset =  x%lx\n",s->Sident,sz,(long)s->Soffset);

                if (alignsize > Auto.alignment)
                    Auto.alignment = alignsize;
                break;

            case SCstack:
                EEStack.offset = align(sz,EEStack.offset);
                s->Soffset = EEStack.offset;
                //printf("EEStack.offset =  x%lx\n",(long)s->Soffset);
                EEStack.offset += sz;
                break;

            case SCshadowreg:
            case SCparameter:
                if (config.exe == EX_WIN64)
                {
                    assert((Para.offset & 7) == 0);
                    s->Soffset = Para.offset;
                    Para.offset += 8;
                    break;
                }
                /* Alignment on OSX 32 is odd. reals are 16 byte aligned in general,
                 * but are 4 byte aligned on the OSX 32 stack.
                 */
                Para.offset = align(REGSIZE,Para.offset); /* align on word stack boundary */
                if (alignsize == 16 && (I64 || tyvector(s->ty())))
                {
                    if (Para.offset & 4)
                        Para.offset += 4;
                    if (Para.offset & 8)
                        Para.offset += 8;
                }
                s->Soffset = Para.offset;
                //printf("%s param offset =  x%lx, alignsize = %d\n",s->Sident,(long)s->Soffset, (int)alignsize);
                Para.offset += (s->Sflags & SFLdouble)
                            ? type_size(tsdouble)   // float passed as double
                            : type_size(s->Stype);
                break;

            case SCpseudo:
            case SCstatic:
            case SCbprel:
                break;
            default:
#ifdef DEBUG
                symbol_print(s);
#endif
                assert(0);
        }
    }

    if (autosi)
    {
        qsort(autos, autosi, sizeof(symbol *), &autosort_cmp);

        vec_t tbl = vec_calloc(autosi);

        for (size_t si = 0; si < autosi; si++)
        {   symbol *s = autos[si];

            targ_size_t sz = type_size(s->Stype);
            if (sz == 0)
                sz++;               // can't handle 0 length structs

            unsigned alignsize = s->Salignsize();
            if (alignsize > STACKALIGN)
                alignsize = STACKALIGN;         // no point if the stack is less aligned

            /* See if we can share storage with another variable
             * if their live ranges do not overlap.
             */
            if (// Don't share because could stomp on variables
                // used in finally blocks
                !(usednteh & ~NTEHjmonitor) &&
                s->Srange && !(s->Sflags & SFLspill))
            {
                for (size_t i = 0; i < si; i++)
                {
                    if (!vec_testbit(i,tbl))
                        continue;
                    symbol *sp = autos[i];
//printf("auto    s = '%s', sp = '%s', %d, %d, %d\n",s->Sident,sp->Sident,dfotop,vec_numbits(s->Srange),vec_numbits(sp->Srange));
                    if (vec_disjoint(s->Srange,sp->Srange) &&
                        !(sp->Soffset & (alignsize - 1)) &&
                        sz <= type_size(sp->Stype))
                    {
                        vec_or(sp->Srange,sp->Srange,s->Srange);
                        //printf("sharing space - '%s' onto '%s'\n",s->Sident,sp->Sident);
                        s->Soffset = sp->Soffset;
                        goto L2;
                    }
                }
            }
            Auto.offset = align(sz,Auto.offset);
            s->Soffset = Auto.offset;
            //printf("auto    '%s' sz = %d, auto offset =  x%lx\n",s->Sident,sz,(long)s->Soffset);
            Auto.offset += sz;
            if (s->Srange && !(s->Sflags & SFLspill))
                vec_setbit(si,tbl);

            if (alignsize > Auto.alignment)
                Auto.alignment = alignsize;
        L2: ;
        }

        vec_free(tbl);

        if (autos != autotmp)
            free(autos);
    }
}

/****************************
 * Generate code for a block.
 */

STATIC void blcodgen(block *bl)
{
    regm_t mfuncregsave = mfuncreg;
    char *sflsave = NULL;

    //dbg_printf("blcodgen(%p)\n",bl);

    /* Determine existing immediate values in registers by ANDing
        together the values from all the predecessors of b.
     */
    assert(bl->Bregcon.immed.mval == 0);
    regcon.immed.mval = 0;      // assume no previous contents in registers
//    regcon.cse.mval = 0;
    for (list_t bpl = bl->Bpred; bpl; bpl = list_next(bpl))
    {   block *bp = list_block(bpl);

        if (bpl == bl->Bpred)
        {   regcon.immed = bp->Bregcon.immed;
            regcon.params = bp->Bregcon.params;
//          regcon.cse = bp->Bregcon.cse;
        }
        else
        {   int i;

            regcon.params &= bp->Bregcon.params;
            if ((regcon.immed.mval &= bp->Bregcon.immed.mval) != 0)
                // Actual values must match, too
                for (i = 0; i < REGMAX; i++)
                {
                    if (regcon.immed.value[i] != bp->Bregcon.immed.value[i])
                        regcon.immed.mval &= ~mask[i];
                }
        }
    }
    regcon.cse.mops &= regcon.cse.mval;

    // Set regcon.mvar according to what variables are in registers for this block
    code* c = NULL;
    regcon.mvar = 0;
    regcon.mpvar = 0;
    regcon.indexregs = 1;
    int anyspill = 0;
    if (config.flags4 & CFG4optimized)
    {   SYMIDX i;
        code *cload = NULL;
        code *cstore = NULL;

        sflsave = (char *) alloca(globsym.top * sizeof(char));
        for (i = 0; i < globsym.top; i++)
        {   symbol *s = globsym.tab[i];

            sflsave[i] = s->Sfl;
            if ((s->Sclass == SCfastpar || s->Sclass == SCshadowreg) &&
                regcon.params & s->Spregm() &&
                vec_testbit(dfoidx,s->Srange))
            {
                regcon.used |= s->Spregm();
            }

            if (s->Sfl == FLreg)
            {   if (vec_testbit(dfoidx,s->Srange))
                {   regcon.mvar |= s->Sregm;
                    if (s->Sclass == SCfastpar || s->Sclass == SCshadowreg)
                        regcon.mpvar |= s->Sregm;
                }
            }
            else if (s->Sflags & SFLspill)
            {   if (vec_testbit(dfoidx,s->Srange))
                {
                    anyspill = i + 1;
                    cgreg_spillreg_prolog(bl,s,&cstore,&cload);
                    if (vec_testbit(dfoidx,s->Slvreg))
                    {   s->Sfl = FLreg;
                        regcon.mvar |= s->Sregm;
                        regcon.cse.mval &= ~s->Sregm;
                        regcon.immed.mval &= ~s->Sregm;
                        regcon.params &= ~s->Sregm;
                        if (s->Sclass == SCfastpar || s->Sclass == SCshadowreg)
                            regcon.mpvar |= s->Sregm;
                    }
                }
            }
        }
        if ((regcon.cse.mops & regcon.cse.mval) != regcon.cse.mops)
        {   code *cx;

            cx = cse_save(regcon.cse.mops & ~regcon.cse.mval);
            cstore = cat(cx, cstore);
        }
        c = cat(cstore,cload);
        mfuncreg &= ~regcon.mvar;               // use these registers
        regcon.used |= regcon.mvar;

        // Determine if we have more than 1 uncommitted index register
        regcon.indexregs = IDXREGS & ~regcon.mvar;
        regcon.indexregs &= regcon.indexregs - 1;
    }

    /* This doesn't work when calling the BC_finally function,
     * as it is one block calling another.
     */
    //regsave.idx = 0;

    reflocal = 0;
    int refparamsave = refparam;
    refparam = 0;
    assert((regcon.cse.mops & regcon.cse.mval) == regcon.cse.mops);

    outblkexitcode(bl, c, anyspill, sflsave, &retsym, mfuncregsave);

    for (int i = 0; i < anyspill; i++)
    {   symbol *s = globsym.tab[i];

        s->Sfl = sflsave[i];    // undo block register assignments
    }

    if (reflocal)
        bl->Bflags |= BFLreflocal;
    if (refparam)
        bl->Bflags |= BFLrefparam;
    refparam |= refparamsave;
    bl->Bregcon.immed = regcon.immed;
    bl->Bregcon.cse = regcon.cse;
    bl->Bregcon.used = regcon.used;
    bl->Bregcon.params = regcon.params;
#ifdef DEBUG
    debugw && printf("code gen complete\n");
#endif
}

/*****************************************
 * Add in exception handling code.
 */

#if SCPP

STATIC void cgcod_eh()
{   block *btry;
    code *c;
    code *c1;
    list_t stack;
    list_t list;
    block *b;
    int idx;
    int lastidx;
    int tryidx;
    int i;

    if (!(usednteh & (EHtry | EHcleanup)))
        return;

    // Compute Bindex for each block
    for (b = startblock; b; b = b->Bnext)
    {   b->Bindex = -1;
        b->Bflags &= ~BFLvisited;               /* mark as unvisited    */
    }
    btry = NULL;
    lastidx = 0;
    startblock->Bindex = 0;
    for (b = startblock; b; b = b->Bnext)
    {
        if (btry == b->Btry && b->BC == BCcatch)  // if don't need to pop try block
        {   block *br;

            br = list_block(b->Bpred);          // find corresponding try block
            assert(br->BC == BCtry);
            b->Bindex = br->Bindex;
        }
        else if (btry != b->Btry && b->BC != BCcatch ||
                 !(b->Bflags & BFLvisited))
            b->Bindex = lastidx;
        b->Bflags |= BFLvisited;
#ifdef DEBUG
        if (debuge)
        {
            WRBC(b->BC);
            dbg_printf(" block (%p) Btry=%p Bindex=%d\n",b,b->Btry,b->Bindex);
        }
#endif
        except_index_set(b->Bindex);
        if (btry != b->Btry)                    // exited previous try block
        {
            except_pop(b,NULL,btry);
            btry = b->Btry;
        }
        if (b->BC == BCtry)
        {
            except_push(b,NULL,b);
            btry = b;
            tryidx = except_index_get();
            b->Bcode = cat(nteh_gensindex(tryidx - 1),b->Bcode);
        }

        stack = NULL;
        for (c = b->Bcode; c; c = code_next(c))
        {
            if ((c->Iop & ESCAPEmask) == ESCAPE)
            {
                c1 = NULL;
                switch (c->Iop & 0xFFFF00)
                {
                    case ESCctor:
//printf("ESCctor\n");
                        except_push(c,c->IEV1.Vtor,NULL);
                        goto L1;

                    case ESCdtor:
//printf("ESCdtor\n");
                        except_pop(c,c->IEV1.Vtor,NULL);
                    L1: if (config.flags2 & CFG2seh)
                        {
                            c1 = nteh_gensindex(except_index_get() - 1);
                            code_next(c1) = code_next(c);
                            code_next(c) = c1;
                        }
                        break;
                    case ESCmark:
//printf("ESCmark\n");
                        idx = except_index_get();
                        list_prependdata(&stack,idx);
                        except_mark();
                        break;
                    case ESCrelease:
//printf("ESCrelease\n");
                        idx = list_data(stack);
                        list_pop(&stack);
                        if (idx != except_index_get())
                        {
                            if (config.flags2 & CFG2seh)
                            {   c1 = nteh_gensindex(idx - 1);
                                code_next(c1) = code_next(c);
                                code_next(c) = c1;
                            }
                            else
                            {   except_pair_append(c,idx - 1);
                                c->Iop = ESCAPE | ESCoffset;
                            }
                        }
                        except_release();
                        break;
                    case ESCmark2:
//printf("ESCmark2\n");
                        except_mark();
                        break;
                    case ESCrelease2:
//printf("ESCrelease2\n");
                        except_release();
                        break;
                }
            }
        }
        assert(stack == NULL);
        b->Bendindex = except_index_get();

        if (b->BC != BCret && b->BC != BCretexp)
            lastidx = b->Bendindex;

        // Set starting index for each of the successors
        i = 0;
        for (list = b->Bsucc; list; list = list_next(list))
        {   block *bs = list_block(list);

            if (b->BC == BCtry)
            {   switch (i)
                {   case 0:                             // block after catches
                        bs->Bindex = b->Bendindex;
                        break;
                    case 1:                             // 1st catch block
                        bs->Bindex = tryidx;
                        break;
                    default:                            // subsequent catch blocks
                        bs->Bindex = b->Bindex;
                        break;
                }
#ifdef DEBUG
                if (debuge)
                {
                    dbg_printf(" 1setting %p to %d\n",bs,bs->Bindex);
                }
#endif
            }
            else if (!(bs->Bflags & BFLvisited))
            {
                bs->Bindex = b->Bendindex;
#ifdef DEBUG
                if (debuge)
                {
                    dbg_printf(" 2setting %p to %d\n",bs,bs->Bindex);
                }
#endif
            }
            bs->Bflags |= BFLvisited;
            i++;
        }
    }

    if (config.flags2 & CFG2seh)
        for (b = startblock; b; b = b->Bnext)
        {
            if (/*!b->Bcount ||*/ b->BC == BCtry)
                continue;
            for (list = b->Bpred; list; list = list_next(list))
            {   int pi;

                pi = list_block(list)->Bendindex;
                if (b->Bindex != pi)
                {
                    b->Bcode = cat(nteh_gensindex(b->Bindex - 1),b->Bcode);
                    break;
                }
            }
        }
}

#endif

/******************************
 * Count the number of bits set in a register mask.
 */

int numbitsset(regm_t regm)
{
    int n = 0;
    if (regm)
        do
            n++;
        while ((regm &= regm - 1) != 0);
    return n;
}

/******************************
 * Given a register mask, find and return the number
 * of the first register that fits.
 */

#undef findreg

unsigned findreg(regm_t regm
#ifdef DEBUG
        ,int line,const char *file
#endif
        )
#ifdef DEBUG
#define findreg(regm) findreg((regm),__LINE__,__FILE__)
#endif
{
#ifdef DEBUG
    regm_t regmsave = regm;
#endif
    int i = 0;
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
#ifdef DEBUG
  printf("findreg(%s, line=%d, file='%s', function = '%s')\n",regm_str(regmsave),line,file,funcsym_p->Sident);
  fflush(stdout);
#endif
//*(char*)0=0;
  assert(0);
  return 0;
}

/***************
 * Free element (but not it's leaves! (assume they are already freed))
 * Don't decrement Ecount! This is so we can detect if the common subexp
 * has already been evaluated.
 * If common subexpression is not required anymore, eliminate
 * references to it.
 */

void freenode(elem *e)
{
    elem_debug(e);
    //dbg_printf("freenode(%p) : comsub = %d, count = %d\n",e,e->Ecomsub,e->Ecount);
    if (e->Ecomsub--) return;             /* usage count                  */
    if (e->Ecount)                        /* if it was a CSE              */
    {
        for (unsigned i = 0; i < arraysize(regcon.cse.value); i++)
        {   if (regcon.cse.value[i] == e)       /* if a register is holding it  */
            {   regcon.cse.mval &= ~mask[i];
                regcon.cse.mops &= ~mask[i];    /* free masks                   */
            }
        }
        for (unsigned i = 0; i < cstop; i++)
        {   if (csextab[i].e == e)
                csextab[i].e = NULL;
        }
    }
}

/*********************************
 * Reset Ecomsub for all elem nodes, i.e. reverse the effects of freenode().
 */

STATIC void resetEcomsub(elem *e)
{
    while (1)
    {
        elem_debug(e);
        e->Ecomsub = e->Ecount;
        unsigned op = e->Eoper;
        if (!OTleaf(op))
        {   if (OTbinary(op))
                resetEcomsub(e->E2);
            e = e->E1;
        }
        else
            break;
    }
}

/*********************************
 * Determine if elem e is a register variable.
 * If so:
 *      *pregm = mask of registers that make up the variable
 *      *preg = the least significant register
 *      returns TRUE
 * Else
 *      returns FALSE
 */

int isregvar(elem *e,regm_t *pregm,unsigned *preg)
{   symbol *s;
    unsigned u;
    regm_t m;
    regm_t regm;
    unsigned reg;

    elem_debug(e);
    if (e->Eoper == OPvar || e->Eoper == OPrelconst)
    {
        s = e->EV.sp.Vsym;
        switch (s->Sfl)
        {   case FLreg:
                if (s->Sclass == SCparameter)
                {   refparam = TRUE;
                    reflocal = TRUE;
                }
                reg = s->Sreglsw;
                regm = s->Sregm;
                //assert(tyreg(s->ty()));
#if 0
                // Let's just see if there is a CSE in a reg we can use
                // instead. This helps avoid AGI's.
                if (e->Ecount && e->Ecount != e->Ecomsub)
                {   int i;

                    for (i = 0; i < arraysize(regcon.cse.value); i++)
                    {
                        if (regcon.cse.value[i] == e)
                        {   reg = i;
                            break;
                        }
                    }
                }
#endif
                assert(regm & regcon.mvar && !(regm & ~regcon.mvar));
                goto Lreg;

            case FLpseudo:
#if MARS
                assert(0);
#else
                u = s->Sreglsw;
                m = pseudomask[u];
                if (m & ALLREGS && (u & ~3) != 4) // if not BP,SP,EBP,ESP,or ?H
                {   reg = pseudoreg[u] & 7;
                    regm = m;
                    goto Lreg;
                }
#endif
                break;
        }
    }
    return FALSE;

Lreg:
    if (preg)
        *preg = reg;
    if (pregm)
        *pregm = regm;
    return TRUE;
}

/*********************************
 * Allocate some registers.
 * Input:
 *      pretregs        Pointer to mask of registers to make selection from.
 *      tym             Mask of type we will store in registers.
 * Output:
 *      *pretregs       Mask of allocated registers.
 *      *preg           Register number of first allocated register.
 *      msavereg,mfuncreg       retregs bits are cleared.
 *      regcon.cse.mval,regcon.cse.mops updated
 * Returns:
 *      pointer to code generated if necessary to save any regcon.cse.mops on the
 *      stack.
 */

#undef allocreg

code *allocreg(regm_t *pretregs,unsigned *preg,tym_t tym
#ifdef DEBUG
        ,int line,const char *file
#endif
        )
#ifdef DEBUG
#define allocreg(a,b,c) allocreg((a),(b),(c),__LINE__,__FILE__)
#endif
{
#if TX86
        unsigned reg;

#if 0
        if (pass == PASSfinal)
        {
            dbg_printf("allocreg %s,%d: regcon.mvar %s regcon.cse.mval %s msavereg %s *pretregs %s tym ",
                file,line,regm_str(regcon.mvar),regm_str(regcon.cse.mval),
                regm_str(msavereg),regm_str(*pretregs));
            WRTYxx(tym);
            dbg_printf("\n");
        }
#endif
        tym = tybasic(tym);
        unsigned size = tysize[tym];
        *pretregs &= mES | allregs | XMMREGS;
        regm_t retregs = *pretregs;
        if ((retregs & regcon.mvar) == retregs) // if exactly in reg vars
        {
            if (size <= REGSIZE || (retregs & XMMREGS))
            {   *preg = findreg(retregs);
                assert(retregs == mask[*preg]); /* no more bits are set */
            }
            else if (size <= 2 * REGSIZE)
            {   *preg = findregmsw(retregs);
                assert(retregs & mLSW);
            }
            else
                assert(0);
            return getregs(retregs);
        }
        int count = 0;
L1:
        //printf("L1: allregs = %s, *pretregs = %s\n", regm_str(allregs), regm_str(*pretregs));
        assert(++count < 20);           /* fail instead of hanging if blocked */
        assert(retregs);
        unsigned msreg = -1, lsreg = -1;  /* no value assigned yet        */
L3:
        //printf("L2: allregs = %s, *pretregs = %s\n", regm_str(allregs), regm_str(*pretregs));
        regm_t r = retregs & ~(msavereg | regcon.cse.mval | regcon.params);
        if (!r)
        {
            r = retregs & ~(msavereg | regcon.cse.mval);
            if (!r)
            {
                r = retregs & ~(msavereg | regcon.cse.mops);
                if (!r)
                {   r = retregs & ~msavereg;
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
            if (!regcon.indexregs && r & ~mLSW)
                r &= ~mLSW;

            if (pass == PASSfinal && r & ~lastretregs && !I16)
            {   // Try not to always allocate the same register,
                // to schedule better

                r &= ~lastretregs;
                if (r & ~last2retregs)
                {   r &= ~last2retregs;
                    if (r & ~last3retregs)
                    {   r &= ~last3retregs;
                        if (r & ~last4retregs)
                        {   r &= ~last4retregs;
//                          if (r & ~last5retregs)
//                              r &= ~last5retregs;
                        }
                    }
                }
                if (r & ~mfuncreg)
                    r &= ~mfuncreg;
            }
            reg = findreg(r);
            retregs = mask[reg];
        }
        else if (size <= 2 * REGSIZE)
        {
            /* Select pair with both regs free. Failing */
            /* that, select pair with one reg free.             */

            if (r & mBP)
            {   retregs &= ~mBP;
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
                else if (lsreg == -1)   /* if don't have LSW yet */
                {       retregs &= mLSW;
                    goto L3;
                }
            }
            else
            {
                if (I64 && !(r & mLSW))
                {   retregs = *pretregs & (mMSW | mLSW);
                    assert(retregs);
                    goto L1;
                }
                lsreg = findreglsw(r);
                if (msreg == -1)
                {   retregs &= mMSW;
                    assert(retregs);
                    goto L3;
                }
            }
            reg = (msreg == ES) ? lsreg : msreg;
            retregs = mask[msreg] | mask[lsreg];
        }
        else if (I16 && (tym == TYdouble || tym == TYdouble_alias))
        {
#ifdef DEBUG
            if (retregs != DOUBLEREGS)
                printf("retregs = %s, *pretregs = %s\n", regm_str(retregs), regm_str(*pretregs));
#endif
            assert(retregs == DOUBLEREGS);
            reg = AX;
        }
        else
        {
#ifdef DEBUG
            WRTYxx(tym);
            printf("\nallocreg: fil %s lin %d, regcon.mvar %s msavereg %s *pretregs %s, reg %d, tym x%x\n",
                file,line,regm_str(regcon.mvar),regm_str(msavereg),regm_str(*pretregs),*preg,tym);
#endif
            assert(0);
        }
        if (retregs & regcon.mvar)              // if conflict with reg vars
        {
            if (!(size > REGSIZE && *pretregs == (mAX | mDX)))
            {
                retregs = (*pretregs &= ~(retregs & regcon.mvar));
                goto L1;                // try other registers
            }
        }
        *preg = reg;
        *pretregs = retregs;

        //printf("Allocating %s\n",regm_str(retregs));
        last5retregs = last4retregs;
        last4retregs = last3retregs;
        last3retregs = last2retregs;
        last2retregs = lastretregs;
        lastretregs = retregs;
        return getregs(retregs);
#else
#warning cpu specific code
#endif
}

/*************************
 * Mark registers as used.
 */

void useregs(regm_t regm)
{
    //printf("useregs(x%x) %s\n", regm, regm_str(regm));
    mfuncreg &= ~regm;
    regcon.used |= regm;                // registers used in this block
    regcon.params &= ~regm;
    if (regm & regcon.mpvar)            // if modified a fastpar register variable
        regcon.params = 0;              // toss them all out
}

/*************************
 * We are going to use the registers in mask r.
 * Generate any code necessary to save any regs.
 */

code *getregs(regm_t r)
{
    //printf("getregs(x%x) %s\n", r, regm_str(r));
    regm_t ms = r & regcon.cse.mops;           // mask of common subs we must save
    useregs(r);
    regcon.cse.mval &= ~r;
    msavereg &= ~r;                     // regs that are destroyed
    regcon.immed.mval &= ~r;
    return ms ? cse_save(ms) : NULL;
}

/*****************************************
 * Copy registers in cse.mops into memory.
 */

STATIC code * cse_save(regm_t ms)
{
    code *c = NULL;

    assert((ms & regcon.cse.mops) == ms);
    regcon.cse.mops &= ~ms;

    /* Skip CSEs that are already saved */
    for (regm_t regm = 1; regm < mask[NUMREGS]; regm <<= 1)
    {
        if (regm & ms)
        {
            elem *e = regcon.cse.value[findreg(regm)];
            for (unsigned i = 0; i < csmax; i++)
            {
                if (csextab[i].e == e)
                {
                    tym_t tym = e->Ety;
                    unsigned sz = tysize(tym);
                    if (sz <= REGSIZE ||
                        sz <= 2 * REGSIZE &&
                            (regm & mMSW && csextab[i].regm & mMSW ||
                             regm & mLSW && csextab[i].regm & mLSW) ||
                        sz == 4 * REGSIZE && regm == csextab[i].regm
                       )
                    {
                        ms &= ~regm;
                        if (!ms)
                            goto Lret;
                        break;
                    }
                }
            }
        }
    }

    for (unsigned i = cstop; ms; i++)
    {
        if (i >= csmax)                 /* array overflow               */
        {   unsigned cseinc;

#ifdef DEBUG
            cseinc = 8;                 /* flush out reallocation bugs  */
#else
            cseinc = csmax + 32;
#endif
            csextab = (struct CSE *) util_realloc(csextab,
                (csmax + cseinc), sizeof(csextab[0]));
            memset(&csextab[csmax],0,cseinc * sizeof(csextab[0]));
            csmax += cseinc;
            goto L1;
        }
        if (i >= cstop)
        {
            memset(&csextab[cstop],0,sizeof(csextab[0]));
            goto L1;
        }
        if (csextab[i].e == NULL || i >= cstop)
        {
        L1:
            unsigned reg = findreg(ms);          /* the register to save         */
            csextab[i].e = regcon.cse.value[reg];
            csextab[i].regm = mask[reg];
            csextab[i].flags &= CSEload;
            if (i >= cstop)
                cstop = i + 1;

            ms &= ~mask[reg];           /* turn off reg bit in ms       */

            // If we can simply reload the CSE, we don't need to save it
            if (cse_simple(&csextab[i].csimple, csextab[i].e))
                csextab[i].flags |= CSEsimple;
            else
            {
                c = cat(c, gensavereg(reg, i));
                reflocal = TRUE;
            }
        }
    }
Lret:
    return c;
}

/******************************************
 * Getregs without marking immediate register values as gone.
 */

code *getregs_imm(regm_t r)
{
    regm_t save = regcon.immed.mval;
    code* c = getregs(r);
    regcon.immed.mval = save;
    return c;
}

/******************************************
 * Flush all CSE's out of registers and into memory.
 * Input:
 *      do87    !=0 means save 87 registers too
 */

code *cse_flush(int do87)
{
    //dbg_printf("cse_flush()\n");
    code* c = cse_save(regcon.cse.mops);      // save any CSEs to memory
    if (do87)
        c = cat(c,save87());    // save any 8087 temporaries
    return c;
}

/*************************
 * Common subexpressions exist in registers. Note this in regcon.cse.mval.
 * Input:
 *      e       the subexpression
 *      regm    mask of registers holding it
 *      opsflag if != 0 then regcon.cse.mops gets set too
 * Returns:
 *      false   not saved as a CSE
 *      true    saved as a CSE
 */

bool cssave(elem *e,regm_t regm,unsigned opsflag)
{
    bool result = false;

    /*if (e->Ecount && e->Ecount == e->Ecomsub)*/
    if (e->Ecount && e->Ecomsub)
    {
        if (!opsflag && pass != PASSfinal && (I32 || I64))
            return false;

        //printf("cssave(e = %p, regm = %s, opsflag = x%x)\n", e, regm_str(regm), opsflag);
        regm &= mBP | ALLREGS | mES;    /* just to be sure              */

#if 0
        /* Do not register CSEs if they are register variables and      */
        /* are not operator nodes. This forces the register allocation  */
        /* to go through allocreg(), which will prevent using register  */
        /* variables for scratch.                                       */
        if (opsflag || !(regm & regcon.mvar))
#endif
            for (unsigned i = 0; regm; i++)
            {
                regm_t mi = mask[i];
                if (regm & mi)
                {
                    regm &= ~mi;

                    // If we don't need this CSE, and the register already
                    // holds a CSE that we do need, don't mark the new one
                    if (regcon.cse.mval & mi && regcon.cse.value[i] != e &&
                        !opsflag && regcon.cse.mops & mi)
                        continue;

                    regcon.cse.mval |= mi;
                    if (opsflag)
                        regcon.cse.mops |= mi;
                    //printf("cssave set: regcon.cse.value[%s] = %p\n",regstring[i],e);
                    regcon.cse.value[i] = e;
                    result = true;
                }
            }
    }
    return result;
}

/*************************************
 * Determine if a computation should be done into a register.
 */

bool evalinregister(elem *e)
{
    if (config.exe == EX_WIN64 && e->Eoper == OPrelconst)
        return TRUE;

    if (e->Ecount == 0)             /* elem is not a CSE, therefore */
                                    /* we don't need to evaluate it */
                                    /* in a register                */
        return FALSE;
    if (EOP(e))                     /* operators are always in register */
        return TRUE;

    // Need to rethink this code if float or double can be CSE'd
    unsigned sz = tysize(e->Ety);
    if (e->Ecount == e->Ecomsub)    /* elem is a CSE that needs     */
                                    /* to be generated              */
    {
        if ((I32 || I64) &&
            //pass == PASSfinal && // bug 8987
            sz <= REGSIZE)
        {
            // Do it only if at least 2 registers are available
            regm_t m = allregs & ~regcon.mvar;
            if (sz == 1)
                m &= BYTEREGS;
            if (m & (m - 1))        // if more than one register
            {   // Need to be at least 3 registers available, as
                // addressing modes can use up 2.
                while (!(m & 1))
                    m >>= 1;
                m >>= 1;
                if (m & (m - 1))
                    return TRUE;
            }
        }
        return FALSE;
    }

    /* Elem is now a CSE that might have been generated. If so, and */
    /* it's in a register already, the computation should be done   */
    /* using that register.                                         */
    regm_t emask = 0;
    for (unsigned i = 0; i < arraysize(regcon.cse.value); i++)
        if (regcon.cse.value[i] == e)
            emask |= mask[i];
    emask &= regcon.cse.mval;       // mask of available CSEs
    if (sz <= REGSIZE)
        return emask != 0;      /* the CSE is in a register     */
    else if (sz <= 2 * REGSIZE)
        return (emask & mMSW) && (emask & mLSW);
    return TRUE;                    /* cop-out for now              */
}

/*******************************************************
 * Return mask of scratch registers.
 */

regm_t getscratch()
{
    regm_t scratch = 0;
    if (pass == PASSfinal)
    {
        scratch = allregs & ~(regcon.mvar | regcon.mpvar | regcon.cse.mval |
                regcon.immed.mval | regcon.params | mfuncreg);
    }
    return scratch;
}

/******************************
 * Evaluate an elem that is a common subexp that has been encountered
 * before.
 * Look first to see if it is already in a register.
 */

STATIC code * comsub(elem *e,regm_t *pretregs)
{   tym_t tym;
    regm_t regm,emask,csemask;
    unsigned reg,i,byte,sz;

    //printf("comsub(e = %p, *pretregs = %s)\n",e,regm_str(*pretregs));
    elem_debug(e);
#ifdef DEBUG
    //if (e->Ecomsub > e->Ecount)
        //elem_print(e);
#endif
    assert(e->Ecomsub <= e->Ecount);

    code* c = CNIL;
    if (*pretregs == 0) goto done;        /* no possible side effects anyway */

    if (tyfloating(e->Ety) && config.inline8087)
        return comsub87(e,pretregs);

  /* First construct a mask, emask, of all the registers that   */
  /* have the right contents.                                   */

  emask = 0;
  for (unsigned i = 0; i < arraysize(regcon.cse.value); i++)
  {
        //dbg_printf("regcon.cse.value[%d] = %p\n",i,regcon.cse.value[i]);
        if (regcon.cse.value[i] == e)   /* if contents are right        */
                emask |= mask[i];       /* turn on bit for reg          */
  }
  emask &= regcon.cse.mval;                     /* make sure all bits are valid */

  /* create mask of what's in csextab[] */
  csemask = 0;
  for (unsigned i = 0; i < cstop; i++)
  {     if (csextab[i].e)
            elem_debug(csextab[i].e);
        if (csextab[i].e == e)
                csemask |= csextab[i].regm;
  }
  csemask &= ~emask;            /* stuff already in registers   */

#ifdef DEBUG
if (debugw)
{
printf("comsub(e=%p): *pretregs=%s, emask=%s, csemask=%s, regcon.cse.mval=%s, regcon.mvar=%s\n",
        e,regm_str(*pretregs),regm_str(emask),regm_str(csemask),regm_str(regcon.cse.mval),regm_str(regcon.mvar));
if (regcon.cse.mval & 1) elem_print(regcon.cse.value[0]);
}
#endif

  tym = tybasic(e->Ety);
  sz = tysize[tym];
  byte = sz == 1;

  if (sz <= REGSIZE || tyvector(tym))                   // if data will fit in one register
  {
        /* First see if it is already in a correct register     */

        regm = emask & *pretregs;
        if (regm == 0)
                regm = emask;           /* try any other register       */
        if (regm)                       /* if it's in a register        */
        {
            if (EOP(e) || !(regm & regcon.mvar) || (*pretregs & regcon.mvar) == *pretregs)
            {
                regm = mask[findreg(regm)];
                goto fix;
            }
        }

        if (!EOP(e))                    /* if not op or func            */
                goto reload;            /* reload data                  */
        for (unsigned i = cstop; i--;)           /* look through saved comsubs   */
                if (csextab[i].e == e)  /* found it             */
                {   regm_t retregs;

                    if (csextab[i].flags & CSEsimple)
                    {   code *cr;

                        retregs = *pretregs;
                        if (byte && !(retregs & BYTEREGS))
                            retregs = BYTEREGS;
                        else if (!(retregs & allregs))
                            retregs = allregs;
                        c = allocreg(&retregs,&reg,tym);
                        cr = &csextab[i].csimple;
                        cr->setReg(reg);
                        c = gen(c,cr);
                        goto L10;
                    }
                    else
                    {
                        reflocal = TRUE;
                        csextab[i].flags |= CSEload;
                        if (*pretregs == mPSW)  /* if result in CCs only */
                        {                       // CMP cs[BP],0
                            c = gen_testcse(NULL, sz, i);
                        }
                        else
                        {
                            retregs = *pretregs;
                            if (byte && !(retregs & BYTEREGS))
                                    retregs = BYTEREGS;
                            c = allocreg(&retregs,&reg,tym);
                            c = gen_loadcse(c, reg, i);
                        L10:
                            regcon.cse.mval |= mask[reg]; // cs is in a reg
                            regcon.cse.value[reg] = e;
                            c = cat(c,fixresult(e,retregs,pretregs));
                        }
                    }
                    freenode(e);
                    return c;
                }
#ifdef DEBUG
        printf("couldn't find cse e = %p, pass = %d\n",e,pass);
        elem_print(e);
#endif
        assert(0);                      /* should have found it         */
  }
  else                                  /* reg pair is req'd            */
  if (sz <= 2 * REGSIZE)
  {     unsigned msreg,lsreg;

        /* see if we have both  */
        if (!((emask | csemask) & mMSW && (emask | csemask) & (mLSW | mBP)))
        {                               /* we don't have both           */
#if DEBUG
                if (EOP(e))
                {
                    printf("e = %p, op = x%x, emask = %s, csemask = %s\n",
                        e,e->Eoper,regm_str(emask),regm_str(csemask));
                    //printf("mMSW = x%x, mLSW = x%x\n", mMSW, mLSW);
                    elem_print(e);
                }
#endif
                assert(!EOP(e));        /* must have both for operators */
                goto reload;
        }

        /* Look for right vals in any regs      */

        regm = *pretregs & mMSW;
        if (emask & regm)
            msreg = findreg(emask & regm);
        else if (emask & mMSW)
            msreg = findregmsw(emask);
        else                    /* reload from cse array        */
        {
            if (!regm)
                regm = mMSW & ALLREGS;
            c = allocreg(&regm,&msreg,TYint);
            c = cat(c,loadcse(e,msreg,mMSW));
        }

        regm = *pretregs & (mLSW | mBP);
        if (emask & regm)
            lsreg = findreg(emask & regm);
        else if (emask & (mLSW | mBP))
            lsreg = findreglsw(emask);
        else
        {
            if (!regm)
                regm = mLSW;
            c = cat(c,allocreg(&regm,&lsreg,TYint));
            c = cat(c,loadcse(e,lsreg,mLSW | mBP));
        }

        regm = mask[msreg] | mask[lsreg];       /* mask of result       */
        goto fix;
  }
  else if (tym == TYdouble || tym == TYdouble_alias)    // double
  {
        assert(I16);
        if (((csemask | emask) & DOUBLEREGS_16) == DOUBLEREGS_16)
        {
            for (reg = 0; reg != -1; reg = dblreg[reg])
            {   assert((int) reg >= 0 && reg <= 7);
                if (mask[reg] & csemask)
                    c = cat(c,loadcse(e,reg,mask[reg]));
            }
            regm = DOUBLEREGS_16;
            goto fix;
        }
        if (!EOP(e)) goto reload;
#if DEBUG
        printf("e = %p, csemask = %s, emask = %s\n",e,regm_str(csemask),regm_str(emask));
#endif
        assert(0);
  }
  else
  {
#if DEBUG
        printf("e = %p, tym = x%x\n",e,tym);
#endif
        assert(0);
  }

reload:                                 /* reload result from memory    */
    switch (e->Eoper)
    {
        case OPrelconst:
            c = cdrelconst(e,pretregs);
            break;
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        case OPgot:
            c = cdgot(e,pretregs);
            break;
#endif
        default:
            c = loaddata(e,pretregs);
            break;
    }
    cssave(e,*pretregs,FALSE);
    freenode(e);
    return c;

fix:                                    /* we got result in regm, fix   */
  c = cat(c,fixresult(e,regm,pretregs));
done:
  freenode(e);
  return c;
}


/*****************************
 * Load reg from cse stack.
 * Returns:
 *      pointer to the MOV instruction
 */

STATIC code * loadcse(elem *e,unsigned reg,regm_t regm)
{
  for (unsigned i = cstop; i--;)
  {
        //printf("csextab[%d] = %p, regm = %s\n", i, csextab[i].e, regm_str(csextab[i].regm));
        if (csextab[i].e == e && csextab[i].regm & regm)
        {
                reflocal = TRUE;
                csextab[i].flags |= CSEload;    /* it was loaded        */
                regcon.cse.value[reg] = e;
                regcon.cse.mval |= mask[reg];
                code *c = getregs(mask[reg]);
                return gen_loadcse(c, reg, i);
        }
  }
#if DEBUG
  printf("loadcse(e = %p, reg = %d, regm = %s)\n",e,reg,regm_str(regm));
elem_print(e);
#endif
  assert(0);
  /* NOTREACHED */
  return 0;
}

/***************************
 * Generate code sequence for an elem.
 * Input:
 *      pretregs        mask of possible registers to return result in
 *                      Note:   longs are in AX,BX or CX,DX or SI,DI
 *                              doubles are AX,BX,CX,DX only
 *      constflag       TRUE if user of result will not modify the
 *                      registers returned in *pretregs.
 * Output:
 *      *pretregs       mask of registers result is returned in
 * Returns:
 *      pointer to code sequence generated
 */

#include "cdxxx.c"                      /* jump table                   */

code *codelem(elem *e,regm_t *pretregs,bool constflag)
{ code *c;
  Symbol *s;

#ifdef DEBUG
  if (debugw)
  {     printf("+codelem(e=%p,*pretregs=%s) ",e,regm_str(*pretregs));
        WROP(e->Eoper);
        printf("msavereg=%s regcon.cse.mval=%s regcon.cse.mops=%s\n",
                regm_str(msavereg),regm_str(regcon.cse.mval),regm_str(regcon.cse.mops));
        printf("Ecount = %d, Ecomsub = %d\n", e->Ecount, e->Ecomsub);
  }
#endif
  assert(e);
  elem_debug(e);
  if ((regcon.cse.mops & regcon.cse.mval) != regcon.cse.mops)
  {
#ifdef DEBUG
        printf("+codelem(e=%p,*pretregs=%s) ", e, regm_str(*pretregs));
        elem_print(e);
        printf("msavereg=%s regcon.cse.mval=%s regcon.cse.mops=%s\n",
                regm_str(msavereg),regm_str(regcon.cse.mval),regm_str(regcon.cse.mops));
        printf("Ecount = %d, Ecomsub = %d\n", e->Ecount, e->Ecomsub);
#endif
        assert(0);
  }

  if (!constflag && *pretregs & (mES | ALLREGS | mBP | XMMREGS) & ~regcon.mvar)
        *pretregs &= ~regcon.mvar;                      /* can't use register vars */
  unsigned op = e->Eoper;
  if (e->Ecount && e->Ecount != e->Ecomsub)     /* if common subexp     */
  {     c = comsub(e,pretregs);
        goto L1;
  }

  switch (op)
  {
    default:
        if (e->Ecount)                          /* if common subexp     */
        {
            /* if no return value       */
            if ((*pretregs & (mSTACK | mES | ALLREGS | mBP)) == 0)
            {   if (tysize(e->Ety) == 1)
                    *pretregs |= BYTEREGS;
                else if (tybasic(e->Ety) == TYdouble || tybasic(e->Ety) == TYdouble_alias)
                    *pretregs |= DOUBLEREGS;
                else
                    *pretregs |= ALLREGS;       /* make one             */
            }

            /* BUG: For CSEs, make sure we have both an MSW             */
            /* and an LSW specified in *pretregs                        */
        }
        assert(op <= OPMAX);
        c = (*cdxxx[op])(e,pretregs);
        break;
    case OPrelconst:
        c = cdrelconst(e,pretregs);
        break;
    case OPvar:
        if (constflag && (s = e->EV.sp.Vsym)->Sfl == FLreg &&
            (s->Sregm & *pretregs) == s->Sregm)
        {
            if (tysize(e->Ety) <= REGSIZE && tysize(s->Stype->Tty) == 2 * REGSIZE)
                *pretregs &= mPSW | (s->Sregm & mLSW);
            else
                *pretregs &= mPSW | s->Sregm;
        }
    case OPconst:
        if (*pretregs == 0 && (e->Ecount >= 3 || e->Ety & mTYvolatile))
        {
            switch (tybasic(e->Ety))
            {
                case TYbool:
                case TYchar:
                case TYschar:
                case TYuchar:
                    *pretregs |= BYTEREGS;
                    break;

                case TYnptr:
#if TARGET_SEGMENTED
                case TYsptr:
                case TYcptr:
#endif
                    *pretregs |= IDXREGS;
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
#if TARGET_SEGMENTED
                case TYfptr:
                case TYhptr:
                case TYvptr:
#endif
                    *pretregs |= ALLREGS;
                    break;
            }
        }
        c = loaddata(e,pretregs);
        break;
  }
  cssave(e,*pretregs,!OTleaf(op));
  freenode(e);
L1:
#ifdef DEBUG
  if (debugw)
  {     printf("-codelem(e=%p,*pretregs=%s) ",e,regm_str(*pretregs));
        WROP(op);
        printf("msavereg=%s regcon.cse.mval=%s regcon.cse.mops=%s\n",
                regm_str(msavereg),regm_str(regcon.cse.mval),regm_str(regcon.cse.mops));
  }
#endif
    if (configv.addlinenumbers && e->Esrcpos.Slinnum)
        cgen_prelinnum(&c,e->Esrcpos);
    return c;
}

/*******************************
 * Same as codelem(), but do not destroy the registers in keepmsk.
 * Use scratch registers as much as possible, then use stack.
 * Input:
 *      constflag       TRUE if user of result will not modify the
 *                      registers returned in *pretregs.
 */

code *scodelem(elem *e,regm_t *pretregs,regm_t keepmsk,bool constflag)
{ code *c,*cs1,*cs2,*cs3;
  regm_t touse;

#ifdef DEBUG
    if (debugw)
        printf("+scodelem(e=%p *pretregs=%s keepmsk=%s constflag=%d\n",
                e,regm_str(*pretregs),regm_str(keepmsk),constflag);
#endif
  elem_debug(e);
  if (constflag)
  {     regm_t regm;
        unsigned reg;

        if (isregvar(e,&regm,&reg) &&           // if e is a register variable
            (regm & *pretregs) == regm &&       // in one of the right regs
            e->EV.sp.Voffset == 0
           )
        {
                unsigned sz1 = tysize(e->Ety);
                unsigned sz2 = tysize(e->EV.sp.Vsym->Stype->Tty);
                if (sz1 <= REGSIZE && sz2 > REGSIZE)
                    regm &= mLSW | XMMREGS;
                c = fixresult(e,regm,pretregs);
                cssave(e,regm,0);
                freenode(e);
#ifdef DEBUG
                if (debugw)
                    printf("-scodelem(e=%p *pretregs=%s keepmsk=%s constflag=%d\n",
                            e,regm_str(*pretregs),regm_str(keepmsk),constflag);
#endif
                return c;
        }
  }
  regm_t overlap = msavereg & keepmsk;
  msavereg |= keepmsk;          /* add to mask of regs to save          */
  regm_t oldregcon = regcon.cse.mval;
  regm_t oldregimmed = regcon.immed.mval;
  regm_t oldmfuncreg = mfuncreg;       /* remember old one                     */
  mfuncreg = (XMMREGS | mBP | mES | ALLREGS) & ~regcon.mvar;
  unsigned stackpushsave = stackpush;
  char calledafuncsave = calledafunc;
  calledafunc = 0;
  c = codelem(e,pretregs,constflag);    /* generate code for the elem   */

  regm_t tosave = keepmsk & ~msavereg; /* registers to save                    */
  if (tosave)
  {     cgstate.stackclean++;
        c = genstackclean(c,stackpush - stackpushsave,*pretregs | msavereg);
        cgstate.stackclean--;
  }

  /* Assert that no new CSEs are generated that are not reflected       */
  /* in mfuncreg.                                                       */
#ifdef DEBUG
  if ((mfuncreg & (regcon.cse.mval & ~oldregcon)) != 0)
        printf("mfuncreg %s, regcon.cse.mval %s, oldregcon %s, regcon.mvar %s\n",
                regm_str(mfuncreg),regm_str(regcon.cse.mval),regm_str(oldregcon),regm_str(regcon.mvar));
#endif
  assert((mfuncreg & (regcon.cse.mval & ~oldregcon)) == 0);

  /* bugzilla 3521
   * The problem is:
   *    reg op (reg = exp)
   * where reg must be preserved (in keepregs) while the expression to be evaluated
   * must change it.
   * The only solution is to make this variable not a register.
   */
  if (regcon.mvar & tosave)
  {
        //elem_print(e);
        //printf("test1: regcon.mvar %s tosave %s\n", regm_str(regcon.mvar), regm_str(tosave));
        cgreg_unregister(regcon.mvar & tosave);
  }

  /* which registers can we use to save other registers in? */
  if (config.flags4 & CFG4space ||              // if optimize for space
      config.target_cpu >= TARGET_80486)        // PUSH/POP ops are 1 cycle
        touse = 0;                              // PUSH/POP pairs are always shorter
  else
  {     touse = mfuncreg & allregs & ~(msavereg | oldregcon | regcon.cse.mval);
        /* Don't use registers we'll have to save/restore               */
        touse &= ~(fregsaved & oldmfuncreg);
        /* Don't use registers that have constant values in them, since
           the code generated might have used the value.
         */
        touse &= ~oldregimmed;
  }

  cs1 = cs2 = cs3 = NULL;
  int adjesp = 0;

  for (unsigned i = 0; tosave; i++)
  {     regm_t mi = mask[i];

        assert(i < REGMAX);
        if (mi & tosave)        /* i = register to save                 */
        {
            if (touse)          /* if any scratch registers             */
            {
                unsigned j;
                for (j = 0; j < 8; j++)
                {   regm_t mj = mask[j];

                    if (touse & mj)
                    {   cs1 = genmovreg(cs1,j,i);
                        cs2 = cat(genmovreg(CNIL,i,j),cs2);
                        touse &= ~mj;
                        mfuncreg &= ~mj;
                        regcon.used |= mj;
                        break;
                    }
                }
                assert(j < 8);
            }
            else                        // else use memory
            {
                unsigned size = gensaverestore2(mask[i], &cs1, &cs2);
                if (size)
                {
                    stackchanged = 1;
                    adjesp += size;
                }
            }
            cs3 = cat(getregs(mi),cs3);
            tosave &= ~mi;
        }
  }
  if (adjesp)
  {
        // If this is done an odd number of times, it
        // will throw off the 8 byte stack alignment.
        // We should *only* worry about this if a function
        // was called in the code generation by codelem().
        int sz;
        if (STACKALIGN == 16)
            sz = -(adjesp & (STACKALIGN - 1)) & (STACKALIGN - 1);
        else
            sz = -(adjesp & 7) & 7;
        if (calledafunc && !I16 && sz && (STACKALIGN == 16 || config.flags4 & CFG4stackalign))
        {
            regm_t mval_save = regcon.immed.mval;
            regcon.immed.mval = 0;      // prevent reghasvalue() optimizations
                                        // because c hasn't been executed yet
            cs1 = cod3_stackadj(cs1, sz);
            regcon.immed.mval = mval_save;
            cs1 = genadjesp(cs1, sz);

            code *cx = cod3_stackadj(NULL, -sz);
            cx = genadjesp(cx, -sz);
            cs2 = cat(cx, cs2);
        }

        cs1 = genadjesp(cs1,adjesp);
        cs2 = genadjesp(cs2,-adjesp);
  }

  calledafunc |= calledafuncsave;
  msavereg &= ~keepmsk | overlap; /* remove from mask of regs to save   */
  mfuncreg &= oldmfuncreg;      /* update original                      */
#ifdef DEBUG
  if (debugw)
        printf("-scodelem(e=%p *pretregs=%s keepmsk=%s constflag=%d\n",
                e,regm_str(*pretregs),regm_str(keepmsk),constflag);
#endif
  return cat4(cs1,c,cs3,cs2);
}

/*********************************************
 * Turn register mask into a string suitable for printing.
 */

#ifdef DEBUG

const char *regm_str(regm_t rm)
{
    #define NUM 10
    #define SMAX 128
    static char str[NUM][SMAX + 1];
    static int i;

    if (rm == 0)
        return "0";
    if (rm == ALLREGS)
        return "ALLREGS";
    if (rm == BYTEREGS)
        return "BYTEREGS";
    if (rm == allregs)
        return "allregs";
    if (rm == XMMREGS)
        return "XMMREGS";
    char *p = str[i];
    if (++i == NUM)
        i = 0;
    *p = 0;
    for (size_t j = 0; j < 32; j++)
    {
        if (mask[j] & rm)
        {
            strcat(p,regstring[j]);
            rm &= ~mask[j];
            if (rm)
                strcat(p,"|");
        }
    }
    if (rm)
    {   char *s = p + strlen(p);
        sprintf(s,"x%02x",rm);
    }
    assert(strlen(p) <= SMAX);
    return strdup(p);
}

#endif

/*********************************
 * Scan down comma-expressions.
 * Output:
 *      *pe = first elem down right side that is not an OPcomma
 * Returns:
 *      code generated for left branches of comma-expressions
 */

code *docommas(elem **pe)
{
    unsigned stackpushsave = stackpush;
    int stackcleansave = cgstate.stackclean;
    cgstate.stackclean = 0;
    code* cc = CNIL;
    elem* e = *pe;
    while (1)
    {
        if (configv.addlinenumbers && e->Esrcpos.Slinnum)
        {       cc = genlinnum(cc,e->Esrcpos);
                //e->Esrcpos.Slinnum = 0;               // don't do it twice
        }
        if (e->Eoper != OPcomma)
                break;
        regm_t retregs = 0;
        cc = cat(cc,codelem(e->E1,&retregs,TRUE));
        elem* eold = e;
        e = e->E2;
        freenode(eold);
    }
    *pe = e;
    assert(cgstate.stackclean == 0);
    cgstate.stackclean = stackcleansave;
    cc = genstackclean(cc,stackpush - stackpushsave,0);
    return cc;
}

/**************************
 * For elems in regcon that don't match regconsave,
 * clear the corresponding bit in regcon.cse.mval.
 * Do same for regcon.immed.
 */

void andregcon(con_t *pregconsave)
{
    regm_t m = ~1;
    for (int i = 0; i < REGMAX; i++)
    {   if (pregconsave->cse.value[i] != regcon.cse.value[i])
            regcon.cse.mval &= m;
        if (pregconsave->immed.value[i] != regcon.immed.value[i])
            regcon.immed.mval &= m;
        m <<= 1;
        m |= 1;
    }
    //printf("regcon.cse.mval = %s, regconsave->mval = %s ",regm_str(regcon.cse.mval),regm_str(pregconsave->cse.mval));
    regcon.used |= pregconsave->used;
    regcon.cse.mval &= pregconsave->cse.mval;
    regcon.immed.mval &= pregconsave->immed.mval;
    regcon.params &= pregconsave->params;
    //printf("regcon.cse.mval&regcon.cse.mops = %s, regcon.cse.mops = %s\n",regm_str(regcon.cse.mval & regcon.cse.mops), regm_str(regcon.cse.mops));
    regcon.cse.mops &= regcon.cse.mval;
}

#endif // !SPP
