/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgen.c, backend/cgen.c)
 */

#if (SCPP && !HTOD) || MARS

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
#include        "dt.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

dt_t *dt_get_nzeros(unsigned n);

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
 * within this module, we stuff it in an array of references to be
 * fixed up later.
 */
struct Fixup
{
    symbol      *sym;       // the referenced symbol
    int         seg;        // where the fixup is going (CODE or DATA, never UDATA)
    int         flags;      // CFxxxx
    targ_size_t offset;     // addr of reference to symbol
    targ_size_t val;        // value to add into location
#if TARGET_OSX
    symbol      *funcsym;   // function the symbol goes in
#endif
};

struct FixupArray
{
    Fixup *ptr;
    size_t dim, cap;

    FixupArray()
    : ptr(NULL)
    , dim(0)
    , cap(0)
    {}

    void push(const Fixup &e)
    {
        if (dim == cap)
        {
            // 0x800 determined experimentally to minimize reallocations
            cap = cap
                ? (3 * cap) / 2 // use 'Tau' of 1.5
                : 0x800;
            ptr = (Fixup *)::mem_realloc(ptr, cap * sizeof(Fixup));
        }
        ptr[dim++] = e;
    }

    const Fixup& operator[](size_t idx) const
    {
        assert(idx < dim);
        return ptr[idx];
    }

    void clear()
    {
        dim = 0;
    }
};

static FixupArray fixups;

/****************************
 * Add to the fix list.
 */

size_t addtofixlist(symbol *s,targ_size_t offset,int seg,targ_size_t val,int flags)
{
        static char zeros[8];

        //printf("addtofixlist(%p '%s')\n",s,s->Sident);
        assert(I32 || flags);
        Fixup f;
        f.sym = s;
        f.offset = offset;
        f.seg = seg;
        f.flags = flags;
        f.val = val;
#if TARGET_OSX
        f.funcsym = funcsym_p;
#endif
        fixups.push(f);

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
        objmod->bytes(seg,offset,numbytes,zeros);
        return numbytes;
}

#if 0
void searchfixlist (symbol *s )
{
    //printf("searchfixlist(%s)\n", s->Sident);
}
#endif

/****************************
 * Output fixups as references to external or static symbol.
 * First emit data for still undefined static symbols or mark non-static symbols as SCextern.
 */
static void outfixup(const Fixup &f)
{
    symbol_debug(f.sym);
    //printf("outfixup '%s' offset %04x\n", f.sym->Sident, f.offset);

#if TARGET_SEGMENTED
    if (tybasic(f.sym->ty()) == TYf16func)
    {
        Obj::far16thunk(f.sym);          /* make it into a thunk         */
    }
    else
#endif
    if (f.sym->Sxtrnnum == 0)
    {
        if (f.sym->Sclass == SCstatic)
        {
#if SCPP
            if (f.sym->Sdt)
            {
                outdata(f.sym);
            }
            else if (f.sym->Sseg == UNKNOWN)
                synerr(EM_no_static_def,prettyident(f.sym)); // no definition found for static
#else // MARS
            // OBJ_OMF does not set Sxtrnnum for static symbols, so check
            // whether the symbol was assigned to a segment instead, compare
            // outdata(symbol *s)
            if (f.sym->Sseg == UNKNOWN)
            {
                printf("Error: no definition for static %s\n", prettyident(f.sym)); // no definition found for static
                err_exit(); // BUG: do better
            }
#endif
        }
        else if (f.sym->Sflags & SFLwasstatic)
        {
            // Put it in BSS
            f.sym->Sclass = SCstatic;
            f.sym->Sfl = FLunde;
            f.sym->Sdt = dt_get_nzeros(type_size(f.sym->Stype));
            outdata(f.sym);
        }
        else if (f.sym->Sclass != SCsinline)
        {
            f.sym->Sclass = SCextern;   /* make it external             */
            objmod->external(f.sym);
            if (f.sym->Sflags & SFLweak)
                objmod->wkext(f.sym, NULL);
        }
    }

#if TARGET_OSX
    symbol *funcsymsave = funcsym_p;
    funcsym_p = f.funcsym;
    objmod->reftoident(f.seg, f.offset, f.sym, f.val, f.flags);
    funcsym_p = funcsymsave;
#else
    objmod->reftoident(f.seg, f.offset, f.sym, f.val, f.flags);
#endif
}

/****************************
 * End of module. Output fixups as references
 * to external symbols.
 */
void outfixlist()
{
    for (size_t i = 0; i < fixups.dim; ++i)
        outfixup(fixups[i]);
    fixups.clear();
}

#endif // !SPP
