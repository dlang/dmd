/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cod1.c
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
#include        "xmm.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/* Generate the appropriate ESC instruction     */
#define ESC(MF,b)       (0xD8 + ((MF) << 1) + (b))
enum MF
{       // Values for MF
        MFfloat         = 0,
        MFlong          = 1,
        MFdouble        = 2,
        MFword          = 3
};

targ_size_t paramsize(elem *e);
static void funccall(CodeBuilder& cdb,elem *,unsigned,unsigned,regm_t *,regm_t,bool);
static void movParams(CodeBuilder& cdb,elem *e,unsigned stackalign, unsigned funcargtos);

/* array to convert from index register to r/m field    */
                                       /* AX CX DX BX SP BP SI DI       */
static const signed char regtorm32[8] = {  0, 1, 2, 3,-1, 5, 6, 7 };
             signed char regtorm  [8] = { -1,-1,-1, 7,-1, 6, 4, 5 };

/**************************
 * Determine if e is a 32 bit scaled index addressing mode.
 * Returns:
 *      0       not a scaled index addressing mode
 *      !=0     the value for ss in the SIB byte
 */

int isscaledindex(elem *e)
{   targ_uns ss;

    assert(!I16);
    while (e->Eoper == OPcomma)
        e = e->E2;
    if (!(e->Eoper == OPshl && !e->Ecount &&
          e->E2->Eoper == OPconst &&
          (ss = e->E2->EV.Vuns) <= 3
         )
       )
        ss = 0;
    return ss;
}

/*********************************************
 * Generate code for which isscaledindex(e) returned a non-zero result.
 */

static void cdisscaledindex(CodeBuilder& cdb,elem *e,regm_t *pidxregs,regm_t keepmsk)
{
    // Load index register with result of e->E1
    while (e->Eoper == OPcomma)
    {
        regm_t r = 0;
        scodelem(cdb,e->E1,&r,keepmsk,TRUE);
        freenode(e);
        e = e->E2;
    }
    assert(e->Eoper == OPshl);
    scodelem(cdb,e->E1,pidxregs,keepmsk,TRUE);
    freenode(e->E2);
    freenode(e);
}

/***********************************
 * Determine index if we can do two LEA instructions as a multiply.
 * Returns:
 *      0       can't do it
 */

static struct Ssindex
{
    targ_uns product;
    char ss1;
    char ss2;
    char ssflags;
        #define SSFLnobp        1       // can't have EBP in relconst
        #define SSFLnobase1     2       // no base register for first LEA
        #define SSFLnobase      4       // no base register
        #define SSFLlea         8       // can do it in one LEA
} ssindex_array[] =
{       {0, 0,0},               // [0] is a place holder

        {3, 1,0,SSFLnobp | SSFLlea},
        {5, 2,0,SSFLnobp | SSFLlea},
        {9, 3,0,SSFLnobp | SSFLlea},

        {6, 1,1,SSFLnobase},
        {12,1,2,SSFLnobase},
        {24,1,3,SSFLnobase},
        {10,2,1,SSFLnobase},
        {20,2,2,SSFLnobase},
        {40,2,3,SSFLnobase},
        {18,3,1,SSFLnobase},
        {36,3,2,SSFLnobase},
        {72,3,3,SSFLnobase},

        {15,2,1,SSFLnobp},
        {25,2,2,SSFLnobp},
        {27,3,1,SSFLnobp},
        {45,3,2,SSFLnobp},
        {81,3,3,SSFLnobp},

        {16,3,1,SSFLnobase1 | SSFLnobase},
        {32,3,2,SSFLnobase1 | SSFLnobase},
        {64,3,3,SSFLnobase1 | SSFLnobase},
};

int ssindex(int op,targ_uns product)
{   int i;

    if (op == OPshl)
        product = 1 << product;
    for (i = 1; i < arraysize(ssindex_array); i++)
    {
        if (ssindex_array[i].product == product)
            return i;
    }
    return 0;
}

/***************************************
 * Build an EA of the form disp[base][index*scale].
 * Input:
 *      c       struct to fill in
 *      base    base register (-1 if none)
 *      index   index register (-1 if none)
 *      scale   scale factor - 1,2,4,8
 *      disp    displacement
 */

void buildEA(code *c,int base,int index,int scale,targ_size_t disp)
{   unsigned char rm;
    unsigned char sib;
    unsigned char rex = 0;

    sib = 0;
    if (!I16)
    {   unsigned ss;

        assert(index != SP);

        switch (scale)
        {   case 1:     ss = 0; break;
            case 2:     ss = 1; break;
            case 4:     ss = 2; break;
            case 8:     ss = 3; break;
            default:    assert(0);
        }

        if (base == -1)
        {
            if (index == -1)
                rm = modregrm(0,0,5);
            else
            {
                rm  = modregrm(0,0,4);
                sib = modregrm(ss,index & 7,5);
                if (index & 8)
                    rex |= REX_X;
            }
        }
        else if (index == -1)
        {
            if (base == SP)
            {
                rm  = modregrm(2,0,4);
                sib = modregrm(0,4,SP);
            }
            else
            {   rm = modregrm(2,0,base & 7);
                if (base & 8)
                {   rex |= REX_B;
                    if (base == R12)
                    {
                        rm = modregrm(2,0,4);
                        sib = modregrm(0,4,4);
                    }
                }
            }
        }
        else
        {
            rm  = modregrm(2,0,4);
            sib = modregrm(ss,index & 7,base & 7);
            if (index & 8)
                rex |= REX_X;
            if (base & 8)
                rex |= REX_B;
        }
    }
    else
    {
        // -1 AX CX DX BX SP BP SI DI
        static unsigned char EA16rm[9][9] =
        {
            {   0x06,0x09,0x09,0x09,0x87,0x09,0x86,0x84,0x85,   },      // -1
            {   0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,   },      // AX
            {   0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,   },      // CX
            {   0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,   },      // DX
            {   0x87,0x09,0x09,0x09,0x09,0x09,0x09,0x80,0x81,   },      // BX
            {   0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,   },      // SP
            {   0x86,0x09,0x09,0x09,0x09,0x09,0x09,0x82,0x83,   },      // BP
            {   0x84,0x09,0x09,0x09,0x80,0x09,0x82,0x09,0x09,   },      // SI
            {   0x85,0x09,0x09,0x09,0x81,0x09,0x83,0x09,0x09,   }       // DI
        };

        assert(scale == 1);
        rm = EA16rm[base + 1][index + 1];
        assert(rm != 9);
    }
    c->Irm = rm;
    c->Isib = sib;
    c->Irex = rex;
    c->IFL1 = FLconst;
    c->IEV1.Vuns = disp;
}

/*********************************************
 * Build REX, modregrm and sib bytes
 */

unsigned buildModregrm(int mod, int reg, int rm)
{   unsigned m;
    if (I16)
        m = modregrm(mod, reg, rm);
    else
    {
        if ((rm & 7) == SP && mod != 3)
            m = (modregrm(0,4,SP) << 8) | modregrm(mod,reg & 7,4);
        else
            m = modregrm(mod,reg & 7,rm & 7);
        if (reg & 8)
            m |= REX_R << 16;
        if (rm & 8)
            m |= REX_B << 16;
    }
    return m;
}

/****************************************
 * Generate code for eecontext
 */

void genEEcode()
{
    CodeBuilder cdb;

    eecontext.EEin++;
    regcon.immed.mval = 0;
    regm_t retregs = 0;    //regmask(eecontext.EEelem->Ety);
    assert(EEStack.offset >= REGSIZE);
    cod3_stackadj(cdb, EEStack.offset - REGSIZE);
    cdb.gen1(0x50 + SI);                      // PUSH ESI
    cdb.append(genadjesp(CNIL,EEStack.offset));
    gencodelem(cdb,eecontext.EEelem,&retregs, FALSE);
    code *c = cdb.finish();
    assignaddrc(c);
    pinholeopt(c,NULL);
    jmpaddr(c);
    eecontext.EEcode = gen1(c,0xCC);        // INT 3
    eecontext.EEin--;
}

/********************************************
 * Gen a save/restore sequence for mask of registers.
 * Returns:
 *      amount of stack consumed
 */

unsigned gensaverestore2(regm_t regm,code **csave,code **crestore)
{
    CodeBuilder cdb1;
    cdb1.append(*csave);
    code *cs2 = *crestore;
    unsigned stackused = 0;

    //printf("gensaverestore2(%s)\n", regm_str(regm));
    regm &= mBP | mES | ALLREGS | XMMREGS | mST0 | mST01;
    for (int i = 0; regm; i++)
    {
        if (regm & 1)
        {
            if (i == ES)
            {
                stackused += REGSIZE;
                cdb1.gen1(0x06);                        // PUSH ES
                cs2 = cat(gen1(CNIL, 0x07),cs2);        // POP  ES
            }
            else if (i == ST0 || i == ST01)
            {
                code *cs1 = NULL;
                gensaverestore87(1 << i, &cs1, &cs2);
                cdb1.append(cs1);
            }
            else if (i >= XMM0 || I64 || cgstate.funcarg.size)
            {   unsigned idx;
                cdb1.append(regsave.save(NULL, i, &idx));
                cs2 = regsave.restore(cs2, i, idx);
            }
            else
            {
                stackused += REGSIZE;
                cdb1.gen1(0x50 + (i & 7));              // PUSH i
                code *c = gen1(NULL, 0x58 + (i & 7));   // POP  i
                if (i & 8)
                {   code_orrex(cdb1.last(), REX_B);
                    code_orrex(c, REX_B);
                }
                cs2 = cat(c,cs2);
            }
        }
        regm >>= 1;
    }
    *csave = cdb1.finish();
    *crestore = cs2;
    return stackused;
}

unsigned gensaverestore(regm_t regm,code **csave,code **crestore)
{
    *csave = NULL;
    *crestore = NULL;
    return gensaverestore2(regm, csave, crestore);
}

/****************************************
 * Clean parameters off stack.
 * Input:
 *      numpara         amount to adjust stack pointer
 *      keepmsk         mask of registers to not destroy
 */

void genstackclean(CodeBuilder& cdb,unsigned numpara,regm_t keepmsk)
{
    //dbg_printf("genstackclean(numpara = %d, stackclean = %d)\n",numpara,cgstate.stackclean);
    if (numpara && (cgstate.stackclean || STACKALIGN == 16))
    {
#if 0       // won't work if operand of scodelem
        if (numpara == stackpush &&             // if this is all those pushed
            needframe &&                        // and there will be a BP
            !config.windows &&
            !(regcon.mvar & fregsaved)          // and no registers will be pushed
        )
            cdb.append(genregs(CNIL,0x89,BP,SP));  // MOV SP,BP
        else
#endif
        {   regm_t scratchm = 0;

            if (numpara == REGSIZE && config.flags4 & CFG4space)
            {
                scratchm = ALLREGS & ~keepmsk & regcon.used & ~regcon.mvar;
            }

            if (scratchm)
            {
                unsigned r;
                allocreg(cdb,&scratchm,&r,TYint);
                cdb.gen1(0x58 + r);           // POP r
            }
            else
                cod3_stackadj(cdb, -numpara);
        }
        stackpush -= numpara;
        cdb.append(genadjesp(CNIL,-numpara));
    }
}


/*********************************
 * Generate code for a logical expression.
 * Input:
 *      e       elem
 *      jcond
 *         bit 1 if TRUE then goto jump address if e
 *               if FALSE then goto jump address if !e
 *         2    don't call save87()
 *      fltarg   FLcode or FLblock, flavor of target if e evaluates to jcond
 *      targ    either code or block pointer to destination
 */

void logexp(CodeBuilder& cdb,elem *e,int jcond,unsigned fltarg,code *targ)
{
    //printf("logexp(e = %p, jcond = %d)\n", e, jcond);
    int no87 = (jcond & 2) == 0;
    docommas(cdb,&e);             // scan down commas
    cgstate.stackclean++;

    code *c, *ce, *cnop;
    if (EOP(e) && !e->Ecount)     // if operator and not common sub
    {
        switch (e->Eoper)
        {
            case OPoror:
            {
                con_t regconsave;
                if (jcond & 1)
                {
                    logexp(cdb,e->E1,jcond,fltarg,targ);
                    regconsave = regcon;
                    logexp(cdb,e->E2,jcond,fltarg,targ);
                }
                else
                {
                    code *cnop = gennop(CNIL);
                    logexp(cdb,e->E1,jcond | 1,FLcode,cnop);
                    regconsave = regcon;
                    logexp(cdb,e->E2,jcond,fltarg,targ);
                    cdb.append(cnop);
                }
                andregcon(&regconsave);
                freenode(e);
                cgstate.stackclean--;
                return;
            }

            case OPandand:
            {
                con_t regconsave;
                if (jcond & 1)
                {
                    code *cnop = gennop(CNIL);    // a dummy target address
                    logexp(cdb,e->E1,jcond & ~1,FLcode,cnop);
                    regconsave = regcon;
                    logexp(cdb,e->E2,jcond,fltarg,targ);
                    cdb.append(cnop);
                }
                else
                {
                    logexp(cdb,e->E1,jcond,fltarg,targ);
                    regconsave = regcon;
                    logexp(cdb,e->E2,jcond,fltarg,targ);
                }
                andregcon(&regconsave);
                freenode(e);
                cgstate.stackclean--;
                return;
            }

            case OPnot:
                jcond ^= 1;
            case OPbool:
            case OPs8_16:
            case OPu8_16:
            case OPs16_32:
            case OPu16_32:
            case OPs32_64:
            case OPu32_64:
            case OPu32_d:
            case OPd_ld:
                logexp(cdb,e->E1,jcond,fltarg,targ);
                freenode(e);
                cgstate.stackclean--;
                return;

            case OPcond:
            {
                code *cnop2 = gennop(CNIL);   // addresses of start of leaves
                code *cnop = gennop(CNIL);
                logexp(cdb,e->E1,FALSE,FLcode,cnop2);   // eval condition
                con_t regconold = regcon;
                logexp(cdb,e->E2->E1,jcond,fltarg,targ);
                genjmp(cdb,JMP,FLcode,(block *) cnop); // skip second leaf

                con_t regconsave = regcon;
                regcon = regconold;

                cdb.append(cnop2);
                logexp(cdb,e->E2->E2,jcond,fltarg,targ);
                andregcon(&regconold);
                andregcon(&regconsave);
                freenode(e->E2);
                freenode(e);
                cdb.append(cnop);
                cgstate.stackclean--;
                return;;
            }
        }
    }

    /* Special code for signed long compare.
     * Not necessary for I64 until we do cents.
     */
    if (OTrel2(e->Eoper) &&               // if < <= >= >
        !e->Ecount &&
        ( (I16 && tybasic(e->E1->Ety) == TYlong  && tybasic(e->E2->Ety) == TYlong) ||
          (I32 && tybasic(e->E1->Ety) == TYllong && tybasic(e->E2->Ety) == TYllong))
       )
    {
        longcmp(cdb,e,jcond,fltarg,targ);
        cgstate.stackclean--;
        return;
    }

    regm_t retregs = mPSW;                // return result in flags
    unsigned op = jmpopcode(e);           // get jump opcode
    if (!(jcond & 1))
        op ^= 0x101;                      // toggle jump condition(s)
    codelem(cdb,e,&retregs,TRUE);         // evaluate elem
    if (no87)
        cse_flush(cdb,no87);              // flush CSE's to memory
    genjmp(cdb,op,fltarg,(block *) targ); // generate jmp instruction
    cgstate.stackclean--;
}


/******************************
 * Routine to aid in setting things up for gen().
 * Look for common subexpression.
 * Can handle indirection operators, but not if they're common subs.
 * Input:
 *      e ->    elem where we get some of the data from
 *      cs ->   partially filled code to add
 *      op =    opcode
 *      reg =   reg field of (mod reg r/m)
 *      offset = data to be added to Voffset field
 *      keepmsk = mask of registers we must not destroy
 *      desmsk  = mask of registers destroyed by executing the instruction
 * Returns:
 *      pointer to code generated
 */

void loadea(CodeBuilder& cdb,elem *e,code *cs,unsigned op,unsigned reg,targ_size_t offset,
        regm_t keepmsk,regm_t desmsk)
{
  code *c,*cg,*cd;

#ifdef DEBUG
  if (debugw)
    printf("loadea: e=%p cs=%p op=x%x reg=%d offset=%lld keepmsk=%s desmsk=%s\n",
            e,cs,op,reg,(unsigned long long)offset,regm_str(keepmsk),regm_str(desmsk));
#endif

  assert(e);
  cs->Iflags = 0;
  cs->Irex = 0;
  cs->Iop = op;
  tym_t tym = e->Ety;
  int sz = tysize(tym);

  /* Determine if location we want to get is in a register. If so,      */
  /* substitute the register for the EA.                                */
  /* Note that operators don't go through this. CSE'd operators are     */
  /* picked up by comsub().                                             */
  if (e->Ecount &&                      /* if cse                       */
      e->Ecount != e->Ecomsub &&        /* and cse was generated        */
      op != 0x8D && op != 0xC4 &&       /* and not an LEA or LES        */
      (op != 0xFF || reg != 3) &&       /* and not CALLF MEM16          */
      (op & 0xFFF8) != 0xD8)            // and not 8087 opcode
  {
        assert(!EOP(e));                /* can't handle this            */
        regm_t rm = regcon.cse.mval & ~regcon.cse.mops & ~regcon.mvar; // possible regs
        if (op == 0xFF && reg == 6)
            rm &= ~XMMREGS;             // can't PUSH an XMM register
        if (sz > REGSIZE)               // value is in 2 or 4 registers
        {
                if (I16 && sz == 8)     // value is in 4 registers
                {       static regm_t rmask[4] = { mDX,mCX,mBX,mAX };
                        rm &= rmask[offset >> 1];
                }

                else if (offset)
                        rm &= mMSW;             /* only high words      */
                else
                        rm &= mLSW;             /* only low words       */
        }
        for (unsigned i = 0; rm; i++)
        {       if (mask[i] & rm)
                {       if (regcon.cse.value[i] == e && // if register has elem
                            /* watch out for a CWD destroying DX        */
                            !(i == DX && op == 0xF7 && desmsk & mDX))
                        {
                                /* if ES, then it can only be a load    */
                                if (i == ES)
                                {       if (op != 0x8B)
                                            break;      // not a load
                                        cs->Iop = 0x8C; /* MOV reg,ES   */
                                        cs->Irm = modregrm(3,0,reg & 7);
                                        if (reg & 8)
                                            code_orrex(cs, REX_B);
                                }
                                else    // XXX reg,i
                                {
                                    cs->Irm = modregrm(3,reg & 7,i & 7);
                                    if (reg & 8)
                                        cs->Irex |= REX_R;
                                    if (i & 8)
                                        cs->Irex |= REX_B;
                                    if (sz == 1 && I64 && (i >= 4 || reg >= 4))
                                        cs->Irex |= REX;
                                    if (I64 && (sz == 8 || sz == 16))
                                        cs->Irex |= REX_W;
                                }
                                goto L2;
                        }
                        rm &= ~mask[i];
                }
        }
  }

  getlvalue(cdb,cs,e,keepmsk);
  if (offset == REGSIZE)
        getlvalue_msw(cs);
  else
        cs->IEVoffset1 += offset;
  if (I64)
  {     if (reg >= 4 && sz == 1)               // if byte register
            // Can only address those 8 bit registers if a REX byte is present
            cs->Irex |= REX;
        if ((op & 0xFFFFFFF8) == 0xD8)
            cs->Irex &= ~REX_W;                 // not needed for x87 ops
  }
  code_newreg(cs, reg);                         // OR in reg field
  if (!I16)
  {
      if (reg == 6 && op == 0xFF ||             /* don't PUSH a word    */
          op == 0x0FB7 || op == 0x0FBF ||       /* MOVZX/MOVSX          */
          (op & 0xFFF8) == 0xD8 ||              /* 8087 instructions    */
          op == 0x8D)                           /* LEA                  */
        {
            cs->Iflags &= ~CFopsize;
            if (reg == 6 && op == 0xFF)         // if PUSH
                cs->Irex &= ~REX_W;             // REX is ignored for PUSH anyway
        }
  }
  else if ((op & 0xFFF8) == 0xD8 && ADDFWAIT())
        cs->Iflags |= CFwait;
L2:
  getregs(cdb,desmsk);                  // save any regs we destroy

  /* KLUDGE! fix up DX for divide instructions */
  if (op == 0xF7 && desmsk == (mAX|mDX))        /* if we need to fix DX */
  {     if (reg == 7)                           /* if IDIV              */
        {
            cdb.gen1(0x99);                     // CWD
            if (I64 && sz == 8)
                code_orrex(cdb.last(), REX_W);
        }
        else if (reg == 6)                      // if DIV
            cdb.append(genregs(CNIL,0x33,DX,DX));        // XOR DX,DX
  }

  // Eliminate MOV reg,reg
  if ((cs->Iop & ~3) == 0x88 &&
      (cs->Irm & 0xC7) == modregrm(3,0,reg & 7))
  {
        unsigned r = cs->Irm & 7;
        if (cs->Irex & REX_B)
            r |= 8;
        if (r == reg)
            cs->Iop = NOP;
  }

  cdb.gen(cs);
}

/**************************
 * Get addressing mode.
 */

unsigned getaddrmode(regm_t idxregs)
{
    unsigned mode;

    if (I16)
    {
        mode =  (idxregs & mBX) ? modregrm(2,0,7) :     /* [BX] */
                (idxregs & mDI) ? modregrm(2,0,5):      /* [DI] */
                (idxregs & mSI) ? modregrm(2,0,4):      /* [SI] */
                                  (assert(0),1);
    }
    else
    {   unsigned reg = findreg(idxregs & (ALLREGS | mBP));
        if (reg == R12)
            mode = (REX_B << 16) | (modregrm(0,4,4) << 8) | modregrm(2,0,4);
        else
            mode = modregrmx(2,0,reg);
    }
    return mode;
}

void setaddrmode(code *c, regm_t idxregs)
{
    unsigned mode = getaddrmode(idxregs);
    c->Irm = mode & 0xFF;
    c->Isib = mode >> 8;
    c->Irex &= ~REX_B;
    c->Irex |= mode >> 16;
}

/**********************************************
 */

void getlvalue_msw(code *c)
{
    if (c->IFL1 == FLreg)
    {
        unsigned regmsw = c->IEVsym1->Sregmsw;
        c->Irm = (c->Irm & ~7) | (regmsw & 7);
        if (regmsw & 8)
            c->Irex |= REX_B;
        else
            c->Irex &= ~REX_B;
    }
    else
        c->IEVoffset1 += REGSIZE;
}

/**********************************************
 */

void getlvalue_lsw(code *c)
{
    if (c->IFL1 == FLreg)
    {
        unsigned reglsw = c->IEVsym1->Sreglsw;
        c->Irm = (c->Irm & ~7) | (reglsw & 7);
        if (reglsw & 8)
            c->Irex |= REX_B;
        else
            c->Irex &= ~REX_B;
    }
    else
        c->IEVoffset1 -= REGSIZE;
}

/******************
 * Compute addressing mode.
 * Generate & return sequence of code (if any).
 * Return in cs the info on it.
 * Input:
 *      pcs ->  where to store data about addressing mode
 *      e ->    the lvalue elem
 *      keepmsk mask of registers we must not destroy or use
 *              if (keepmsk & RMstore), this will be only a store operation
 *              into the lvalue
 *              if (keepmsk & RMload), this will be a read operation only
 */

void getlvalue(CodeBuilder& cdb,code *pcs,elem *e,regm_t keepmsk)
{ regm_t idxregs;
  unsigned fl,f,opsave;
  elem *e1;
  elem *e11;
  elem *e12;
  bool e1isadd,e1free;
  unsigned reg;
  tym_t e1ty;
  symbol *s;

  //printf("getlvalue(e = %p, keepmsk = %s)\n",e,regm_str(keepmsk));
  //elem_print(e);
  assert(e);
  elem_debug(e);
  if (e->Eoper == OPvar || e->Eoper == OPrelconst)
  {     s = e->EV.sp.Vsym;
        fl = s->Sfl;
        if (tyfloating(s->ty()))
            objmod->fltused();
  }
  else
        fl = FLoper;
  pcs->IFL1 = fl;
  pcs->Iflags = CFoff;                  /* only want offsets            */
  pcs->Irex = 0;
  pcs->IEVoffset1 = 0;

  tym_t ty = e->Ety;
  unsigned sz = tysize(ty);
  if (tyfloating(ty))
        objmod->fltused();
  if (I64 && (sz == 8 || sz == 16) && !tyvector(ty))
        pcs->Irex |= REX_W;
  if (!I16 && sz == SHORTSIZE)
        pcs->Iflags |= CFopsize;
  if (ty & mTYvolatile)
        pcs->Iflags |= CFvolatile;

  switch (fl)
  {
    case FLoper:
#ifdef DEBUG
        if (debugw) printf("getlvalue(e = %p, keepmsk = %s)\n", e, regm_str(keepmsk));
#endif
        switch (e->Eoper)
        {
            case OPadd:                 // this way when we want to do LEA
                e1 = e;
                e1free = FALSE;
                e1isadd = TRUE;
                break;
            case OPind:
            case OPpostinc:             // when doing (*p++ = ...)
            case OPpostdec:             // when doing (*p-- = ...)
            case OPbt:
            case OPbtc:
            case OPbtr:
            case OPbts:
            case OPvecfill:
                e1 = e->E1;
                e1free = TRUE;
                e1isadd = e1->Eoper == OPadd;
                break;
            default:
                elem_print(e);
                assert(0);
        }
        e1ty = tybasic(e1->Ety);
        if (e1isadd)
        {   e12 = e1->E2;
            e11 = e1->E1;
        }

        /* First see if we can replace *(e+&v) with
         *      MOV     idxreg,e
         *      EA =    [ES:] &v+idxreg
         */
        f = FLconst;
        if (e1isadd &&
            ((e12->Eoper == OPrelconst
              && (f = el_fl(e12)) != FLfardata
             ) ||
             (e12->Eoper == OPconst && !I16 && !e1->Ecount && (!I64 || el_signx32(e12)))) &&
            !(I64 && (config.flags3 & CFG3pic || config.exe == EX_WIN64)) &&
            e1->Ecount == e1->Ecomsub &&
            (!e1->Ecount || (~keepmsk & ALLREGS & mMSW) || (e1ty != TYfptr && e1ty != TYhptr)) &&
            tysize(e11->Ety) == REGSIZE
           )
        {   unsigned char t;            /* component of r/m field */
            int ss;
            int ssi;

            if (e12->Eoper == OPrelconst)
                f = el_fl(e12);
            /*assert(datafl[f]);*/              /* what if addr of func? */
            if (!I16)
            {   /* Any register can be an index register        */
                regm_t idxregs = allregs & ~keepmsk;
                assert(idxregs);

                /* See if e1->E1 can be a scaled index  */
                ss = isscaledindex(e11);
                if (ss)
                {
                    /* Load index register with result of e11->E1       */
                    cdisscaledindex(cdb,e11,&idxregs,keepmsk);
                    reg = findreg(idxregs);
                    {
                        t = stackfl[f] ? 2 : 0;
                        pcs->Irm = modregrm(t,0,4);
                        pcs->Isib = modregrm(ss,reg & 7,5);
                        if (reg & 8)
                            pcs->Irex |= REX_X;
                    }
                }
                else if ((e11->Eoper == OPmul || e11->Eoper == OPshl) &&
                         !e11->Ecount &&
                         e11->E2->Eoper == OPconst &&
                         (ssi = ssindex(e11->Eoper,e11->E2->EV.Vuns)) != 0
                        )
                {
                    regm_t scratchm;

                    char ssflags = ssindex_array[ssi].ssflags;
                    if (ssflags & SSFLnobp && stackfl[f])
                        goto L6;

                    // Load index register with result of e11->E1
                    scodelem(cdb,e11->E1,&idxregs,keepmsk,TRUE);
                    reg = findreg(idxregs);

                    int ss1 = ssindex_array[ssi].ss1;
                    if (ssflags & SSFLlea)
                    {
                        assert(!stackfl[f]);
                        pcs->Irm = modregrm(2,0,4);
                        pcs->Isib = modregrm(ss1,reg & 7,reg & 7);
                        if (reg & 8)
                            pcs->Irex |= REX_X | REX_B;
                    }
                    else
                    {   int rbase;
                        unsigned r;

                        scratchm = ALLREGS & ~keepmsk;
                        allocreg(cdb,&scratchm,&r,TYint);

                        if (ssflags & SSFLnobase1)
                        {   t = 0;
                            rbase = 5;
                        }
                        else
                        {   t = 0;
                            rbase = reg;
                            if (rbase == BP || rbase == R13)
                            {   static unsigned imm32[4] = {1+1,2+1,4+1,8+1};

                                // IMUL r,BP,imm32
                                cdb.genc2(0x69,modregxrmx(3,r,rbase),imm32[ss1]);
                                goto L7;
                            }
                        }

                        cdb.gen2sib(0x8D,modregxrm(t,r,4),modregrm(ss1,reg & 7,rbase & 7));
                        if (reg & 8)
                            code_orrex(cdb.last(), REX_X);
                        if (rbase & 8)
                            code_orrex(cdb.last(), REX_B);
                        if (I64)
                            code_orrex(cdb.last(), REX_W);

                        if (ssflags & SSFLnobase1)
                        {   cdb.last()->IFL1 = FLconst;
                            cdb.last()->IEV1.Vuns = 0;
                        }
                    L7:
                        if (ssflags & SSFLnobase)
                        {   t = stackfl[f] ? 2 : 0;
                            rbase = 5;
                        }
                        else
                        {   t = 2;
                            rbase = r;
                            assert(rbase != BP);
                        }
                        pcs->Irm = modregrm(t,0,4);
                        pcs->Isib = modregrm(ssindex_array[ssi].ss2,r & 7,rbase & 7);
                        if (r & 8)
                            pcs->Irex |= REX_X;
                        if (rbase & 8)
                            pcs->Irex |= REX_B;
                    }
                    freenode(e11->E2);
                    freenode(e11);
                }
                else
                {
                 L6:
                    /* Load index register with result of e11   */
                    scodelem(cdb,e11,&idxregs,keepmsk,TRUE);
                    setaddrmode(pcs, idxregs);
                    if (stackfl[f])             /* if we need [EBP] too */
                    {   unsigned idx = pcs->Irm & 7;
                        if (pcs->Irex & REX_B)
                            pcs->Irex = (pcs->Irex & ~REX_B) | REX_X;
                        pcs->Isib = modregrm(0,idx,BP);
                        pcs->Irm = modregrm(2,0,4);
                    }
                }
            }
            else
            {
                idxregs = IDXREGS & ~keepmsk;   /* only these can be index regs */
                assert(idxregs);
                if (stackfl[f])                 /* if stack data type   */
                {   idxregs &= mSI | mDI;       /* BX can't index off stack */
                    if (!idxregs) goto L1;      /* index regs aren't avail */
                    t = 6;                      /* [BP+SI+disp]         */
                }
                else
                    t = 0;                      /* [SI + disp]          */
                scodelem(cdb,e11,&idxregs,keepmsk,TRUE); // load idx reg
                pcs->Irm = getaddrmode(idxregs) ^ t;
            }
            if (f == FLpara)
                refparam = TRUE;
            else if (f == FLauto || f == FLbprel || f == FLfltreg || f == FLfast)
                reflocal = TRUE;
            else if (f == FLcsdata || tybasic(e12->Ety) == TYcptr)
                pcs->Iflags |= CFcs;
            else
                assert(f != FLreg);
            pcs->IFL1 = f;
            if (f != FLconst)
                pcs->IEVsym1 = e12->EV.sp.Vsym;
            pcs->IEVoffset1 = e12->EV.sp.Voffset; /* += ??? */

            /* If e1 is a CSE, we must generate an addressing mode      */
            /* but also leave EA in registers so others can use it      */
            if (e1->Ecount)
            {   unsigned flagsave;

                idxregs = IDXREGS & ~keepmsk;
                allocreg(cdb,&idxregs,&reg,TYoffset);

                /* If desired result is a far pointer, we'll have       */
                /* to load another register with the segment of v       */
                if (e1ty == TYfptr)
                {
                    unsigned msreg;

                    idxregs |= mMSW & ALLREGS & ~keepmsk;
                    allocreg(cdb,&idxregs,&msreg,TYfptr);
                    msreg = findregmsw(idxregs);
                                                /* MOV msreg,segreg     */
                    cdb.append(genregs(CNIL,0x8C,segfl[f],msreg));
                }
                opsave = pcs->Iop;
                flagsave = pcs->Iflags;
                unsigned char rexsave = pcs->Irex;
                pcs->Iop = 0x8D;
                code_newreg(pcs, reg);
                if (!I16)
                    pcs->Iflags &= ~CFopsize;
                if (I64)
                    pcs->Irex |= REX_W;
                cdb.gen(pcs);                 // LEA idxreg,EA
                cssave(e1,idxregs,TRUE);
                if (!I16)
                {   pcs->Iflags = flagsave;
                    pcs->Irex = rexsave;
                }
                if (stackfl[f] && (config.wflags & WFssneds))   // if pointer into stack
                    pcs->Iflags |= CFss;        // add SS: override
                pcs->Iop = opsave;
                pcs->IFL1 = FLoffset;
                pcs->IEV1.Vuns = 0;
                setaddrmode(pcs, idxregs);
            }
            freenode(e12);
            if (e1free)
                freenode(e1);
            goto Lptr;
        }

        L1:

        /* The rest of the cases could be a far pointer */

        idxregs = (I16 ? IDXREGS : allregs) & ~keepmsk; // only these can be index regs
        assert(idxregs);
        if (!I16 &&
            (sz == REGSIZE || (I64 && sz == 4)) &&
            keepmsk & RMstore)
            idxregs |= regcon.mvar;

        switch (e1ty)
        {   case TYfptr:                        /* if far pointer       */
            case TYhptr:
                idxregs = (mES | IDXREGS) & ~keepmsk;   // need segment too
                assert(idxregs & mES);
                pcs->Iflags |= CFes;            /* ES segment override  */
                break;
            case TYsptr:                        /* if pointer to stack  */
                if (config.wflags & WFssneds)   // if SS != DS
                    pcs->Iflags |= CFss;        /* then need SS: override */
                break;
            case TYcptr:                        /* if pointer to code   */
                pcs->Iflags |= CFcs;            /* then need CS: override */
                break;
        }
        pcs->IFL1 = FLoffset;
        pcs->IEV1.Vuns = 0;

        /* see if we can replace *(e+c) with
         *      MOV     idxreg,e
         *      [MOV    ES,segment]
         *      EA =    [ES:]c[idxreg]
         */
        if (e1isadd && e12->Eoper == OPconst &&
            (!I64 || el_signx32(e12)) &&
            (tysize(e12->Ety) == REGSIZE || (I64 && tysize(e12->Ety) == 4)) &&
            (!e1->Ecount || !e1free)
           )
        {   int ss;

            pcs->IEV1.Vuns = e12->EV.Vuns;
            freenode(e12);
            if (e1free) freenode(e1);
            if (!I16 && e11->Eoper == OPadd && !e11->Ecount &&
                tysize(e11->Ety) == REGSIZE)
            {
                e12 = e11->E2;
                e11 = e11->E1;
                e1 = e1->E1;
                e1free = TRUE;
                goto L4;
            }
            if (!I16 && (ss = isscaledindex(e11)) != 0)
            {   // (v * scale) + const
                cdisscaledindex(cdb,e11,&idxregs,keepmsk);
                reg = findreg(idxregs);
                pcs->Irm = modregrm(0,0,4);
                pcs->Isib = modregrm(ss,reg & 7,5);
                if (reg & 8)
                    pcs->Irex |= REX_X;
            }
            else
            {
                scodelem(cdb,e11,&idxregs,keepmsk,TRUE); // load index reg
                setaddrmode(pcs, idxregs);
            }
            goto Lptr;
        }

        /* Look for *(v1 + v2)
         *      EA = [v1][v2]
         */

        if (!I16 && e1isadd && (!e1->Ecount || !e1free) &&
            (_tysize[e1ty] == REGSIZE || (I64 && _tysize[e1ty] == 4)))
        {
        L4:
            regm_t idxregs2;
            unsigned base,index;

            // Look for *(v1 + v2 << scale)
            int ss = isscaledindex(e12);
            if (ss)
            {
                scodelem(cdb,e11,&idxregs,keepmsk,TRUE);
                idxregs2 = allregs & ~(idxregs | keepmsk);
                cdisscaledindex(cdb,e12,&idxregs2,keepmsk | idxregs);
            }

            // Look for *(v1 << scale + v2)
            else if ((ss = isscaledindex(e11)) != 0)
            {
                idxregs2 = idxregs;
                cdisscaledindex(cdb,e11,&idxregs2,keepmsk);
                idxregs = allregs & ~(idxregs2 | keepmsk);
                scodelem(cdb,e12,&idxregs,keepmsk | idxregs2,TRUE);
            }
            // Look for *(((v1 << scale) + c1) + v2)
            else if (e11->Eoper == OPadd && !e11->Ecount &&
                     e11->E2->Eoper == OPconst &&
                     (ss = isscaledindex(e11->E1)) != 0
                    )
            {
                pcs->IEV1.Vuns = e11->E2->EV.Vuns;
                idxregs2 = idxregs;
                cdisscaledindex(cdb,e11->E1,&idxregs2,keepmsk);
                idxregs = allregs & ~(idxregs2 | keepmsk);
                scodelem(cdb,e12,&idxregs,keepmsk | idxregs2,TRUE);
                freenode(e11->E2);
                freenode(e11);
            }
            else
            {
                scodelem(cdb,e11,&idxregs,keepmsk,TRUE);
                idxregs2 = allregs & ~(idxregs | keepmsk);
                scodelem(cdb,e12,&idxregs2,keepmsk | idxregs,TRUE);
            }
            base = findreg(idxregs);
            index = findreg(idxregs2);
            pcs->Irm  = modregrm(2,0,4);
            pcs->Isib = modregrm(ss,index & 7,base & 7);
            if (index & 8)
                pcs->Irex |= REX_X;
            if (base & 8)
                pcs->Irex |= REX_B;
            if (e1free) freenode(e1);
            goto Lptr;
        }

        /* give up and replace *e1 with
         *      MOV     idxreg,e
         *      EA =    0[idxreg]
         * pinholeopt() will usually correct the 0, we need it in case
         * we have a pointer to a long and need an offset to the second
         * word.
         */

        assert(e1free);
        scodelem(cdb,e1,&idxregs,keepmsk,TRUE);  // load index register
        setaddrmode(pcs, idxregs);
    Lptr:
        if (config.flags3 & CFG3ptrchk)
            cod3_ptrchk(cdb,pcs,keepmsk);        // validate pointer code
        break;
    case FLdatseg:
        assert(0);
#if 0
        pcs->Irm = modregrm(0,0,BPRM);
        pcs->IEVpointer1 = e->EVpointer;
        break;
#endif
    case FLfltreg:
        reflocal = TRUE;
        pcs->Irm = modregrm(2,0,BPRM);
        pcs->IEV1.Vint = 0;
        break;
    case FLreg:
        goto L2;
    case FLpara:
        if (s->Sclass == SCshadowreg)
            goto Lauto;
    Lpara:
        refparam = TRUE;
        pcs->Irm = modregrm(2,0,BPRM);
        goto L2;

    case FLauto:
    case FLfast:
        if (s->Sclass == SCfastpar)
        {
    Lauto:
            regm_t pregm = s->Spregm();
            /* See if the parameter is still hanging about in a register,
             * and so can we load from that register instead.
             */
            if (regcon.params & pregm /*&& s->Spreg2 == NOREG && !(pregm & XMMREGS)*/)
            {
                if (keepmsk & RMload)
                {
                    if (sz == REGSIZE)      // could this be (sz <= REGSIZE) ?
                    {
                        reg_t preg = s->Spreg;
                        if (e->EV.sp.Voffset == REGSIZE)
                            preg = s->Spreg2;
                        /* preg could be NOREG if it's a variadic function and we're
                         * in Win64 shadow regs and we're offsetting to get to the start
                         * of the variadic args.
                         */
                        if (preg != NOREG && regcon.params & mask[preg])
                        {
                            pcs->Irm = modregrm(3,0,preg & 7);
                            if (preg & 8)
                                pcs->Irex |= REX_B;
                            regcon.used |= mask[preg];
                            break;
                        }
                    }
                }
                else
                    regcon.params &= ~pregm;
            }
        }
        if (s->Sclass == SCshadowreg)
            goto Lpara;
    case FLbprel:
        reflocal = TRUE;
        pcs->Irm = modregrm(2,0,BPRM);
        goto L2;
    case FLextern:
        if (s->Sident[0] == '_' && memcmp(s->Sident + 1,"tls_array",10) == 0)
        {
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            // Rewrite as GS:[0000], or FS:[0000] for 64 bit
            if (I64)
            {
                pcs->Irm = modregrm(0, 0, 4);
                pcs->Isib = modregrm(0, 4, 5);  // don't use [RIP] addressing
                pcs->IFL1 = FLconst;
                pcs->IEV1.Vuns = 0;
                pcs->Iflags = CFfs;
                pcs->Irex |= REX_W;
            }
            else
            {
                pcs->Irm = modregrm(0, 0, BPRM);
                pcs->IFL1 = FLconst;
                pcs->IEV1.Vuns = 0;
                pcs->Iflags = CFgs;
            }
            break;
#elif TARGET_WINDOS
            if (I64)
            {   // GS:[88]
                pcs->Irm = modregrm(0, 0, 4);
                pcs->Isib = modregrm(0, 4, 5);  // don't use [RIP] addressing
                pcs->IFL1 = FLconst;
                pcs->IEV1.Vuns = 88;
                pcs->Iflags = CFgs;
                pcs->Irex |= REX_W;
                break;
            }
            else
            {
                pcs->Iflags |= CFfs;    // add FS: override
            }
#endif
        }
        if (s->ty() & mTYcs && LARGECODE)
            goto Lfardata;
        goto L3;
    case FLdata:
    case FLudata:
    case FLcsdata:
    case FLgot:
    case FLgotoff:
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    case FLtlsdata:
#endif
    L3:
        pcs->Irm = modregrm(0,0,BPRM);
    L2:
        if (fl == FLreg)
        {
            if (!(s->Sregm & regcon.mvar)) symbol_print(s);
            assert(s->Sregm & regcon.mvar);

            /* Attempting to paint a float as an integer or an integer as a float
             * will cause serious problems since the EA is loaded separatedly from
             * the opcode. The only way to deal with this is to prevent enregistering
             * such variables.
             */
            if (tyxmmreg(ty) && !(s->Sregm & XMMREGS) ||
                !tyxmmreg(ty) && (s->Sregm & XMMREGS))
                cgreg_unregister(s->Sregm);

            if (
                s->Sclass == SCregpar ||
                s->Sclass == SCparameter)
            {   refparam = TRUE;
                reflocal = TRUE;        // kludge to set up prolog
            }
            pcs->Irm = modregrm(3,0,s->Sreglsw & 7);
            if (s->Sreglsw & 8)
                pcs->Irex |= REX_B;
            if (e->EV.sp.Voffset == REGSIZE && sz == REGSIZE)
            {
                pcs->Irm = modregrm(3,0,s->Sregmsw & 7);
                if (s->Sregmsw & 8)
                    pcs->Irex |= REX_B;
                else
                    pcs->Irex &= ~REX_B;
            }
            else if (e->EV.sp.Voffset == 1 && sz == 1)
            {   assert(s->Sregm & BYTEREGS);
                assert(s->Sreglsw < 4);
                pcs->Irm |= 4;                  // use 2nd byte of register
            }
            else
            {   assert(!e->EV.sp.Voffset);
                if (I64 && sz == 1 && s->Sreglsw >= 4)
                    pcs->Irex |= REX;
            }
        }
        else if (s->ty() & mTYcs && !(fl == FLextern && LARGECODE))
        {
            pcs->Iflags |= CFcs | CFoff;
        }
        if (I64 && config.flags3 & CFG3pic &&
            (fl == FLtlsdata || s->ty() & mTYthread))
        {
            pcs->Iflags |= CFopsize;
            pcs->Irex = 0x48;
        }
        pcs->IEVsym1 = s;
        pcs->IEVoffset1 = e->EV.sp.Voffset;
        if (sz == 1)
        {   /* Don't use SI or DI for this variable     */
            s->Sflags |= GTbyte;
            if (e->EV.sp.Voffset > 1 ||
                I64)                            // could work if restrict reg to AH,BH,CH,DH
                s->Sflags &= ~GTregcand;
        }
        else if (e->EV.sp.Voffset)
            s->Sflags &= ~GTregcand;

        if (config.fpxmmregs && tyfloating(s->ty()) && !tyfloating(ty))
            // Can't successfully mix XMM register variables accessed as integers
            s->Sflags &= ~GTregcand;

        if (!(keepmsk & RMstore))               // if not store only
            s->Sflags |= SFLread;               // assume we are doing a read
        break;
    case FLpseudo:
#if MARS
    {
        getregs(cdb,mask[s->Sreglsw]);
        pcs->Irm = modregrm(3,0,s->Sreglsw & 7);
        if (s->Sreglsw & 8)
            pcs->Irex |= REX_B;
        if (e->EV.sp.Voffset == 1 && sz == 1)
        {   assert(s->Sregm & BYTEREGS);
            assert(s->Sreglsw < 4);
            pcs->Irm |= 4;                  // use 2nd byte of register
        }
        else
        {   assert(!e->EV.sp.Voffset);
            if (I64 && sz == 1 && s->Sreglsw >= 4)
                pcs->Irex |= REX;
        }
        break;
    }
#else
    {
        unsigned u = s->Sreglsw;
        getregs(cdb,pseudomask[u]);
        pcs->Irm = modregrm(3,0,pseudoreg[u] & 7);
        break;
    }
#endif
    case FLfardata:
    case FLfunc:                                /* reading from code seg */
        if (config.exe & EX_flat)
            goto L3;
    Lfardata:
    {
        regm_t regm = ALLREGS & ~keepmsk;       // need scratch register
        allocreg(cdb,&regm,&reg,TYint);
        getregs(cdb,mES);
        // MOV mreg,seg of symbol
        cdb.gencs(0xB8 + reg,0,FLextern,s);
        cdb.last()->Iflags = CFseg;
        cdb.gen2(0x8E,modregrmx(3,0,reg));     // MOV ES,reg
        pcs->Iflags |= CFes | CFoff;            /* ES segment override  */
        goto L3;
    }

    case FLstack:
        assert(!I16);
        pcs->Irm = modregrm(2,0,4);
        pcs->Isib = modregrm(0,4,SP);
        pcs->IEVsym1 = s;
        pcs->IEVoffset1 = e->EV.sp.Voffset;
        break;

    default:
        WRFL((enum FL)fl);
        symbol_print(s);
        assert(0);
  }
}

/*****************************
 * Given an opcode and EA in cs, generate code
 * for each floating register in turn.
 * Input:
 *      tym     either TYdouble or TYfloat
 */

void fltregs(CodeBuilder& cdb,code *pcs,tym_t tym)
{
    assert(!I64);
    tym = tybasic(tym);
    if (I32)
    {
        getregs(cdb,(tym == TYfloat) ? mAX : mAX | mDX);
        if (tym != TYfloat)
        {
            pcs->IEVoffset1 += REGSIZE;
            NEWREG(pcs->Irm,DX);
            cdb.gen(pcs);
            pcs->IEVoffset1 -= REGSIZE;
        }
        NEWREG(pcs->Irm,AX);
        cdb.gen(pcs);
    }
    else
    {
        getregs(cdb,(tym == TYfloat) ? FLOATREGS_16 : DOUBLEREGS_16);
        pcs->IEVoffset1 += (tym == TYfloat) ? 2 : 6;
        if (tym == TYfloat)
            NEWREG(pcs->Irm,DX);
        else
            NEWREG(pcs->Irm,AX);
        cdb.gen(pcs);
        pcs->IEVoffset1 -= 2;
        if (tym == TYfloat)
            NEWREG(pcs->Irm,AX);
        else
            NEWREG(pcs->Irm,BX);
        cdb.gen(pcs);
        if (tym != TYfloat)
        {     pcs->IEVoffset1 -= 2;
              NEWREG(pcs->Irm,CX);
              cdb.gen(pcs);
              pcs->IEVoffset1 -= 2;     /* note that exit is with Voffset unaltered */
              NEWREG(pcs->Irm,DX);
              cdb.gen(pcs);
        }
    }
}


/*****************************
 * Given a result in registers, test it for TRUE or FALSE.
 * Will fail if TYfptr and the reg is ES!
 * If saveflag is TRUE, preserve the contents of the
 * registers.
 */

void tstresult(CodeBuilder& cdb,regm_t regm,tym_t tym,unsigned saveflag)
{
  unsigned scrreg;                      // scratch register
  regm_t scrregm;

#ifdef DEBUG
  //if (!(regm & (mBP | ALLREGS)))
        //printf("tstresult(regm = %s, tym = x%x, saveflag = %d)\n",
            //regm_str(regm),tym,saveflag);
#endif
  assert(regm & (XMMREGS | mBP | ALLREGS));
  tym = tybasic(tym);
  unsigned reg = findreg(regm);
  unsigned sz = _tysize[tym];
  if (sz == 1)
  {
        assert(regm & BYTEREGS);
        cdb.append(genregs(CNIL,0x84,reg,reg));        // TEST regL,regL
        if (I64 && reg >= 4)
            code_orrex(cdb.last(), REX);
        return;
  }
  if (regm & XMMREGS)
  {
        unsigned xreg;
        regm_t xregs = XMMREGS & ~regm;
        allocreg(cdb,&xregs, &xreg, TYdouble);
        unsigned op = 0;
        if (tym == TYdouble || tym == TYidouble || tym == TYcdouble)
            op = 0x660000;
        cdb.gen2(op | 0x0F57,modregrm(3,xreg-XMM0,xreg-XMM0));      // XORPS xreg,xreg
        cdb.gen2(op | 0x0F2E,modregrm(3,xreg-XMM0,reg-XMM0));    // UCOMISS xreg,reg
        if (tym == TYcfloat || tym == TYcdouble)
        {   code *cnop = gennop(CNIL);
            genjmp(cdb,JNE,FLcode,(block *) cnop); // JNE     L1
            genjmp(cdb,JP, FLcode,(block *) cnop); // JP      L1
            reg = findreg(regm & ~mask[reg]);
            cdb.gen2(op | 0x0F2E,modregrm(3,xreg-XMM0,reg-XMM0));        // UCOMISS xreg,reg
            cdb.append(cnop);
        }
        return;
  }
  if (sz <= REGSIZE)
  {
    if (!I16)
    {
        if (tym == TYfloat)
        {   if (saveflag)
            {
                scrregm = allregs & ~regm;              // possible scratch regs
                allocreg(cdb,&scrregm,&scrreg,TYoffset); // allocate scratch reg
                cdb.append(genmovreg(CNIL,scrreg,reg));  // MOV scrreg,msreg
                reg = scrreg;
            }
            getregs(cdb,mask[reg]);
            cdb.gen2(0xD1,modregrmx(3,4,reg)); // SHL reg,1
            return;
        }
        cdb.append(gentstreg(CNIL,reg));                 // TEST reg,reg
        if (sz == SHORTSIZE)
            cdb.last()->Iflags |= CFopsize;             // 16 bit operands
        else if (sz == 8)
            code_orrex(cdb.last(), REX_W);
    }
    else
        cdb.append(gentstreg(CNIL,reg));                 // TEST reg,reg
    return;
  }

    if (saveflag || tyfv(tym))
    {
        scrregm = ALLREGS & ~regm;              // possible scratch regs
        allocreg(cdb,&scrregm,&scrreg,TYoffset); // allocate scratch reg
        if (I32 || sz == REGSIZE * 2)
        {
            assert(regm & mMSW && regm & mLSW);

            reg = findregmsw(regm);
            if (I32)
            {
                if (tyfv(tym))
                    cdb.append(genregs(CNIL,0x0FB7,scrreg,reg)); // MOVZX scrreg,msreg
                else
                {   cdb.append(genmovreg(CNIL,scrreg,reg));      // MOV scrreg,msreg
                    if (tym == TYdouble || tym == TYdouble_alias)
                        cdb.gen2(0xD1,modregrm(3,4,scrreg)); // SHL scrreg,1
                }
            }
            else
            {
                cdb.append(genmovreg(CNIL,scrreg,reg));  // MOV scrreg,msreg
                if (tym == TYfloat)
                    cdb.gen2(0xD1,modregrm(3,4,scrreg)); // SHL scrreg,1
            }
            reg = findreglsw(regm);
            cdb.append(genorreg(CNIL,scrreg,reg));           // OR scrreg,lsreg
        }
        else if (sz == 8)
        {
            // !I32
            cdb.append(genmovreg(CNIL,scrreg,AX));           // MOV scrreg,AX
            if (tym == TYdouble || tym == TYdouble_alias)
                cdb.gen2(0xD1,modregrm(3,4,scrreg));         // SHL scrreg,1
            cdb.append(genorreg(CNIL,scrreg,BX));            // OR scrreg,BX
            cdb.append(genorreg(CNIL,scrreg,CX));            // OR scrreg,CX
            cdb.append(genorreg(CNIL,scrreg,DX));            // OR scrreg,DX
        }
        else
            assert(0);
    }
    else
    {
        if (I32 || sz == REGSIZE * 2)
        {
            // can't test ES:LSW for 0
            assert(regm & mMSW & ALLREGS && regm & (mLSW | mBP));

            reg = findregmsw(regm);
            getregs(cdb,mask[reg]);            // we're going to trash reg
            if (tyfloating(tym) && sz == 2 * intsize)
                cdb.gen2(0xD1,modregrm(3,4,reg));   // SHL reg,1
            cdb.append(genorreg(CNIL,reg,findreglsw(regm)));     // OR reg,reg+1
            if (I64)
                code_orrex(cdb.last(), REX_W);
       }
        else if (sz == 8)
        {   assert(regm == DOUBLEREGS_16);
            getregs(cdb,mAX);                  // allocate AX
            if (tym == TYdouble || tym == TYdouble_alias)
                cdb.gen2(0xD1,modregrm(3,4,AX));       // SHL AX,1
            cdb.append(genorreg(CNIL,AX,BX));          // OR AX,BX
            cdb.append(genorreg(CNIL,AX,CX));          // OR AX,CX
            cdb.append(genorreg(CNIL,AX,DX));          // OR AX,DX
        }
        else
            assert(0);
    }
    code_orflag(cdb.last(),CFpsw);
}


/******************************
 * Given the result of an expression is in retregs,
 * generate necessary code to return result in *pretregs.
 */

void fixresult(CodeBuilder& cdb,elem *e,regm_t retregs,regm_t *pretregs)
{
  unsigned reg,rreg;

  //printf("fixresult(e = %p, retregs = %s, *pretregs = %s)\n",e,regm_str(retregs),regm_str(*pretregs));
  if (*pretregs == 0) return;           // if don't want result
  assert(e && retregs);                 // need something to work with
  regm_t forccs = *pretregs & mPSW;
  regm_t forregs = *pretregs & (mST01 | mST0 | mBP | ALLREGS | mES | mSTACK | XMMREGS);
  tym_t tym = tybasic(e->Ety);
#if TARGET_SEGMENTED
  if (tym == TYstruct)
        // Hack to support cdstreq()
        tym = (forregs & mMSW) ? TYfptr : TYnptr;
#else
  if (tym == TYstruct)
  {
        // Hack to support cdstreq()
        assert(!(forregs & mMSW));
        tym = TYnptr;
  }
#endif
    int sz = _tysize[tym];

  if (sz == 1)
  {
        assert(retregs & BYTEREGS);
        unsigned reg = findreg(retregs);
        if (e->Eoper == OPvar &&
            e->EV.sp.Voffset == 1 &&
            e->EV.sp.Vsym->Sfl == FLreg)
        {
            assert(reg < 4);
            if (forccs)
                cdb.gen2(0x84,modregrm(3,reg | 4,reg | 4));   // TEST regH,regH
            forccs = 0;
        }
  }
  if ((retregs & forregs) == retregs)   // if already in right registers
        *pretregs = retregs;
  else if (forregs)             // if return the result in registers
  {
        if (forregs & (mST01 | mST0))
        {
            fixresult87(cdb,e,retregs,pretregs);
            return;
        }
        unsigned opsflag = FALSE;
        if (I16 && sz == 8)
        {   if (forregs & mSTACK)
            {   assert(retregs == DOUBLEREGS_16);
                // Push floating regs
                cdb.gen1(0x50 + AX);
                cdb.gen1(0x50 + BX);
                cdb.gen1(0x50 + CX);
                cdb.gen1(0x50 + DX);
                stackpush += DOUBLESIZE;
            }
            else if (retregs & mSTACK)
            {   assert(forregs == DOUBLEREGS_16);
                // Pop floating regs
                getregs(cdb,forregs);
                cdb.gen1(0x58 + DX);
                cdb.gen1(0x58 + CX);
                cdb.gen1(0x58 + BX);
                cdb.gen1(0x58 + AX);
                stackpush -= DOUBLESIZE;
                retregs = DOUBLEREGS_16; // for tstresult() below
            }
            else
#ifdef DEBUG
                printf("retregs = %s, forregs = %s\n", regm_str(retregs), regm_str(forregs)),
#endif
                assert(0);
            if (EOP(e))
                opsflag = TRUE;
        }
        else
        {
            allocreg(cdb,pretregs,&rreg,tym);  // allocate return regs
            if (retregs & XMMREGS)
            {
                reg = findreg(retregs & XMMREGS);
                // MOVSD floatreg, XMM?
                cdb.append(genxmmreg(CNIL,xmmstore(tym),reg,0,tym));
                if (mask[rreg] & XMMREGS)
                    // MOVSD XMM?, floatreg
                    cdb.append(genxmmreg(CNIL,xmmload(tym),rreg,0,tym));
                else
                {
                    // MOV rreg,floatreg
                    cdb.genfltreg(0x8B,rreg,0);
                    if (sz == 8)
                    {
                        if (I32)
                        {
                            rreg = findregmsw(*pretregs);
                            cdb.genfltreg(0x8B,rreg,4);
                        }
                        else
                            code_orrex(cdb.last(),REX_W);
                    }
                }
            }
            else if (forregs & XMMREGS)
            {
                reg = findreg(retregs & (mBP | ALLREGS));
                switch (sz)
                {
                case 4:
                    cdb.gen2(LODD, modregxrmx(3,rreg - XMM0,reg)); // MOVD xmm,reg
                    break;
                case 8:
                    if (I32)
                    {
                        cdb.genfltreg(0x89,reg,0);
                        reg = findregmsw(retregs);
                        cdb.genfltreg(0x89,reg,4);
                        cdb.append(genxmmreg(CNIL,xmmload(tym),rreg,0,tym)); // MOVQ xmm,mem
                    }
                    else
                    {
                        cdb.gen2(LODD /* [sic!] */, modregxrmx(3,rreg - XMM0,reg));
                        code_orrex(cdb.last(),REX_W); // MOVQ xmm,reg
                    }
                    break;
                default:
                    assert(false);
                }
                checkSetVex(cdb.last(), tym);
            }
            else if (sz > REGSIZE)
            {
                unsigned msreg = findregmsw(retregs);
                unsigned lsreg = findreglsw(retregs);
                unsigned msrreg = findregmsw(*pretregs);
                unsigned lsrreg = findreglsw(*pretregs);

                cdb.append(genmovreg(CNIL,msrreg,msreg)); // MOV msrreg,msreg
                cdb.append(genmovreg(CNIL,lsrreg,lsreg)); // MOV lsrreg,lsreg
            }
            else
            {
                assert(!(retregs & XMMREGS));
                assert(!(forregs & XMMREGS));
                reg = findreg(retregs & (mBP | ALLREGS));
                cdb.append(genmovreg(CNIL,rreg,reg));    // MOV rreg,reg
            }
        }
        cssave(e,retregs | *pretregs,opsflag);
        // Commented out due to Bugzilla 8840
        //forregs = 0;    // don't care about result in reg cuz real result is in rreg
        retregs = *pretregs & ~mPSW;
  }
  if (forccs)                           // if return result in flags
  {
        if (retregs & (mST01 | mST0))
            fixresult87(cdb,e,retregs,pretregs);
        else
            tstresult(cdb,retregs,tym,forregs);
  }
}

/*******************************
 * Extra information about each CLIB runtime library function.
 */
struct ClibInfo
{
    regm_t retregs16;   /* registers that 16 bit result is returned in  */
    regm_t retregs32;   /* registers that 32 bit result is returned in  */
    char pop;           /* # of bytes popped off of stack upon return   */
    char flags;
        #define INF32           1       // if 32 bit only
        #define INFfloat        2       // if this is floating point
        #define INFwkdone       4       // if weak extern is already done
        #define INF64           8       // if 64 bit only
        #define INFpushebx      0x10    // push EBX before load_localgot()
    char push87;                        // # of pushes onto the 8087 stack
    char pop87;                         // # of pops off of the 8087 stack
};

int clib_inited = false;          // true if initialized

symbol *symboly(const char *name, regm_t desregs)
{
    symbol *s = symbol_calloc(name);
    s->Stype = tsclib;
    s->Sclass = SCextern;
    s->Sfl = FLfunc;
    s->Ssymnum = 0;
    s->Sregsaved = ~desregs & (mBP | mES | ALLREGS);
    return s;
}

void getClibInfo(unsigned clib, symbol **ps, ClibInfo **pinfo)
{
    static symbol *clibsyms[CLIBMAX];
    static ClibInfo clibinfo[CLIBMAX];

    if (!clib_inited)
    {
        for (size_t i = 0; i < CLIBMAX; ++i)
        {
            symbol *s = clibsyms[i];
            if (s)
            {
                s->Sxtrnnum = 0;
                s->Stypidx = 0;
                clibinfo[i].flags &= ~INFwkdone;
            }
        }
        clib_inited = true;
    }

    const unsigned ex_unix = (EX_LINUX   | EX_LINUX64   |
                              EX_OSX     | EX_OSX64     |
                              EX_FREEBSD | EX_FREEBSD64 |
                              EX_OPENBSD | EX_OPENBSD64 |
                              EX_SOLARIS | EX_SOLARIS64);

    ClibInfo *cinfo = &clibinfo[clib];
    symbol *s = clibsyms[clib];
    if (!s)
    {

        switch (clib)
        {
            case CLIBlcmp:
                {
                    const char *name = (config.exe & ex_unix) ? "__LCMP__" : "_LCMP@";
                    s = symboly(name, 0);
                }
                break;
            case CLIBlmul:
                {
                    const char *name = (config.exe & ex_unix) ? "__LMUL__" : "_LMUL@";
                    s = symboly(name, mAX|mCX|mDX);
                    cinfo->retregs16 = mDX|mAX;
                    cinfo->retregs32 = mDX|mAX;
                }
                break;
            case CLIBldiv:
                cinfo->retregs16 = mDX|mAX;
                if (config.exe & (EX_LINUX | EX_FREEBSD))
                {
                    s = symboly("__divdi3", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mDX|mAX;
                }
                else if (config.exe & (EX_OPENBSD | EX_SOLARIS))
                {
                    s = symboly("__LDIV2__", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mDX|mAX;
                }
                else if (I32 && config.objfmt == OBJ_MSCOFF)
                {
                    s = symboly("_ms_alldiv", ALLREGS);
                    cinfo->retregs32 = mDX|mAX;
                }
                else
                {
                    const char *name = (config.exe & ex_unix) ? "__LDIV__" : "_LDIV@";
                    s = symboly(name, (config.exe & ex_unix) ? mAX|mBX|mCX|mDX : ALLREGS);
                    cinfo->retregs32 = mDX|mAX;
                }
                break;
            case CLIBlmod:
                cinfo->retregs16 = mCX|mBX;
                if (config.exe & (EX_LINUX | EX_FREEBSD))
                {
                    s = symboly("__moddi3", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mDX|mAX;
                }
                else if (config.exe & (EX_OPENBSD | EX_SOLARIS))
                {
                    s = symboly("__LDIV2__", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mCX|mBX;
                }
                else if (I32 && config.objfmt == OBJ_MSCOFF)
                {
                    s = symboly("_ms_allrem", ALLREGS);
                    cinfo->retregs32 = mDX|mAX;
                }
                else
                {
                    const char *name = (config.exe & ex_unix) ? "__LDIV__" : "_LDIV@";
                    s = symboly(name, (config.exe & ex_unix) ? mAX|mBX|mCX|mDX : ALLREGS);
                    cinfo->retregs32 = mCX|mBX;
                }
                break;
            case CLIBuldiv:
                cinfo->retregs16 = mDX|mAX;
                if (config.exe & (EX_LINUX | EX_FREEBSD))
                {
                    s = symboly("__udivdi3", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mDX|mAX;
                }
                else if (config.exe & (EX_OPENBSD | EX_SOLARIS))
                {
                    s = symboly("__ULDIV2__", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mDX|mAX;
                }
                else if (I32 && config.objfmt == OBJ_MSCOFF)
                {
                    s = symboly("_ms_aulldiv", ALLREGS);
                    cinfo->retregs32 = mDX|mAX;
                }
                else
                {
                    const char *name = (config.exe & ex_unix) ? "__ULDIV__" : "_ULDIV@";
                    s = symboly(name, (config.exe & ex_unix) ? mAX|mBX|mCX|mDX : ALLREGS);
                    cinfo->retregs32 = mDX|mAX;
                }
                break;
            case CLIBulmod:
                cinfo->retregs16 = mCX|mBX;
                if (config.exe & (EX_LINUX | EX_FREEBSD))
                {
                    s = symboly("__umoddi3", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mDX|mAX;
                }
                else if (config.exe & (EX_OPENBSD | EX_SOLARIS))
                {
                    s = symboly("__LDIV2__", mAX|mBX|mCX|mDX);
                    cinfo->flags = INFpushebx;
                    cinfo->retregs32 = mCX|mBX;
                }
                else if (I32 && config.objfmt == OBJ_MSCOFF)
                {
                    s = symboly("_ms_aullrem", ALLREGS);
                    cinfo->retregs32 = mDX|mAX;
                }
                else
                {
                    const char *name = (config.exe & ex_unix) ? "__ULDIV__" : "_ULDIV@";
                    s = symboly(name, (config.exe & ex_unix) ? mAX|mBX|mCX|mDX : ALLREGS);
                    cinfo->retregs32 = mCX|mBX;
                }
                break;

            // This section is only for Windows and DOS (i.e. machines without the x87 FPU)
            case CLIBdmul:
                s = symboly("_DMUL@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->pop = 8;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBddiv:
                s = symboly("_DDIV@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->pop = 8;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBdtst0:
                s = symboly("_DTST0@",0);
                cinfo->flags = INFfloat;
                break;
            case CLIBdtst0exc:
                s = symboly("_DTST0EXC@",0);
                cinfo->flags = INFfloat;
                break;
            case CLIBdcmp:
                s = symboly("_DCMP@",0);
                cinfo->pop = 8;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBdcmpexc:
                s = symboly("_DCMPEXC@",0);
                cinfo->pop = 8;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBdneg:
                s = symboly("_DNEG@",I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                break;
            case CLIBdadd:
                s = symboly("_DADD@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->pop = 8;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBdsub:
                s = symboly("_DSUB@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->pop = 8;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBfmul:
                s = symboly("_FMUL@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = FLOATREGS_16;
                cinfo->retregs32 = FLOATREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBfdiv:
                s = symboly("_FDIV@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = FLOATREGS_16;
                cinfo->retregs32 = FLOATREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBftst0:
                s = symboly("_FTST0@",0);
                cinfo->flags = INFfloat;
                break;
            case CLIBftst0exc:
                s = symboly("_FTST0EXC@",0);
                cinfo->flags = INFfloat;
                break;
            case CLIBfcmp:
                s = symboly("_FCMP@",0);
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBfcmpexc:
                s = symboly("_FCMPEXC@",0);
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBfneg:
                s = symboly("_FNEG@",I16 ? FLOATREGS_16 : FLOATREGS_32);
                cinfo->retregs16 = FLOATREGS_16;
                cinfo->retregs32 = FLOATREGS_32;
                cinfo->flags = INFfloat;
                break;
            case CLIBfadd:
                s = symboly("_FADD@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = FLOATREGS_16;
                cinfo->retregs32 = FLOATREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            case CLIBfsub:
                s = symboly("_FSUB@",mAX|mBX|mCX|mDX);
                cinfo->retregs16 = FLOATREGS_16;
                cinfo->retregs32 = FLOATREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;

            case CLIBdbllng:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLLNG" : "_DBLLNG@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = mDX | mAX;
                cinfo->retregs32 = mAX;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBlngdbl:
            {
                const char *name = (config.exe & ex_unix) ? "__LNGDBL" : "_LNGDBL@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBdblint:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLINT" : "_DBLINT@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = mAX;
                cinfo->retregs32 = mAX;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBintdbl:
            {
                const char *name = (config.exe & ex_unix) ? "__INTDBL" : "_INTDBL@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBdbluns:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLUNS" : "_DBLUNS@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = mAX;
                cinfo->retregs32 = mAX;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBunsdbl:
                // Y(DOUBLEREGS_32,"__UNSDBL"),         // CLIBunsdbl
                // Y(DOUBLEREGS_16,"_UNSDBL@"),
                // {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _UNSDBL@     unsdbl
            {
                const char *name = (config.exe & ex_unix) ? "__UNSDBL" : "_UNSDBL@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBdblulng:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLULNG" : "_DBLULNG@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = mDX|mAX;
                cinfo->retregs32 = mAX;
                cinfo->flags = (config.exe & ex_unix) ? INFfloat | INF32 : INFfloat;
                cinfo->push87 = (config.exe & ex_unix) ? 0 : 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBulngdbl:
            {
                const char *name = (config.exe & ex_unix) ? "__ULNGDBL@" : "_ULNGDBL@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBdblflt:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLFLT" : "_DBLFLT@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = FLOATREGS_16;
                cinfo->retregs32 = FLOATREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBfltdbl:
            {
                const char *name = (config.exe & ex_unix) ? "__FLTDBL" : "_FLTDBL@";
                s = symboly(name, I16 ? ALLREGS : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBdblllng:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLLLNG" : "_DBLLLNG@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = mDX|mAX;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBllngdbl:
            {
                const char *name = (config.exe & ex_unix) ? "__LLNGDBL" : "_LLNGDBL@";
                s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                cinfo->retregs16 = DOUBLEREGS_16;
                cinfo->retregs32 = DOUBLEREGS_32;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBdblullng:
            {
                if (config.exe == EX_WIN64)
                {
                    s = symboly("__DBLULLNG", DOUBLEREGS_32);
                    cinfo->retregs32 = mAX;
                    cinfo->flags = INFfloat;
                    cinfo->push87 = 2;
                    cinfo->pop87 = 2;
                }
                else
                {
                    const char *name = (config.exe & ex_unix) ? "__DBLULLNG" : "_DBLULLNG@";
                    s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                    cinfo->retregs16 = DOUBLEREGS_16;
                    cinfo->retregs32 = I64 ? mAX : mDX|mAX;
                    cinfo->flags = INFfloat;
                    cinfo->push87 = (config.exe & ex_unix) ? 2 : 1;
                    cinfo->pop87 = (config.exe & ex_unix) ? 2 : 1;
                }
                break;
            }
            case CLIBullngdbl:
            {
                if (config.exe == EX_WIN64)
                {
                    s = symboly("__ULLNGDBL", DOUBLEREGS_32);
                    cinfo->retregs32 = mAX;
                    cinfo->flags = INFfloat;
                    cinfo->push87 = 1;
                    cinfo->pop87 = 1;
                }
                else
                {
                    const char *name = (config.exe & ex_unix) ? "__ULLNGDBL" : "_ULLNGDBL@";
                    s = symboly(name, I16 ? DOUBLEREGS_16 : DOUBLEREGS_32);
                    cinfo->retregs16 = DOUBLEREGS_16;
                    cinfo->retregs32 = I64 ? mAX : DOUBLEREGS_32;
                    cinfo->flags = INFfloat;
                    cinfo->push87 = 1;
                    cinfo->pop87 = 1;
                }
                break;
            }
            case CLIBdtst:
            {
                const char *name = (config.exe & ex_unix) ? "__DTST" : "_DTST@";
                s = symboly(name, 0);
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBvptrfptr:
            {
                const char *name = (config.exe & ex_unix) ? "__HTOFPTR" : "_HTOFPTR@";
                s = symboly(name, mES|mBX);
                cinfo->retregs16 = mES|mBX;
                cinfo->retregs32 = mES|mBX;
                break;
            }
            case CLIBcvptrfptr:
            {
                const char *name = (config.exe & ex_unix) ? "__HCTOFPTR" : "_HCTOFPTR@";
                s = symboly(name, mES|mBX);
                cinfo->retregs16 = mES|mBX;
                cinfo->retregs32 = mES|mBX;
                break;
            }
            case CLIB87topsw:
            {
                const char *name = (config.exe & ex_unix) ? "__87TOPSW" : "_87TOPSW@";
                s = symboly(name, 0);
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBfltto87:
            {
                const char *name = (config.exe & ex_unix) ? "__FLTTO87" : "_FLTTO87@";
                s = symboly(name, mST0);
                cinfo->retregs16 = mST0;
                cinfo->retregs32 = mST0;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                break;
            }
            case CLIBdblto87:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLTO87" : "_DBLTO87@";
                s = symboly(name, mST0);
                cinfo->retregs16 = mST0;
                cinfo->retregs32 = mST0;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                break;
            }
            case CLIBdblint87:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLINT87" : "_DBLINT87@";
                s = symboly(name, mST0|mAX);
                cinfo->retregs16 = mAX;
                cinfo->retregs32 = mAX;
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBdbllng87:
            {
                const char *name = (config.exe & ex_unix) ? "__DBLLNG87" : "_DBLLNG87@";
                s = symboly(name, mST0|mAX|mDX);
                cinfo->retregs16 = mDX|mAX;
                cinfo->retregs32 = mAX;
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBftst:
            {
                const char *name = (config.exe & ex_unix) ? "__FTST" : "_FTST@";
                s = symboly(name, 0);
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBfcompp:
            {
                const char *name = (config.exe & ex_unix) ? "__FCOMPP" : "_FCOMPP@";
                s = symboly(name, 0);
                cinfo->retregs16 = mPSW;
                cinfo->retregs32 = mPSW;
                cinfo->flags = INFfloat;
                cinfo->pop87 = 2;
                break;
            }
            case CLIBftest:
            {
                const char *name = (config.exe & ex_unix) ? "__FTEST" : "_FTEST@";
                s = symboly(name, 0);
                cinfo->retregs16 = mPSW;
                cinfo->retregs32 = mPSW;
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBftest0:
            {
                const char *name = (config.exe & ex_unix) ? "__FTEST0" : "_FTEST0@";
                s = symboly(name, 0);
                cinfo->retregs16 = mPSW;
                cinfo->retregs32 = mPSW;
                cinfo->flags = INFfloat;
                break;
            }
            case CLIBfdiv87:
            {
                const char *name = (config.exe & ex_unix) ? "__FDIVP" : "_FDIVP";
                s = symboly(name, mST0|mAX|mBX|mCX|mDX);
                cinfo->retregs16 = mST0;
                cinfo->retregs32 = mST0;
                cinfo->flags = INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 1;
                break;
            }

            // Complex numbers
            case CLIBcmul:
            {
                s = symboly("_Cmul", mST0|mST01);
                cinfo->retregs16 = mST01;
                cinfo->retregs32 = mST01;
                cinfo->flags = INF32|INFfloat;
                cinfo->push87 = 3;
                cinfo->pop87 = 5;
                break;
            }
            case CLIBcdiv:
            {
                s = symboly("_Cdiv", mAX|mCX|mDX|mST0|mST01);
                cinfo->retregs16 = mST01;
                cinfo->retregs32 = mST01;
                cinfo->flags = INF32|INFfloat;
                cinfo->push87 = 0;
                cinfo->pop87 = 2;
                break;
            }
            case CLIBccmp:
            {
                s = symboly("_Ccmp", mAX|mST0|mST01);
                cinfo->retregs16 = mPSW;
                cinfo->retregs32 = mPSW;
                cinfo->flags = INF32|INFfloat;
                cinfo->push87 = 0;
                cinfo->pop87 = 4;
                break;
            }

            case CLIBu64_ldbl:
            {
                const char *name = (config.exe & ex_unix) ? "__U64_LDBL" : "_U64_LDBL";
                s = symboly(name, mST0);
                cinfo->retregs16 = mST0;
                cinfo->retregs32 = mST0;
                cinfo->flags = INF32|INF64|INFfloat;
                cinfo->push87 = 2;
                cinfo->pop87 = 1;
                break;
            }
            case CLIBld_u64:
            {
                const char *name = (config.exe & ex_unix) ? (config.objfmt == OBJ_ELF ||
                                                             config.objfmt == OBJ_MACH ?
                                                                "__LDBLULLNG" : "___LDBLULLNG")
                                                          : "__LDBLULLNG";
                s = symboly(name, mST0|mAX|mDX);
                cinfo->retregs16 = 0;
                cinfo->retregs32 = mDX|mAX;
                cinfo->flags = INF32|INF64|INFfloat;
                cinfo->push87 = 1;
                cinfo->pop87 = 2;
                break;
            }
                break;

            default:
                assert(0);
        }
        clibsyms[clib] = s;
    }

    *ps = s;
    *pinfo = cinfo;
}

/********************************
 * Generate code sequence to call C runtime library support routine.
 *      clib = CLIBxxxx
 *      keepmask = mask of registers not to destroy. Currently can
 *              handle only 1. Should use a temporary rather than
 *              push/pop for speed.
 */

void callclib(CodeBuilder& cdb,elem *e,unsigned clib,regm_t *pretregs,regm_t keepmask)
{
    //printf("callclib(e = %p, clib = %d, *pretregs = %s, keepmask = %s\n", e, clib, regm_str(*pretregs), regm_str(keepmask));
    //elem_print(e);

    symbol *s;
    ClibInfo *cinfo;
    getClibInfo(clib, &s, &cinfo);

    if (I16)
        assert(!(cinfo->flags & (INF32 | INF64)));
    getregs(cdb,(~s->Sregsaved & (mES | mBP | ALLREGS)) & ~keepmask); // mask of regs destroyed
    keepmask &= ~s->Sregsaved;
    int npushed = numbitsset(keepmask);
    code *c = CNIL;
    code *cpop = CNIL;
    gensaverestore2(keepmask, &c, &cpop);
    cdb.append(c);

    save87regs(cdb,cinfo->push87);
    for (int i = 0; i < cinfo->push87; i++)
        push87(cdb);

    for (int i = 0; i < cinfo->pop87; i++)
        pop87();

  if (config.target_cpu >= TARGET_80386 && clib == CLIBlmul && !I32)
  {     static unsigned char lmul[] = {
            0x66,0xc1,0xe1,0x10,        // shl  ECX,16
            0x8b,0xcb,                  // mov  CX,BX           ;ECX = CX,BX
            0x66,0xc1,0xe0,0x10,        // shl  EAX,16
            0x66,0x0f,0xac,0xd0,0x10,   // shrd EAX,EDX,16      ;EAX = DX,AX
            0x66,0xf7,0xe1,             // mul  ECX
            0x66,0x0f,0xa4,0xc2,0x10,   // shld EDX,EAX,16      ;DX,AX = EAX
        };

        cdb.append(genasm(CNIL,lmul,sizeof(lmul)));
  }
  else
  {
        code *cgot = NULL;
        if (config.exe & (EX_LINUX | EX_FREEBSD | EX_OPENBSD | EX_SOLARIS))
        {
            // Note: not for OSX
            /* Pass EBX on the stack instead, this is because EBX is used
             * for shared library function calls
             */
            if (config.flags3 & CFG3pic)
            {
                cgot = load_localgot();     // EBX gets set to this value
            }
        }

        makeitextern(s);
        int nalign = 0;
        int pushebx = (cinfo->flags & INFpushebx) != 0;
        if (STACKALIGN == 16)
        {   // Align the stack (assume no args on stack)
            int npush = (npushed + pushebx) * REGSIZE + stackpush;
            if (npush & (STACKALIGN - 1))
            {   nalign = STACKALIGN - (npush & (STACKALIGN - 1));
                cod3_stackadj(cdb, nalign);
            }
        }
        if (pushebx)
        {
            if (config.exe & (EX_LINUX | EX_LINUX64 | EX_FREEBSD | EX_FREEBSD64))
            {
                cdb.gen1(0x50 + CX);                             // PUSH ECX
                cdb.gen1(0x50 + BX);                             // PUSH EBX
                cdb.gen1(0x50 + DX);                             // PUSH EDX
                cdb.gen1(0x50 + AX);                             // PUSH EAX
                nalign += 4 * REGSIZE;
            }
            else
            {
                cdb.gen1(0x50 + BX);                             // PUSH EBX
                nalign += REGSIZE;
            }
        }
        cdb.append(cgot);                                        // EBX = localgot
        cdb.append(gencs(CNIL,LARGECODE ? 0x9A : 0xE8,0,FLfunc,s));  // CALL s
        if (nalign)
            cod3_stackadj(cdb, -nalign);
        calledafunc = 1;

#if SCPP & TX86
        if (I16 &&                                   // bug in Optlink for weak references
            config.flags3 & CFG3wkfloat &&
            (cinfo->flags & (INFfloat | INFwkdone)) == INFfloat)
        {   cinfo->flags |= INFwkdone;
            makeitextern(getRtlsym(RTLSYM_INTONLY));
            objmod->wkext(s,getRtlsym(RTLSYM_INTONLY));
        }
#endif
    }
    if (I16)
        stackpush -= cinfo->pop;
    regm_t retregs = I16 ? cinfo->retregs16 : cinfo->retregs32;
    cdb.append(cpop);
    fixresult(cdb,e,retregs,pretregs);
}

/*************************************************
 * Helper function for converting OPparam's into array of Parameters.
 */
struct Parameter { elem *e; reg_t reg; reg_t reg2; unsigned numalign; };

void fillParameters(elem *e, Parameter *parameters, int *pi)
{
    if (e->Eoper == OPparam)
    {
        fillParameters(e->E1, parameters, pi);
        fillParameters(e->E2, parameters, pi);
        freenode(e);
    }
    else
    {
        parameters[*pi].e = e;
        (*pi)++;
    }
}


/***********************************
 * tyf: type of the function
 */
FuncParamRegs FuncParamRegs::create(tym_t tyf)
{
    return FuncParamRegs(tyf);
}

FuncParamRegs::FuncParamRegs(tym_t tyf)
{
    this->tyf = tyf;
    i = 0;
    regcnt = 0;
    xmmcnt = 0;

    if (I16)
    {
        numintegerregs = 0;
        numfloatregs = 0;
    }
    else if (I32)
    {
        if (tyf == TYjfunc)
        {
            static const unsigned char reglist[] = { AX };
            argregs = reglist;
            numintegerregs = sizeof(reglist) / sizeof(reglist[0]);
        }
        else if (tyf == TYmfunc)
        {
            static const unsigned char reglist[] = { CX };
            argregs = reglist;
            numintegerregs = sizeof(reglist) / sizeof(reglist[0]);
        }
        else
            numintegerregs = 0;
        numfloatregs = 0;
    }
    else if (I64 && config.exe == EX_WIN64)
    {
        static const unsigned char reglist[] = { CX,DX,R8,R9 };
        argregs = reglist;
        numintegerregs = sizeof(reglist) / sizeof(reglist[0]);

        static const unsigned char freglist[] = { XMM0, XMM1, XMM2, XMM3 };
        floatregs = freglist;
        numfloatregs = sizeof(freglist) / sizeof(freglist[0]);
    }
    else if (I64)
    {
        static const unsigned char reglist[] = { DI,SI,DX,CX,R8,R9 };
        argregs = reglist;
        numintegerregs = sizeof(reglist) / sizeof(reglist[0]);

        static const unsigned char freglist[] = { XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6, XMM7 };
        floatregs = freglist;
        numfloatregs = sizeof(freglist) / sizeof(freglist[0]);
    }
    else
        assert(0);
}

/*****************************************
 * Allocate parameter of type t and ty to registers *preg1 and *preg2.
 * Returns:
 *      0       not allocated to any register
 *      1       *preg1, *preg2 set to allocated register pair
 */

// t is valid only if ty is a TYstruct or TYarray
static int type_jparam2(type *t, tym_t ty)
{
    ty = tybasic(ty);

    if (tyfloating(ty))
        ;
    else if (ty == TYstruct || ty == TYarray)
    {
        type_debug(t);
        targ_size_t sz = type_size(t);
        return (sz <= NPTRSIZE) &&
               (config.exe == EX_WIN64 || sz == 1 || sz == 2 || sz == 4 || sz == 8);
    }
    else if (tysize(ty) <= NPTRSIZE)
        return 1;
    return 0;
}

int FuncParamRegs::alloc(type *t, tym_t ty, reg_t *preg1, reg_t *preg2)
{
    //printf("FuncParamRegs::alloc(ty = TY%s)\n", tystring[tybasic(ty)]);
    //if (t) type_print(t);
    ++i;

    *preg1 = NOREG;
    *preg2 = NOREG;

    type *t2 = NULL;
    tym_t ty2 = TYMAX;

    // If struct just wraps another type
    if (tybasic(ty) == TYstruct && tybasic(t->Tty) == TYstruct)
    {
        if (config.exe == EX_WIN64)
        {
            /* Structs occupy a general purpose register, regardless of the struct
             * size or the number & types of its fields.
             */
            t = NULL;
            ty = TYnptr;
        }
        else
        {
            type *targ1 = t->Ttag->Sstruct->Sarg1type;
            type *targ2 = t->Ttag->Sstruct->Sarg2type;
            if (targ1)
            {
                t = targ1;
                ty = t->Tty;
                if (targ2)
                {
                    t2 = targ2;
                    ty2 = t2->Tty;
                }
            }
            else if (I64 && !targ2)
                return 0;
        }
    }

    reg_t *preg = preg1;
    int regcntsave = regcnt;
    int xmmcntsave = xmmcnt;

    if (config.exe == EX_WIN64)
    {
        if (tybasic(ty) == TYcfloat)
        {
            ty = TYnptr;                // treat like a struct
        }
    }
    else if (I64)
    {
        if ((tybasic(ty) == TYcent || tybasic(ty) == TYucent) &&
            numintegerregs - regcnt >= 2)
        {
            // Allocate to register pair
            *preg1 = argregs[regcnt];
            *preg2 = argregs[regcnt + 1];
            regcnt += 2;
            return 1;
        }

        if (tybasic(ty) == TYcdouble &&
            numfloatregs - xmmcnt >= 2)
        {
            // Allocate to register pair
            *preg1 = floatregs[xmmcnt];
            *preg2 = floatregs[xmmcnt + 1];
            xmmcnt += 2;
            return 1;
        }
    }

    for (int j = 0; j < 2; j++)
    {
        if (regcnt < numintegerregs)
        {
            if ((I64 || (i == 1 && (tyf == TYjfunc || tyf == TYmfunc))) &&
                type_jparam2(t, ty))
            {
                *preg = argregs[regcnt];
                ++regcnt;
                if (config.exe == EX_WIN64)
                    ++xmmcnt;
                goto Lnext;
            }
        }
        if (xmmcnt < numfloatregs)
        {
            if (tyxmmreg(ty))
            {
                *preg = floatregs[xmmcnt];
                if (config.exe == EX_WIN64)
                    ++regcnt;
                ++xmmcnt;
                goto Lnext;
            }
        }
        // Failed to allocate to a register
        if (j == 1)
        {   /* Unwind first preg1 assignment, because it's both or nothing
             */
            *preg1 = NOREG;
            regcnt = regcntsave;
            xmmcnt = xmmcntsave;
        }
        return 0;

     Lnext:
        if (!t2)
            break;
        preg = preg2;
        t = t2;
        ty = ty2;
    }
    return 1;
}

/*******************************
 * Generate code sequence for function call.
 */

void cdfunc(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    //printf("cdfunc()\n"); elem_print(e);
    assert(e);
    unsigned numpara = 0;               // bytes of parameters
    unsigned numalign = 0;              // bytes to align stack before pushing parameters
    unsigned stackpushsave = stackpush;            // so we can compute # of parameters
    cgstate.stackclean++;
    regm_t keepmsk = 0;
    int xmmcnt = 0;
    tym_t tyf = tybasic(e->E1->Ety);        // the function type

    // Easier to deal with parameters as an array: parameters[0..np]
    int np = OTbinary(e->Eoper) ? el_nparams(e->E2) : 0;
    Parameter *parameters = (Parameter *)alloca(np * sizeof(Parameter));

    if (np)
    {   int n = 0;
        fillParameters(e->E2, parameters, &n);
        assert(n == np);
    }

    symbol *sf = NULL;                  // symbol of the function being called
    if (e->E1->Eoper == OPvar)
        sf = e->E1->EV.sp.Vsym;

    /* Special handling for call to __tls_get_addr, we must save registers
     * before evaluating the parameter, so that the parameter load and call
     * are adjacent.
     */
    if (np == 1 && sf)
    {
        if (sf == tls_get_addr_sym)
            getregs(cdb,~sf->Sregsaved & (mBP | ALLREGS | mES | XMMREGS));
    }

    unsigned stackalign = REGSIZE;
    if (tyf == TYf16func)
        stackalign = 2;
    // Figure out which parameters go in registers.
    // Compute numpara, the total bytes pushed on the stack
    FuncParamRegs fpr(tyf);
    for (int i = np; --i >= 0;)
    {
        elem *ep = parameters[i].e;
        unsigned psize = _align(stackalign, paramsize(ep));     // align on stack boundary
        if (config.exe == EX_WIN64)
        {
            //printf("[%d] size = %u, numpara = %d ep = %p ", i, psize, numpara, ep); WRTYxx(ep->Ety); printf("\n");
#ifdef DEBUG
            if (psize > REGSIZE) elem_print(e);
#endif
            assert(psize <= REGSIZE);
            psize = REGSIZE;
        }
        //printf("[%d] size = %u, numpara = %d ", i, psize, numpara); WRTYxx(ep->Ety); printf("\n");
        if (fpr.alloc(ep->ET, ep->Ety, &parameters[i].reg, &parameters[i].reg2))
        {
            if (config.exe == EX_WIN64)
                numpara += REGSIZE;             // allocate stack space for it anyway
            continue;   // goes in register, not stack
        }

        // Parameter i goes on the stack
        parameters[i].reg = NOREG;
        unsigned alignsize = el_alignsize(ep);
        parameters[i].numalign = 0;
        if (alignsize > stackalign &&
            (I64 || (alignsize == 16 && tyvector(ep->Ety))))
        {   unsigned newnumpara = (numpara + (alignsize - 1)) & ~(alignsize - 1);
            parameters[i].numalign = newnumpara - numpara;
            numpara = newnumpara;
            assert(config.exe != EX_WIN64);
        }
        numpara += psize;
    }

    if (config.exe == EX_WIN64)
    {
        if (numpara < 4 * REGSIZE)
            numpara = 4 * REGSIZE;
    }

    //printf("numpara = %d, stackpush = %d\n", numpara, stackpush);
    assert((numpara & (REGSIZE - 1)) == 0);
    assert((stackpush & (REGSIZE - 1)) == 0);

    /* Should consider reordering the order of evaluation of the parameters
     * so that args that go into registers are evaluated after args that get
     * pushed. We can reorder args that are constants or relconst's.
     */

    /* Determine if we should use cgstate.funcarg for the parameters or push them
     */
    bool usefuncarg = FALSE;
#if 0
    printf("test1 %d %d %d %d %d %d %d %d\n", (config.flags4 & CFG4speed)!=0, !Alloca.size,
        !(usednteh & ~NTEHjmonitor),
        (int)numpara, !stackpush,
        (cgstate.funcargtos == ~0 || numpara < cgstate.funcargtos),
        (!typfunc(tyf) || sf && sf->Sflags & SFLexit), !I16);
#endif
    if (config.flags4 & CFG4speed &&
        !Alloca.size &&
        /* The cleanup code calls a local function, leaving the return address on
         * the top of the stack. If parameters are placed there, the return address
         * is stepped on.
         * A better solution is turn this off only inside the cleanup code.
         */
        !usednteh &&
        (numpara || config.exe == EX_WIN64) &&
        stackpush == 0 &&               // cgstate.funcarg needs to be at top of stack
        (cgstate.funcargtos == ~0 || numpara < cgstate.funcargtos) &&
        (!(typfunc(tyf) || tyf == TYhfunc) || sf && sf->Sflags & SFLexit) &&
        !anyiasm && !I16
       )
    {
        for (int i = 0; i < np; i++)
        {
            elem *ep = parameters[i].e;
            int preg = parameters[i].reg;
            //printf("parameter[%d] = %d, np = %d\n", i, preg, np);
            if (preg == NOREG)
            {
                switch (ep->Eoper)
                {
                    case OPstrctor:
                    case OPstrthis:
                    case OPstrpar:
                    case OPnp_fp:
                        goto Lno;
                }
            }
        }

        if (numpara > cgstate.funcarg.size)
        {   // New high water mark
            //printf("increasing size from %d to %d\n", (int)cgstate.funcarg.size, (int)numpara);
            cgstate.funcarg.size = numpara;
        }
        usefuncarg = TRUE;
    }
  Lno: ;

    /* Adjust start of the stack so after all args are pushed,
     * the stack will be aligned.
     */
    if (!usefuncarg && STACKALIGN == 16 && (numpara + stackpush) & (STACKALIGN - 1))
    {
        numalign = STACKALIGN - ((numpara + stackpush) & (STACKALIGN - 1));
        cod3_stackadj(cdb, numalign);
        cdb.append(genadjesp(CNIL, numalign));
        stackpush += numalign;
        stackpushsave += numalign;
    }
    assert(stackpush == stackpushsave);
    if (config.exe == EX_WIN64)
    {
        //printf("np = %d, numpara = %d, stackpush = %d\n", np, numpara, stackpush);
        assert(numpara == ((np < 4) ? 4 * REGSIZE : np * REGSIZE));

        // Allocate stack space for four entries anyway
        // http://msdn.microsoft.com/en-US/library/ew5tede7(v=vs.80)
    }

    int regsaved[XMM7 + 1];
    memset(regsaved, -1, sizeof(regsaved));
    CodeBuilder cdbrestore;
    regm_t saved = 0;
    targ_size_t funcargtossave = cgstate.funcargtos;
    targ_size_t funcargtos = numpara;
    //printf("funcargtos1 = %d\n", (int)funcargtos);

    /* Parameters go into the registers RDI,RSI,RDX,RCX,R8,R9
     * float and double parameters go into XMM0..XMM7
     * For variadic functions, count of XMM registers used goes in AL
     */
    for (int i = 0; i < np; i++)
    {
        elem *ep = parameters[i].e;
        int preg = parameters[i].reg;
        //printf("parameter[%d] = %d, np = %d\n", i, preg, np);
        if (preg == NOREG)
        {
            /* Push parameter on stack, but keep track of registers used
             * in the process. If they interfere with keepmsk, we'll have
             * to save/restore them.
             */
            CodeBuilder cdbsave;
            regm_t overlap = msavereg & keepmsk;
            msavereg |= keepmsk;
            CodeBuilder cdbparams;
            if (usefuncarg)
                movParams(cdbparams, ep, stackalign, funcargtos);
            else
                pushParams(cdbparams,ep,stackalign);
            regm_t tosave = keepmsk & ~msavereg;
            msavereg &= ~keepmsk | overlap;

            // tosave is the mask to save and restore
            for (int j = 0; tosave; j++)
            {   regm_t mi = mask[j];
                assert(j <= XMM7);
                if (mi & tosave)
                {
                    unsigned idx;
                    cdbsave.append(regsave.save(CNIL, j, &idx));
                    cdbrestore.append(regsave.restore(CNIL, j, idx));
                    saved |= mi;
                    keepmsk &= ~mi;             // don't need to keep these for rest of params
                    tosave &= ~mi;
                }
            }

            cdb.append(cdbsave);
            cdb.append(cdbparams);

            // Alignment for parameter comes after it got pushed
            unsigned numalign = parameters[i].numalign;
            if (usefuncarg)
            {
                funcargtos -= _align(stackalign, paramsize(ep)) + numalign;
                cgstate.funcargtos = funcargtos;
            }
            else if (numalign)
            {
                cod3_stackadj(cdb, numalign);
                cdb.append(genadjesp(CNIL, numalign));
                stackpush += numalign;
            }
        }
        else
        {
            // Goes in register preg, not stack
            regm_t retregs = mask[preg];
            if (retregs & XMMREGS)
                ++xmmcnt;
            int preg2 = parameters[i].reg2;
            reg_t mreg,lreg;
            if (preg2 != NOREG)
            {
                // BUG: still doesn't handle case of mXMM0|mAX or mAX|mXMM0
                assert(ep->Eoper != OPstrthis);
                if (mask[preg2] & XMMREGS)
                {   ++xmmcnt;
                    lreg = XMM0;
                    mreg = XMM1;
                }
                else
                {
                    lreg = mask[preg ] & mLSW ? preg  : AX;
                    mreg = mask[preg2] & mMSW ? preg2 : DX;
                }
                retregs = mask[mreg] | mask[lreg];

                CodeBuilder cdbsave;
                if (keepmsk & retregs)
                {
                    regm_t tosave = keepmsk & retregs;

                    // tosave is the mask to save and restore
                    for (int j = 0; tosave; j++)
                    {   regm_t mi = mask[j];
                        assert(j <= XMM7);
                        if (mi & tosave)
                        {
                            unsigned idx;
                            cdbsave.append(regsave.save(CNIL, j, &idx));
                            cdbrestore.append(regsave.restore(CNIL, j, idx));
                            saved |= mi;
                            keepmsk &= ~mi;             // don't need to keep these for rest of params
                            tosave &= ~mi;
                        }
                    }
                }
                cdb.append(cdbsave);

                scodelem(cdb,ep,&retregs,keepmsk,FALSE);

                // Move result [mreg,lreg] into parameter registers from [preg2,preg]
                retregs = 0;
                if (preg != lreg)
                    retregs |= mask[preg];
                if (preg2 != mreg)
                    retregs |= mask[preg2];
                getregs(cdb,retregs);

                tym_t ty1 = tybasic(ep->Ety);
                tym_t ty2 = ty1;
                if (ty1 == TYstruct)
                {   type *targ1 = ep->ET->Ttag->Sstruct->Sarg1type;
                    type *targ2 = ep->ET->Ttag->Sstruct->Sarg2type;
                    if (targ1)
                        ty1 = targ1->Tty;
                    if (targ2)
                        ty2 = targ2->Tty;
                }

                for (int v = 0; v < 2; v++)
                {
                    if (v ^ (preg != mreg))
                    {
                        if (preg != lreg)
                        {
                            if (mask[preg] & XMMREGS)
                            {   unsigned op = xmmload(ty1);            // MOVSS/D preg,lreg
                                cdb.gen2(op,modregxrmx(3,preg-XMM0,lreg-XMM0));
                                checkSetVex(cdb.last(),ty1);
                            }
                            else
                                cdb.append(genmovreg(CNIL, preg, lreg));
                        }
                    }
                    else
                    {
                        if (preg2 != mreg)
                        {
                            if (mask[preg2] & XMMREGS)
                            {   unsigned op = xmmload(ty2);            // MOVSS/D preg2,mreg
                                cdb.gen2(op,modregxrmx(3,preg2-XMM0,mreg-XMM0));
                                checkSetVex(cdb.last(),ty2);
                            }
                            else
                                cdb.append(genmovreg(CNIL, preg2, mreg));
                        }
                    }
                }

                retregs = mask[preg] | mask[preg2];
            }
            else if (ep->Eoper == OPstrthis)
            {
                getregs(cdb,retregs);
                // LEA preg,np[RSP]
                unsigned np = stackpush - ep->EV.Vuns;   // stack delta to parameter
                cdb.genc1(LEA,
                        (modregrm(0,4,SP) << 8) | modregxrm(2,preg,4), FLconst,np);
                if (I64)
                    code_orrex(cdb.last(), REX_W);
            }
            else if (ep->Eoper == OPstrpar && config.exe == EX_WIN64 && type_size(ep->ET) == 0)
            {
            }
            else
            {
                scodelem(cdb,ep,&retregs,keepmsk,FALSE);
            }
            keepmsk |= retregs;      // don't change preg when evaluating func address
        }
    }

    if (config.exe == EX_WIN64)
    {   // Allocate stack space for four entries anyway
        // http://msdn.microsoft.com/en-US/library/ew5tede7(v=vs.80)
        {   unsigned sz = 4 * REGSIZE;
            if (usefuncarg)
            {
                funcargtos -= sz;
                cgstate.funcargtos = funcargtos;
            }
            else
            {
                cod3_stackadj(cdb, sz);
                cdb.append(genadjesp(CNIL, sz));
                stackpush += sz;
            }
        }

        /* Variadic functions store XMM parameters into their corresponding GP registers
         */
        for (int i = 0; i < np; i++)
        {
            int preg = parameters[i].reg;
            regm_t retregs = mask[preg];
            if (retregs & XMMREGS)
            {   int reg;

                switch (preg)
                {   case XMM0: reg = CX; break;
                    case XMM1: reg = DX; break;
                    case XMM2: reg = R8; break;
                    case XMM3: reg = R9; break;
                    default:   assert(0);
                }
                getregs(cdb,mask[reg]);
                cdb.gen2(STOD,(REX_W << 16) | modregxrmx(3,preg-XMM0,reg)); // MOVD reg,preg
            }
        }
    }

    // Restore any register parameters we saved
    getregs(cdb,saved);
    cdb.append(cdbrestore);
    keepmsk |= saved;

    // Variadic functions store the number of XMM registers used in AL
    if (I64 && config.exe != EX_WIN64 && e->Eflags & EFLAGS_variadic)
    {
        getregs(cdb,mAX);
        movregconst(cdb,AX,xmmcnt,1);
        keepmsk |= mAX;
    }

    //printf("funcargtos2 = %d\n", (int)funcargtos);
    assert(!usefuncarg || (funcargtos == 0 && cgstate.funcargtos == 0));
    cgstate.stackclean--;

#ifdef DEBUG
    if (!usefuncarg && numpara != stackpush - stackpushsave)
    {
        printf("function %s\n", funcsym_p->Sident);
        printf("numpara = %d, stackpush = %d, stackpushsave = %d\n", numpara, stackpush, stackpushsave);
        elem_print(e);
    }
#endif
    assert(usefuncarg || numpara == stackpush - stackpushsave);

    funccall(cdb,e,numpara,numalign,pretregs,keepmsk,usefuncarg);
    cgstate.funcargtos = funcargtossave;
}

/***********************************
 */

void cdstrthis(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    assert(tysize(e->Ety) == REGSIZE);
    unsigned reg = findreg(*pretregs & allregs);
    getregs(cdb,mask[reg]);
    // LEA reg,np[ESP]
    unsigned np = stackpush - e->EV.Vuns;        // stack delta to parameter
    cdb.genc1(0x8D,(modregrm(0,4,SP) << 8) | modregxrm(2,reg,4),FLconst,np);
    if (I64)
        code_orrex(cdb.last(), REX_W);
    fixresult(cdb,e,mask[reg],pretregs);
}

/******************************
 * Call function. All parameters have already been pushed onto the stack.
 * Params:
 *      e          = function call
 *      numpara    = size in bytes of all the parameters
 *      numalign   = amount the stack was aligned by before the parameters were pushed
 *      pretregs   = where return value goes
 *      keepmsk    = registers to not change when evaluating the function address
 *      usefuncarg = using cgstate.funcarg, so no need to adjust stack after func return
 */

static void funccall(CodeBuilder& cdb,elem *e,unsigned numpara,unsigned numalign,
        regm_t *pretregs,regm_t keepmsk, bool usefuncarg)
{
    //printf("%s ", funcsym_p->Sident);
    //printf("funccall(e = %p, *pretregs = %s, numpara = %d, numalign = %d, usefuncarg=%d)\n",e,regm_str(*pretregs),numpara,numalign,usefuncarg);
    calledafunc = 1;
    // Determine if we need frame for function prolog/epilog
#if TARGET_WINDOS
    if (config.memmodel == Vmodel)
    {
        if (tyfarfunc(funcsym_p->ty()))
            needframe = TRUE;
    }
#endif
    code cs;
    regm_t retregs;
    Symbol *s;

    elem *e1 = e->E1;
    tym_t tym1 = tybasic(e1->Ety);
    char farfunc = tyfarfunc(tym1) || tym1 == TYifunc;

    CodeBuilder cdbe;

    if (e1->Eoper == OPvar)
    {   // Call function directly

        if (!tyfunc(tym1))
            WRTYxx(tym1);
        assert(tyfunc(tym1));
        s = e1->EV.sp.Vsym;
        if (s->Sflags & SFLexit)
        { }
        else if (s != tls_get_addr_sym)
            save87(cdb);               // assume 8087 regs are all trashed

        // Function calls may throw Errors, unless marked that they don't
        if (s == funcsym_p || !s->Sfunc || !(s->Sfunc->Fflags3 & Fnothrow))
            funcsym_p->Sfunc->Fflags3 &= ~Fnothrow;

        if (s->Sflags & SFLexit)
        {
            // Function doesn't return, so don't worry about registers
            // it may use
        }
        else if (!tyfunc(s->ty()) || !(config.flags4 & CFG4optimized))
            // so we can replace func at runtime
            getregs(cdbe,~fregsaved & (mBP | ALLREGS | mES | XMMREGS));
        else
            getregs(cdbe,~s->Sregsaved & (mBP | ALLREGS | mES | XMMREGS));
        if (strcmp(s->Sident,"alloca") == 0)
        {
            s = getRtlsym(RTLSYM_ALLOCA);
            makeitextern(s);
            int areg = CX;
            if (config.exe == EX_WIN64)
                areg = DX;
            getregs(cdbe,mask[areg]);
            cdbe.genc(0x8D,modregrm(2,areg,BPRM),FLallocatmp,0,0,0);  // LEA areg,&localsize[BP]
            if (I64)
                code_orrex(cdbe.last(), REX_W);
            Alloca.size = REGSIZE;
        }
        if (sytab[s->Sclass] & SCSS)    // if function is on stack (!)
        {
            retregs = allregs & ~keepmsk;
            s->Sflags &= ~GTregcand;
            s->Sflags |= SFLread;
            cdrelconst(cdbe,e1,&retregs);
            if (farfunc)
            {
                unsigned reg = findregmsw(retregs);
                unsigned lsreg = findreglsw(retregs);
                floatreg = TRUE;                // use float register
                reflocal = TRUE;
                cdbe.genc1(0x89,                 // MOV floatreg+2,reg
                        modregrm(2,reg,BPRM),FLfltreg,REGSIZE);
                cdbe.genc1(0x89,                 // MOV floatreg,lsreg
                        modregrm(2,lsreg,BPRM),FLfltreg,0);
                if (tym1 == TYifunc)
                    cdbe.gen1(0x9C);             // PUSHF
                cdbe.genc1(0xFF,                 // CALL [floatreg]
                        modregrm(2,3,BPRM),FLfltreg,0);
            }
            else
            {
                unsigned reg = findreg(retregs);
                cdbe.gen2(0xFF,modregrmx(3,2,reg));   // CALL reg
                if (I64)
                    code_orrex(cdbe.last(), REX_W);
            }
        }
        else
        {
            int fl = FLfunc;
            if (!tyfunc(s->ty()))
                fl = el_fl(e1);
            if (tym1 == TYifunc)
                cdbe.gen1(0x9C);                             // PUSHF
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            assert(!farfunc);
            if (s != tls_get_addr_sym)
            {
                //printf("call %s\n", s->Sident);
                cdbe.append(load_localgot());
                cdbe.gencs(0xE8,0,fl,s);    // CALL extern
            }
            else if (I64)
            {
                /* Prepend 66 66 48 so GNU linker has patch room
                 */
                assert(!farfunc);
                cdbe.gen1(0x66);
                cdbe.gen1(0x66);
                cdbe.gencs(0xE8,0,fl,s);      // CALL extern
                cdbe.last()->Irex = REX | REX_W;
            }
            else
                cdbe.gencs(0xE8,0,fl,s);    // CALL extern
#else
            cdbe.gencs(farfunc ? 0x9A : 0xE8,0,fl,s);    // CALL extern
#endif
            code_orflag(cdbe.last(), farfunc ? (CFseg | CFoff) : (CFselfrel | CFoff));
        }
  }
  else
  {     // Call function via pointer

        // Function calls may throw Errors
        funcsym_p->Sfunc->Fflags3 &= ~Fnothrow;

        if (e1->Eoper != OPind) { WRFL((enum FL)el_fl(e1)); WROP(e1->Eoper); }
        save87(cdb);                   // assume 8087 regs are all trashed
        assert(e1->Eoper == OPind);
        elem *e11 = e1->E1;
        tym_t e11ty = tybasic(e11->Ety);
        assert(!I16 || (e11ty == (farfunc ? TYfptr : TYnptr)));
        cdb.append(load_localgot());
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        if (config.flags3 & CFG3pic && I32)
            keepmsk |= mBX;
#endif

        /* Mask of registers destroyed by the function call
         */
        regm_t desmsk = (mBP | ALLREGS | mES | XMMREGS) & ~fregsaved;

        // if we can't use loadea()
        if ((EOP(e11) || e11->Eoper == OPconst) &&
            (e11->Eoper != OPind || e11->Ecount))
        {
            retregs = allregs & ~keepmsk;
            cgstate.stackclean++;
            scodelem(cdbe,e11,&retregs,keepmsk,TRUE);
            cgstate.stackclean--;
            // Kill registers destroyed by an arbitrary function call
            getregs(cdbe,desmsk);
            if (e11ty == TYfptr)
            {
                unsigned reg = findregmsw(retregs);
                unsigned lsreg = findreglsw(retregs);
                floatreg = TRUE;                // use float register
                reflocal = TRUE;
                cdbe.genc1(0x89,                 // MOV floatreg+2,reg
                        modregrm(2,reg,BPRM),FLfltreg,REGSIZE);
                cdbe.genc1(0x89,                 // MOV floatreg,lsreg
                        modregrm(2,lsreg,BPRM),FLfltreg,0);
                if (tym1 == TYifunc)
                    cdbe.gen1(0x9C);             // PUSHF
                cdbe.genc1(0xFF,                 // CALL [floatreg]
                        modregrm(2,3,BPRM),FLfltreg,0);
            }
            else
            {
                unsigned reg = findreg(retregs);
                cdbe.gen2(0xFF,modregrmx(3,2,reg));   // CALL reg
                if (I64)
                    code_orrex(cdbe.last(), REX_W);
            }
        }
        else
        {
            if (tym1 == TYifunc)
                cdb.gen1(0x9C);                 // PUSHF
                                                // CALL [function]
            cs.Iflags = 0;
            cgstate.stackclean++;
            loadea(cdbe,e11,&cs,0xFF,farfunc ? 3 : 2,0,keepmsk,desmsk);
            cgstate.stackclean--;
            freenode(e11);
        }
        s = NULL;
  }
  cdb.append(cdbe);
  freenode(e1);

  /* See if we will need the frame pointer.
     Calculate it here so we can possibly use BP to fix the stack.
   */
#if 0
  if (!needframe)
  {
        // If there is a register available for this basic block
        if (config.flags4 & CFG4optimized && (ALLREGS & ~regcon.used))
            ;
        else
        {
            for (SYMIDX si = 0; si < globsym.top; si++)
            {   Symbol *s = globsym.tab[si];

                if (s->Sflags & GTregcand && type_size(s->Stype) != 0)
                {
                    if (config.flags4 & CFG4optimized)
                    {   // If symbol is live in this basic block and
                        // isn't already in a register
                        if (s->Srange && vec_testbit(dfoidx,s->Srange) &&
                            s->Sfl != FLreg)
                        {   // Then symbol must be allocated on stack
                            needframe = TRUE;
                            break;
                        }
                    }
                    else
                    {   if (mfuncreg == 0)      // if no registers left
                        {   needframe = TRUE;
                            break;
                        }
                    }
                }
            }
        }
  }
#endif

    retregs = regmask(e->Ety, tym1);

    if (!usefuncarg)
    {
        // If stack needs cleanup
        if  (s && s->Sflags & SFLexit)
        {
            /* Function never returns, so don't need to generate stack
             * cleanup code. But still need to log the stack cleanup
             * as if it did return.
             */
            cdb.genadjesp(-(numpara + numalign));
            stackpush -= numpara + numalign;
        }
        else if ((OTbinary(e->Eoper) || config.exe == EX_WIN64) &&
            (!typfunc(tym1) || config.exe == EX_WIN64))
        {
            if (tym1 == TYhfunc)
            {   // Hidden parameter is popped off by the callee
                cdb.genadjesp(-REGSIZE);
                stackpush -= REGSIZE;
                if (numpara + numalign > REGSIZE)
                    genstackclean(cdb, numpara + numalign - REGSIZE, retregs);
            }
            else
                genstackclean(cdb,numpara + numalign,retregs);
        }
        else
        {
            cdb.genadjesp(-numpara);  // popped off by the callee's 'RET numpara'
            stackpush -= numpara;
            if (numalign)               // callee doesn't know about alignment adjustment
                genstackclean(cdb,numalign,retregs);
        }
    }

    /* Special handling for functions which return a floating point
       value in the top of the 8087 stack.
     */

    if (retregs & mST0)
    {
        cdb.append(genadjfpu(CNIL, 1));
        if (*pretregs)                  // if we want the result
        {   //assert(stackused == 0);
            push87(cdb);                // one item on 8087 stack
            fixresult87(cdb,e,retregs,pretregs);
            return;
        }
        else
            // Pop unused result off 8087 stack
            cdb.gen2(0xDD,modregrm(3,3,0));           // FPOP
    }
    else if (retregs & mST01)
    {
        cdb.append(genadjfpu(CNIL, 2));
        if (*pretregs)                  // if we want the result
        {   assert(stackused == 0);
            push87(cdb);
            push87(cdb);                // two items on 8087 stack
            fixresult_complex87(cdb,e,retregs,pretregs);
            return;
        }
        else
        {
            // Pop unused result off 8087 stack
            cdb.gen2(0xDD,modregrm(3,3,0));           // FPOP
            cdb.gen2(0xDD,modregrm(3,3,0));           // FPOP
        }
    }

    fixresult(cdb,e,retregs,pretregs);
}

/***************************
 * Determine size of argument e that will be pushed.
 */

targ_size_t paramsize(elem *e)
{
    assert(e->Eoper != OPparam);
    targ_size_t szb;
    tym_t tym = tybasic(e->Ety);
    if (tyscalar(tym))
        szb = size(tym);
    else if (tym == TYstruct || tym == TYarray)
        szb = type_size(e->ET);
    else
    {
        WRTYxx(tym);
        assert(0);
    }
    return szb;
}

/***************************
 * Generate code to move argument e on the stack.
 */

static void movParams(CodeBuilder& cdb,elem *e,unsigned stackalign, unsigned funcargtos)
{
    //printf("movParams(e = %p, stackalign = %d, funcargtos = %d)\n", e, stackalign, funcargtos);
    //printf("movParams()\n"); elem_print(e);
    assert(!I16);
    assert(e && e->Eoper != OPparam);

    tym_t tym = tybasic(e->Ety);
    if (tyfloating(tym))
        objmod->fltused();

    int grex = I64 ? REX_W << 16 : 0;

    targ_size_t szb = paramsize(e);               // size before alignment
    targ_size_t sz = _align(stackalign,szb);       // size after alignment
    assert((sz & (stackalign - 1)) == 0);         // ensure that alignment worked
    assert((sz & (REGSIZE - 1)) == 0);
    //printf("szb = %d sz = %d\n", (int)szb, (int)sz);

    code cs;
    cs.Iflags = 0;
    cs.Irex = 0;
    switch (e->Eoper)
    {
        case OPstrctor:
        case OPstrthis:
        case OPstrpar:
        case OPnp_fp:
            assert(0);
        case OPrelconst:
        {
            int fl;
            if (!evalinregister(e) &&
                !(I64 && (config.flags3 & CFG3pic || config.exe == EX_WIN64)) &&
                ((fl = el_fl(e)) == FLdata || fl == FLudata || fl == FLextern)
               )
            {
                // MOV -stackoffset[EBP],&variable
                cs.Iop = 0xC7;
                cs.Irm = modregrm(2,0,BPRM);
                if (I64 && sz == 8)
                    cs.Irex |= REX_W;
                cs.IFL1 = FLfuncarg;
                cs.IEVoffset1 = funcargtos - REGSIZE;
                cs.IEVoffset2 = e->EV.sp.Voffset;
                cs.IFL2 = fl;
                cs.IEVsym2 = e->EV.sp.Vsym;
                cs.Iflags |= CFoff;
                cdb.gen(&cs);
                return;
            }
            break;
        }
        case OPconst:
            if (!evalinregister(e))
            {
                cs.Iop = (sz == 1) ? 0xC6 : 0xC7;
                cs.Irm = modregrm(2,0,BPRM);
                cs.IFL1 = FLfuncarg;
                cs.IEVoffset1 = funcargtos - sz;
                cs.IFL2 = FLconst;
                targ_size_t *p = (targ_size_t *) &(e->EV);
                cs.IEV2.Vsize_t = *p;
                if (I64 && tym == TYcldouble)
                    // The alignment of EV.Vcldouble is not the same on the compiler
                    // as on the target
                    goto Lbreak;
                if (I64 && sz >= 8)
                {
                    int i = sz;
                    do
                    {
                        if (*p >= 0x80000000)
                        {   // Use 64 bit register MOV, as the 32 bit one gets sign extended
                            // MOV reg,imm64
                            // MOV EA,reg
                            goto Lbreak;
                        }
                        p = (targ_size_t *)((char *) p + REGSIZE);
                        i -= REGSIZE;
                    } while (i > 0);
                    p = (targ_size_t *) &(e->EV);
                }

                int i = sz;
                do
                {   int regsize = REGSIZE;
                    regm_t retregs = (sz == 1) ? BYTEREGS : allregs;
                    unsigned reg;
                    if (reghasvalue(retregs,*p,&reg))
                    {
                        cs.Iop = (cs.Iop & 1) | 0x88;
                        cs.Irm |= modregrm(0,reg & 7,0); // MOV EA,reg
                        if (reg & 8)
                            cs.Irex |= REX_R;
                        if (I64 && sz == 1 && reg >= 4)
                            cs.Irex |= REX;
                    }
                    if (I64 && sz >= 8)
                        cs.Irex |= REX_W;
                    cdb.gen(&cs);           // MOV EA,const

                    p = (targ_size_t *)((char *) p + regsize);
                    cs.Iop = 0xC7;
                    cs.Irm &= ~modregrm(0,7,0);
                    cs.Irex &= ~REX_R;
                    cs.IEVoffset1 += regsize;
                    cs.IEV2.Vint = *p;
                    i -= regsize;
                } while (i > 0);
                return;
            }
        Lbreak:
            break;
        default:
            break;
    }
    regm_t retregs = tybyte(tym) ? BYTEREGS : allregs;
    if (tyvector(tym))
    {
        retregs = XMMREGS;
        codelem(cdb,e,&retregs,FALSE);
        unsigned op = xmmstore(tym);
        unsigned r = findreg(retregs);
        cdb.genc1(op,modregxrm(2,r - XMM0,BPRM),FLfuncarg,funcargtos - 16);   // MOV funcarg[EBP],r
        checkSetVex(cdb.last(),tym);
        return;
    }
    else if (tyfloating(tym))
    {
        if (config.inline8087)
        {
            retregs = tycomplex(tym) ? mST01 : mST0;
            codelem(cdb,e,&retregs,FALSE);

            unsigned op;
            unsigned r;
            switch (tym)
            {
                case TYfloat:
                case TYifloat:
                case TYcfloat:
                    op = 0xD9;
                    r = 3;
                    break;

                case TYdouble:
                case TYidouble:
                case TYdouble_alias:
                case TYcdouble:
                    op = 0xDD;
                    r = 3;
                    break;

                case TYldouble:
                case TYildouble:
                case TYcldouble:
                    op = 0xDB;
                    r = 7;
                    break;

                default:
                    assert(0);
            }
            if (tycomplex(tym))
            {
                // FSTP sz/2[ESP]
                cdb.genc1(op,modregxrm(2,r,BPRM),FLfuncarg,funcargtos - sz/2);
                pop87();
            }
            pop87();
            cdb.genc1(op,modregxrm(2,r,BPRM),FLfuncarg,funcargtos - sz);    // FSTP -sz[EBP]
            return;
        }
    }
    scodelem(cdb,e,&retregs,0,TRUE);
    if (sz <= REGSIZE)
    {
        unsigned r = findreg(retregs);
        cdb.genc1(0x89,modregxrm(2,r,BPRM),FLfuncarg,funcargtos - REGSIZE);   // MOV -REGSIZE[EBP],r
        if (sz == 8)
            code_orrex(cdb.last(), REX_W);
    }
    else if (sz == REGSIZE * 2)
    {
        unsigned r = findregmsw(retregs);
        cdb.genc1(0x89,grex | modregxrm(2,r,BPRM),FLfuncarg,funcargtos - REGSIZE);    // MOV -REGSIZE[EBP],r
        r = findreglsw(retregs);
        cdb.genc1(0x89,grex | modregxrm(2,r,BPRM),FLfuncarg,funcargtos - REGSIZE * 2); // MOV -2*REGSIZE[EBP],r
    }
    else
        assert(0);
}


/***************************
 * Generate code to push argument e on the stack.
 * stackpush is incremented by stackalign for each PUSH.
 */

void pushParams(CodeBuilder& cdb,elem *e,unsigned stackalign)
{
  //printf("params(e = %p, stackalign = %d)\n", e, stackalign);
  //printf("params()\n"); elem_print(e);
  stackchanged = 1;
  assert(e && e->Eoper != OPparam);

  tym_t tym = tybasic(e->Ety);
  if (tyfloating(tym))
        objmod->fltused();

  int grex = I64 ? REX_W << 16 : 0;

  targ_size_t szb = paramsize(e);               // size before alignment
  targ_size_t sz = _align(stackalign,szb);      // size after alignment
  assert((sz & (stackalign - 1)) == 0);         // ensure that alignment worked
  assert((sz & (REGSIZE - 1)) == 0);

  switch (e->Eoper)
  {
#if SCPP
    case OPstrctor:
    {
        elem *e1 = e->E1;
        docommas(cdb,&e1);              // skip over any comma expressions

        cod3_stackadj(cdb, sz);
        stackpush += sz;
        cdb.append(genadjesp(CNIL,sz));

        // Find OPstrthis and set it to stackpush
        exp2_setstrthis(e1,NULL,stackpush,NULL);

        regm_t retregs = 0;
        codelem(cdb,e1,&retregs,TRUE);
        freenode(e);
        return;
    }
    case OPstrthis:
        // This is the parameter for the 'this' pointer corresponding to
        // OPstrctor. We push a pointer to an object that was already
        // allocated on the stack by OPstrctor.
    {
        regm_t retregs = allregs;
        unsigned reg;
        allocreg(cdb,&retregs,&reg,TYoffset);
        cdb.append(genregs(CNIL,0x89,SP,reg));        // MOV reg,SP
        if (I64)
            code_orrex(cdb.last(), REX_W);
        unsigned np = stackpush - e->EV.Vuns;         // stack delta to parameter
        cdb.genc2(0x81,grex | modregrmx(3,0,reg),np); // ADD reg,np
        if (sz > REGSIZE)
        {
            cdb.gen1(0x16);                     // PUSH SS
            stackpush += REGSIZE;
        }
        cdb.gen1(0x50 + (reg & 7));             // PUSH reg
        if (reg & 8)
            code_orrex(cdb.last(), REX_B);
        stackpush += REGSIZE;
        cdb.append(genadjesp(CNIL,sz));
        freenode(e);
        return;
    }
#endif
    case OPstrpar:
        {
                unsigned rm;

                elem *e1 = e->E1;
                if (sz == 0)
                {
                    docommas(cdb,&e1); // skip over any commas
                    freenode(e);
                    return;
                }
                if ((sz & 3) == 0 && (sz / REGSIZE) <= 4 && e1->Eoper == OPvar)
                {   freenode(e);
                    e = e1;
                    goto L1;
                }
                docommas(cdb,&e1);             // skip over any commas
                unsigned seg = 0;              // assume no seg override
                regm_t retregs = sz ? IDXREGS : 0;
                bool doneoff = FALSE;
                unsigned pushsize = REGSIZE;
                unsigned op16 = 0;
                if (!I16 && sz & 2)     // if odd number of words to push
                {   pushsize = 2;
                    op16 = 1;
                }
                else if (I16 && config.target_cpu >= TARGET_80386 && (sz & 3) == 0)
                {   pushsize = 4;       // push DWORDs at a time
                    op16 = 1;
                }
                unsigned npushes = sz / pushsize;
                switch (e1->Eoper)
                {   case OPind:
                        if (sz)
                        {   switch (tybasic(e1->E1->Ety))
                            {
                                case TYfptr:
                                case TYhptr:
                                    seg = CFes;
                                    retregs |= mES;
                                    break;
                                case TYsptr:
                                    if (config.wflags & WFssneds)
                                        seg = CFss;
                                    break;
                                case TYcptr:
                                    seg = CFcs;
                                    break;
                            }
                        }
                        codelem(cdb,e1->E1,&retregs,FALSE);
                        freenode(e1);
                        break;
                    case OPvar:
                        /* Symbol is no longer a candidate for a register */
                        e1->EV.sp.Vsym->Sflags &= ~GTregcand;

                        if (!e1->Ecount && npushes > 4)
                        {       /* Kludge to point at last word in struct. */
                                /* Don't screw up CSEs.                 */
                                e1->EV.sp.Voffset += sz - pushsize;
                                doneoff = TRUE;
                        }
                        //if (LARGEDATA) /* if default isn't DS */
                        {   static const unsigned segtocf[4] = { CFes,CFcs,CFss,0 };

                            int fl = el_fl(e1);
                            if (fl == FLfardata)
                            {   seg = CFes;
                                retregs |= mES;
                            }
                            else
                            {
                                unsigned s = segfl[fl];
                                assert(s < 4);
                                seg = segtocf[s];
                                if (seg == CFss && !(config.wflags & WFssneds))
                                    seg = 0;
                            }
                        }
                        if (e1->Ety & mTYfar)
                        {   seg = CFes;
                            retregs |= mES;
                        }
                        cdrelconst(cdb,e1,&retregs);
                        // Reverse the effect of the previous add
                        if (doneoff)
                            e1->EV.sp.Voffset -= sz - pushsize;
                        freenode(e1);
                        break;
                    case OPstreq:
                    //case OPcond:
                        if (!(config.exe & EX_flat))
                        {   seg = CFes;
                            retregs |= mES;
                        }
                        codelem(cdb,e1,&retregs,FALSE);
                        break;
                    default:
                        elem_print(e1);
                        assert(0);
                }
                unsigned reg = findreglsw(retregs);
                rm = I16 ? regtorm[reg] : regtorm32[reg];
                if (op16)
                    seg |= CFopsize;            // operand size
                if (npushes <= 4)
                {
                    assert(!doneoff);
                    for (; npushes > 1; --npushes)
                    {
                        cdb.genc1(0xFF,buildModregrm(2,6,rm),FLconst,pushsize * (npushes - 1));  // PUSH [reg]
                        code_orflag(cdb.last(),seg);
                        cdb.append(genadjesp(CNIL,pushsize));
                    }
                    cdb.gen2(0xFF,buildModregrm(0,6,rm));     // PUSH [reg]
                    cdb.last()->Iflags |= seg;
                    cdb.append(genadjesp(CNIL,pushsize));
                }
                else if (sz)
                {
                    getregs_imm(cdb,mCX | retregs);
                                                        // MOV CX,sz/2
                    movregconst(cdb,CX,npushes,0);
                    if (!doneoff)
                    {   // This should be done when
                        // reg is loaded. Fix later
                                                        // ADD reg,sz-2
                        cdb.genc2(0x81,grex | modregrmx(3,0,reg),sz-pushsize);
                    }
                    getregs(cdb,mCX);                       // the LOOP decrements it
                    cdb.gen2(0xFF,buildModregrm(0,6,rm));           // PUSH [reg]
                    cdb.last()->Iflags |= seg | CFtarg2;
                    code *c3 = cdb.last();
                    cdb.genc2(0x81,grex | buildModregrm(3,5,reg),pushsize);  // SUB reg,2
                    genjmp(cdb,0xE2,FLcode,(block *)c3);        // LOOP c3
                    regimmed_set(CX,0);
                    cdb.append(genadjesp(CNIL,sz));
                }
                stackpush += sz;
                freenode(e);
                return;
        }
    case OPind:
        if (!e->Ecount)                         /* if *e1       */
        {
            if (sz <= REGSIZE)
            {   // Watch out for single byte quantities being up
                // against the end of a segment or in memory-mapped I/O
                if (!(config.exe & EX_flat) && szb == 1)
                    break;
                goto L1;            // can handle it with loadea()
            }

            // Avoid PUSH MEM on the Pentium when optimizing for speed
            if (config.flags4 & CFG4speed &&
                (config.target_cpu >= TARGET_80486 &&
                 config.target_cpu <= TARGET_PentiumMMX) &&
                sz <= 2 * REGSIZE &&
                !tyfloating(tym))
                break;

            if (tym == TYldouble || tym == TYildouble || tycomplex(tym))
                break;

            code cs;
            cs.Iflags = 0;
            cs.Irex = 0;
            if (I32)
            {
                assert(sz >= REGSIZE * 2);
                loadea(cdb,e,&cs,0xFF,6,sz - REGSIZE,0,0); // PUSH EA+4
                cdb.append(genadjesp(CNIL,REGSIZE));
                stackpush += REGSIZE;
                sz -= REGSIZE;

                if (sz > REGSIZE)
                {
                    while (sz)
                    {
                        cs.IEVoffset1 -= REGSIZE;
                        cdb.gen(&cs);                    // PUSH EA+...
                        cdb.append(genadjesp(CNIL,REGSIZE));
                        stackpush += REGSIZE;
                        sz -= REGSIZE;
                    }
                    freenode(e);
                    return;
                }
            }
            else
            {
                if (sz == DOUBLESIZE)
                {
                    loadea(cdb,e,&cs,0xFF,6,DOUBLESIZE - REGSIZE,0,0); // PUSH EA+6
                    cs.IEVoffset1 -= REGSIZE;
                    cdb.gen(&cs);                    // PUSH EA+4
                    cdb.append(genadjesp(CNIL,REGSIZE));
                    getlvalue_lsw(&cs);
                    cdb.gen(&cs);                    // PUSH EA+2
                }
                else /* TYlong */
                    loadea(cdb,e,&cs,0xFF,6,REGSIZE,0,0); // PUSH EA+2
                cdb.append(genadjesp(CNIL,REGSIZE));
            }
            stackpush += sz;
            getlvalue_lsw(&cs);
            cdb.gen(&cs);                            // PUSH EA
            cdb.append(genadjesp(CNIL,REGSIZE));
            freenode(e);
            return;
        }
        break;

    case OPnp_fp:
        if (!e->Ecount)                         /* if (far *)e1 */
        {
            elem *e1 = e->E1;
            tym_t tym1 = tybasic(e1->Ety);
            /* BUG: what about pointers to functions?   */
            int segreg;
            switch (tym1)
            {
                case TYnptr: segreg = 3<<3; break;
                case TYcptr: segreg = 1<<3; break;
                default:     segreg = 2<<3; break;
            }
            if (I32 && stackalign == 2)
                cdb.gen1(0x66);                 // push a word
            cdb.gen1(0x06 + segreg);            // PUSH SEGREG
            if (I32 && stackalign == 2)
                code_orflag(cdb.last(),CFopsize);        // push a word
            cdb.append(genadjesp(CNIL,stackalign));
            stackpush += stackalign;
            pushParams(cdb,e1,stackalign);
            freenode(e);
            return;
        }
        break;

    case OPrelconst:
#if TARGET_SEGMENTED
        /* Determine if we can just push the segment register           */
        /* Test size of type rather than TYfptr because of (long)(&v)   */
        Symbol *s = e->EV.sp.Vsym;
        //if (sytab[s->Sclass] & SCSS && !I32)  // if variable is on stack
        //    needframe = TRUE;                 // then we need stack frame
        int fl;
        if (_tysize[tym] == tysize(TYfptr) &&
            (fl = s->Sfl) != FLfardata &&
            /* not a function that CS might not be the segment of       */
            (!((fl == FLfunc || s->ty() & mTYcs) &&
              (s->Sclass == SCcomdat || s->Sclass == SCextern || s->Sclass == SCinline || config.wflags & WFthunk)) ||
             (fl == FLfunc && config.exe == EX_DOSX)
            )
           )
        {
            stackpush += sz;
            cdb.gen1(0x06 +           // PUSH SEGREG
                    (((fl == FLfunc || s->ty() & mTYcs) ? 1 : segfl[fl]) << 3));
            cdb.append(genadjesp(CNIL,REGSIZE));

            if (config.target_cpu >= TARGET_80286 && !e->Ecount)
            {
                getoffset(cdb,e,STACK);
                freenode(e);
                return;
            }
            else
            {
                regm_t retregs;
                offsetinreg(cdb,e,&retregs);
                unsigned reg = findreg(retregs);
                cdb.append(genpush(CNIL,reg));             // PUSH reg
                cdb.append(genadjesp(CNIL,REGSIZE));
            }
            return;
        }
        if (config.target_cpu >= TARGET_80286 && !e->Ecount)
        {
            stackpush += sz;
            if (_tysize[tym] == tysize(TYfptr))
            {
                // PUSH SEG e
                cdb.gencs(0x68,0,FLextern,s);
                cdb.last()->Iflags = CFseg;
                cdb.append(genadjesp(CNIL,REGSIZE));
            }
            getoffset(cdb,e,STACK);
            freenode(e);
            return;
        }
#endif
        break;                          /* else must evaluate expression */
    case OPvar:
    L1:
        if (config.flags4 & CFG4speed &&
                 (config.target_cpu >= TARGET_80486 &&
                  config.target_cpu <= TARGET_PentiumMMX) &&
                 sz <= 2 * REGSIZE &&
                 !tyfloating(tym))
        {   // Avoid PUSH MEM on the Pentium when optimizing for speed
            break;
        }
        else if (movOnly(e))
            break;                      // no PUSH MEM
        else
        {
            int regsize = REGSIZE;
            unsigned flag = 0;
            if (I16 && config.target_cpu >= TARGET_80386 && sz > 2 &&
                !e->Ecount)
            {   regsize = 4;
                flag |= CFopsize;
            }
            code cs;
            cs.Iflags = 0;
            cs.Irex = 0;
            loadea(cdb,e,&cs,0xFF,6,sz - regsize,RMload,0);    // PUSH EA+sz-2
            code_orflag(cdb.last(),flag);
            cdb.append(genadjesp(CNIL,REGSIZE));
            stackpush += sz;
            while ((targ_int)(sz -= regsize) > 0)
            {
                loadea(cdb,e,&cs,0xFF,6,sz - regsize,RMload,0);
                code_orflag(cdb.last(),flag);
                cdb.append(genadjesp(CNIL,REGSIZE));
            }
            freenode(e);
            return;
        }
    case OPconst:
    {
        char pushi = 0;
        unsigned flag = 0;
        int regsize = REGSIZE;

        if (tycomplex(tym))
            break;

        if (I64 && tyfloating(tym) && sz > 4 && boolres(e))
            // Can't push 64 bit non-zero args directly
            break;

        if (I32 && szb == 10)           // special case for long double constants
        {
            assert(sz == 12);
            targ_int value = ((unsigned short *)&e->EV.Vldouble)[4];
            stackpush += sz;
            cdb.append(genadjesp(NULL,sz));
            for (int i = 2; i >= 0; i--)
            {
                unsigned reg;
                if (reghasvalue(allregs, value, &reg))
                    cdb.gen1(0x50 + reg);           // PUSH reg
                else
                    cdb.genc2(0x68,0,value);        // PUSH value
                value = ((unsigned *)&e->EV.Vldouble)[i - 1];
            }
            freenode(e);
            return;
        }

        assert(I64 || sz <= tysize(TYldouble));
        int i = sz;
        if (!I16 && i == 2)
            flag = CFopsize;

        if (config.target_cpu >= TARGET_80286)
//       && (e->Ecount == 0 || e->Ecount != e->Ecomsub))
        {   pushi = 1;
            if (I16 && config.target_cpu >= TARGET_80386 && i >= 4)
            {   regsize = 4;
                flag = CFopsize;
            }
        }
        else if (i == REGSIZE)
            break;

        stackpush += sz;
        cdb.append(genadjesp(NULL,sz));
        targ_uns *pi = (targ_uns *) &e->EV.Vdouble;
        targ_ushort *ps = (targ_ushort *) pi;
        targ_ullong *pl = (targ_ullong *)pi;
        i /= regsize;
        do
        {
            if (i)                      /* be careful not to go negative */
                i--;

            targ_size_t value;
            switch (regsize)
            {
                case 2:
                    value = ps[i];
                    break;
                case 4:
                    if (tym == TYldouble || tym == TYildouble)
                        /* The size is 10 bytes, and since we have 2 bytes left over,
                         * just read those 2 bytes, not 4.
                         * Otherwise we're reading uninitialized data.
                         * I.e. read 4 bytes, 4 bytes, then 2 bytes
                         */
                        value = i == 2 ? ps[4] : pi[i]; // 80 bits
                    else
                        value = pi[i];
                    break;
                case 8:
                    value = pl[i];
                    break;
                default:
                    assert(0);
            }

            unsigned reg;
            if (pushi)
            {
                if (I64 && regsize == 8 && value != (int)value)
                {
                    regwithvalue(cdb,allregs,value,&reg,64);
                    goto Preg;          // cannot push imm64 unless it is sign extended 32 bit value
                }
                if (regsize == REGSIZE && reghasvalue(allregs,value,&reg))
                    goto Preg;
                cdb.genc2((szb == 1) ? 0x6A : 0x68,0,value); // PUSH value
            }
            else
            {
                regwithvalue(cdb,allregs,value,&reg,0);
            Preg:
                cdb.append(genpush(CNIL,reg));         // PUSH reg
            }
            code_orflag(cdb.last(),flag);              // operand size
        } while (i);
        freenode(e);
        return;
    }
    default:
        break;
  }

    regm_t retregs = tybyte(tym) ? BYTEREGS : allregs;
    if (tyvector(tym))
    {
        regm_t retregs = XMMREGS;
        codelem(cdb,e,&retregs,FALSE);
        stackpush += sz;
        cdb.append(genadjesp(CNIL,sz));
        cod3_stackadj(cdb, sz);
        unsigned op = xmmstore(tym);
        unsigned r = findreg(retregs);
        cdb.gen2sib(op,modregxrm(0,r - XMM0,4),modregrm(0,4,SP));   // MOV [ESP],r
        checkSetVex(cdb.last(),tym);
        return;
    }
    else if (tyfloating(tym))
    {
        if (config.inline8087)
        {
            retregs = tycomplex(tym) ? mST01 : mST0;
            codelem(cdb,e,&retregs,FALSE);
            stackpush += sz;
            cdb.append(genadjesp(CNIL,sz));
            cod3_stackadj(cdb, sz);
            unsigned op;
            unsigned r;
            switch (tym)
            {
                case TYfloat:
                case TYifloat:
                case TYcfloat:
                    op = 0xD9;
                    r = 3;
                    break;

                case TYdouble:
                case TYidouble:
                case TYdouble_alias:
                case TYcdouble:
                    op = 0xDD;
                    r = 3;
                    break;

                case TYldouble:
                case TYildouble:
                case TYcldouble:
                    op = 0xDB;
                    r = 7;
                    break;

                default:
                    assert(0);
            }
            if (!I16)
            {
                if (tycomplex(tym))
                {
                    // FSTP sz/2[ESP]
                    cdb.genc1(op,(modregrm(0,4,SP) << 8) | modregxrm(2,r,4),FLconst,sz/2);
                    pop87();
                }
                pop87();
                cdb.gen2sib(op,modregrm(0,r,4),modregrm(0,4,SP));   // FSTP [ESP]
            }
            else
            {
                retregs = IDXREGS;                             // get an index reg
                unsigned reg;
                allocreg(cdb,&retregs,&reg,TYoffset);
                cdb.append(genregs(CNIL,0x89,SP,reg));         // MOV reg,SP
                pop87();
                cdb.gen2(op,modregrm(0,r,regtorm[reg]));       // FSTP [reg]
            }
            if (LARGEDATA)
                cdb.last()->Iflags |= CFss;     // want to store into stack
            genfwait(cdb);         // FWAIT
            return;
        }
        else if (I16 && (tym == TYdouble || tym == TYdouble_alias))
            retregs = mSTACK;
    }
    else if (I16 && sz == 8)             // if long long
        retregs = mSTACK;

    scodelem(cdb,e,&retregs,0,TRUE);
    if (retregs != mSTACK)                // if stackpush not already inc'd
        stackpush += sz;
    if (sz <= REGSIZE)
    {
        cdb.append(genpush(CNIL,findreg(retregs)));        // PUSH reg
        cdb.append(genadjesp(CNIL,REGSIZE));
    }
    else if (sz == REGSIZE * 2)
    {
        cdb.append(genpush(CNIL,findregmsw(retregs)));     // PUSH msreg
        cdb.append(genpush(CNIL,findreglsw(retregs)));     // PUSH lsreg
        cdb.append(genadjesp(CNIL,sz));
    }
}


/*******************************
 * Get offset portion of e, and store it in an index
 * register. Return mask of index register in *pretregs.
 */

void offsetinreg(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    unsigned reg;
    regm_t retregs = mLSW;                     // want only offset
    if (e->Ecount && e->Ecount != e->Ecomsub)
    {
        regm_t rm = retregs & regcon.cse.mval & ~regcon.cse.mops & ~regcon.mvar; /* possible regs */
        for (unsigned i = 0; rm; i++)
        {
            if (mask[i] & rm && regcon.cse.value[i] == e)
            {
                *pretregs = mask[i];
                getregs(cdb,*pretregs);
                goto L3;
            }
            rm &= ~mask[i];
        }
    }

    *pretregs = retregs;
    allocreg(cdb,pretregs,&reg,TYoffset);
    getoffset(cdb,e,reg);
L3:
    cssave(e,*pretregs,FALSE);
    freenode(e);
}


/******************************
 * Generate code to load data into registers.
 */

void loaddata(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{ unsigned reg,nreg,op,sreg;
  tym_t tym;
  code cs;
  regm_t flags,forregs,regm;

#ifdef DEBUG
//  if (debugw)
//        printf("loaddata(e = %p,*pretregs = %s)\n",e,regm_str(*pretregs));
//  elem_print(e);
#endif
  assert(e);
  elem_debug(e);
  if (*pretregs == 0)
        return;
  tym = tybasic(e->Ety);
  if (tym == TYstruct)
  {
        cdrelconst(cdb,e,pretregs);
        return;
  }
  if (tyfloating(tym))
  {     objmod->fltused();
        if (config.inline8087)
        {   if (*pretregs & mST0)
            {
                load87(cdb,e,0,pretregs,NULL,-1);
                return;
            }
            else if (tycomplex(tym))
            {
                cload87(cdb, e, pretregs);
                return;
            }
        }
  }
  int sz = _tysize[tym];
  cs.Iflags = 0;
  cs.Irex = 0;
  if (*pretregs == mPSW)
  {
        symbol *s;
        regm = allregs;
        if (e->Eoper == OPconst)
        {       /* TRUE:        OR SP,SP        (SP is never 0)         */
                /* FALSE:       CMP SP,SP       (always equal)          */
                cdb.append(genregs(CNIL,(boolres(e)) ? 0x09 : 0x39,SP,SP));
                if (I64)
                    code_orrex(cdb.last(), REX_W);
        }
        else if (e->Eoper == OPvar &&
            (s = e->EV.sp.Vsym)->Sfl == FLreg &&
            s->Sregm & XMMREGS &&
            (tym == TYfloat || tym == TYifloat || tym == TYdouble || tym ==TYidouble))
        {
            tstresult(cdb,s->Sregm,e->Ety,TRUE);
        }
        else if (sz <= REGSIZE)
        {
            if (!I16 && (tym == TYfloat || tym == TYifloat))
            {
                allocreg(cdb,&regm,&reg,TYoffset);   // get a register
                loadea(cdb,e,&cs,0x8B,reg,0,0,0);    // MOV reg,data
                cdb.gen2(0xD1,modregrmx(3,4,reg));           // SHL reg,1
            }
            else if (I64 && (tym == TYdouble || tym ==TYidouble))
            {
                allocreg(cdb,&regm,&reg,TYoffset);   // get a register
                loadea(cdb,e,&cs,0x8B,reg,0,0,0);    // MOV reg,data
                // remove sign bit, so that -0.0 == 0.0
                cdb.gen2(0xD1,modregrmx(3,4,reg));           // SHL reg,1
                code_orrex(cdb.last(), REX_W);
            }

#if TARGET_OSX
            else if (e->Eoper == OPvar && movOnly(e))
            {
                allocreg(cdb,&regm,&reg,TYoffset);   // get a register
                loadea(cdb,e,&cs,0x8B,reg,0,0,0);    // MOV reg,data
                fixresult(cdb,e,regm,pretregs);
            }
#endif
            else
            {   cs.IFL2 = FLconst;
                cs.IEV2.Vsize_t = 0;
                op = (sz == 1) ? 0x80 : 0x81;
                loadea(cdb,e,&cs,op,7,0,0,0);        // CMP EA,0

                // Convert to TEST instruction if EA is a register
                // (to avoid register contention on Pentium)
                code *c = cdb.last();
                if ((c->Iop & ~1) == 0x38 &&
                    (c->Irm & modregrm(3,0,0)) == modregrm(3,0,0)
                   )
                {   c->Iop = (c->Iop & 1) | 0x84;
                    code_newreg(c, c->Irm & 7);
                    if (c->Irex & REX_B)
                        //c->Irex = (c->Irex & ~REX_B) | REX_R;
                        c->Irex |= REX_R;
                }
            }
        }
        else if (sz < 8)
        {
            allocreg(cdb,&regm,&reg,TYoffset);  // get a register
            if (I32)                                    // it's a 48 bit pointer
                loadea(cdb,e,&cs,0x0FB7,reg,REGSIZE,0,0); // MOVZX reg,data+4
            else
            {
                loadea(cdb,e,&cs,0x8B,reg,REGSIZE,0,0); // MOV reg,data+2
                if (tym == TYfloat || tym == TYifloat)       // dump sign bit
                    cdb.gen2(0xD1,modregrm(3,4,reg));        // SHL reg,1
            }
            loadea(cdb,e,&cs,0x0B,reg,0,regm,0);     // OR reg,data
        }
        else if (sz == 8 || (I64 && sz == 2 * REGSIZE && !tyfloating(tym)))
        {
            allocreg(cdb,&regm,&reg,TYoffset);       // get a register
            int i = sz - REGSIZE;
            loadea(cdb,e,&cs,0x8B,reg,i,0,0);        // MOV reg,data+6
            if (tyfloating(tym))                             // TYdouble or TYdouble_alias
                cdb.gen2(0xD1,modregrm(3,4,reg));            // SHL reg,1

            while ((i -= REGSIZE) >= 0)
            {
                loadea(cdb,e,&cs,0x0B,reg,i,regm,0); // OR reg,data+i
                code *c = cdb.last();
                if (i == 0)
                    c->Iflags |= CFpsw;                      // need the flags on last OR
            }
        }
        else if (sz == tysize(TYldouble))               // TYldouble
            load87(cdb,e,0,pretregs,NULL,-1);
        else
        {
            elem_print(e);
            assert(0);
        }
        return;
  }
  /* not for flags only */
  flags = *pretregs & mPSW;             /* save original                */
  forregs = *pretregs & (mBP | ALLREGS | mES | XMMREGS);
  if (*pretregs & mSTACK)
        forregs |= DOUBLEREGS;
  if (e->Eoper == OPconst)
  {
        targ_size_t value = e->EV.Vint;
        if (sz == 8)
            value = e->EV.Vullong;

        if (sz == REGSIZE && reghasvalue(forregs,value,&reg))
            forregs = mask[reg];

        regm_t save = regcon.immed.mval;
        allocreg(cdb,&forregs,&reg,tym);        // allocate registers
        regcon.immed.mval = save;               // KLUDGE!
        if (sz <= REGSIZE)
        {
            if (sz == 1)
                flags |= 1;
            else if (!I16 && sz == SHORTSIZE &&
                     !(mask[reg] & regcon.mvar) &&
                     !(config.flags4 & CFG4speed)
                    )
                flags |= 2;
            if (sz == 8)
                flags |= 64;
            if (reg >= XMM0)
            {   /* This comes about because 0, 1, pi, etc., constants don't get stored
                 * in the data segment, because they are x87 opcodes.
                 * Not so efficient. We should at least do a PXOR for 0.
                 */
                unsigned r;
                targ_size_t value = e->EV.Vuns;
                if (sz == 8)
                    value = e->EV.Vullong;
                regwithvalue(cdb,ALLREGS, value,&r,flags);
                flags = 0;                          // flags are already set
                cdb.genfltreg(0x89,r,0);            // MOV floatreg,r
                if (sz == 8)
                    code_orrex(cdb.last(), REX_W);
                assert(sz == 4 || sz == 8);         // float or double
                unsigned op = xmmload(tym);
                cdb.genxmmreg(op,reg,0,tym);        // MOVSS/MOVSD XMMreg,floatreg
            }
            else
            {
                movregconst(cdb,reg,value,flags);
                flags = 0;                          // flags are already set
            }
        }
        else if (sz < 8)        // far pointers, longs for 16 bit targets
        {
            targ_int msw = I32 ? e->EV.Vfp.Vseg
                        : (e->EV.Vulong >> 16);
            targ_int lsw = e->EV.Vfp.Voff;
            regm_t mswflags = 0;
            if (forregs & mES)
            {
                movregconst(cdb,reg,msw,0); // MOV reg,segment
                cdb.append(genregs(CNIL,0x8E,0,reg));    // MOV ES,reg
                msw = lsw;                               // MOV reg,offset
            }
            else
            {
                sreg = findreglsw(forregs);
                movregconst(cdb,sreg,lsw,0);
                reg = findregmsw(forregs);
                /* Decide if we need to set flags when we load msw      */
                if (flags && (msw && msw|lsw || !(msw|lsw)))
                {   mswflags = mPSW;
                    flags = 0;
                }
            }
            movregconst(cdb,reg,msw,mswflags);
        }
        else if (sz == 8)
        {
            if (I32)
            {
                targ_long *p = (targ_long *) &e->EV.Vdouble;
                if (reg >= XMM0)
                {   /* This comes about because 0, 1, pi, etc., constants don't get stored
                     * in the data segment, because they are x87 opcodes.
                     * Not so efficient. We should at least do a PXOR for 0.
                     */
                    unsigned r;
                    regm_t rm = ALLREGS;
                    allocreg(cdb,&rm,&r,TYint);    // allocate scratch register
                    movregconst(cdb,r,p[0],0);
                    cdb.genfltreg(0x89,r,0);               // MOV floatreg,r
                    movregconst(cdb,r,p[1],0);
                    cdb.genfltreg(0x89,r,4);               // MOV floatreg+4,r

                    unsigned op = xmmload(tym);
                    cdb.genxmmreg(op,reg,0,tym);           // MOVSS/MOVSD XMMreg,floatreg
                }
                else
                {
                    movregconst(cdb,findreglsw(forregs),p[0],0);
                    movregconst(cdb,findregmsw(forregs),p[1],0);
                }
            }
            else
            {   targ_short *p = (targ_short *) &e->EV.Vdouble;

                assert(reg == AX);
                movregconst(cdb,AX,p[3],0);   // MOV AX,p[3]
                movregconst(cdb,DX,p[0],0);
                movregconst(cdb,CX,p[1],0);
                movregconst(cdb,BX,p[2],0);
            }
        }
        else if (I64 && sz == 16)
        {
            movregconst(cdb,findreglsw(forregs),e->EV.Vcent.lsw,64);
            movregconst(cdb,findregmsw(forregs),e->EV.Vcent.msw,64);
        }
        else
            assert(0);
        // Flags may already be set
        *pretregs &= flags | ~mPSW;
        fixresult(cdb,e,forregs,pretregs);
        return;
  }
  else
  {
    // See if we can use register that parameter was passed in
    if (regcon.params &&
        (e->EV.sp.Vsym->Sclass == SCfastpar || e->EV.sp.Vsym->Sclass == SCshadowreg) &&
        (regcon.params & mask[e->EV.sp.Vsym->Spreg] && e->EV.sp.Voffset == 0 ||
         regcon.params & mask[e->EV.sp.Vsym->Spreg2] && e->EV.sp.Voffset == REGSIZE) &&
        sz <= REGSIZE)                  // make sure no 'paint' to a larger size happened
    {
        reg = e->EV.sp.Voffset ? e->EV.sp.Vsym->Spreg2 : e->EV.sp.Vsym->Spreg;
        forregs = mask[reg];
#ifdef DEBUG
//        if (debugr)
//            printf("%s is fastpar and using register %s\n", e->EV.sp.Vsym->Sident, regm_str(forregs));
#endif
        mfuncreg &= ~forregs;
        regcon.used |= forregs;
        fixresult(cdb,e,forregs,pretregs);
        return;
    }

    allocreg(cdb,&forregs,&reg,tym);            // allocate registers

    if (sz == 1)
    {   regm_t nregm;

#ifdef DEBUG
        if (!(forregs & BYTEREGS))
        {       elem_print(e);
                printf("forregs = %s\n", regm_str(forregs));
        }
#endif
        int op = 0x8A;                                  // byte MOV
#if TARGET_OSX
        if (movOnly(e))
            op = 0x8B;
#endif
        assert(forregs & BYTEREGS);
        if (!I16)
        {
            if (config.target_cpu >= TARGET_PentiumPro && config.flags4 & CFG4speed &&
                // Workaround for OSX linker bug:
                //   ld: GOT load reloc does not point to a movq instruction in test42 for x86_64
                !(config.exe & EX_OSX64 && !(sytab[e->EV.sp.Vsym->Sclass] & SCSS))
               )
            {
                op = tyuns(tym) ? 0x0FB6 : 0x0FBE;      // MOVZX/MOVSX
            }
            loadea(cdb,e,&cs,op,reg,0,0,0);     // MOV regL,data
        }
        else
        {   nregm = tyuns(tym) ? BYTEREGS : mAX;
            if (*pretregs & nregm)
                nreg = reg;                             // already allocated
            else
                allocreg(cdb,&nregm,&nreg,tym);
            loadea(cdb,e,&cs,op,nreg,0,0,0);    // MOV nregL,data
            if (reg != nreg)
            {
                cdb.append(genmovreg(CNIL,reg,nreg));   // MOV reg,nreg
                cssave(e,mask[nreg],FALSE);
            }
        }
    }
    else if (forregs & XMMREGS)
    {
        // Can't load from registers directly to XMM regs
        //e->EV.sp.Vsym->Sflags &= ~GTregcand;

        op = xmmload(tym, xmmIsAligned(e));
        if (e->Eoper == OPvar)
        {   symbol *s = e->EV.sp.Vsym;
            if (s->Sfl == FLreg && !(mask[s->Sreglsw] & XMMREGS))
            {   op = LODD;          // MOVD/MOVQ
                /* getlvalue() will unwind this and unregister s; could use a better solution */
            }
        }
        loadea(cdb,e,&cs,op,reg,0,RMload,0); // MOVSS/MOVSD reg,data
        checkSetVex(cdb.last(),tym);
    }
    else if (sz <= REGSIZE)
    {
        unsigned op = 0x8B;                     // MOV reg,data
        if (sz == 2 && !I16 && config.target_cpu >= TARGET_PentiumPro &&
            // Workaround for OSX linker bug:
            //   ld: GOT load reloc does not point to a movq instruction in test42 for x86_64
            !(config.exe & EX_OSX64 && !(sytab[e->EV.sp.Vsym->Sclass] & SCSS))
           )
        {
            op = tyuns(tym) ? 0x0FB7 : 0x0FBF;  // MOVZX/MOVSX
        }
        loadea(cdb,e,&cs,op,reg,0,RMload,0);
    }
    else if (sz <= 2 * REGSIZE && forregs & mES)
    {
        loadea(cdb,e,&cs,0xC4,reg,0,0,mES);    // LES data
    }
    else if (sz <= 2 * REGSIZE)
    {
        if (I32 && sz == 8 &&
            (*pretregs & (mSTACK | mPSW)) == mSTACK)
        {
            assert(0);
            /* Note that we allocreg(DOUBLEREGS) needlessly     */
            stackchanged = 1;
            int i = DOUBLESIZE - REGSIZE;
            do
            {
                loadea(cdb,e,&cs,0xFF,6,i,0,0); // PUSH EA+i
                cdb.append(genadjesp(CNIL,REGSIZE));
                stackpush += REGSIZE;
                i -= REGSIZE;
            }
            while (i >= 0);
            return;
        }

        reg = findregmsw(forregs);
        loadea(cdb,e,&cs,0x8B,reg,REGSIZE,forregs,0); // MOV reg,data+2
        if (I32 && sz == REGSIZE + 2)
            cdb.last()->Iflags |= CFopsize;                   // seg is 16 bits
        reg = findreglsw(forregs);
        loadea(cdb,e,&cs,0x8B,reg,0,forregs,0);       // MOV reg,data
    }
    else if (sz >= 8)
    {
        assert(!I32);
        if ((*pretregs & (mSTACK | mPSW)) == mSTACK)
        {
            // Note that we allocreg(DOUBLEREGS) needlessly
            stackchanged = 1;
            int i = sz - REGSIZE;
            do
            {
                loadea(cdb,e,&cs,0xFF,6,i,0,0); // PUSH EA+i
                cdb.append(genadjesp(CNIL,REGSIZE));
                stackpush += REGSIZE;
                i -= REGSIZE;
            }
            while (i >= 0);
            return;
        }
        else
        {
            assert(reg == AX);
            loadea(cdb,e,&cs,0x8B,AX,6,0,0);           // MOV AX,data+6
            loadea(cdb,e,&cs,0x8B,BX,4,mAX,0);         // MOV BX,data+4
            loadea(cdb,e,&cs,0x8B,CX,2,mAX|mBX,0);     // MOV CX,data+2
            loadea(cdb,e,&cs,0x8B,DX,0,mAX|mCX|mCX,0); // MOV DX,data
        }
    }
    else
        assert(0);
    // Flags may already be set
    *pretregs &= flags | ~mPSW;
    fixresult(cdb,e,forregs,pretregs);
    return;
  }
}

#endif // SPP
