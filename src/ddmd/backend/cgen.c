/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cgen.c
 */

#if !SPP

#include        <stdio.h>
#include        <stdlib.h>
#include        <string.h>
#include        <time.h>
#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "global.h"
#include        "aa.h"
#include        "dt.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*********************************
 */
CodeBuilder::CodeBuilder(code *c)
{
    head = c;
    pTail = c ? &code_last(c)->next : &head;
}

/*************************************
 * Handy function to answer the question: who the heck is generating this piece of code?
 */
inline void ccheck(code *cs)
{
//    if (cs->Iop == LEA && (cs->Irm & 0x3F) == 0x34 && cs->Isib == 7) *(char*)0=0;
//    if (cs->Iop == 0x31) *(char*)0=0;
//    if (cs->Irm == 0x3D) *(char*)0=0;
//    if (cs->Iop == LEA && cs->Irm == 0xCB) *(char*)0=0;
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

#if TX86
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
#endif

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

#if TX86 && __INTSIZE == 4 && __DMC__
__declspec(naked) code *cat(code *c1,code *c2)
{
    _asm
    {
        mov     EAX,c1-4[ESP]
        mov     ECX,c2-4[ESP]
        test    EAX,EAX
        jne     L6D
        mov     EAX,ECX
        ret

L6D:    mov     EDX,EAX
        cmp     dword ptr [EAX],0
        je      L7B
L74:    mov     EDX,[EDX]
        cmp     dword ptr [EDX],0
        jne     L74
L7B:    mov     [EDX],ECX
        ret
    }
}
#else
code *cat(code *c1,code *c2)
{   code **pc;

    if (!c1)
        return c2;
    for (pc = &code_next(c1); *pc; pc = &code_next(*pc))
        ;
    *pc = c2;
    return c1;
}
#endif


/************************************
 * Concatenate code.
 */
void CodeBuilder::append(CodeBuilder& cdb)
{
    if (cdb.head)
    {
        *pTail = cdb.head;
        pTail = cdb.pTail;
    }
}

void CodeBuilder::append(CodeBuilder& cdb1, CodeBuilder& cdb2)
{
    append(cdb1);
    append(cdb2);
}

void CodeBuilder::append(CodeBuilder& cdb1, CodeBuilder& cdb2, CodeBuilder& cdb3)
{
    append(cdb1);
    append(cdb2);
    append(cdb3);
}

void CodeBuilder::append(CodeBuilder& cdb1, CodeBuilder& cdb2, CodeBuilder& cdb3, CodeBuilder& cdb4)
{
    append(cdb1);
    append(cdb2);
    append(cdb3);
    append(cdb4);
}

void CodeBuilder::append(CodeBuilder& cdb1, CodeBuilder& cdb2, CodeBuilder& cdb3, CodeBuilder& cdb4, CodeBuilder& cdb5)
{
    append(cdb1);
    append(cdb2);
    append(cdb3);
    append(cdb4);
    append(cdb5);
}

void CodeBuilder::append(code *c)
{
    if (c)
    {
        CodeBuilder cdb(c);
        append(cdb);
    }
}

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
{
#ifdef DEBUG                            /* this is a high usage routine */
    assert(cs);
#endif
#if TX86
    assert(I64 || cs->Irex == 0);
#endif
    code* ce = code_malloc();
    *ce = *cs;
    //printf("ce = %p %02x\n", ce, ce->Iop);
    ccheck(ce);
    simplify_code(ce);
    code_next(ce) = CNIL;
    if (c)
    {   code* cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        code_next(c) = ce;                      /* link into list       */
        return cstart;
    }
    return ce;
}

void CodeBuilder::gen(code *cs)
{
#ifdef DEBUG                            /* this is a high usage routine */
    assert(cs);
#endif
#if TX86
    assert(I64 || cs->Irex == 0);
#endif
    code* ce = code_malloc();
    *ce = *cs;
    //printf("ce = %p %02x\n", ce, ce->Iop);
    ccheck(ce);
    simplify_code(ce);
    code_next(ce) = CNIL;

    *pTail = ce;
    pTail = &ce->next;
}

code *gen1(code *c,unsigned op)
{ code *ce,*cstart;

  ce = code_calloc();
  ce->Iop = op;
  ccheck(ce);
#if TX86
  assert(op != LEA);
#endif
  if (c)
  {     cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        code_next(c) = ce;                      /* link into list       */
        return cstart;
  }
  return ce;
}

void CodeBuilder::gen1(unsigned op)
{
    code *ce = code_calloc();
    ce->Iop = op;
    ccheck(ce);
#if TX86
    assert(op != LEA);
#endif

    *pTail = ce;
    pTail = &ce->next;
}

#if TX86
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

void CodeBuilder::gen2(unsigned op, unsigned rm)
{
    code *ce = code_calloc();
    ce->Iop = op;
    ce->Iea = rm;
    ccheck(ce);

    *pTail = ce;
    pTail = &ce->next;
}

/***************************************
 * Generate floating point instruction.
 */

void CodeBuilder::genf2(unsigned op, unsigned rm)
{
    genfwait(*this);
    gen2(op, rm);
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

void CodeBuilder::gen2sib(unsigned op, unsigned rm, unsigned sib)
{
    code *ce = code_calloc();
    ce->Iop = op;
    ce->Irm = rm;
    ce->Isib = sib;
    ce->Irex = (rm | (sib & (REX_B << 16))) >> 16;
    if (sib & (REX_R << 16))
        ce->Irex |= REX_X;
    ccheck(ce);

    *pTail = ce;
    pTail = &ce->next;
}
#endif

/********************************
 * Generate an ASM sequence.
 */

code *genasm(code *c,unsigned char *s,unsigned slen)
{   code *ce;

    ce = code_calloc();
    ce->Iop = ASM;
    ce->IFL1 = FLasm;
    ce->IEV1.as.len = slen;
    ce->IEV1.as.bytes = (char *) mem_malloc(slen);
    memcpy(ce->IEV1.as.bytes,s,slen);
    return cat(c,ce);
}

void CodeBuilder::genasm(char *s, unsigned slen)
{
    code *ce = code_calloc();
    ce->Iop = ASM;
    ce->IFL1 = FLasm;
    ce->IEV1.as.len = slen;
    ce->IEV1.as.bytes = (char *) mem_malloc(slen);
    memcpy(ce->IEV1.as.bytes,s,slen);

    *pTail = ce;
    pTail = &ce->next;
}

void CodeBuilder::genasm(_LabelDsymbol *label)
{
    code *ce = code_calloc();
    ce->Iop = ASM;
    ce->Iflags = CFaddrsize;
    ce->IFL1 = FLblockoff;
    ce->IEVlsym1 = label;

    *pTail = ce;
    pTail = &ce->next;
}

void CodeBuilder::genasm(block *label)
{
    code *ce = code_calloc();
    ce->Iop = ASM;
    ce->Iflags = CFaddrsize;
    ce->IFL1 = FLblockoff;
    ce->IEV1.Vblock = label;
    label->Bflags |= BFLlabel;

    *pTail = ce;
    pTail = &ce->next;
}

#if TX86
code *gencs(code *c,unsigned op,unsigned ea,unsigned FL2,symbol *s)
{   code cs;

    cs.Iop = op;
    cs.Iea = ea;
    ccheck(&cs);
    cs.IFL2 = FL2;
    cs.IEVsym2 = s;
    cs.IEVoffset2 = 0;

    return gen(c,&cs);
}

void CodeBuilder::gencs(unsigned op, unsigned ea, unsigned FL2, symbol *s)
{
    code cs;
    cs.Iop = op;
    cs.Iea = ea;
    ccheck(&cs);
    cs.IFL2 = FL2;
    cs.IEVsym2 = s;
    cs.IEVoffset2 = 0;

    gen(&cs);
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

void CodeBuilder::genc2(unsigned op, unsigned ea, targ_size_t EV2)
{
    code cs;
    cs.Iop = op;
    cs.Iea = ea;
    ccheck(&cs);
    cs.Iflags = CFoff;
    cs.IFL2 = FLconst;
    cs.IEV2.Vsize_t = EV2;

    gen(&cs);
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

void CodeBuilder::genc1(unsigned op, unsigned ea, unsigned FL1, targ_size_t EV1)
{
    code cs;
    assert(FL1 < FLMAX);
    cs.Iop = op;
    cs.Iflags = CFoff;
    cs.Iea = ea;
    ccheck(&cs);
    cs.IFL1 = FL1;
    cs.IEV1.Vsize_t = EV1;

    gen(&cs);
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

void CodeBuilder::genc(unsigned op, unsigned ea, unsigned FL1, targ_size_t EV1, unsigned FL2, targ_size_t EV2)
{
    code cs;
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

    gen(&cs);
}
#endif

/********************************
 * Generate 'instruction' which is actually a line number.
 */

code *genlinnum(code *c,Srcpos srcpos)
{   code cs;

    //srcpos.print("genlinnum");
    cs.Iop = ESCAPE | ESClinnum;
    cs.IEV1.Vsrcpos = srcpos;
    return gen(c,&cs);
}

void CodeBuilder::genlinnum(Srcpos srcpos)
{
    code cs;
    //srcpos.print("genlinnum");
    cs.Iop = ESCAPE | ESClinnum;
    cs.IEV1.Vsrcpos = srcpos;
    gen(&cs);
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
        cs.IEV1.Vint = offset;
        return gen(c,&cs);
    }
    else
        return c;
}

void CodeBuilder::genadjesp(int offset)
{
    if (!I16 && offset)
    {
        code cs;
        cs.Iop = ESCAPE | ESCadjesp;
        cs.IEV1.Vint = offset;
        gen(&cs);
    }
}

#if TX86
/********************************
 * Generate 'instruction' which tells the scheduler that the fpu stack has
 * changed.
 */

code *genadjfpu(code *c, int offset)
{   code cs;

    if (!I16 && offset)
    {
        cs.Iop = ESCAPE | ESCadjfpu;
        cs.IEV1.Vint = offset;
        return gen(c,&cs);
    }
    else
        return c;
}

void CodeBuilder::genadjfpu(int offset)
{
    if (!I16 && offset)
    {
        code cs;
        cs.Iop = ESCAPE | ESCadjfpu;
        cs.IEV1.Vint = offset;
        gen(&cs);
    }
}
#endif

/********************************
 * Generate 'nop'
 */

code *gennop(code *c)
{
    return gen1(c,NOP);
}

void CodeBuilder::gennop()
{
    gen1(NOP);
}


/**************************
 * Generate code to deal with floatreg.
 */

void CodeBuilder::genfltreg(unsigned opcode,unsigned reg,targ_size_t offset)
{
    floatreg = TRUE;
    reflocal = TRUE;
    if ((opcode & ~7) == 0xD8)
        genfwait(*this);
    genc1(opcode,modregxrm(2,reg,BPRM),FLfltreg,offset);
}

code *genxmmreg(code *c,unsigned opcode,unsigned xreg,targ_size_t offset, tym_t tym)
{
    assert(xreg >= XMM0);
    floatreg = TRUE;
    reflocal = TRUE;
    code *c1 = genc1(CNIL,opcode,modregxrm(2,xreg - XMM0,BPRM),FLfltreg,offset);
    checkSetVex(c1, tym);
    return cat(c, c1);
}

void CodeBuilder::genxmmreg(unsigned opcode,unsigned xreg,targ_size_t offset, tym_t tym)
{
    assert(xreg >= XMM0);
    floatreg = TRUE;
    reflocal = TRUE;
    genc1(opcode,modregxrm(2,xreg - XMM0,BPRM),FLfltreg,offset);
    checkSetVex(last(), tym);
}

/****************************************
 * Clean stack after call to codelem().
 */

void gencodelem(CodeBuilder& cdb,elem *e,regm_t *pretregs,bool constflag)
{
    if (e)
    {
        unsigned stackpushsave;
        int stackcleansave;

        stackpushsave = stackpush;
        stackcleansave = cgstate.stackclean;
        cgstate.stackclean = 0;                         // defer cleaning of stack
        codelem(cdb,e,pretregs,constflag);
        assert(cgstate.stackclean == 0);
        cgstate.stackclean = stackcleansave;
        genstackclean(cdb,stackpush - stackpushsave,*pretregs);       // do defered cleaning
    }
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

void regwithvalue(CodeBuilder& cdb,regm_t regm,targ_size_t value,unsigned *preg,regm_t flags)
{
    //printf("regwithvalue(value = %lld)\n", (long long)value);
    unsigned reg;
    if (!preg)
        preg = &reg;

    // If we don't already have a register with the right value in it
    if (!reghasvalue(regm,value,preg))
    {
        regm_t save = regcon.immed.mval;
        allocreg(cdb,&regm,preg,TYint);  // allocate register
        regcon.immed.mval = save;
        movregconst(cdb,*preg,value,flags);   // store value into reg
    }
}

/************************
 * When we don't know whether a function symbol is defined or not
 * within this module, we stuff it in this linked list of references
 * to be fixed up later.
 */

struct fixlist
{
    int         Lseg;           // where the fixup is going (CODE or DATA, never UDATA)
    int         Lflags;         // CFxxxx
    targ_size_t Loffset;        // addr of reference to symbol
    targ_size_t Lval;           // value to add into location
#if TARGET_OSX
    symbol      *Lfuncsym;      // function the symbol goes in
#endif
    fixlist *Lnext;             // next in threaded list

    static int nodel;           // don't delete from within searchfixlist
};

int fixlist::nodel = 0;

/* The AArray, being hashed on the pointer value of the symbol s, is in a different
 * order from run to run. This plays havoc with trying to compare the .obj file output.
 * When needing to do that, set FLARRAY to 1. This will replace the AArray with a
 * simple (and very slow) linear array. Handy for tracking down compiler issues, though.
 */
#define FLARRAY 0
struct Flarray
{
#if FLARRAY
    symbol *s;
    fixlist *fl;

    static Flarray *flarray;
    static size_t flarray_dim;
    static size_t flarray_max;

    static fixlist **add(symbol *s)
    {
        //printf("add %s\n", s->Sident);
        fixlist **pv;
        for (size_t i = 0; 1; i++)
        {
            assert(i <= flarray_dim);
            if (i == flarray_dim)
            {
                if (flarray_dim == flarray_max)
                {
                    flarray_max = flarray_max * 2 + 1000;
                    flarray = (Flarray *)mem_realloc(flarray, flarray_max * sizeof(flarray[0]));
                }
                flarray_dim += 1;
                flarray[i].s = s;
                flarray[i].fl = NULL;
                pv = &flarray[i].fl;
                break;
            }
            if (flarray[i].s == s)
            {
                pv = &flarray[i].fl;
                break;
            }
        }
        return pv;
    }

    static fixlist **search(symbol *s)
    {
        //printf("search %s\n", s->Sident);
        fixlist **lp = NULL;
        for (size_t i = 0; i < flarray_dim; i++)
        {
            if (flarray[i].s == s)
            {
                lp = &flarray[i].fl;
                break;
            }
        }
        return lp;
    }

    static void del(symbol *s)
    {
        //printf("del %s\n", s->Sident);
        for (size_t i = 0; 1; i++)
        {
            assert(i < flarray_dim);
            if (flarray[i].s == s)
            {
                if (i + 1 == flarray_dim)
                    --flarray_dim;
                else
                    flarray[i].s = NULL;
                break;
            }
        }
    }

    static void apply(int (*dg)(void *parameter, void *pkey, void *pvalue))
    {
        //printf("apply\n");
        for (size_t i = 0; i < flarray_dim; i++)
        {
            fixlist::nodel++;
            if (flarray[i].s)
                (*dg)(NULL, &flarray[i].s, &flarray[i].fl);
            fixlist::nodel--;
        }
    }
#else
    static AArray *start;

    static fixlist **add(symbol *s)
    {
        if (!start)
            start = new AArray(&ti_pvoid, sizeof(fixlist *));
        return (fixlist **)start->get(&s);
    }

    static fixlist **search(symbol *s)
    {
        return (fixlist **)(start ? start->in(&s) : NULL);
    }

    static void del(symbol *s)
    {
        start->del(&s);
    }

    static void apply(int (*dg)(void *parameter, void *pkey, void *pvalue))
    {
        if (start)
        {
            fixlist::nodel++;
            start->apply(NULL, dg);
            fixlist::nodel--;
#if TERMCODE
            delete start;
#endif
            start = NULL;
        }
    }
#endif
};

#if FLARRAY
Flarray *Flarray::flarray;
size_t Flarray::flarray_dim;
size_t Flarray::flarray_max;
#else
AArray *Flarray::start = NULL;
#endif

/****************************
 * Add to the fix list.
 */

size_t addtofixlist(symbol *s,targ_size_t soffset,int seg,targ_size_t val,int flags)
{
        static char zeros[8];

        //printf("addtofixlist(%p '%s')\n",s,s->Sident);
        assert(I32 || flags);
        fixlist *ln = (fixlist *) mem_calloc(sizeof(fixlist));
        //ln->Lsymbol = s;
        ln->Loffset = soffset;
        ln->Lseg = seg;
        ln->Lflags = flags;
        ln->Lval = val;
#if TARGET_OSX
        ln->Lfuncsym = funcsym_p;
#endif

        fixlist **pv = Flarray::add(s);
        ln->Lnext = *pv;
        *pv = ln;

        size_t numbytes;
#if TARGET_SEGMENTED
        switch (flags & (CFoff | CFseg))
        {
            case CFoff:         numbytes = tysize(TYnptr);      break;
            case CFseg:         numbytes = 2;                   break;
            case CFoff | CFseg: numbytes = tysize(TYfptr);      break;
            default:            assert(0);
        }
#else
        numbytes = tysize(TYnptr);
        if (I64 && !(flags & CFoffset64))
            numbytes = 4;

#if TARGET_WINDOS
        /* This can happen when generating CV8 data
         */
        if (flags & CFseg)
            numbytes += 2;
#endif
#endif
#ifdef DEBUG
        assert(numbytes <= sizeof(zeros));
#endif
        objmod->bytes(seg,soffset,numbytes,zeros);
        return numbytes;
}

/****************************
 * Given a function symbol we've just defined the offset for,
 * search for it in the fixlist, and resolve any matches we find.
 * Input:
 *      s       function symbol just defined
 */

void searchfixlist(symbol *s)
{
    //printf("searchfixlist(%s)\n",s->Sident);
        fixlist **lp = Flarray::search(s);
        if (lp)
        {   fixlist *p;
            while ((p = *lp) != NULL)
            {
                //dbg_printf("Found reference at x%lx\n",p->Loffset);

                // Determine if it is a self-relative fixup we can
                // resolve directly.
                if (s->Sseg == p->Lseg &&
                    (s->Sclass == SCstatic ||
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                     (!(config.flags3 & CFG3pic) && s->Sclass == SCglobal)) &&
#else
                        s->Sclass == SCglobal) &&
#endif
                    s->Sxtrnnum == 0 && p->Lflags & CFselfrel)
                {   targ_size_t ad;

                    //printf("Soffset = x%lx, Loffset = x%lx, Lval = x%lx\n",s->Soffset,p->Loffset,p->Lval);
                    ad = s->Soffset - p->Loffset - REGSIZE + p->Lval;
                    objmod->bytes(p->Lseg,p->Loffset,REGSIZE,&ad);
                }
                else
                {
#if TARGET_OSX
                    symbol *funcsymsave = funcsym_p;
                    funcsym_p = p->Lfuncsym;
                    Obj::reftoident(p->Lseg,p->Loffset,s,p->Lval,p->Lflags);
                    funcsym_p = funcsymsave;
#else
                    objmod->reftoident(p->Lseg,p->Loffset,s,p->Lval,p->Lflags);
#endif
                }
                *lp = p->Lnext;
                mem_free(p);            /* remove from list             */
            }
            if (!fixlist::nodel)
            {
                Flarray::del(s);
            }
        }
}

/****************************
 * End of module. Output remaining fixlist elements as references
 * to external symbols.
 */

STATIC int outfixlist_dg(void *parameter, void *pkey, void *pvalue)
{
    //printf("outfixlist_dg(pkey = %p, pvalue = %p)\n", pkey, pvalue);
    symbol *s = *(symbol **)pkey;

    fixlist **plnext = (fixlist **)pvalue;

    while (*plnext)
    {
        fixlist *ln = *plnext;

        symbol_debug(s);
        //printf("outfixlist '%s' offset %04x\n",s->Sident,ln->Loffset);

#if TARGET_SEGMENTED
        if (tybasic(s->ty()) == TYf16func)
        {
            Obj::far16thunk(s);          /* make it into a thunk         */
            searchfixlist(s);
        }
        else
#endif
        {
            if (s->Sxtrnnum == 0)
            {   if (s->Sclass == SCstatic)
                {
#if SCPP
                    if (s->Sdt)
                    {
                        outdata(s);
                        searchfixlist(s);
                        continue;
                    }

                    synerr(EM_no_static_def,prettyident(s));    // no definition found for static
#else // MARS
                    printf("Error: no definition for static %s\n",prettyident(s));      // no definition found for static
                    err_exit();                         // BUG: do better
#endif
                }
                if (s->Sflags & SFLwasstatic)
                {
                    // Put it in BSS
                    s->Sclass = SCstatic;
                    s->Sfl = FLunde;
                    DtBuilder dtb;
                    dtb.nzeros(type_size(s->Stype));
                    s->Sdt = dtb.finish();
                    outdata(s);
                    searchfixlist(s);
                    continue;
                }
                s->Sclass = SCextern;   /* make it external             */
                objmod->external(s);
                if (s->Sflags & SFLweak)
                {
                    objmod->wkext(s, NULL);
                }
            }
#if TARGET_OSX
            symbol *funcsymsave = funcsym_p;
            funcsym_p = ln->Lfuncsym;
            Obj::reftoident(ln->Lseg,ln->Loffset,s,ln->Lval,ln->Lflags);
            funcsym_p = funcsymsave;
#else
            objmod->reftoident(ln->Lseg,ln->Loffset,s,ln->Lval,ln->Lflags);
#endif
            *plnext = ln->Lnext;
#if TERMCODE
            mem_free(ln);
#endif
        }
    }
    s->Sxtrnnum = 0;
    return 0;
}

void outfixlist()
{
    //printf("outfixlist()\n");
    Flarray::apply(&outfixlist_dg);
}

#endif // !SPP
