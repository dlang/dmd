// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2012 by Digital Mars
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
code * genf2(code *c,unsigned op,unsigned rm);

targ_size_t paramsize(elem *e,unsigned stackalign);
STATIC code * funccall (elem *,unsigned,unsigned,regm_t *,regm_t);

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

code *cdisscaledindex(elem *e,regm_t *pidxregs,regm_t keepmsk)
{   code *c;
    regm_t r;

    // Load index register with result of e->E1
    c = NULL;
    while (e->Eoper == OPcomma)
    {
        r = 0;
        c = cat(c,scodelem(e->E1,&r,keepmsk,TRUE));
        freenode(e);
        e = e->E2;
    }
    assert(e->Eoper == OPshl);
    c = cat(c,scodelem(e->E1,pidxregs,keepmsk,TRUE));
    freenode(e->E2);
    freenode(e);
    return c;
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
{   regm_t retregs;
    code *c;

    eecontext.EEin++;
    regcon.immed.mval = 0;
    retregs = 0;    //regmask(eecontext.EEelem->Ety);
    assert(EEStack.offset >= REGSIZE);
    c = cod3_stackadj(NULL, EEStack.offset - REGSIZE);
    gen1(c,0x50 + SI);                      // PUSH ESI
    genadjesp(c,EEStack.offset);
    c = gencodelem(c,eecontext.EEelem,&retregs, FALSE);
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
    code *cs1 = *csave;
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
                cs1 = gen1(cs1, 0x06);                  // PUSH ES
                cs2 = cat(gen1(CNIL, 0x07),cs2);        // POP  ES
            }
            else if (i == ST0 || i == ST01)
            {
                gensaverestore87(1 << i, &cs1, &cs2);
            }
            else if (i >= XMM0 || I64)
            {   unsigned idx;
                cs1 = regsave.save(cs1, i, &idx);
                cs2 = regsave.restore(cs2, i, idx);
            }
            else
            {
                stackused += REGSIZE;
                cs1 = gen1(cs1,0x50 + (i & 7));         // PUSH i
                code *c = gen1(NULL, 0x58 + (i & 7));   // POP  i
                if (i & 8)
                {   code_orrex(cs1, REX_B);
                    code_orrex(c, REX_B);
                }
                cs2 = cat(c,cs2);
            }
        }
        regm >>= 1;
    }
    *csave = cs1;
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

code *genstackclean(code *c,unsigned numpara,regm_t keepmsk)
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
            c = genregs(c,0x89,BP,SP);  // MOV SP,BP
        else
#endif
        {   regm_t scratchm = 0;

            if (numpara == REGSIZE && config.flags4 & CFG4space)
            {
                scratchm = ALLREGS & ~keepmsk & regcon.used & ~regcon.mvar;
            }

            if (scratchm)
            {   unsigned r;
                c = cat(c,allocreg(&scratchm,&r,TYint));
                c = gen1(c,0x58 + r);           // POP r
            }
            else
                c = cod3_stackadj(c, -numpara);
        }
        stackpush -= numpara;
        c = genadjesp(c,-numpara);
    }
    return c;
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

code *logexp(elem *e,int jcond,unsigned fltarg,code *targ)
{ code *c,*ce,*cnop;
  regm_t retregs;
  unsigned op;

  //printf("logexp(e = %p, jcond = %d)\n", e, jcond);
  int no87 = (jcond & 2) == 0;
  _chkstack();
  code *cc = docommas(&e);            // scan down commas
  cgstate.stackclean++;

  if (EOP(e) && !e->Ecount)     /* if operator and not common sub */
  {     con_t regconsave;

        switch (e->Eoper)
        {   case OPoror:
                if (jcond & 1)
                {       c = logexp(e->E1,jcond,fltarg,targ);
                        regconsave = regcon;
                        ce = logexp(e->E2,jcond,fltarg,targ);
                }
                else
                {       cnop = gennop(CNIL);
                        c = logexp(e->E1,jcond | 1,FLcode,cnop);
                        regconsave = regcon;
                        ce = logexp(e->E2,jcond,fltarg,targ);
                        ce = cat(ce,cnop);
                }
                cnop = CNIL;
                goto L1;

            case OPandand:
                if (jcond & 1)
                {       cnop = gennop(CNIL);    /* a dummy target address */
                        c = logexp(e->E1,jcond & ~1,FLcode,cnop);
                        regconsave = regcon;
                        ce = logexp(e->E2,jcond,fltarg,targ);
                }
                else
                {       c = logexp(e->E1,jcond,fltarg,targ);
                        regconsave = regcon;
                        ce = logexp(e->E2,jcond,fltarg,targ);
                        cnop = CNIL;
                }
        L1:     andregcon(&regconsave);
                freenode(e);
                c = cat4(cc,c,ce,cnop);
                goto Lret;

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
                c = logexp(e->E1,jcond,fltarg,targ);
                freenode(e);
                goto Lretc;

            case OPcond:
            {
                code *cnop2 = gennop(CNIL);   // addresses of start of leaves
                cnop = gennop(CNIL);
                c = logexp(e->E1,FALSE,FLcode,cnop2);   /* eval condition */
                con_t regconold = regcon;
                ce = logexp(e->E2->E1,jcond,fltarg,targ);
                ce = genjmp(ce,JMP,FLcode,(block *) cnop); /* skip second leaf */

                regconsave = regcon;
                regcon = regconold;

                code_next(cnop2) = logexp(e->E2->E2,jcond,fltarg,targ);
                andregcon(&regconold);
                andregcon(&regconsave);
                freenode(e->E2);
                freenode(e);
                c = cat6(cc,c,NULL,ce,cnop2,cnop);
                goto Lret;
            }
        }
  }

  /* Special code for signed long compare.
   * Not necessary for I64 until we do cents.
   */
  if (OTrel2(e->Eoper) &&               /* if < <= >= >                 */
      !e->Ecount &&
      ( (I16 && tybasic(e->E1->Ety) == TYlong  && tybasic(e->E2->Ety) == TYlong) ||
        (I32 && tybasic(e->E1->Ety) == TYllong && tybasic(e->E2->Ety) == TYllong))
     )
  {
        c = longcmp(e,jcond,fltarg,targ);
        goto Lretc;
  }

  retregs = mPSW;               /* return result in flags               */
  op = jmpopcode(e);            /* get jump opcode                      */
  if (!(jcond & 1))
        op ^= 0x101;            // toggle jump condition(s)
  c = codelem(e,&retregs,TRUE); /* evaluate elem                        */
  if (no87)
        c = cat(c,cse_flush(no87));     // flush CSE's to memory
  genjmp(c,op,fltarg,(block *) targ);   /* generate jmp instruction     */
Lretc:
  c = cat(cc,c);
Lret:
  cgstate.stackclean--;
  return c;
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

code *loadea(elem *e,code *cs,unsigned op,unsigned reg,targ_size_t offset,
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
                                            goto L1;    /* not a load   */
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
                                c = CNIL;
                                goto L2;
                        }
                        rm &= ~mask[i];
                }
        }
  }

L1:
  c = getlvalue(cs,e,keepmsk);
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
  cg = getregs(desmsk);                 /* save any regs we destroy     */

  /* KLUDGE! fix up DX for divide instructions */
  cd = CNIL;
  if (op == 0xF7 && desmsk == (mAX|mDX))        /* if we need to fix DX */
  {     if (reg == 7)                           /* if IDIV              */
        {   cd = gen1(cd,0x99);                 // CWD
            if (I64 && sz == 8)
                code_orrex(cd, REX_W);
        }
        else if (reg == 6)                      // if DIV
        {   cd = genregs(cd,0x33,DX,DX);        // XOR DX,DX
        }
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

  return cat4(c,cg,cd,gen(NULL,cs));
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

code *getlvalue(code *pcs,elem *e,regm_t keepmsk)
{ regm_t idxregs;
  unsigned fl,f,opsave;
  code *c;
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
  c = CNIL;
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
#if TARGET_SEGMENTED
            (!e1->Ecount || (~keepmsk & ALLREGS & mMSW) || (e1ty != TYfptr && e1ty != TYhptr)) &&
#endif
            tysize(e11->Ety) == REGSIZE
           )
        {   unsigned char t;            /* component of r/m field */
            int ss;
            int ssi;

#if !TARGET_SEGMENTED
            if (e12->Eoper == OPrelconst)
                f = el_fl(e12);
#endif
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
                    c = cdisscaledindex(e11,&idxregs,keepmsk);
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
                    c = scodelem(e11->E1,&idxregs,keepmsk,TRUE);
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
                        c = cat(c,allocreg(&scratchm,&r,TYint));

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
                                c = genc2(c,0x69,modregxrmx(3,r,rbase),imm32[ss1]);
                                goto L7;
                            }
                        }

                        c = gen2sib(c,0x8D,modregxrm(t,r,4),modregrm(ss1,reg & 7,rbase & 7));
                        if (reg & 8)
                            code_orrex(c, REX_X);
                        if (rbase & 8)
                            code_orrex(c, REX_B);
                        if (I64)
                            code_orrex(c, REX_W);

                        if (ssflags & SSFLnobase1)
                        {   code_last(c)->IFL1 = FLconst;
                            code_last(c)->IEV1.Vuns = 0;
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
                    c = scodelem(e11,&idxregs,keepmsk,TRUE);
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
                c = scodelem(e11,&idxregs,keepmsk,TRUE); /* load idx reg */
                pcs->Irm = getaddrmode(idxregs) ^ t;
            }
            if (f == FLpara)
                refparam = TRUE;
            else if (f == FLauto || f == FLbprel || f == FLfltreg || f == FLfast)
                reflocal = TRUE;
#if TARGET_SEGMENTED
            else if (f == FLcsdata || tybasic(e12->Ety) == TYcptr)
                pcs->Iflags |= CFcs;
#endif
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
                c = cat(c,allocreg(&idxregs,&reg,TYoffset));

#if TARGET_SEGMENTED
                /* If desired result is a far pointer, we'll have       */
                /* to load another register with the segment of v       */
                if (e1ty == TYfptr)
                {
                    unsigned msreg;

                    idxregs |= mMSW & ALLREGS & ~keepmsk;
                    c = cat(c,allocreg(&idxregs,&msreg,TYfptr));
                    msreg = findregmsw(idxregs);
                                                /* MOV msreg,segreg     */
                    c = genregs(c,0x8C,segfl[f],msreg);
                }
#endif
                opsave = pcs->Iop;
                flagsave = pcs->Iflags;
                unsigned char rexsave = pcs->Irex;
                pcs->Iop = 0x8D;
                code_newreg(pcs, reg);
                if (!I16)
                    pcs->Iflags &= ~CFopsize;
                if (I64)
                    pcs->Irex |= REX_W;
                c = gen(c,pcs);                 /* LEA idxreg,EA        */
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

#if TARGET_SEGMENTED
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
#endif
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
                c = cdisscaledindex(e11,&idxregs,keepmsk);
                reg = findreg(idxregs);
                pcs->Irm = modregrm(0,0,4);
                pcs->Isib = modregrm(ss,reg & 7,5);
                if (reg & 8)
                    pcs->Irex |= REX_X;
            }
            else
            {
                c = scodelem(e11,&idxregs,keepmsk,TRUE); // load index reg
                setaddrmode(pcs, idxregs);
            }
            goto Lptr;
        }

        /* Look for *(v1 + v2)
         *      EA = [v1][v2]
         */

        if (!I16 && e1isadd && (!e1->Ecount || !e1free) &&
            (tysize[e1ty] == REGSIZE || (I64 && tysize[e1ty] == 4)))
        {   code *c2;
            regm_t idxregs2;
            unsigned base,index;
            int ss;

        L4:
            // Look for *(v1 + v2 << scale)
            ss = isscaledindex(e12);
            if (ss)
            {
                c = scodelem(e11,&idxregs,keepmsk,TRUE);
                idxregs2 = allregs & ~(idxregs | keepmsk);
                c2 = cdisscaledindex(e12,&idxregs2,keepmsk | idxregs);
            }

            // Look for *(v1 << scale + v2)
            else if ((ss = isscaledindex(e11)) != 0)
            {
                idxregs2 = idxregs;
                c = cdisscaledindex(e11,&idxregs2,keepmsk);
                idxregs = allregs & ~(idxregs2 | keepmsk);
                c2 = scodelem(e12,&idxregs,keepmsk | idxregs2,TRUE);
            }
            // Look for *(((v1 << scale) + c1) + v2)
            else if (e11->Eoper == OPadd && !e11->Ecount &&
                     e11->E2->Eoper == OPconst &&
                     (ss = isscaledindex(e11->E1)) != 0
                    )
            {
                pcs->IEV1.Vuns = e11->E2->EV.Vuns;
                idxregs2 = idxregs;
                c = cdisscaledindex(e11->E1,&idxregs2,keepmsk);
                idxregs = allregs & ~(idxregs2 | keepmsk);
                c2 = scodelem(e12,&idxregs,keepmsk | idxregs2,TRUE);
                freenode(e11->E2);
                freenode(e11);
            }
            else
            {
                c = scodelem(e11,&idxregs,keepmsk,TRUE);
                idxregs2 = allregs & ~(idxregs | keepmsk);
                c2 = scodelem(e12,&idxregs2,keepmsk | idxregs,TRUE);
            }
            c = cat(c,c2);
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
        c = scodelem(e1,&idxregs,keepmsk,TRUE); /* load index register  */
        setaddrmode(pcs, idxregs);
    Lptr:
        if (config.flags3 & CFG3ptrchk)
            cod3_ptrchk(&c,pcs,keepmsk);        // validate pointer code
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
#if TARGET_SEGMENTED
        if (s->ty() & mTYcs && LARGECODE)
            goto Lfardata;
#endif
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
#ifdef DEBUG
            if (!(s->Sregm & regcon.mvar)) symbol_print(s);
#endif
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
        }
#if TARGET_SEGMENTED
        else if (s->ty() & mTYcs && !(fl == FLextern && LARGECODE))
        {
            pcs->Iflags |= CFcs | CFoff;
        }
#endif
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
            if (e->EV.sp.Voffset > 1)
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
        assert(0);
#else
    {
        unsigned u = s->Sreglsw;
        c = getregs(pseudomask[u]);
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
        code *c1 = allocreg(&regm,&reg,TYint);
        /* MOV mreg,seg of symbol       */
        c = gencs(CNIL,0xB8 + reg,0,FLextern,s);
        c->Iflags = CFseg;
        c = gen2(c,0x8E,modregrmx(3,0,reg));     /* MOV ES,reg           */
        c = cat3(c1,getregs(mES),c);
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
#ifdef DEBUG
        symbol_print(s);
#endif
        assert(0);
  }
  return c;
}

/*****************************
 * Given an opcode and EA in cs, generate code
 * for each floating register in turn.
 * Input:
 *      tym     either TYdouble or TYfloat
 */

code *fltregs(code *pcs,tym_t tym)
{   code *c;

    assert(!I64);
    tym = tybasic(tym);
    if (I32)
    {
        c = getregs((tym == TYfloat) ? mAX : mAX | mDX);
        if (tym != TYfloat)
        {
            pcs->IEVoffset1 += REGSIZE;
            NEWREG(pcs->Irm,DX);
            c = gen(c,pcs);
            pcs->IEVoffset1 -= REGSIZE;
        }
        NEWREG(pcs->Irm,AX);
        c = gen(c,pcs);
    }
    else
    {
        c = getregs((tym == TYfloat) ? FLOATREGS_16 : DOUBLEREGS_16);
        pcs->IEVoffset1 += (tym == TYfloat) ? 2 : 6;
        if (tym == TYfloat)
            NEWREG(pcs->Irm,DX);
        else
            NEWREG(pcs->Irm,AX);
        c = gen(c,pcs);
        pcs->IEVoffset1 -= 2;
        if (tym == TYfloat)
            NEWREG(pcs->Irm,AX);
        else
            NEWREG(pcs->Irm,BX);
        gen(c,pcs);
        if (tym != TYfloat)
        {     pcs->IEVoffset1 -= 2;
              NEWREG(pcs->Irm,CX);
              gen(c,pcs);
              pcs->IEVoffset1 -= 2;     /* note that exit is with Voffset unaltered */
              NEWREG(pcs->Irm,DX);
              gen(c,pcs);
        }
    }
    return c;
}


/*****************************
 * Given a result in registers, test it for TRUE or FALSE.
 * Will fail if TYfptr and the reg is ES!
 * If saveflag is TRUE, preserve the contents of the
 * registers.
 */

code *tstresult(regm_t regm,tym_t tym,unsigned saveflag)
{
  unsigned scrreg;                      /* scratch register             */
  regm_t scrregm;

#ifdef DEBUG
  //if (!(regm & (mBP | ALLREGS)))
        //printf("tstresult(regm = %s, tym = x%x, saveflag = %d)\n",
            //regm_str(regm),tym,saveflag);
#endif
  assert(regm & (XMMREGS | mBP | ALLREGS));
  tym = tybasic(tym);
  code *ce = CNIL;
  unsigned reg = findreg(regm);
  unsigned sz = tysize[tym];
  if (sz == 1)
  {     assert(regm & BYTEREGS);
        ce = genregs(ce,0x84,reg,reg);        // TEST regL,regL
        if (I64 && reg >= 4)
            code_orrex(ce, REX);
        return ce;
  }
  if (regm & XMMREGS)
  {
        unsigned xreg;
        regm_t xregs = XMMREGS & ~regm;
        ce = allocreg(&xregs, &xreg, TYdouble);
        unsigned op = 0;
        if (tym == TYdouble || tym == TYidouble || tym == TYcdouble)
            op = 0x660000;
        ce = gen2(ce,op | 0x0F57,modregrm(3,xreg-XMM0,xreg-XMM0));      // XORPS xreg,xreg
        gen2(ce,op | 0x0F2E,modregrm(3,xreg-XMM0,reg-XMM0));    // UCOMISS xreg,reg
        if (tym == TYcfloat || tym == TYcdouble)
        {   code *cnop = gennop(CNIL);
            genjmp(ce,JNE,FLcode,(block *) cnop); // JNE     L1
            genjmp(ce,JP, FLcode,(block *) cnop); // JP      L1
            reg = findreg(regm & ~mask[reg]);
            gen2(ce,op | 0x0F2E,modregrm(3,xreg-XMM0,reg-XMM0));        // UCOMISS xreg,reg
            ce = cat(ce, cnop);
        }
        return ce;
  }
  if (sz <= REGSIZE)
  {
    if (!I16)
    {
        if (tym == TYfloat)
        {   if (saveflag)
            {
                scrregm = allregs & ~regm;              /* possible scratch regs */
                ce = allocreg(&scrregm,&scrreg,TYoffset); /* allocate scratch reg */
                ce = genmovreg(ce,scrreg,reg);  /* MOV scrreg,msreg     */
                reg = scrreg;
            }
            ce = cat(ce,getregs(mask[reg]));
            return gen2(ce,0xD1,modregrmx(3,4,reg)); // SHL reg,1
        }
        ce = gentstreg(ce,reg);                 // TEST reg,reg
        if (sz == SHORTSIZE)
            ce->Iflags |= CFopsize;             /* 16 bit operands      */
        else if (sz == 8)
            code_orrex(ce, REX_W);
    }
    else
        ce = gentstreg(ce,reg);                 // TEST reg,reg
    return ce;
  }
  if (saveflag || tyfv(tym))
  {
        scrregm = ALLREGS & ~regm;              /* possible scratch regs */
        ce = allocreg(&scrregm,&scrreg,TYoffset); /* allocate scratch reg */
        if (I32 || sz == REGSIZE * 2)
        {   code *c;

            assert(regm & mMSW && regm & mLSW);

            reg = findregmsw(regm);
            if (I32)
            {
                if (tyfv(tym))
                {   c = genregs(CNIL,0x0FB7,scrreg,reg); // MOVZX scrreg,msreg
                    ce = cat(ce,c);
                }
                else
                {   ce = genmovreg(ce,scrreg,reg);      /* MOV scrreg,msreg     */
                    if (tym == TYdouble || tym == TYdouble_alias)
                        gen2(ce,0xD1,modregrm(3,4,scrreg)); /* SHL scrreg,1     */
                }
            }
            else
            {
                ce = genmovreg(ce,scrreg,reg);  /* MOV scrreg,msreg     */
                if (tym == TYfloat)
                    gen2(ce,0xD1,modregrm(3,4,scrreg)); /* SHL scrreg,1 */
            }
            reg = findreglsw(regm);
            genorreg(ce,scrreg,reg);                    /* OR scrreg,lsreg */
        }
        else if (sz == 8)
        {       /* !I32 */
                ce = genmovreg(ce,scrreg,AX);           /* MOV scrreg,AX */
                if (tym == TYdouble || tym == TYdouble_alias)
                    gen2(ce,0xD1,modregrm(3,4,scrreg)); // SHL scrreg,1
                genorreg(ce,scrreg,BX);                 /* OR scrreg,BX */
                genorreg(ce,scrreg,CX);                 /* OR scrreg,CX */
                genorreg(ce,scrreg,DX);                 /* OR scrreg,DX */
        }
        else
            assert(0);
  }
  else
  {
        if (I32 || sz == REGSIZE * 2)
        {
            /* can't test ES:LSW for 0  */
            assert(regm & mMSW & ALLREGS && regm & (mLSW | mBP));

            reg = findregmsw(regm);
            ce = getregs(mask[reg]);            /* we're going to trash reg */
            if (tyfloating(tym) && sz == 2 * intsize)
                ce = gen2(ce,0xD1,modregrm(3,4,reg));   // SHL reg,1
            ce = genorreg(ce,reg,findreglsw(regm));     // OR reg,reg+1
            if (I64)
                code_orrex(ce, REX_W);
       }
        else if (sz == 8)
        {   assert(regm == DOUBLEREGS_16);
            ce = getregs(mAX);                          // allocate AX
            if (tym == TYdouble || tym == TYdouble_alias)
                ce = gen2(ce,0xD1,modregrm(3,4,AX));    // SHL AX,1
            genorreg(ce,AX,BX);                         // OR AX,BX
            genorreg(ce,AX,CX);                         // OR AX,CX
            genorreg(ce,AX,DX);                         // OR AX,DX
        }
        else
            assert(0);
  }
  code_orflag(ce,CFpsw);
  return ce;
}


/******************************
 * Given the result of an expression is in retregs,
 * generate necessary code to return result in *pretregs.
 */

code *fixresult(elem *e,regm_t retregs,regm_t *pretregs)
{ code *c,*ce;
  unsigned reg,rreg;
  regm_t forccs,forregs;
  tym_t tym;
  int sz;

  //printf("fixresult(e = %p, retregs = %s, *pretregs = %s)\n",e,regm_str(retregs),regm_str(*pretregs));
  if (*pretregs == 0) return CNIL;      /* if don't want result         */
  assert(e && retregs);                 /* need something to work with  */
  forccs = *pretregs & mPSW;
  forregs = *pretregs & (mST01 | mST0 | mBP | ALLREGS | mES | mSTACK | XMMREGS);
  tym = tybasic(e->Ety);
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
  c = CNIL;
  sz = tysize[tym];
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
                c = gen2(c,0x84,modregrm(3,reg | 4,reg | 4));   // TEST regH,regH
            forccs = 0;
        }
  }
  if ((retregs & forregs) == retregs)   /* if already in right registers */
        *pretregs = retregs;
  else if (forregs)             /* if return the result in registers    */
  {
        if (forregs & (mST01 | mST0))
            return fixresult87(e,retregs,pretregs);
        ce = CNIL;
        unsigned opsflag = FALSE;
        if (I16 && sz == 8)
        {   if (forregs & mSTACK)
            {   assert(retregs == DOUBLEREGS_16);
                /* Push floating regs   */
                c = CNIL;
                ce = gen1(ce,0x50 + AX);
                gen1(ce,0x50 + BX);
                gen1(ce,0x50 + CX);
                gen1(ce,0x50 + DX);
                stackpush += DOUBLESIZE;
            }
            else if (retregs & mSTACK)
            {   assert(forregs == DOUBLEREGS_16);
                /* Pop floating regs    */
                c = getregs(forregs);
                ce = gen1(ce,0x58 + DX);
                gen1(ce,0x58 + CX);
                gen1(ce,0x58 + BX);
                gen1(ce,0x58 + AX);
                stackpush -= DOUBLESIZE;
                retregs = DOUBLEREGS_16; /* for tstresult() below       */
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
            c = allocreg(pretregs,&rreg,tym); /* allocate return regs   */
            if (retregs & XMMREGS)
            {
                reg = findreg(retregs & XMMREGS);
                // MOVSD floatreg, XMM?
                ce = genfltreg(ce,xmmstore(tym),reg - XMM0,0);
                if (mask[rreg] & XMMREGS)
                    // MOVSD XMM?, floatreg
                    ce = genfltreg(ce,xmmload(tym),rreg - XMM0,0);
                else
                {
                    // MOV rreg,floatreg
                    ce = genfltreg(ce,0x8B,rreg,0);
                    if (sz == 8)
                    {
                        if (I32)
                        {
                            rreg = findregmsw(*pretregs);
                            ce = genfltreg(ce,0x8B,rreg,4);
                        }
                        else
                            code_orrex(ce,REX_W);
                    }
                }
            }
            else if (forregs & XMMREGS)
            {
                reg = findreg(retregs & (mBP | ALLREGS));
                // MOV floatreg,reg
                ce = genfltreg(ce,0x89,reg,0);
                if (sz == 8)
                {
                    if (I32)
                    {
                        reg = findregmsw(retregs);
                        ce = genfltreg(ce,0x89,reg,4);
                    }
                    else
                        code_orrex(ce,REX_W);
                }
                // MOVSS/MOVSD XMMreg,floatreg
                ce = genfltreg(ce,xmmload(tym),rreg - XMM0,0);
            }
            else if (sz > REGSIZE)
            {
                unsigned msreg = findregmsw(retregs);
                unsigned lsreg = findreglsw(retregs);
                unsigned msrreg = findregmsw(*pretregs);
                unsigned lsrreg = findreglsw(*pretregs);

                ce = genmovreg(ce,msrreg,msreg); /* MOV msrreg,msreg    */
                ce = genmovreg(ce,lsrreg,lsreg); /* MOV lsrreg,lsreg    */
            }
            else
            {
                assert(!(retregs & XMMREGS));
                assert(!(forregs & XMMREGS));
                reg = findreg(retregs & (mBP | ALLREGS));
                ce = genmovreg(ce,rreg,reg);    /* MOV rreg,reg         */
            }
        }
        c = cat(c,ce);
        cssave(e,retregs | *pretregs,opsflag);
        // Commented out due to Bugzilla 8840
        //forregs = 0;    // don't care about result in reg cuz real result is in rreg
        retregs = *pretregs & ~mPSW;
  }
  if (forccs)                           /* if return result in flags    */
        c = cat(c,tstresult(retregs,tym,forregs));
  return c;
}


/********************************
 * Generate code sequence to call C runtime library support routine.
 *      clib = CLIBxxxx
 *      keepmask = mask of registers not to destroy. Currently can
 *              handle only 1. Should use a temporary rather than
 *              push/pop for speed.
 */

int clib_inited = 0;            // != 0 if initialized

code *callclib(elem *e,unsigned clib,regm_t *pretregs,regm_t keepmask)
{
    //printf("callclib(e = %p, clib = %d, *pretregs = %s, keepmask = %s\n", e, clib, regm_str(*pretregs), regm_str(keepmask));
    //elem_print(e);
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
  static symbol lib[] =
  {
/* Convert destroyed regs into saved regs       */
#define Z(desregs)      (~(desregs) & (mBP| mES | ALLREGS))
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define N(name) "_" name
#else
#define N(name) name
#endif

/* Shorthand to map onto SYMBOLY()              */
#define Y(desregs,name)  SYMBOLY(FLfunc,Z(desregs),N(name),0)

    Y(0,"_LCMP__"),                     // CLIBlcmp
    Y(mAX|mCX|mDX,"_LMUL__"),           // CLIBlmul
#if 1
    Y(mAX|mBX|mCX|mDX,"_LDIV__"),       // CLIBldiv
    Y(mAX|mBX|mCX|mDX,"_LDIV__"),       // CLIBlmod
    Y(mAX|mBX|mCX|mDX,"_ULDIV__"),      // CLIBuldiv
    Y(mAX|mBX|mCX|mDX,"_ULDIV__"),      // CLIBulmod
#else
    Y(ALLREGS,"_LDIV__"),               // CLIBldiv
    Y(ALLREGS,"_LDIV__"),               // CLIBlmod
    Y(ALLREGS,"_ULDIV__"),              // CLIBuldiv
    Y(ALLREGS,"_ULDIV__"),              // CLIBulmod
#endif
#if 0
    Y(DOUBLEREGS_16,"_DNEG"),
    Y(mAX|mBX|mCX|mDX,"_DMUL"),         // CLIBdmul
    Y(mAX|mBX|mCX|mDX,"_DDIV"),         // CLIBddiv
    Y(0,"_DTST0"),                      // CLIBdtst0
    Y(0,"_DTST0EXC"),                   // CLIBdtst0exc
    Y(0,"_DCMP"),                       // CLIBdcmp
    Y(0,"_DCMPEXC"),                    // CLIBdcmpexc

    Y(mAX|mBX|mCX|mDX,"_DADD"),         // CLIBdadd
    Y(mAX|mBX|mCX|mDX,"_DSUB"),         // CLIBdsub

    Y(mAX|mBX|mCX|mDX,"_FMUL"),         // CLIBfmul
    Y(mAX|mBX|mCX|mDX,"_FDIV"),         // CLIBfdiv
    Y(0,"_FTST0"),                      // CLIBftst0
    Y(0,"_FTST0EXC"),                   // CLIBftst0exc
    Y(0,"_FCMP"),                       // CLIBfcmp
    Y(0,"_FCMPEXC"),                    // CLIBfcmpexc
    Y(FLOATREGS_32,"_FNEG"),            // CLIBfneg
    Y(mAX|mBX|mCX|mDX,"_FADD"),         // CLIBfadd
    Y(mAX|mBX|mCX|mDX,"_FSUB"),         // CLIBfsub
#endif
    Y(DOUBLEREGS_32,"_DBLLNG"),         // CLIBdbllng
    Y(DOUBLEREGS_32,"_LNGDBL"),         // CLIBlngdbl
    Y(DOUBLEREGS_32,"_DBLINT"),         // CLIBdblint
    Y(DOUBLEREGS_32,"_INTDBL"),         // CLIBintdbl
    Y(DOUBLEREGS_32,"_DBLUNS"),         // CLIBdbluns
    Y(DOUBLEREGS_32,"_UNSDBL"),         // CLIBunsdbl
    Y(mAX|mST0,"_DBLULNG"),             // CLIBdblulng
#if 0
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _ULNGDBL@    ulngdbl
#endif
    Y(DOUBLEREGS_32,"_DBLFLT"),         // CLIBdblflt
    Y(DOUBLEREGS_32,"_FLTDBL"),         // CLIBfltdbl

    Y(DOUBLEREGS_32,"_DBLLLNG"),        // CLIBdblllng
    Y(DOUBLEREGS_32,"_LLNGDBL"),        // CLIBllngdbl
    Y(DOUBLEREGS_32,"_DBLULLNG"),       // CLIBdblullng
    Y(DOUBLEREGS_32,"_ULLNGDBL"),       // CLIBullngdbl

    Y(0,"_DTST"),                       // CLIBdtst
    Y(mES|mBX,"_HTOFPTR"),              // CLIBvptrfptr
    Y(mES|mBX,"_HCTOFPTR"),             // CLIBcvptrfptr
    Y(0,"_87TOPSW"),                    // CLIB87topsw
    Y(mST0,"_FLTTO87"),                 // CLIBfltto87
    Y(mST0,"_DBLTO87"),                 // CLIBdblto87
    Y(mST0|mAX,"_DBLINT87"),            // CLIBdblint87
    Y(mST0|mAX|mDX,"_DBLLNG87"),        // CLIBdbllng87
    Y(0,"_FTST"),                       // CLIBftst
    Y(0,"_FCOMPP"),                     // CLIBfcompp
    Y(0,"_FTEST"),                      // CLIBftest
    Y(0,"_FTEST0"),                     // CLIBftest0
    Y(mST0|mAX|mBX|mCX|mDX,"_FDIVP"),   // CLIBfdiv87

    Y(mST0|mST01,"Cmul"),               // CLIBcmul
    Y(mAX|mCX|mDX|mST0|mST01,"Cdiv"),   // CLIBcdiv
    Y(mAX|mST0|mST01,"Ccmp"),           // CLIBccmp

    Y(mST0,"_U64_LDBL"),                // CLIBu64_ldbl
#if ELFOBJ || MACHOBJ
    Y(mST0|mAX|mDX,"_LDBLULLNG"),       // CLIBld_u64
#else
    Y(mST0|mAX|mDX,"__LDBLULLNG"),      // CLIBld_u64
#endif
  };
  static symbol clibldiv2  = Y(mAX|mBX|mCX|mDX,"_LDIV2__");
  static symbol clibuldiv2 = Y(mAX|mBX|mCX|mDX,"_ULDIV2__");

  static symbol clibldiv3  = Y(mAX|mBX|mCX|mDX,"_divdi3");
  static symbol clibuldiv3 = Y(mAX|mBX|mCX|mDX,"_udivdi3");
  static symbol cliblmod3  = Y(mAX|mBX|mCX|mDX,"_moddi3");
  static symbol clibulmod3 = Y(mAX|mBX|mCX|mDX,"_umoddi3");
#else
  static symbol lib[CLIBMAX] =
  {
/* Convert destroyed regs into saved regs       */
#define Z(desregs)      (~(desregs) & (mBP| mES | ALLREGS))

/* Shorthand to map onto SYMBOLY()              */
#define Y(desregs,name)  SYMBOLY(FLfunc,Z(desregs),name,0)

    Y(0,"_LCMP@"),
    Y(mAX|mCX|mDX,"_LMUL@"),
    Y(ALLREGS,"_LDIV@"),
    Y(ALLREGS,"_LDIV@"),
    Y(ALLREGS,"_ULDIV@"),
    Y(ALLREGS,"_ULDIV@"),
    Y(mAX|mBX|mCX|mDX,"_DMUL@"),
    Y(mAX|mBX|mCX|mDX,"_DDIV@"),
    Y(0,"_DTST0@"),
    Y(0,"_DTST0EXC@"),
    Y(0,"_DCMP@"),
    Y(0,"_DCMPEXC@"),

    /* _DNEG@ only really destroys EDX, but then EAX would hold */
    /* 2 values, and we can't handle that.                      */

    /* _DNEG@ only really destroys AX, but then BX,CX,DX would hold     */
    /* 2 values, and we can't handle that.                              */

    Y(DOUBLEREGS_16,"_DNEG@"),
    Y(mAX|mBX|mCX|mDX,"_DADD@"),
    Y(mAX|mBX|mCX|mDX,"_DSUB@"),

    Y(mAX|mBX|mCX|mDX,"_FMUL@"),
    Y(mAX|mBX|mCX|mDX,"_FDIV@"),
    Y(0,"_FTST0@"),
    Y(0,"_FTST0EXC@"),
    Y(0,"_FCMP@"),
    Y(0,"_FCMPEXC@"),
    Y(FLOATREGS_16,"_FNEG@"),
    Y(mAX|mBX|mCX|mDX,"_FADD@"),
    Y(mAX|mBX|mCX|mDX,"_FSUB@"),
    Y(DOUBLEREGS_16,"_DBLLNG@"),
    Y(DOUBLEREGS_16,"_LNGDBL@"),
    Y(DOUBLEREGS_16,"_DBLINT@"),
    Y(DOUBLEREGS_16,"_INTDBL@"),
    Y(DOUBLEREGS_16,"_DBLUNS@"),
    Y(DOUBLEREGS_16,"_UNSDBL@"),
    Y(DOUBLEREGS_16,"_DBLULNG@"),
    Y(DOUBLEREGS_16,"_ULNGDBL@"),
    Y(DOUBLEREGS_16,"_DBLFLT@"),
    Y(ALLREGS,"_FLTDBL@"),

    Y(DOUBLEREGS_16,"_DBLLLNG@"),
    Y(DOUBLEREGS_16,"_LLNGDBL@"),
#if 0
    Y(DOUBLEREGS_16,"__DBLULLNG"),
#else
    Y(DOUBLEREGS_16,"_DBLULLNG@"),
#endif
    Y(DOUBLEREGS_16,"_ULLNGDBL@"),

    Y(0,"_DTST@"),
    Y(mES|mBX,"_HTOFPTR@"),             // CLIBvptrfptr
    Y(mES|mBX,"_HCTOFPTR@"),            // CLIBcvptrfptr
    Y(0,"_87TOPSW@"),                   // CLIB87topsw
    Y(mST0,"_FLTTO87@"),                // CLIBfltto87
    Y(mST0,"_DBLTO87@"),                // CLIBdblto87
    Y(mST0|mAX,"_DBLINT87@"),           // CLIBdblint87
    Y(mST0|mAX|mDX,"_DBLLNG87@"),       // CLIBdbllng87
    Y(0,"_FTST@"),
    Y(0,"_FCOMPP@"),                    // CLIBfcompp
    Y(0,"_FTEST@"),                     // CLIBftest
    Y(0,"_FTEST0@"),                    // CLIBftest0
    Y(mST0|mAX|mBX|mCX|mDX,"_FDIVP"),   // CLIBfdiv87

    // NOTE: desregs is wrong for 16 bit code, mBX should be included
    Y(mST0|mST01,"_Cmul"),              // CLIBcmul
    Y(mAX|mCX|mDX|mST0|mST01,"_Cdiv"),  // CLIBcdiv
    Y(mAX|mST0|mST01,"_Ccmp"),          // CLIBccmp

    Y(mST0,"_U64_LDBL"),                // CLIBu64_ldbl
    Y(mST0|mAX|mDX,"__LDBLULLNG"),      // CLIBld_u64


    Y(DOUBLEREGS_32,"__DBLULLNG"),      // CLIBdblullng_win64
    Y(DOUBLEREGS_32,"__ULLNGDBL"),      // CLIBullngdbl_win64
  };
#endif

  static struct
  {
    regm_t retregs16;   /* registers that 16 bit result is returned in  */
    regm_t retregs32;   /* registers that 32 bit result is returned in  */
    char pop;           /* # of bytes popped off of stack upon return   */
    char flags;
        #define INF32           1       // if 32 bit only
        #define INFfloat        2       // if this is floating point
        #define INFwkdone       4       // if weak extern is already done
        #define INF64           8       // if 64 bit only
    char push87;                        // # of pushes onto the 8087 stack
    char pop87;                         // # of pops off of the 8087 stack
  } info[CLIBMAX] =
  {
    {0,0,0,0},                          /* _LCMP@       lcmp    */
    {mDX|mAX,mDX|mAX,0,0},              // _LMUL@       lmul
    {mDX|mAX,mDX|mAX,0,0},              // _LDIV@       ldiv
    {mCX|mBX,mCX|mBX,0,0},              /* _LDIV@       lmod    */
    {mDX|mAX,mDX|mAX,0,0},              /* _ULDIV@      uldiv   */
    {mCX|mBX,mCX|mBX,0,0},              /* _ULDIV@      ulmod   */

#if TARGET_WINDOS
    {DOUBLEREGS_16,DOUBLEREGS_32,8,INFfloat,1,1},       // _DMUL@       dmul
    {DOUBLEREGS_16,DOUBLEREGS_32,8,INFfloat,1,1},       // _DDIV@       ddiv
    {0,0,0,2},                                          // _DTST0@
    {0,0,0,2},                                          // _DTST0EXC@
    {0,0,8,INFfloat,1,1},                               // _DCMP@       dcmp
    {0,0,8,INFfloat,1,1},                               // _DCMPEXC@    dcmp
    {DOUBLEREGS_16,DOUBLEREGS_32,0,2},                  // _DNEG@       dneg
    {DOUBLEREGS_16,DOUBLEREGS_32,8,INFfloat,1,1},       // _DADD@       dadd
    {DOUBLEREGS_16,DOUBLEREGS_32,8,INFfloat,1,1},       // _DSUB@       dsub

    {FLOATREGS_16,FLOATREGS_32,0,INFfloat,1,1},         // _FMUL@       fmul
    {FLOATREGS_16,FLOATREGS_32,0,INFfloat,1,1},         // _FDIV@       fdiv
    {0,0,0,2},                                          // _FTST0@
    {0,0,0,2},                                          // _FTST0EXC@
    {0,0,0,INFfloat,1,1},                               // _FCMP@       fcmp
    {0,0,0,INFfloat,1,1},                               // _FCMPEXC@    fcmp
    {FLOATREGS_16,FLOATREGS_32,0,2},                    // _FNEG@       fneg
    {FLOATREGS_16,FLOATREGS_32,0,INFfloat,1,1},         // _FADD@       fadd
    {FLOATREGS_16,FLOATREGS_32,0,INFfloat,1,1},         // _FSUB@       fsub
#endif

    {mDX|mAX,mAX,0,INFfloat,1,1},                       // _DBLLNG@     dbllng
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _LNGDBL@     lngdbl
    {mAX,mAX,0,INFfloat,1,1},                           // _DBLINT@     dblint
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _INTDBL@     intdbl
    {mAX,mAX,0,INFfloat,1,1},                           // _DBLUNS@     dbluns
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _UNSDBL@     unsdbl
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    {mDX|mAX,mAX,0,INF32|INFfloat,0,1},                 // _DBLULNG@    dblulng
#else
    {mDX|mAX,mAX,0,INFfloat,1,1},                       // _DBLULNG@    dblulng
#endif
#if TARGET_WINDOS
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _ULNGDBL@    ulngdbl
#endif
    {FLOATREGS_16,FLOATREGS_32,0,INFfloat,1,1},         // _DBLFLT@     dblflt
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _FLTDBL@     fltdbl

    {DOUBLEREGS_16,mDX|mAX,0,INFfloat,1,1},             // _DBLLLNG@
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _LLNGDBL@
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    {DOUBLEREGS_16,mDX|mAX,0,INFfloat,2,2},             // _DBLULLNG@
#else
    {DOUBLEREGS_16,mDX|mAX,0,INFfloat,1,1},             // _DBLULLNG@
#endif
    {DOUBLEREGS_16,DOUBLEREGS_32,0,INFfloat,1,1},       // _ULLNGDBL@

    {0,0,0,2},                          // _DTST@       dtst
    {mES|mBX,mES|mBX,0,0},              // _HTOFPTR@    vptrfptr
    {mES|mBX,mES|mBX,0,0},              // _HCTOFPTR@   cvptrfptr
    {0,0,0,2},                          // _87TOPSW@    87topsw
    {mST0,mST0,0,INFfloat,1,0},         // _FLTTO87@    fltto87
    {mST0,mST0,0,INFfloat,1,0},         // _DBLTO87@    dblto87
    {mAX,mAX,0,2},                      // _DBLINT87@   dblint87
    {mDX|mAX,mAX,0,2},                  // _DBLLNG87@   dbllng87
    {0,0,0,2},                          // _FTST@
    {mPSW,mPSW,0,INFfloat,0,2},         // _FCOMPP@
    {mPSW,mPSW,0,2},                    // _FTEST@
    {mPSW,mPSW,0,2},                    // _FTEST0@
    {mST0,mST0,0,INFfloat,1,1},         // _FDIV@

    {mST01,mST01,0,INF32|INFfloat,3,5}, // _Cmul
    {mST01,mST01,0,INF32|INFfloat,0,2}, // _Cdiv
    {mPSW, mPSW, 0,INF32|INFfloat,0,4}, // _Ccmp

    {mST0,mST0,0,INF32|INF64|INFfloat,2,1},   // _U64_LDBL
    {0,mDX|mAX,0,INF32|INF64|INFfloat,1,2},   // __LDBLULLNG

#if TARGET_WINDOS
    {0,mAX,0,INFfloat,2,2},                   // __DBLULLNG   CLIBdblullng_win64
    {0,mAX,0,INFfloat,1,1},                   // __ULLNGDBL   CLIBullngdbl_win64
#endif
  };

  if (!clib_inited)                             /* if not initialized   */
  {
        assert(sizeof(lib) / sizeof(lib[0]) == CLIBMAX);
        assert(sizeof(info) / sizeof(info[0]) == CLIBMAX);
        for (int i = 0; i < CLIBMAX; i++)
        {   lib[i].Stype = tsclib;
#if MARS
            lib[i].Sxtrnnum = 0;
            lib[i].Stypidx = 0;
#endif
        }
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        clibldiv2.Stype = tsclib;
        clibuldiv2.Stype = tsclib;
        clibldiv3.Stype = tsclib;
        clibuldiv3.Stype = tsclib;
        cliblmod3.Stype = tsclib;
        clibulmod3.Stype = tsclib;
#if MARS
        clibldiv2.Sxtrnnum = 0;
        clibldiv2.Stypidx = 0;

        clibuldiv2.Sxtrnnum = 0;
        clibuldiv2.Stypidx = 0;

        clibldiv3.Sxtrnnum = 0;
        clibldiv3.Stypidx = 0;

        clibuldiv3.Sxtrnnum = 0;
        clibuldiv3.Stypidx = 0;

        cliblmod3.Sxtrnnum = 0;
        cliblmod3.Stypidx = 0;

        clibulmod3.Sxtrnnum = 0;
        clibulmod3.Stypidx = 0;
#endif
#endif
        if (!I16)
        {   /* Adjust table for 386     */
            lib[CLIBdbllng].Sregsaved  = Z(DOUBLEREGS_32);
            lib[CLIBlngdbl].Sregsaved  = Z(DOUBLEREGS_32);
            lib[CLIBdblint].Sregsaved  = Z(DOUBLEREGS_32);
            lib[CLIBintdbl].Sregsaved  = Z(DOUBLEREGS_32);
#if TARGET_WINDOS
            lib[CLIBfneg].Sregsaved    = Z(FLOATREGS_32);
            lib[CLIBdneg].Sregsaved    = Z(DOUBLEREGS_32);
            lib[CLIBdbluns].Sregsaved  = Z(DOUBLEREGS_32);
            lib[CLIBunsdbl].Sregsaved  = Z(DOUBLEREGS_32);
            lib[CLIBdblulng].Sregsaved = Z(DOUBLEREGS_32);
            lib[CLIBulngdbl].Sregsaved = Z(DOUBLEREGS_32);
#endif
            lib[CLIBdblflt].Sregsaved  = Z(DOUBLEREGS_32);
            lib[CLIBfltdbl].Sregsaved  = Z(DOUBLEREGS_32);

            lib[CLIBdblllng].Sregsaved = Z(DOUBLEREGS_32);
            lib[CLIBllngdbl].Sregsaved = Z(DOUBLEREGS_32);
            lib[CLIBdblullng].Sregsaved = Z(DOUBLEREGS_32);
            lib[CLIBullngdbl].Sregsaved = Z(DOUBLEREGS_32);

            if (I64)
            {
                info[CLIBullngdbl].retregs32 = mAX;
                info[CLIBdblullng].retregs32 = mAX;
            }
            else if (config.objfmt == OBJ_MSCOFF)
            {
                strcpy(lib[CLIBldiv].Sident, "_ms_alldiv");
                strcpy(lib[CLIBlmod].Sident, "_ms_allrem");   info[CLIBlmod].retregs32 = mAX|mDX;
                strcpy(lib[CLIBuldiv].Sident, "_ms_aulldiv");
                strcpy(lib[CLIBulmod].Sident, "_ms_aullrem"); info[CLIBulmod].retregs32 = mAX|mDX;
            }
        }
        clib_inited++;
  }
#undef Z

  assert(clib < CLIBMAX);
#if TARGET_WINDOS
  if (config.exe == EX_WIN64)
  {
        switch (clib)
        {
            case CLIBdblullng:  clib = CLIBdblullng_win64; break;
            case CLIBullngdbl:  clib = CLIBullngdbl_win64; break;
            case CLIBu64_ldbl:  assert(0); break;
        }
  }
#endif
  symbol *s = &lib[clib];
  if (I16)
        assert(!(info[clib].flags & (INF32 | INF64)));
  code *cpop = CNIL;
  code *c = getregs((~s->Sregsaved & (mES | mBP | ALLREGS)) & ~keepmask); // mask of regs destroyed
  keepmask &= ~s->Sregsaved;
    int npushed = numbitsset(keepmask);
    gensaverestore2(keepmask, &c, &cpop);
#if 0
  while (keepmask)
  {     unsigned keepreg;

        if (keepmask & (mBP|ALLREGS))
        {       keepreg = findreg(keepmask & (mBP|ALLREGS));
                c = gen1(c,0x50 + keepreg);             /* PUSH keepreg */
                cpop = cat(gen1(CNIL,0x58 + keepreg),cpop);     // POP keepreg
                keepmask &= ~mask[keepreg];
                npushed++;
        }
        if (keepmask & mES)
        {       c = gen1(c,0x06);                       /* PUSH ES      */
                cpop = cat(gen1(CNIL,0x07),cpop);       /* POP ES       */
                keepmask &= ~mES;
                npushed++;
        }
  }
#endif

    c = cat(c, save87regs(info[clib].push87));
    for (int i = 0; i < info[clib].push87; i++)
        c = cat(c, push87());

    for (int i = 0; i < info[clib].pop87; i++)
        pop87();

  if (config.target_cpu >= TARGET_80386 && clib == CLIBlmul && !I32)
  {     static char lmul[] = {
            0x66,0xc1,0xe1,0x10,        // shl  ECX,16
            0x8b,0xcb,                  // mov  CX,BX           ;ECX = CX,BX
            0x66,0xc1,0xe0,0x10,        // shl  EAX,16
            0x66,0x0f,0xac,0xd0,0x10,   // shrd EAX,EDX,16      ;EAX = DX,AX
            0x66,0xf7,0xe1,             // mul  ECX
            0x66,0x0f,0xa4,0xc2,0x10,   // shld EDX,EAX,16      ;DX,AX = EAX
        };

        c = genasm(c,lmul,sizeof(lmul));
  }
  else
  {
        code *cgot = NULL;
        bool pushebx = false;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        if (I32)
        {
            /* Pass EBX on the stack instead, this is because EBX is used
             * for shared library function calls
             */
            if (config.flags3 & CFG3pic)
            {
                cgot = load_localgot();     // EBX gets set to this value
            }
#if TARGET_LINUX || TARGET_FREEBSD
            switch (clib)
            {
                case CLIBldiv:
                    s = &clibldiv3;
                    pushebx = true;
                    break;
                case CLIBlmod:
                    s = &cliblmod3;
                    pushebx = true;
                    info[clib].retregs32 = mAX|mDX;
                    break;
                case CLIBuldiv:
                    s = &clibuldiv3;
                    pushebx = true;
                    break;
                case CLIBulmod:
                    s = &clibulmod3;
                    pushebx = true;
                    info[clib].retregs32 = mAX|mDX;
                    break;
            }
#else
            switch (clib)
            {   // EBX is a parameter to these, so push it on the stack before load_localgot()
                case CLIBldiv:
                case CLIBlmod:
                    s = &clibldiv2;
                    pushebx = true;
                    break;
                case CLIBuldiv:
                case CLIBulmod:
                    s = &clibuldiv2;
                    pushebx = true;
                    break;
            }
#endif
        }
#endif
        makeitextern(s);
        int nalign = 0;
        if (STACKALIGN == 16)
        {   // Align the stack (assume no args on stack)
            int npush = (npushed + pushebx) * REGSIZE + stackpush;
            if (npush & (STACKALIGN - 1))
            {   nalign = STACKALIGN - (npush & (STACKALIGN - 1));
                c = cod3_stackadj(c, nalign);
            }
        }
        if (pushebx)
        {
#if TARGET_LINUX || TARGET_FREEBSD
            c = gen1(c, 0x50 + CX);                             // PUSH ECX
            c = gen1(c, 0x50 + BX);                             // PUSH EBX
            c = gen1(c, 0x50 + DX);                             // PUSH EDX
            c = gen1(c, 0x50 + AX);                             // PUSH EAX
            nalign += 4 * REGSIZE;
#else
            c = gen1(c, 0x50 + BX);                             // PUSH EBX
            nalign += REGSIZE;
#endif
        }
        c = cat(c, cgot);                                       // EBX = localgot
        c = gencs(c,(LARGECODE) ? 0x9A : 0xE8,0,FLfunc,s);      // CALL s
        if (nalign)
            c = cod3_stackadj(c, -nalign);
        calledafunc = 1;

#if SCPP & TX86
        if (I16 &&                                   // bug in Optlink for weak references
            config.flags3 & CFG3wkfloat &&
            (info[clib].flags & (INFfloat | INFwkdone)) == INFfloat)
        {   info[clib].flags |= INFwkdone;
            makeitextern(rtlsym[RTLSYM_INTONLY]);
            objmod->wkext(s,rtlsym[RTLSYM_INTONLY]);
        }
#endif
    }
    if (I16)
        stackpush -= info[clib].pop;
    regm_t retregs = I16 ? info[clib].retregs16 : info[clib].retregs32;
    return cat(cat(c,cpop),fixresult(e,retregs,pretregs));
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

code *cdfunc(elem *e,regm_t *pretregs)
{
    //printf("cdfunc()\n"); elem_print(e);
    assert(e);
    unsigned numpara = 0;
    unsigned numalign = 0;
    unsigned stackpushsave = stackpush;            // so we can compute # of parameters
    cgstate.stackclean++;
    code *c = CNIL;
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

    /* Special handling for call to __tls_get_addr, we must save registers
     * before evaluating the parameter, so that the parameter load and call
     * are adjacent.
     */
    if (np == 1 && e->E1->Eoper == OPvar)
    {   symbol *s = e->E1->EV.sp.Vsym;
        if (s == tls_get_addr_sym)
            c = getregs(~s->Sregsaved & (mBP | ALLREGS | mES | XMMREGS));
    }

    unsigned stackalign = REGSIZE;
#if TARGET_SEGMENTED
    if (tyf == TYf16func)
        stackalign = 2;
#endif
    // Figure out which parameters go in registers.
    // Compute numpara, the total bytes pushed on the stack
    FuncParamRegs fpr(tyf);
    for (int i = np; --i >= 0;)
    {
        elem *ep = parameters[i].e;
        unsigned psize = paramsize(ep, stackalign);
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

    /* Adjust start of the stack so after all args are pushed,
     * the stack will be aligned.
     */
    if (STACKALIGN == 16 && (numpara + stackpush) & (STACKALIGN - 1))
    {
        numalign = STACKALIGN - ((numpara + stackpush) & (STACKALIGN - 1));
        c = cod3_stackadj(c, numalign);
        c = genadjesp(c, numalign);
        stackpush += numalign;
        stackpushsave += numalign;
    }
    assert(stackpush == stackpushsave);
    if (config.exe == EX_WIN64)
    {
        //printf("np = %d, numpara = %d, stackpush = %d\n", np, numpara, stackpush);
        assert(numpara == ((np < 4) ? 4 * REGSIZE : np * REGSIZE));
    }

    int regsaved[XMM7 + 1];
    memset(regsaved, -1, sizeof(regsaved));
    code *crest = NULL;
    regm_t saved = 0;

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
            code *csave = NULL;
            regm_t overlap = msavereg & keepmsk;
            msavereg |= keepmsk;
            code *cp = params(ep,stackalign);
            regm_t tosave = keepmsk & ~msavereg;
            msavereg &= ~keepmsk | overlap;

            // tosave is the mask to save and restore
            for (int j = 0; tosave; j++)
            {   regm_t mi = mask[j];
                assert(j <= XMM7);
                if (mi & tosave)
                {
                    unsigned idx;
                    csave = regsave.save(csave, j, &idx);
                    crest = regsave.restore(crest, j, idx);
                    saved |= mi;
                    keepmsk &= ~mi;             // don't need to keep these for rest of params
                    tosave &= ~mi;
                }
            }

            c = cat4(c, csave, cp, NULL);

            // Alignment for parameter comes after it got pushed
            unsigned numalign = parameters[i].numalign;
            if (numalign)
            {
                c = cod3_stackadj(c, numalign);
                c = genadjesp(c, numalign);
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

                code *csave = NULL;
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
                            csave = regsave.save(csave, j, &idx);
                            crest = regsave.restore(crest, j, idx);
                            saved |= mi;
                            keepmsk &= ~mi;             // don't need to keep these for rest of params
                            tosave &= ~mi;
                        }
                    }
                }

                code *cp = scodelem(ep,&retregs,keepmsk,FALSE);

                // Move result [mreg,lreg] into parameter registers from [preg2,preg]
                retregs = 0;
                if (preg != lreg)
                    retregs |= mask[preg];
                if (preg2 != mreg)
                    retregs |= mask[preg2];
                code *c1 = getregs(retregs);

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
                                c1 = gen2(c1,op,modregxrmx(3,preg-XMM0,lreg-XMM0));
                            }
                            else
                                c1 = genmovreg(c1, preg, lreg);
                        }
                    }
                    else
                    {
                        if (preg2 != mreg)
                        {
                            if (mask[preg2] & XMMREGS)
                            {   unsigned op = xmmload(ty2);            // MOVSS/D preg2,mreg
                                c1 = gen2(c1,op,modregxrmx(3,preg2-XMM0,mreg-XMM0));
                            }
                            else
                                c1 = genmovreg(c1, preg2, mreg);
                        }
                    }
                }

                c = cat4(c,csave,cp,c1);
                retregs = mask[preg] | mask[preg2];
            }
            else if (ep->Eoper == OPstrthis)
            {
                code *c1 = getregs(retregs);
                // LEA preg,np[RSP]
                unsigned np = stackpush - ep->EV.Vuns;   // stack delta to parameter
                code *c2 = genc1(CNIL,LEA,
                        (modregrm(0,4,SP) << 8) | modregxrm(2,preg,4), FLconst,np);
                if (I64)
                    code_orrex(c2, REX_W);
                c = cat3(c,c1,c2);
            }
            else if (ep->Eoper == OPstrpar && config.exe == EX_WIN64 && type_size(ep->ET) == 0)
            {
            }
            else
            {
                code *cp = scodelem(ep,&retregs,keepmsk,FALSE);
                c = cat(c,cp);
            }
            keepmsk |= retregs;      // don't change preg when evaluating func address
        }
    }

    if (config.exe == EX_WIN64)
    {   // Allocate stack space for four entries anyway
        // http://msdn.microsoft.com/en-US/library/ew5tede7(v=vs.80)
        {   unsigned sz = 4 * REGSIZE;
            c = cod3_stackadj(c, sz);
            c = genadjesp(c, sz);
            stackpush += sz;
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
                code *c1 = getregs(mask[reg]);
                c1 = gen2(c1,STOD,(REX_W << 16) | modregxrmx(3,preg-XMM0,reg)); // MOVD reg,preg
                c = cat(c,c1);
            }
        }
    }

    // Restore any register parameters we saved
    c = cat4(c, getregs(saved), crest, NULL);
    keepmsk |= saved;

    // Variadic functions store the number of XMM registers used in AL
    if (I64 && config.exe != EX_WIN64 && e->Eflags & EFLAGS_variadic)
    {   code *c1 = getregs(mAX);
        c1 = movregconst(c1,AX,xmmcnt,1);
        c = cat(c, c1);
        keepmsk |= mAX;
    }

    cgstate.stackclean--;

#ifdef DEBUG
    if (numpara != stackpush - stackpushsave)
    {
        printf("function %s\n", funcsym_p->Sident);
        printf("numpara = %d, stackpush = %d, stackpushsave = %d\n", numpara, stackpush, stackpushsave);
        elem_print(e);
    }
#endif
    assert(numpara == stackpush - stackpushsave);

    return cat(c,funccall(e,numpara,numalign,pretregs,keepmsk));
}

/***********************************
 */

code *cdstrthis(elem *e,regm_t *pretregs)
{
    code *c1;
    code *c2;

    assert(tysize(e->Ety) == REGSIZE);
    unsigned reg = findreg(*pretregs & allregs);
    c1 = getregs(mask[reg]);
    // LEA reg,np[ESP]
    unsigned np = stackpush - e->EV.Vuns;        // stack delta to parameter
    c2 = genc1(CNIL,0x8D,(modregrm(0,4,SP) << 8) | modregxrm(2,reg,4),FLconst,np);
    if (I64)
        code_orrex(c2, REX_W);
    return cat3(c1,c2,fixresult(e,mask[reg],pretregs));
}

/******************************
 * Call function. All parameters are pushed onto the stack, numpara gives
 * the size of them all.
 */

STATIC code * funccall(elem *e,unsigned numpara,unsigned numalign,regm_t *pretregs,regm_t keepmsk)
{
    elem *e1;
    code *c,*ce,cs;
    tym_t tym1;
    char farfunc;
    regm_t retregs;
    symbol *s;

    //printf("funccall(e = %p, *pretregs = %s, numpara = %d, numalign = %d)\n",e,regm_str(*pretregs),numpara,numalign);
    calledafunc = 1;
    /* Determine if we need frame for function prolog/epilog    */
#if TARGET_WINDOS
    if (config.memmodel == Vmodel)
    {
        if (tyfarfunc(funcsym_p->ty()))
            needframe = TRUE;
    }
#endif
    e1 = e->E1;
    tym1 = tybasic(e1->Ety);
    farfunc = tyfarfunc(tym1) || tym1 == TYifunc;
    c = NULL;
    if (e1->Eoper == OPvar)
    {   /* Call function directly       */
        code *c1;

        if (!tyfunc(tym1))
            WRTYxx(tym1);
        assert(tyfunc(tym1));
        s = e1->EV.sp.Vsym;
        if (s->Sflags & SFLexit)
            c = NULL;
        else if (s != tls_get_addr_sym)
            c = save87();               // assume 8087 regs are all trashed
        if (s->Sflags & SFLexit)
            // Function doesn't return, so don't worry about registers
            // it may use
            c1 = NULL;
        else if (!tyfunc(s->ty()) || !(config.flags4 & CFG4optimized))
            // so we can replace func at runtime
            c1 = getregs(~fregsaved & (mBP | ALLREGS | mES | XMMREGS));
        else
            c1 = getregs(~s->Sregsaved & (mBP | ALLREGS | mES | XMMREGS));
        if (strcmp(s->Sident,"alloca") == 0)
        {
#if 1
            s = rtlsym[RTLSYM_ALLOCA];
            makeitextern(s);
            int areg = CX;
            if (config.exe == EX_WIN64)
                areg = DX;
            c1 = cat(c1,getregs(mask[areg]));
            c1 = genc(c1,0x8D,modregrm(2,areg,BPRM),FLallocatmp,0,0,0);  // LEA areg,&localsize[BP]
            if (I64)
                code_orrex(c1, REX_W);
            usedalloca = 2;             // new way
#else
            usedalloca = 1;             // old way
#endif
        }
        if (sytab[s->Sclass] & SCSS)    // if function is on stack (!)
        {
            retregs = allregs & ~keepmsk;
            s->Sflags &= ~GTregcand;
            s->Sflags |= SFLread;
            ce = cat(c1,cdrelconst(e1,&retregs));
#if TARGET_SEGMENTED
            if (farfunc)
            {
                unsigned reg = findregmsw(retregs);
                unsigned lsreg = findreglsw(retregs);
                floatreg = TRUE;                /* use float register   */
                reflocal = TRUE;
                ce = genc1(ce,0x89,             /* MOV floatreg+2,reg   */
                        modregrm(2,reg,BPRM),FLfltreg,REGSIZE);
                genc1(ce,0x89,                  /* MOV floatreg,lsreg   */
                        modregrm(2,lsreg,BPRM),FLfltreg,0);
                if (tym1 == TYifunc)
                    gen1(ce,0x9C);              // PUSHF
                genc1(ce,0xFF,                  /* CALL [floatreg]      */
                        modregrm(2,3,BPRM),FLfltreg,0);
            }
            else
#endif
            {
                unsigned reg = findreg(retregs);
                ce = gen2(ce,0xFF,modregrmx(3,2,reg));   /* CALL reg     */
                if (I64)
                    code_orrex(ce, REX_W);
            }
        }
        else
        {   int fl;

            fl = FLfunc;
            if (!tyfunc(s->ty()))
                fl = el_fl(e1);
            if (tym1 == TYifunc)
                c1 = gen1(c1,0x9C);                             // PUSHF
            ce = CNIL;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            if (s != tls_get_addr_sym)
            {
                //printf("call %s\n", s->Sident);
                ce = load_localgot();
            }
#endif
            ce = gencs(ce,farfunc ? 0x9A : 0xE8,0,fl,s);      // CALL extern
            code_orflag(ce, farfunc ? (CFseg | CFoff) : (CFselfrel | CFoff));
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            if (s == tls_get_addr_sym)
            {
                if (I64)
                {
                    /* Prepend 66 66 48 so GNU linker has patch room
                     */
                    ce->Irex = REX | REX_W;
                    ce = cat(gen1(CNIL, 0x66), ce);
                    ce = cat(gen1(CNIL, 0x66), ce);
                }
            }
#endif
        }
        ce = cat(c1,ce);
  }
  else
  {     /* Call function via pointer    */

        if (e1->Eoper != OPind) { WRFL((enum FL)el_fl(e1)); WROP(e1->Eoper); }
        c = save87();                   // assume 8087 regs are all trashed
        assert(e1->Eoper == OPind);
        elem *e11 = e1->E1;
        tym_t e11ty = tybasic(e11->Ety);
#if TARGET_SEGMENTED
        assert(!I16 || (e11ty == (farfunc ? TYfptr : TYnptr)));
#else
        assert(!I16 || (e11ty == TYnptr));
#endif
        c = cat(c, load_localgot());
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        if (config.flags3 & CFG3pic && I32)
            keepmsk |= mBX;
#endif

        /* Mask of registers destroyed by the function call
         */
        regm_t desmsk = (mBP | ALLREGS | mES | XMMREGS) & ~fregsaved;

        /* if we can't use loadea()     */
        if ((EOP(e11) || e11->Eoper == OPconst) &&
            (e11->Eoper != OPind || e11->Ecount))
        {
            retregs = allregs & ~keepmsk;
            cgstate.stackclean++;
            ce = scodelem(e11,&retregs,keepmsk,TRUE);
            cgstate.stackclean--;
            /* Kill registers destroyed by an arbitrary function call */
            ce = cat(ce,getregs(desmsk));
#if TARGET_SEGMENTED
            if (e11ty == TYfptr)
            {
                unsigned reg = findregmsw(retregs);
                unsigned lsreg = findreglsw(retregs);
                floatreg = TRUE;                /* use float register   */
                reflocal = TRUE;
                ce = genc1(ce,0x89,             /* MOV floatreg+2,reg   */
                        modregrm(2,reg,BPRM),FLfltreg,REGSIZE);
                genc1(ce,0x89,                  /* MOV floatreg,lsreg   */
                        modregrm(2,lsreg,BPRM),FLfltreg,0);
                if (tym1 == TYifunc)
                    gen1(ce,0x9C);              // PUSHF
                genc1(ce,0xFF,                  /* CALL [floatreg]      */
                        modregrm(2,3,BPRM),FLfltreg,0);
            }
            else
#endif
            {
                unsigned reg = findreg(retregs);
                ce = gen2(ce,0xFF,modregrmx(3,2,reg));   /* CALL reg     */
                if (I64)
                    code_orrex(ce, REX_W);
            }
        }
        else
        {
            if (tym1 == TYifunc)
                c = gen1(c,0x9C);               // PUSHF
                                                // CALL [function]
            cs.Iflags = 0;
            cgstate.stackclean++;
            ce = loadea(e11,&cs,0xFF,farfunc ? 3 : 2,0,keepmsk,desmsk);
            cgstate.stackclean--;
            freenode(e11);
        }
        s = NULL;
  }
  c = cat(c,ce);
  freenode(e1);

  /* See if we will need the frame pointer.
     Calculate it here so we can possibly use BP to fix the stack.
   */
#if 0
  if (!needframe)
  {     SYMIDX si;

        /* If there is a register available for this basic block        */
        if (config.flags4 & CFG4optimized && (ALLREGS & ~regcon.used))
            ;
        else
        {
            for (si = 0; si < globsym.top; si++)
            {   symbol *s = globsym.tab[si];

                if (s->Sflags & GTregcand && type_size(s->Stype) != 0)
                {
                    if (config.flags4 & CFG4optimized)
                    {   /* If symbol is live in this basic block and    */
                        /* isn't already in a register                  */
                        if (s->Srange && vec_testbit(dfoidx,s->Srange) &&
                            s->Sfl != FLreg)
                        {   /* Then symbol must be allocated on stack */
                            needframe = TRUE;
                            break;
                        }
                    }
                    else
                    {   if (mfuncreg == 0)      /* if no registers left */
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

    // If stack needs cleanup
    if ((OTbinary(e->Eoper) || config.exe == EX_WIN64) &&
        (!typfunc(tym1) || config.exe == EX_WIN64) &&
      !(s && s->Sflags & SFLexit))
    {
        if (tym1 == TYhfunc)
        {   // Hidden parameter is popped off by the callee
            c = genadjesp(c, -REGSIZE);
            stackpush -= REGSIZE;
            if (numpara + numalign > REGSIZE)
                c = genstackclean(c, numpara + numalign - REGSIZE, retregs);
        }
        else
            c = genstackclean(c,numpara + numalign,retregs);
    }
    else
    {
        c = genadjesp(c,-numpara);
        stackpush -= numpara;
        if (numalign)
            c = genstackclean(c,numalign,retregs);
    }

    /* Special handling for functions which return a floating point
       value in the top of the 8087 stack.
     */

    if (retregs & mST0)
    {
        c = genadjfpu(c, 1);
        if (*pretregs)                  // if we want the result
        {   //assert(stackused == 0);
            push87();                   // one item on 8087 stack
            return cat(c,fixresult87(e,retregs,pretregs));
        }
        else
            /* Pop unused result off 8087 stack */
            c = gen2(c,0xDD,modregrm(3,3,0));           /* FPOP         */
    }
    else if (retregs & mST01)
    {
        c = genadjfpu(c, 2);
        if (*pretregs)                  // if we want the result
        {   assert(stackused == 0);
            push87();
            push87();                   // two items on 8087 stack
            return cat(c,fixresult_complex87(e,retregs,pretregs));
        }
        else
        {
            // Pop unused result off 8087 stack
            c = gen2(c,0xDD,modregrm(3,3,0));           // FPOP
            c = gen2(c,0xDD,modregrm(3,3,0));           // FPOP
        }
    }

    return cat(c,fixresult(e,retregs,pretregs));
}

/***************************
 * Determine size of everything that will be pushed.
 */

targ_size_t paramsize(elem *e,unsigned stackalign)
{
    targ_size_t psize = 0;
    targ_size_t szb;

    while (e->Eoper == OPparam)         /* if more params               */
    {
        elem *e2 = e->E2;
        psize += paramsize(e->E1,stackalign);   // push them backwards
        e = e2;
    }
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
    psize += align(stackalign,szb);     /* align on word stack boundary */
    return psize;
}

/***************************
 * Generate code to push parameter list.
 * stackpush is incremented by stackalign for each PUSH.
 */

code *params(elem *e,unsigned stackalign)
{ code *c,*ce,cs;
  code *cp;
  unsigned reg;
  targ_size_t szb;                      // size before alignment
  targ_size_t sz;                       // size after alignment
  tym_t tym;
  regm_t retregs;
  elem *e1;
  elem *e2;
  symbol *s;
  int fl;

  //printf("params(e = %p, stackalign = %d)\n", e, stackalign);
  cp = NULL;
  stackchanged = 1;
  assert(e);
  while (e->Eoper == OPparam)           /* if more params               */
  {
        e2 = e->E2;
        cp = cat(cp,params(e->E1,stackalign));  // push them backwards
        freenode(e);
        e = e2;
  }
  //printf("params()\n"); elem_print(e);

  tym = tybasic(e->Ety);
  if (tyfloating(tym))
        objmod->fltused();

  int grex = I64 ? REX_W << 16 : 0;

  /* sz = number of bytes pushed        */
  if (tyscalar(tym))
        szb = size(tym);
  else if (tym == TYstruct || tym == TYarray)
        szb = type_size(e->ET);
  else
  {
        WRTYxx(tym);
        assert(0);
  }
  sz = align(stackalign,szb);           /* align on word stack boundary */
  assert((sz & (stackalign - 1)) == 0); /* ensure that alignment worked */
  assert((sz & (REGSIZE - 1)) == 0);

  c = CNIL;
  cs.Iflags = 0;
  cs.Irex = 0;
  switch (e->Eoper)
  {
#if SCPP
    case OPstrctor:
    {
        e1 = e->E1;
        c = docommas(&e1);              /* skip over any comma expressions */

        c = cod3_stackadj(c, sz);
        stackpush += sz;
        genadjesp(c,sz);

        // Find OPstrthis and set it to stackpush
        exp2_setstrthis(e1,NULL,stackpush,NULL);

        retregs = 0;
        ce = codelem(e1,&retregs,TRUE);
        goto L2;
    }
    case OPstrthis:
        // This is the parameter for the 'this' pointer corresponding to
        // OPstrctor. We push a pointer to an object that was already
        // allocated on the stack by OPstrctor.
    {   unsigned np;

        retregs = allregs;
        c = allocreg(&retregs,&reg,TYoffset);
        c = genregs(c,0x89,SP,reg);             // MOV reg,SP
        if (I64)
            code_orrex(c, REX_W);
        np = stackpush - e->EV.Vuns;            // stack delta to parameter
        c = genc2(c,0x81,grex | modregrmx(3,0,reg),np); // ADD reg,np
        if (sz > REGSIZE)
        {   c = gen1(c,0x16);                   // PUSH SS
            stackpush += REGSIZE;
        }
        c = gen1(c,0x50 + (reg & 7));           // PUSH reg
        if (reg & 8)
            code_orrex(c, REX_B);
        stackpush += REGSIZE;
        genadjesp(c,sz);
        ce = CNIL;
        goto L2;
    }
#endif
    case OPstrpar:
        {       code *cc,*c1,*c2,*c3;
                unsigned rm;
                unsigned seg;           // segment override prefix flags
                bool doneoff;
                unsigned pushsize = REGSIZE;
                unsigned op16 = 0;
                unsigned npushes;

                e1 = e->E1;
                if (sz == 0)
                {
                    ce = docommas(&e1); /* skip over any commas         */
                    goto L2;
                }
                if ((sz & 3) == 0 && (sz / REGSIZE) <= 4 && e1->Eoper == OPvar)
                {   freenode(e);
                    e = e1;
                    goto L1;
                }
                cc = docommas(&e1);     /* skip over any commas         */
                seg = 0;                /* assume no seg override       */
                retregs = sz ? IDXREGS : 0;
                doneoff = FALSE;
                if (!I16 && sz & 2)     // if odd number of words to push
                {   pushsize = 2;
                    op16 = 1;
                }
                else if (I16 && config.target_cpu >= TARGET_80386 && (sz & 3) == 0)
                {   pushsize = 4;       // push DWORDs at a time
                    op16 = 1;
                }
                npushes = sz / pushsize;
                switch (e1->Eoper)
                {   case OPind:
#if TARGET_SEGMENTED
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
#endif
                        c1 = codelem(e1->E1,&retregs,FALSE);
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
                        {   static unsigned segtocf[4] = { CFes,CFcs,CFss,0 };
                            unsigned s;
                            int fl;

                            fl = el_fl(e1);
#if TARGET_SEGMENTED
                            if (fl == FLfardata)
                            {   seg = CFes;
                                retregs |= mES;
                            }
                            else
#endif
                            {
                                s = segfl[fl];
                                assert(s < 4);
                                seg = segtocf[s];
                                if (seg == CFss && !(config.wflags & WFssneds))
                                    seg = 0;
                            }
                        }
#if TARGET_SEGMENTED
                        if (e1->Ety & mTYfar)
                        {   seg = CFes;
                            retregs |= mES;
                        }
#endif
                        c1 = cdrelconst(e1,&retregs);
                        /* Reverse the effect of the previous add       */
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
                        c1 = codelem(e1,&retregs,FALSE);
                        break;
                    default:
                        elem_print(e1);
                        assert(0);
                }
                reg = findreglsw(retregs);
                rm = I16 ? regtorm[reg] : regtorm32[reg];
                if (op16)
                    seg |= CFopsize;            // operand size
                if (npushes <= 4)
                {
                    assert(!doneoff);
                    for (c2 = CNIL; npushes > 1; npushes--)
                    {   c2 = genc1(c2,0xFF,buildModregrm(2,6,rm),FLconst,pushsize * (npushes - 1));  // PUSH [reg]
                        code_orflag(c2,seg);
                        genadjesp(c2,pushsize);
                    }
                    c3 = gen2(CNIL,0xFF,buildModregrm(0,6,rm));     // PUSH [reg]
                    c3->Iflags |= seg;
                    genadjesp(c3,pushsize);
                    ce = cat4(cc,c1,c2,c3);
                }
                else if (sz)
                {   int size;

                    c2 = getregs_imm(mCX | retregs);
                                                        /* MOV CX,sz/2  */
                    c2 = movregconst(c2,CX,npushes,0);
                    if (!doneoff)
                    {   /* This disgusting thing should be done when    */
                        /* reg is loaded. Too lazy to fix it now.       */
                                                        /* ADD reg,sz-2 */
                        c2 = genc2(c2,0x81,grex | modregrmx(3,0,reg),sz-pushsize);
                    }
                    c3 = getregs(mCX);                                  // the LOOP decrements it
                    c3 = gen2(c3,0xFF,buildModregrm(0,6,rm));           // PUSH [reg]
                    c3->Iflags |= seg | CFtarg2;
                    genc2(c3,0x81,grex | buildModregrm(3,5,reg),pushsize);  // SUB reg,2
                    size = ((seg & CFSEG) ? -8 : -7) - op16;
                    if (code_next(c3)->Iop != 0x81)
                        size++;
                    //genc2(c3,0xE2,0,size);    // LOOP .-7 or .-8
                    genjmp(c3,0xE2,FLcode,(block *)c3);         // LOOP c3
                    regimmed_set(CX,0);
                    genadjesp(c3,sz);
                    ce = cat4(cc,c1,c2,c3);
                }
                else
                    ce = cat(cc,c1);
                stackpush += sz;
                goto L2;
        }
    case OPind:
        if (!e->Ecount)                         /* if *e1       */
        {       if (sz <= REGSIZE)
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
                if (I32)
                {
                    assert(sz >= REGSIZE * 2);
                    ce = loadea(e,&cs,0xFF,6,sz - REGSIZE,0,0); /* PUSH EA+4 */
                    ce = genadjesp(ce,REGSIZE);
                    stackpush += REGSIZE;
                    sz -= REGSIZE;

                    if (sz > REGSIZE)
                    {
                        while (sz)
                        {
                            cs.IEVoffset1 -= REGSIZE;
                            ce = gen(ce,&cs);                    // PUSH EA+...
                            ce = genadjesp(ce,REGSIZE);
                            stackpush += REGSIZE;
                            sz -= REGSIZE;
                        }
                        goto L2;
                    }
                }
                else
                {
                    if (sz == DOUBLESIZE)
                    {   ce = loadea(e,&cs,0xFF,6,DOUBLESIZE - REGSIZE,0,0); /* PUSH EA+6        */
                        cs.IEVoffset1 -= REGSIZE;
                        gen(ce,&cs);                    /* PUSH EA+4    */
                        ce = genadjesp(ce,REGSIZE);
                        getlvalue_lsw(&cs);
                        gen(ce,&cs);                    /* PUSH EA+2    */
                    }
                    else /* TYlong */
                        ce = loadea(e,&cs,0xFF,6,REGSIZE,0,0); /* PUSH EA+2 */
                    ce = genadjesp(ce,REGSIZE);
                }
                stackpush += sz;
                getlvalue_lsw(&cs);
                gen(ce,&cs);                            /* PUSH EA      */
                ce = genadjesp(ce,REGSIZE);
                goto L2;
        }
        break;
#if TARGET_SEGMENTED
    case OPnp_fp:
        if (!e->Ecount)                         /* if (far *)e1 */
        {
            int segreg;
            tym_t tym1;

            e1 = e->E1;
            tym1 = tybasic(e1->Ety);
            /* BUG: what about pointers to functions?   */
            switch (tym1)
            {
                case TYnptr: segreg = 3<<3; break;
                case TYcptr: segreg = 1<<3; break;
                default:     segreg = 2<<3; break;
            }
            if (I32 && stackalign == 2)
                c = gen1(c,0x66);               /* push a word          */
            c = gen1(c,0x06 + segreg);          /* PUSH SEGREG          */
            if (I32 && stackalign == 2)
                code_orflag(c,CFopsize);        // push a word
            c = genadjesp(c,stackalign);
            stackpush += stackalign;
            ce = params(e1,stackalign);
            goto L2;
        }
        break;
#endif
    case OPrelconst:
#if TARGET_SEGMENTED
        /* Determine if we can just push the segment register           */
        /* Test size of type rather than TYfptr because of (long)(&v)   */
        s = e->EV.sp.Vsym;
        //if (sytab[s->Sclass] & SCSS && !I32)  // if variable is on stack
        //    needframe = TRUE;                 // then we need stack frame
        if (tysize[tym] == tysize[TYfptr] &&
            (fl = s->Sfl) != FLfardata &&
            /* not a function that CS might not be the segment of       */
            (!((fl == FLfunc || s->ty() & mTYcs) &&
              (s->Sclass == SCcomdat || s->Sclass == SCextern || s->Sclass == SCinline || config.wflags & WFthunk)) ||
             (fl == FLfunc && config.exe == EX_DOSX)
            )
           )
        {
            stackpush += sz;
            c = gen1(c,0x06 +           /* PUSH SEGREG                  */
                    (((fl == FLfunc || s->ty() & mTYcs) ? 1 : segfl[fl]) << 3));
            c = genadjesp(c,REGSIZE);

            if (config.target_cpu >= TARGET_80286 && !e->Ecount)
            {   ce = getoffset(e,STACK);
                goto L2;
            }
            else
            {   c = cat(c,offsetinreg(e,&retregs));
                unsigned reg = findreg(retregs);
                c = genpush(c,reg);             // PUSH reg
                genadjesp(c,REGSIZE);
            }
            goto ret;
        }
        if (config.target_cpu >= TARGET_80286 && !e->Ecount)
        {
            stackpush += sz;
            if (tysize[tym] == tysize[TYfptr])
            {
                /* PUSH SEG e   */
                code *c1 = gencs(CNIL,0x68,0,FLextern,s);
                c1->Iflags = CFseg;
                genadjesp(c1,REGSIZE);
                c = cat(c,c1);
            }
            ce = getoffset(e,STACK);
            goto L2;
        }
#endif
        break;                          /* else must evaluate expression */
    case OPvar:
    L1:
        if (0 && I32 && sz == 2)
        {   /* 32 bit code, but pushing 16 bit values anyway    */
            ce = loadea(e,&cs,0xFF,6,0,0,0);            /* PUSH EA      */
            // BUG: 0x66 fails with scheduler
            ce = cat(gen1(CNIL,0x66),ce);               /* 16 bit override */
            stackpush += sz;
            genadjesp(ce,sz);
        }
        else if (config.flags4 & CFG4speed &&
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
        {   int regsize = REGSIZE;
            unsigned flag = 0;

            if (I16 && config.target_cpu >= TARGET_80386 && sz > 2 &&
                !e->Ecount)
            {   regsize = 4;
                flag |= CFopsize;
            }
            ce = loadea(e,&cs,0xFF,6,sz - regsize,RMload,0);    // PUSH EA+sz-2
            code_orflag(ce,flag);
            ce = genadjesp(ce,REGSIZE);
            stackpush += sz;
            while ((targ_int)(sz -= regsize) > 0)
            {   ce = cat(ce,loadea(e,&cs,0xFF,6,sz - regsize,RMload,0));
                code_orflag(ce,flag);
                ce = genadjesp(ce,REGSIZE);
            }
        }
    L2:
        freenode(e);
        c = cat(c,ce);
        goto ret;
    case OPconst:
    {
        char pushi = 0;
        unsigned flag = 0;
        int regsize = REGSIZE;
        targ_int value;

        if (tycomplex(tym))
            break;

        if (I64 && tyfloating(tym) && sz > 4 && boolres(e))
            // Can't push 64 bit non-zero args directly
            break;

        if (I32 && szb == 10)           // special case for long double constants
        {
            assert(sz == 12);
            value = ((unsigned short *)&e->EV.Vldouble)[4];
            stackpush += sz;
            ce = genadjesp(NULL,sz);
            for (int i = 2; i >= 0; i--)
            {
                if (reghasvalue(allregs, value, &reg))
                    ce = gen1(ce,0x50 + reg);           // PUSH reg
                else
                    ce = genc2(ce,0x68,0,value);        // PUSH value
                value = ((unsigned *)&e->EV.Vldouble)[i - 1];
            }
            goto L2;
        }

        assert(I64 || sz <= LNGDBLSIZE);
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
        ce = genadjesp(NULL,sz);
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

            if (pushi)
            {
                if (I64 && regsize == 8 && value != (int)value)
                {   ce = regwithvalue(ce,allregs,value,&reg,64);
                    goto Preg;          // cannot push imm64 unless it is sign extended 32 bit value
                }
                if (regsize == REGSIZE && reghasvalue(allregs,value,&reg))
                    goto Preg;
                ce = genc2(ce,(szb == 1) ? 0x6A : 0x68,0,value); // PUSH value
            }
            else
            {
                ce = regwithvalue(ce,allregs,value,&reg,0);
            Preg:
                ce = genpush(ce,reg);         // PUSH reg
            }
            code_orflag(ce,flag);                       /* operand size */
        } while (i);
        goto L2;
    }
    default:
        break;
  }
  retregs = tybyte(tym) ? BYTEREGS : allregs;
  if (tyvector(tym))
  {
        retregs = XMMREGS;
        c = cat(c,codelem(e,&retregs,FALSE));
        stackpush += sz;
        c = genadjesp(c,sz);
        c = cod3_stackadj(c, sz);
        unsigned op = xmmstore(tym);
        unsigned r = findreg(retregs);
        c = gen2sib(c,op,modregxrm(0,r - XMM0,4),modregrm(0,4,SP));   // MOV [ESP],r
        goto ret;
  }
  else if (tyfloating(tym))
  {     if (config.inline8087)
        {   code *c1,*c2;
            unsigned op;
            unsigned r;

            retregs = tycomplex(tym) ? mST01 : mST0;
            c = cat(c,codelem(e,&retregs,FALSE));
            stackpush += sz;
            c = genadjesp(c,sz);
            c = cod3_stackadj(c, sz);
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
                c1 = NULL;
                c2 = NULL;
                if (tycomplex(tym))
                {
                    // FSTP sz/2[ESP]
                    c2 = genc1(CNIL,op,(modregrm(0,4,SP) << 8) | modregxrm(2,r,4),FLconst,sz/2);
                    pop87();
                }
                pop87();
                c2 = gen2sib(c2,op,modregrm(0,r,4),modregrm(0,4,SP));   // FSTP [ESP]
            }
            else
            {
                retregs = IDXREGS;                      /* get an index reg */
                c1 = allocreg(&retregs,&reg,TYoffset);
                c1 = genregs(c1,0x89,SP,reg);           /* MOV reg,SP    */
                pop87();
                c2 = gen2(CNIL,op,modregrm(0,r,regtorm[reg]));          // FSTP [reg]
            }
            if (LARGEDATA)
                c2->Iflags |= CFss;     /* want to store into stack     */
            genfwait(c2);               // FWAIT
            c = cat3(c,c1,c2);
            goto ret;
        }
        else if (I16 && (tym == TYdouble || tym == TYdouble_alias))
            retregs = mSTACK;
  }
  else if (I16 && sz == 8)             // if long long
        retregs = mSTACK;
  c = cat(c,scodelem(e,&retregs,0,TRUE));
  if (retregs != mSTACK)                /* if stackpush not already inc'd */
      stackpush += sz;
  if (sz <= REGSIZE)
  {
        c = genpush(c,findreg(retregs));        // PUSH reg
        genadjesp(c,REGSIZE);
  }
  else if (sz == REGSIZE * 2)
  {     c = genpush(c,findregmsw(retregs));     // PUSH msreg
        genpush(c,findreglsw(retregs));         // PUSH lsreg
        genadjesp(c,sz);
  }
ret:
  return cat(cp,c);
}


/*******************************
 * Get offset portion of e, and store it in an index
 * register. Return mask of index register in *pretregs.
 */

code *offsetinreg( elem *e, regm_t *pretregs)
{   regm_t retregs;
    code *c;
    unsigned reg;

    retregs = mLSW;                     /* want only offset     */
    if (e->Ecount && e->Ecount != e->Ecomsub)
    {   unsigned i;
        regm_t rm;

        rm = retregs & regcon.cse.mval & ~regcon.cse.mops & ~regcon.mvar; /* possible regs */
        for (i = 0; rm; i++)
        {       if (mask[i] & rm && regcon.cse.value[i] == e)
                {   reg = i;
                    *pretregs = mask[i];
                    c = getregs(*pretregs);
                    goto L3;
                }
                rm &= ~mask[i];
        }
    }

    *pretregs = retregs;
    c = allocreg(pretregs,&reg,TYoffset);
    c = cat(c,getoffset(e,reg));
L3:
    cssave(e,*pretregs,FALSE);
    freenode(e);
    return c;
}


/******************************
 * Generate code to load data into registers.
 */

code *loaddata(elem *e,regm_t *pretregs)
{ unsigned reg,nreg,op,sreg;
  tym_t tym;
  int sz;
  code *c,*ce,cs;
  regm_t flags,forregs,regm;

#ifdef DEBUG
  if (debugw)
        printf("loaddata(e = %p,*pretregs = %s)\n",e,regm_str(*pretregs));
  //elem_print(e);
#endif
  assert(e);
  elem_debug(e);
  if (*pretregs == 0)
        return CNIL;
  tym = tybasic(e->Ety);
  if (tym == TYstruct)
        return cdrelconst(e,pretregs);
  if (tyfloating(tym))
  {     objmod->fltused();
        if (config.inline8087)
        {   if (*pretregs & mST0)
                return load87(e,0,pretregs,NULL,-1);
            else if (tycomplex(tym))
                return cload87(e, pretregs);
        }
  }
  sz = tysize[tym];
  cs.Iflags = 0;
  cs.Irex = 0;
  if (*pretregs == mPSW)
  {
        symbol *s;
        regm = allregs;
        if (e->Eoper == OPconst)
        {       /* TRUE:        OR SP,SP        (SP is never 0)         */
                /* FALSE:       CMP SP,SP       (always equal)          */
                c = genregs(CNIL,(boolres(e)) ? 0x09 : 0x39,SP,SP);
                if (I64)
                    code_orrex(c, REX_W);
        }
        else if (e->Eoper == OPvar &&
            (s = e->EV.sp.Vsym)->Sfl == FLreg &&
            s->Sregm & XMMREGS &&
            (tym == TYfloat || tym == TYifloat || tym == TYdouble || tym ==TYidouble))
        {
            c = tstresult(s->Sregm,e->Ety,TRUE);
        }
        else if (sz <= REGSIZE)
        {
            if (!I16 && (tym == TYfloat || tym == TYifloat))
            {
                c = allocreg(&regm,&reg,TYoffset);      // get a register
                ce = loadea(e,&cs,0x8B,reg,0,0,0);      // MOV reg,data
                c = cat(c,ce);
                ce = gen2(CNIL,0xD1,modregrmx(3,4,reg)); // SHL reg,1
                c = cat(c,ce);
            }
            else if (I64 && (tym == TYdouble || tym ==TYidouble))
            {
                c = allocreg(&regm,&reg,TYoffset);  // get a register
                ce = loadea(e,&cs,0x8B,reg,0,0,0);  // MOV reg,data
                c = cat(c,ce);
                // remove sign bit, so that -0.0 == 0.0
                ce = gen2(CNIL,0xD1,modregrmx(3,4,reg)); // SHL reg,1
                code_orrex(ce, REX_W);
                c = cat(c,ce);
            }

#if TARGET_OSX
            else if (e->Eoper == OPvar && movOnly(e))
            {   c = allocreg(&regm,&reg,TYoffset);      /* get a register */
                ce = loadea(e,&cs,0x8B,reg,0,0,0);      // MOV reg,data
                c = cat(c,ce);
                ce = fixresult(e,regm,pretregs);
                c = cat(c,ce);
            }
#endif
            else
            {   cs.IFL2 = FLconst;
                cs.IEV2.Vsize_t = 0;
                op = (sz == 1) ? 0x80 : 0x81;
                c = loadea(e,&cs,op,7,0,0,0);           /* CMP EA,0     */

                // Convert to TEST instruction if EA is a register
                // (to avoid register contention on Pentium)
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
            c = allocreg(&regm,&reg,TYoffset);          /* get a register */
            if (I32)                                    // it's a 48 bit pointer
                ce = loadea(e,&cs,0x0FB7,reg,REGSIZE,0,0); /* MOVZX reg,data+4 */
            else
            {   ce = loadea(e,&cs,0x8B,reg,REGSIZE,0,0); /* MOV reg,data+2 */
                if (tym == TYfloat || tym == TYifloat)  // dump sign bit
                    gen2(ce,0xD1,modregrm(3,4,reg));    /* SHL reg,1      */
            }
            c = cat(c,ce);
            ce = loadea(e,&cs,0x0B,reg,0,regm,0);       /* OR reg,data */
            c = cat(c,ce);
        }
        else if (sz == 8 || (I64 && sz == 2 * REGSIZE && !tyfloating(tym)))
        {
            c = allocreg(&regm,&reg,TYoffset);  /* get a register */
            int i = sz - REGSIZE;
            ce = loadea(e,&cs,0x8B,reg,i,0,0);  /* MOV reg,data+6 */
            if (tyfloating(tym))                // TYdouble or TYdouble_alias
                gen2(ce,0xD1,modregrm(3,4,reg));        // SHL reg,1
            c = cat(c,ce);

            while ((i -= REGSIZE) >= 0)
            {
                code *c1 = loadea(e,&cs,0x0B,reg,i,regm,0);   // OR reg,data+i
                if (i == 0)
                    c1->Iflags |= CFpsw;                // need the flags on last OR
                c = cat(c,c1);
            }
        }
        else if (sz == tysize[TYldouble])               // TYldouble
            return load87(e,0,pretregs,NULL,-1);
        else
        {
            elem_print(e);
            assert(0);
        }
        return c;
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
        c = allocreg(&forregs,&reg,tym);        /* allocate registers   */
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
                ce = regwithvalue(CNIL,ALLREGS,value,&r,flags);
                flags = 0;                              // flags are already set
                ce = genfltreg(ce,0x89,r,0);            // MOV floatreg,r
                if (sz == 8)
                    code_orrex(ce, REX_W);
                assert(sz == 4 || sz == 8);             // float or double
                unsigned op = xmmload(tym);
                ce = genfltreg(ce,op,reg - XMM0,0);     // MOVSS/MOVSD XMMreg,floatreg
            }
            else
            {   ce = movregconst(CNIL,reg,value,flags);
                flags = 0;                          // flags are already set
            }
        }
        else if (sz < 8)        // far pointers, longs for 16 bit targets
        {
            targ_int msw,lsw;
            regm_t mswflags;

            msw = I32   ? e->EV.Vfp.Vseg
                        : (e->EV.Vulong >> 16);
            lsw = e->EV.Vfp.Voff;
            mswflags = 0;
            if (forregs & mES)
            {
                ce = movregconst(CNIL,reg,msw,0);       // MOV reg,segment
                genregs(ce,0x8E,0,reg);                 // MOV ES,reg
                msw = lsw;                              // MOV reg,offset
            }
            else
            {
                sreg = findreglsw(forregs);
                ce = movregconst(CNIL,sreg,lsw,0);
                reg = findregmsw(forregs);
                /* Decide if we need to set flags when we load msw      */
                if (flags && (msw && msw|lsw || !(msw|lsw)))
                {   mswflags = mPSW;
                    flags = 0;
                }
            }
            ce = movregconst(ce,reg,msw,mswflags);
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
                    ce = allocreg(&rm,&r,TYint);            // allocate scratch register
                    ce = movregconst(ce,r,p[0],0);
                    ce = genfltreg(ce,0x89,r,0);            // MOV floatreg,r
                    ce = movregconst(ce,r,p[1],0);
                    ce = genfltreg(ce,0x89,r,4);            // MOV floatreg+4,r

                    unsigned op = xmmload(tym);
                    ce = genfltreg(ce,op,reg - XMM0,0);     // MOVSS/MOVSD XMMreg,floatreg
                }
                else
                {
                    ce = movregconst(CNIL,findreglsw(forregs),p[0],0);
                    ce = movregconst(ce,findregmsw(forregs),p[1],0);
                }
            }
            else
            {   targ_short *p = (targ_short *) &e->EV.Vdouble;

                assert(reg == AX);
                ce = movregconst(CNIL,AX,p[3],0);       /* MOV AX,p[3]  */
                ce = movregconst(ce,DX,p[0],0);
                ce = movregconst(ce,CX,p[1],0);
                ce = movregconst(ce,BX,p[2],0);
            }
        }
        else if (I64 && sz == 16)
        {
            ce = movregconst(CNIL,findreglsw(forregs),e->EV.Vcent.lsw,0);
            ce = movregconst(ce,findregmsw(forregs),e->EV.Vcent.msw,0);
        }
        else
            assert(0);
        c = cat(c,ce);
  }
  else
  {
    // See if we can use register that parameter was passed in
    if (regcon.params &&
        (e->EV.sp.Vsym->Sclass == SCfastpar || e->EV.sp.Vsym->Sclass == SCshadowreg) &&
        regcon.params & mask[e->EV.sp.Vsym->Spreg] &&
        !(e->Eoper == OPvar && e->EV.sp.Voffset > 0) && // Must be at the base of that variable
        sz <= REGSIZE)                  // make sure no 'paint' to a larger size happened
    {
        reg = e->EV.sp.Vsym->Spreg;
        forregs = mask[reg];
#ifdef DEBUG
        if (debugr)
            printf("%s is fastpar and using register %s\n", e->EV.sp.Vsym->Sident, regm_str(forregs));
#endif
        mfuncreg &= ~forregs;
        regcon.used |= forregs;
        return fixresult(e,forregs,pretregs);
    }

    c = allocreg(&forregs,&reg,tym);            /* allocate registers   */

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
            c = cat(c,loadea(e,&cs,op,reg,0,0,0));    // MOV regL,data
        else
        {   nregm = tyuns(tym) ? BYTEREGS : mAX;
            if (*pretregs & nregm)
                nreg = reg;                     /* already allocated    */
            else
                c = cat(c,allocreg(&nregm,&nreg,tym));
            ce = loadea(e,&cs,op,nreg,0,0,0); /* MOV nregL,data       */
            c = cat(c,ce);
            if (reg != nreg)
            {   genmovreg(c,reg,nreg);          /* MOV reg,nreg         */
                cssave(e,mask[nreg],FALSE);
            }
        }
    }
    else if (forregs & XMMREGS)
    {
        // Can't load from registers directly to XMM regs
        //e->EV.sp.Vsym->Sflags &= ~GTregcand;

        op = xmmload(tym);
        if (e->Eoper == OPvar)
        {   symbol *s = e->EV.sp.Vsym;
            if (s->Sfl == FLreg && !(mask[s->Sreglsw] & XMMREGS))
            {   op = LODD;          // MOVD/MOVQ
                /* getlvalue() will unwind this and unregister s; could use a better solution */
            }
        }
        ce = loadea(e,&cs,op,reg,0,RMload,0); // MOVSS/MOVSD reg,data
        c = cat(c,ce);
    }
    else if (sz <= REGSIZE)
    {
        ce = loadea(e,&cs,0x8B,reg,0,RMload,0); // MOV reg,data
        c = cat(c,ce);
    }
    else if (sz <= 2 * REGSIZE && forregs & mES)
    {
        ce = loadea(e,&cs,0xC4,reg,0,0,mES);    /* LES data             */
        c = cat(c,ce);
    }
    else if (sz <= 2 * REGSIZE)
    {
        if (I32 && sz == 8 &&
            (*pretregs & (mSTACK | mPSW)) == mSTACK)
        {   int i;

            assert(0);
            /* Note that we allocreg(DOUBLEREGS) needlessly     */
            stackchanged = 1;
            i = DOUBLESIZE - REGSIZE;
            do
            {   c = cat(c,loadea(e,&cs,0xFF,6,i,0,0)); /* PUSH EA+i     */
                c = genadjesp(c,REGSIZE);
                stackpush += REGSIZE;
                i -= REGSIZE;
            }
            while (i >= 0);
            return c;
        }

        reg = findregmsw(forregs);
        ce = loadea(e,&cs,0x8B,reg,REGSIZE,forregs,0); /* MOV reg,data+2 */
        if (I32 && sz == REGSIZE + 2)
            ce->Iflags |= CFopsize;                     /* seg is 16 bits */
        c = cat(c,ce);
        reg = findreglsw(forregs);
        ce = loadea(e,&cs,0x8B,reg,0,forregs,0);        // MOV reg,data
        c = cat(c,ce);
    }
    else if (sz >= 8)
    {
        code *c1,*c2,*c3;

        assert(!I32);
        if ((*pretregs & (mSTACK | mPSW)) == mSTACK)
        {   int i;

            /* Note that we allocreg(DOUBLEREGS) needlessly     */
            stackchanged = 1;
            i = sz - REGSIZE;
            do
            {   c = cat(c,loadea(e,&cs,0xFF,6,i,0,0)); /* PUSH EA+i     */
                c = genadjesp(c,REGSIZE);
                stackpush += REGSIZE;
                i -= REGSIZE;
            }
            while (i >= 0);
            return c;
        }
        else
        {
            assert(reg == AX);
            ce = loadea(e,&cs,0x8B,AX,6,0,0);           /* MOV AX,data+6 */
            c1 = loadea(e,&cs,0x8B,BX,4,mAX,0);         /* MOV BX,data+4 */
            c2 = loadea(e,&cs,0x8B,CX,2,mAX|mBX,0);     /* MOV CX,data+2 */
            c3 = loadea(e,&cs,0x8B,DX,0,mAX|mCX|mCX,0); /* MOV DX,data  */
            c = cat6(c,ce,c1,c2,c3,CNIL);
        }
    }
    else
        assert(0);
  }
  /* Flags may already be set   */
  *pretregs &= flags | ~mPSW;
  c = cat(c,fixresult(e,forregs,pretregs));
  return c;
}

#endif // SPP
