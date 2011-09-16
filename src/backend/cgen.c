// Copyright (C) 1985-1998 by Symantec
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

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "global.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*************************************
 * Handy function to answer the question: who the heck is generating this piece of code?
 */
inline void ccheck(code *cs)
{
//    if (cs->Iop == LEA && (cs->Irm & 0x3F) == 0x34 && cs->Isib == 7) *(char*)0=0;
//    if (cs->Iop == 0x31) *(char*)0=0;
//    if (cs->Iop == 0x8A && cs->Irm == 0xF6) *(char*)0=0;
}

/*****************************
 * Find last code in list.
 */

code *code_last(code *c)
{
    if (c)
    {   while (c->next)
            c = c->next;
    }
    return c;
}

/*****************************
 * Set flag bits on last code in list.
 */

void code_orflag(code *c,unsigned flag)
{
    if (flag && c)
    {   while (c->next)
            c = c->next;
        c->Iflags |= flag;
    }
}

/*****************************
 * Set rex bits on last code in list.
 */

void code_orrex(code *c,unsigned rex)
{
    if (rex && c)
    {   while (c->next)
            c = c->next;
        c->Irex |= rex;
    }
}

/**************************************
 * Set the opcode fields in cs.
 */
code *setOpcode(code *c, code *cs, unsigned op)
{
    cs->Iop = op;
    return c;
}

/*****************************
 * Concatenate two code lists together. Return pointer to result.
 */

#if TX86 && __INTSIZE == 4 && __SC__
__declspec(naked) code * __pascal cat(code *c1,code *c2)
{
    _asm
    {
        mov     EAX,c1-4[ESP]
        mov     ECX,c2-4[ESP]
        test    EAX,EAX
        jne     L6D
        mov     EAX,ECX
        ret     8

L6D:    mov     EDX,EAX
        cmp     dword ptr [EAX],0
        je      L7B
L74:    mov     EDX,[EDX]
        cmp     dword ptr [EDX],0
        jne     L74
L7B:    mov     [EDX],ECX
        ret     8
    }
}
#else
code * __pascal cat(code *c1,code *c2)
{   code **pc;

    if (!c1)
        return c2;
    for (pc = &code_next(c1); *pc; pc = &code_next(*pc))
        ;
    *pc = c2;
    return c1;
}
#endif

code * cat3(code *c1,code *c2,code *c3)
{   code **pc;

    for (pc = &c1; *pc; pc = &code_next(*pc))
        ;
    for (*pc = c2; *pc; pc = &code_next(*pc))
        ;
    *pc = c3;
    return c1;
}

code * cat4(code *c1,code *c2,code *c3,code *c4)
{   code **pc;

    for (pc = &c1; *pc; pc = &code_next(*pc))
        ;
    for (*pc = c2; *pc; pc = &code_next(*pc))
        ;
    for (*pc = c3; *pc; pc = &code_next(*pc))
        ;
    *pc = c4;
    return c1;
}

code * cat6(code *c1,code *c2,code *c3,code *c4,code *c5,code *c6)
{ return cat(cat4(c1,c2,c3,c4),cat(c5,c6)); }

/*****************************
 * Add code to end of linked list.
 * Note that unused operands are garbage.
 * gen1() and gen2() are shortcut routines.
 * Input:
 *      c ->    linked list that code is to be added to end of
 *      cs ->   data for the code
 * Returns:
 *      pointer to start of code list
 */

code *gen(code *c,code *cs)
{   code *ce,*cstart;
    unsigned reg;

#ifdef DEBUG                            /* this is a high usage routine */
    assert(cs);
#endif
    assert(I64 || cs->Irex == 0);
    ce = code_calloc();
    *ce = *cs;
    //printf("ce = %p %02x\n", ce, ce->Iop);
    ccheck(ce);
    if (config.flags4 & CFG4optimized &&
        (ce->Iop == 0x81 || ce->Iop == 0x80) &&
        ce->IFL2 == FLconst &&
        reghasvalue((ce->Iop == 0x80) ? BYTEREGS : ALLREGS,I64 ? ce->IEV2.Vsize_t : ce->IEV2.Vlong,&reg) &&
        !(ce->Iflags & CFopsize && I16)
       )
    {   // See if we can replace immediate instruction with register instruction
        static unsigned char regop[8] =
                { 0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x38 };

        //printf("replacing 0x%02x, val = x%lx\n",ce->Iop,ce->IEV2.Vlong);
        ce->Iop = regop[(ce->Irm & modregrm(0,7,0)) >> 3] | (ce->Iop & 1);
        code_newreg(ce, reg);
    }
    code_next(ce) = CNIL;
    if (c)
    {   cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        code_next(c) = ce;                      /* link into list       */
        return cstart;
    }
    return ce;
}

code *gen1(code *c,unsigned op)
{ code *ce,*cstart;

  ce = code_calloc();
  ce->Iop = op;
  assert(op != LEA);
  if (c)
  {     cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        code_next(c) = ce;                      /* link into list       */
        return cstart;
  }
  return ce;
}

code *gen2(code *c,unsigned op,unsigned rm)
{ code *ce,*cstart;

  cstart = ce = code_calloc();
  /*cxcalloc++;*/
  ce->Iop = op;
  ce->Iea = rm;
  ccheck(ce);
  if (c)
  {     cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        code_next(c) = ce;                      /* link into list       */
  }
  return cstart;
}

code *gen2sib(code *c,unsigned op,unsigned rm,unsigned sib)
{ code *ce,*cstart;

  cstart = ce = code_calloc();
  /*cxcalloc++;*/
  ce->Iop = op;
  ce->Irm = rm;
  ce->Isib = sib;
  ce->Irex = (rm | (sib & (REX_B << 16))) >> 16;
  if (sib & (REX_R << 16))
        ce->Irex |= REX_X;
  ccheck(ce);
  if (c)
  {     cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        code_next(c) = ce;                      /* link into list       */
  }
  return cstart;
}

/********************************
 * Generate an ASM sequence.
 */

code *genasm(code *c,char *s,unsigned slen)
{   code *ce;

    ce = code_calloc();
    ce->Iop = ASM;
    ce->IFL1 = FLasm;
    ce->IEV1.as.len = slen;
    ce->IEV1.as.bytes = (char *) mem_malloc(slen);
    memcpy(ce->IEV1.as.bytes,s,slen);
    return cat(c,ce);
}

code *gencs(code *c,unsigned op,unsigned ea,unsigned FL2,symbol *s)
{   code cs;

    cs.Iop = op;
    cs.Iea = ea;
    ccheck(&cs);
    cs.Iflags = 0;
    cs.IFL2 = FL2;
    cs.IEVsym2 = s;
    cs.IEVoffset2 = 0;

    return gen(c,&cs);
}

code *genc2(code *c,unsigned op,unsigned ea,targ_size_t EV2)
{   code cs;

    cs.Iop = op;
    cs.Iea = ea;
    ccheck(&cs);
    cs.Iflags = CFoff;
    cs.IFL2 = FLconst;
    cs.IEV2.Vsize_t = EV2;
    return gen(c,&cs);
}

/*****************
 * Generate code.
 */

code *genc1(code *c,unsigned op,unsigned ea,unsigned FL1,targ_size_t EV1)
{   code cs;

    assert(FL1 < FLMAX);
    cs.Iop = op;
    cs.Iflags = CFoff;
    cs.Iea = ea;
    ccheck(&cs);
    cs.IFL1 = FL1;
    cs.IEV1.Vsize_t = EV1;
    return gen(c,&cs);
}

/*****************
 * Generate code.
 */

code *genc(code *c,unsigned op,unsigned ea,unsigned FL1,targ_size_t EV1,unsigned FL2,targ_size_t EV2)
{   code cs;

    assert(FL1 < FLMAX);
    cs.Iop = op;
    cs.Iea = ea;
    ccheck(&cs);
    cs.Iflags = CFoff;
    cs.IFL1 = FL1;
    cs.IEV1.Vsize_t = EV1;
    assert(FL2 < FLMAX);
    cs.IFL2 = FL2;
    cs.IEV2.Vsize_t = EV2;
    return gen(c,&cs);
}

/********************************
 * Generate 'instruction' which is actually a line number.
 */

code *genlinnum(code *c,Srcpos srcpos)
{   code cs;

#if 0
    srcpos.print("genlinnum");
#endif
    cs.Iop = ESCAPE | ESClinnum;
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = 0;
    cs.IFL2 = 0;
    cs.IEV1.Vsrcpos = srcpos;
    return gen(c,&cs);
}

/******************************
 * Append line number to existing code.
 */

void cgen_linnum(code **pc,Srcpos srcpos)
{
    *pc = genlinnum(*pc,srcpos);
}

/*****************************
 * Prepend line number to existing code.
 */

void cgen_prelinnum(code **pc,Srcpos srcpos)
{
    *pc = cat(genlinnum(NULL,srcpos),*pc);
}

/********************************
 * Generate 'instruction' which tells the address resolver that the stack has
 * changed.
 */

code *genadjesp(code *c, int offset)
{   code cs;

    if (!I16 && offset)
    {
        cs.Iop = ESCAPE | ESCadjesp;
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IEV1.Vint = offset;
        return gen(c,&cs);
    }
    else
        return c;
}

/********************************
 * Generate 'instruction' which tells the scheduler that the fpu stack has
 * changed.
 */

code *genadjfpu(code *c, int offset)
{   code cs;

    if (!I16 && offset)
    {
        cs.Iop = ESCAPE | ESCadjfpu;
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IEV1.Vint = offset;
        return gen(c,&cs);
    }
    else
        return c;
}

/********************************
 * Generate 'nop'
 */

code *gennop(code *c)
{
    return gen1(c,NOP);
}


/****************************************
 * Clean stack after call to codelem().
 */

code *gencodelem(code *c,elem *e,regm_t *pretregs,bool constflag)
{
    if (e)
    {
        unsigned stackpushsave;
        int stackcleansave;

        stackpushsave = stackpush;
        stackcleansave = cgstate.stackclean;
        cgstate.stackclean = 0;                         // defer cleaning of stack
        c = cat(c,codelem(e,pretregs,constflag));
        assert(cgstate.stackclean == 0);
        cgstate.stackclean = stackcleansave;
        c = genstackclean(c,stackpush - stackpushsave,*pretregs);       // do defered cleaning
    }
    return c;
}

/**********************************
 * Determine if one of the registers in regm has value in it.
 * If so, return !=0 and set *preg to which register it is.
 */

bool reghasvalue(regm_t regm,targ_size_t value,unsigned *preg)
{
    //printf("reghasvalue(%s, %llx)\n", regm_str(regm), (unsigned long long)value);
    /* See if another register has the right value      */
    unsigned r = 0;
    for (regm_t mreg = regcon.immed.mval; mreg; mreg >>= 1)
    {
        if (mreg & regm & 1 && regcon.immed.value[r] == value)
        {   *preg = r;
            return TRUE;
        }
        r++;
        regm >>= 1;
    }
    return FALSE;
}

/**************************************
 * Load a register from the mask regm with value.
 * Output:
 *      *preg   the register selected
 */

code *regwithvalue(code *c,regm_t regm,targ_size_t value,unsigned *preg,regm_t flags)
{   unsigned reg;

    if (!preg)
        preg = &reg;

    /* If we don't already have a register with the right value in it   */
    if (!reghasvalue(regm,value,preg))
    {   regm_t save;

        save = regcon.immed.mval;
        c = cat(c,allocreg(&regm,preg,TYint));  // allocate register
        regcon.immed.mval = save;
        c = movregconst(c,*preg,value,flags);   // store value into reg
    }
    return c;
}

/*************************************************
 * Allocate register temporaries
 */

void REGSAVE::reset()
{
    off = 0;
    top = 0;
    idx = 0;
    alignment = REGSIZE;
}

code *REGSAVE::save(code *c, int reg, unsigned *pidx)
{
    unsigned i;
    if (reg >= XMM0)
    {
        alignment = 16;
        idx = (idx + 15) & ~15;
        i = idx;
        idx += 16;
        // MOVD idx[RBP],xmm
        c = genc1(c,0xF20F11,modregxrm(2, reg - XMM0, BPRM),FLregsave,(targ_uns) i);
    }
    else
    {
        if (!alignment)
            alignment = REGSIZE;
        i = idx;
        idx += REGSIZE;
        // MOV idx[RBP],reg
        c = genc1(c,0x89,modregxrm(2, reg, BPRM),FLregsave,(targ_uns) i);
        if (I64)
            code_orrex(c, REX_W);
    }
    reflocal = TRUE;
    if (idx > top)
        top = idx;              // keep high water mark
    *pidx = i;
    return c;
}

code *REGSAVE::restore(code *c, int reg, unsigned idx)
{
    if (reg >= XMM0)
    {
        assert(alignment == 16);
        // MOVD xmm,idx[RBP]
        c = genc1(c,0xF20F10,modregxrm(2, reg - XMM0, BPRM),FLregsave,(targ_uns) idx);
    }
    else
    {   // MOV reg,idx[RBP]
        c = genc1(c,0x8B,modregxrm(2, reg, BPRM),FLregsave,(targ_uns) idx);
        if (I64)
            code_orrex(c, REX_W);
    }
    return c;
}


#endif // !SPP
