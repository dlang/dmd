// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
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

#include	<stdio.h>
#include	<string.h>
#include	<time.h>
#include	"cc.h"
#include	"el.h"
#include	"oper.h"
#include	"code.h"
#include	"type.h"
#include	"global.h"

static char __file__[] = __FILE__;	/* for tassert.h		*/
#include	"tassert.h"

/*****************************
 * Find last code in list.
 */

code *code_last(code *c)
{
    if (c)
    {	while (c->next)
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
    {	while (c->next)
	    c = c->next;
	c->Iflags |= flag;
    }
}

/*****************************
 * Concatenate two code lists together. Return pointer to result.
 */

#if TX86 && __INTSIZE == 4 && __SC__
__declspec(naked) code * __pascal cat(code *c1,code *c2)
{
    _asm
    {
	mov	EAX,c1-4[ESP]
	mov	ECX,c2-4[ESP]
	test	EAX,EAX
	jne	L6D
	mov	EAX,ECX
	ret	8

L6D:	mov	EDX,EAX
	cmp	dword ptr [EAX],0
	je	L7B
L74:	mov	EDX,[EDX]
	cmp	dword ptr [EDX],0
	jne	L74
L7B:	mov	[EDX],ECX
	ret	8
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
 *	c ->	linked list that code is to be added to end of
 *	cs ->	data for the code
 * Returns:
 *	pointer to start of code list
 */

code *gen(code *c,code *cs)
{   code *ce,*cstart;
    unsigned reg;

#ifdef DEBUG				/* this is a high usage routine	*/
    assert(cs);
#endif
    ce = code_calloc();
    *ce = *cs;
    if (config.flags4 & CFG4optimized &&
	ce->IFL2 == FLconst &&
	(ce->Iop == 0x81 || ce->Iop == 0x80) &&
	reghasvalue((ce->Iop == 0x80) ? BYTEREGS : ALLREGS,ce->IEV2.Vlong,&reg) &&
	!(ce->Iflags & CFopsize && !I32)
       )
    {	// See if we can replace immediate instruction with register instruction
	static unsigned char regop[8] =
		{ 0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x38 };

//printf("replacing 0x%02x, val = x%lx\n",ce->Iop,ce->IEV2.Vlong);
	ce->Iop = regop[(ce->Irm & modregrm(0,7,0)) >> 3] | (ce->Iop & 1);
	ce->Irm = (ce->Irm & modregrm(3,0,7)) | modregrm(0,reg,0);
    }
    code_next(ce) = CNIL;
    if (c)
    {	cstart = c;
	while (code_next(c)) c = code_next(c);	/* find end of list	*/
	code_next(c) = ce;			/* link into list	*/
	return cstart;
    }
    return ce;
}

code *gen1(code *c,unsigned op)
{ code *ce,*cstart;

  ce = code_calloc();
  ce->Iop = op;
  if (c)
  {	cstart = c;
	while (code_next(c)) c = code_next(c);	/* find end of list	*/
	code_next(c) = ce;			/* link into list	*/
	return cstart;
  }
  return ce;
}

code *gen2(code *c,unsigned op,unsigned rm)
{ code *ce,*cstart;

  cstart = ce = code_calloc();
  /*cxcalloc++;*/
  if (op > 0xFF)
  {	ce->Iop = op >> 8;
	ce->Iop2 = op & 0xFF;
  }
  else
	ce->Iop = op;
  ce->Irm = rm;
  if (c)
  {	cstart = c;
	while (code_next(c)) c = code_next(c);	/* find end of list	*/
	code_next(c) = ce;			/* link into list	*/
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
  if (c)
  {	cstart = c;
	while (code_next(c)) c = code_next(c);	/* find end of list	*/
	code_next(c) = ce;			/* link into list	*/
  }
  return cstart;
}

code *genregs(code *c,unsigned op,unsigned dstreg,unsigned srcreg)
{ return gen2(c,op,modregrm(3,dstreg,srcreg)); }

code *gentstreg(code *c,unsigned t)
{
    c = gen2(c,0x85,modregrm(3,t,t));	// TEST t,t
    code_orflag(c,CFpsw);
    return c;
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

/**************************
 * Generate a MOV to,from register instruction.
 * Smart enough to dump redundant register moves, and segment
 * register moves.
 */

code *genmovreg(code *c,unsigned to,unsigned from)
{
#if DEBUG
	if (to > ES || from > ES)
		printf("genmovreg(c = x%lx, to = %d, from = %d)\n",c,to,from);
#endif
	assert(to <= ES && from <= ES);
	if (to != from)
	{
		if (to == ES)
			c = genregs(c,0x8E,0,from);
		else if (from == ES)
			c = genregs(c,0x8C,0,to);
		else
			c = genregs(c,0x89,from,to);
	}
	return c;
}

/**************************
 * Generate a jump instruction.
 */

code *genjmp(code *c,unsigned op,unsigned fltarg,block *targ)
{   code cs;
    code *cj;
    code *cnop;

    cs.Iop = op;
    cs.Iflags = 0;
    cs.Ijty = 0;
    if (op != JMP)			/* if not already long branch	*/
	  cs.Iflags = CFjmp16;		/* assume long branch for op = 0x7x */
    cs.IFL2 = fltarg;			/* FLblock (or FLcode)		*/
    cs.IEV2.Vblock = targ;		/* target block (or code)	*/
    if (fltarg == FLcode)
	((code *)targ)->Iflags |= CFtarg;

    if (config.flags4 & CFG4fastfloat)	// if fast floating point
	return gen(c,&cs);

    cj = gen(CNIL,&cs);
    switch (op & 0xFF00)		/* look at second jump opcode	*/
    {
	/* The JP and JNP come from floating point comparisons		*/
	case JP << 8:
	    cs.Iop = JP;
	    gen(cj,&cs);
	    break;
	case JNP << 8:
	    /* Do a JP around the jump instruction	*/
	    cnop = gennop(CNIL);
	    c = genjmp(c,JP,FLcode,(block *) cnop);
	    cat(cj,cnop);
	    break;
	case 1 << 8:			/* toggled no jump		*/
	case 0 << 8:
	    break;
	default:
#ifdef DEBUG
	    printf("jop = x%x\n",op);
#endif
	    assert(0);
    }
    return cat(c,cj);
}

code *gencs(code *c,unsigned op,unsigned rm,unsigned FL2,symbol *s)
{   code cs;

    cs.Iop = op;
    cs.Irm = rm;
    cs.Iflags = 0;
    cs.Ijty = 0;
    cs.IFL2 = FL2;
    cs.IEVsym2 = s;
    cs.IEVoffset2 = 0;

    return gen(c,&cs);
}

code *genc2(code *c,unsigned op,unsigned rm,targ_uns EV2)
{   code cs;

    if (op > 0xFF)
    {	cs.Iop = op >> 8;
	cs.Iop2 = op & 0xFF;
    }
    else
	cs.Iop = op;
    cs.Irm = rm;
    cs.Iflags = CFoff;
    cs.Ijty = 0;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = EV2;
    return gen(c,&cs);
}

/*****************
 * Generate code.
 */

code *genc1(code *c,unsigned op,unsigned rm,unsigned FL1,targ_uns EV1)
{   code cs;

    assert(FL1 < FLMAX);
    assert(op < 256);
    cs.Iop = op;
    cs.Irm = rm;
    cs.Isib = rm >> 8;
    cs.Iflags = CFoff;
    cs.Ijty = 0;
    cs.IFL1 = FL1;
    cs.IEV1.Vuns = EV1;
    return gen(c,&cs);
}

/*****************
 * Generate code.
 */

code *genc(code *c,unsigned op,unsigned rm,unsigned FL1,targ_uns EV1,unsigned FL2,targ_uns EV2)
{   code cs;

    assert(FL1 < FLMAX);
    assert(op < 256);
    cs.Iop = op;
    cs.Irm = rm;
    cs.Isib = rm >> 8;
    cs.Iflags = CFoff;
    cs.Ijty = 0;
    cs.IFL1 = FL1;
    cs.IEV1.Vuns = EV1;
    assert(FL2 < FLMAX);
    cs.IFL2 = FL2;
    cs.IEV2.Vuns = EV2;
    return gen(c,&cs);
}

/***************************************
 * Generate immediate multiply instruction for r1=r2*imm.
 * Optimize it into LEA's if we can.
 */

code *genmulimm(code *c,unsigned r1,unsigned r2,targ_int imm)
{   code cs;

    // These optimizations should probably be put into pinholeopt()
    switch (imm)
    {	case 1:
	    c = genmovreg(c,r1,r2);
	    break;
	case 5:
	    cs.Iop = LEA;
	    cs.Iflags = 0;
	    cs.Ijty = 0;
	    buildEA(&cs,r2,r2,4,0);
	    cs.Irm |= modregrm(0,r1,0);
	    c = gen(c,&cs);
	    break;
	default:
	    c = genc2(c,0x69,modregrm(3,r1,r2),imm);	// IMUL r1,r2,imm
	    break;
    }
    return c;
}

/********************************
 * Generate 'instruction' which is actually a line number.
 */

code *genlinnum(code *c,Srcpos srcpos)
{   code cs;

#if 0
#if MARS
    printf("genlinnum(Sfilename = %p, Slinnum = %u)\n", srcpos.Sfilename, srcpos.Slinnum);
#else
    printf("genlinnum(Sfilptr = %p, Slinnum = %u)\n", srcpos.Sfilptr, srcpos.Slinnum);
#endif
#endif
    cs.Iop = ESCAPE;
    cs.Iop2 = ESClinnum;
    cs.Iflags = 0;
    cs.Ijty = 0;
    cs.IFL1 = 0;
    cs.IFL2 = 0;
    cs.IEV2.Vsrcpos = srcpos;
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

    if (I32 && offset)
    {
	cs.Iop = ESCAPE;
	cs.Iop2 = ESCadjesp;
	cs.Iflags = 0;
	cs.Ijty = 0;
	cs.IEV2.Vint = offset;
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

/******************************
 * Load CX with the value of _AHSHIFT.
 */

code *genshift(code *c)
{
#if SCPP && TX86
    code *c1;

    // Set up ahshift to trick ourselves into giving the right fixup,
    // which must be seg-relative, external frame, external target.
    c1 = gencs(CNIL,0xC7,modregrm(3,0,CX),FLfunc,rtlsym[RTLSYM_AHSHIFT]);
    c1->Iflags |= CFoff;
    return cat(c,c1);
#else
    assert(0);
    return 0;
#endif
}

/******************************
 * Move constant value into reg.
 * Take advantage of existing values in registers.
 * If flags & mPSW
 *	set flags based on result
 * Else if flags & 8
 *	do not disturb flags
 * Else
 *	don't care about flags
 * If flags & 1 then byte move
 * If flags & 2 then short move (for 386)
 * If flags & 4 then don't disturb unused portion of register
 * Returns:
 *	code (if any) generated
 */

code *movregconst(code *c,unsigned reg,targ_int value,regm_t flags)
{   unsigned r;
    regm_t regm;
    regm_t mreg;
    targ_int regv;

#define genclrreg(a,r) genregs(a,0x31,r,r)

    regm = regcon.immed.mval & mask[reg];
    regv = regcon.immed.value[reg];

    if (flags & 1)
    {	unsigned msk;

	value &= 0xFF;
	regm &= BYTEREGS;

	// If we already have the right value in the right register
	if (regm && (regv & 0xFF) == value)
	    goto L2;

	if ((reg & 4) && regcon.immed.mval & mask[reg & 3] &&
	    (((regv = regcon.immed.value[reg & 3]) >> 8) & 0xFF) == value)
	    goto L2;

	// Avoid byte register loads on Pentium Pro and Pentium II
	if (config.flags4 & CFG4speed &&
	    config.target_cpu >= TARGET_PentiumPro && !(flags & 4))
	    goto L3;

	// See if another register has the right value
	r = 0;
	for (mreg = (regcon.immed.mval & BYTEREGS); mreg; mreg >>= 1)
	{
	    if (mreg & 1)
	    {
		if ((regcon.immed.value[r] & 0xFF) == value)
		{   c = genregs(c,0x8A,reg,r);		// MOV regL,rL
		    goto L2;
		}
		if (((regcon.immed.value[r] >> 8) & 0xFF) == value)
		{   c = genregs(c,0x8A,reg,r | 4);	// MOV regL,rH
		    goto L2;
		}
	    }
	    r++;
	}

	if (value == 0 && !(flags & 8))
	{
	    if (!(flags & 4) && !(reg & 4))
	    {	c = genregs(c,0x31,reg,reg);	// XOR reg,reg
		regimmed_set(reg,value);
		regv = 0;
	    }
	    else
		c = genregs(c,0x30,reg,reg);	// XOR regL,regL
	    flags &= ~mPSW;			// flags already set by XOR
	}
	else
	    c = genc2(c,0xC6,modregrm(3,0,reg),value);	/* MOV regL,value */
    L2:
	if (flags & mPSW)
	    genregs(c,0x84,reg,reg);		// TEST regL,regL

	if (regm)
	    regimmed_set(reg,(regv & 0xFFFFFF00) | value);
	else if ((reg & 4) && regcon.immed.mval & mask[reg & 3])
	    regimmed_set((reg & 3),(regv & 0xFFFF00FF) | (value << 8));
	return c;
    }
L3:
    if (!I32)
	value = (targ_short) value;		/* sign-extend MSW	*/

    if (I32 && flags & 2)
    {	code *c1;

	value &= 0xFFFF;
	if (value == 0)
	    goto L1;
	else
	{
	    if (flags & mPSW)
		goto L1;
	    c1 = genc2(CNIL,0xC7,modregrm(3,0,reg),value); /* MOV reg,value */
	    c1->Iflags |= CFopsize;
	    c = cat(c,c1);
	    if (regm)
		regimmed_set(reg,(regv & 0xFFFF0000) | value);
	}
	return c;
    }
L1:

    /* If we already have the right value in the right register	*/
    if (regm && regv == value)
    {	if (flags & mPSW)
	    c = gentstreg(c,reg);
    }
    else
    {
	if (flags & mPSW)
	{   
	    switch (value)
	    {	case 0:
		    c = genclrreg(c,reg);
		    break;
		case 1:
		    c = genclrreg(c,reg);
		    goto inc;
		case -1:
		    c = genclrreg(c,reg);
		    goto dec;
		default:
		    c = genc2(c,0xC7,modregrm(3,0,reg),value); /* MOV reg,value */
		    gentstreg(c,reg);
		    break;
	    }
	}
	else
	{
	    /* Look for single byte conversion	*/
	    if (regcon.immed.mval & mAX)
	    {
		if (I32)
		{   if (reg == AX && value == (targ_short) regv)
		    {   c = gen1(c,0x98);		/* CWDE		*/
			goto done;
		    }
		    if (reg == DX &&
			value == (regcon.immed.value[AX] & 0x80000000 ? 0xFFFFFFFF : 0) &&
			!(config.flags4 & CFG4speed && config.target_cpu >= TARGET_Pentium)
		       )
		    {   c = gen1(c,0x99);		/* CDQ		*/
			goto done;
		    }
		}
		else
		{
		    if (reg == AX &&
			(targ_short) value == (signed char) regv)
		    {   c = gen1(c,0x98);		/* CBW		*/
			goto done;
		    }

		    if (reg == DX &&
			(targ_short) value == (regcon.immed.value[AX] & 0x8000 ? (targ_short) 0xFFFF : (targ_short) 0) &&
			!(config.flags4 & CFG4speed && config.target_cpu >= TARGET_Pentium)
		       )
		    {   c = gen1(c,0x99);		/* CWD		*/
			goto done;
		    }
		}
	    }
	    if (value == 0 && !(flags & 8) && config.target_cpu >= TARGET_80486)
	    {	c = genclrreg(c,reg);		// CLR reg
		goto done;
	    }

	    if (regm && !(flags & 8))
	    {	if (regv + 1 == value ||
		    /* Catch case of (0xFFFF+1 == 0) for 16 bit compiles */
		    (!I32 && (targ_short)(regv + 1) == (targ_short)value))
		{
		inc:
		    c = gen1(c,0x40 + reg);	/* INC reg		*/
		    goto done;
		}
		if (regv - 1 == value)
		{
		dec:
		    c = gen1(c,0x48 + reg);	/* DEC reg		*/
		    goto done;
		}
	    }

	    /* See if another register has the right value	*/
	    r = 0;
	    for (mreg = regcon.immed.mval; mreg; mreg >>= 1)
	    {
#ifdef DEBUG
		assert(I32 || regcon.immed.value[r] == (targ_short)regcon.immed.value[r]);
#endif
		if (mreg & 1 && regcon.immed.value[r] == value)
		{   c = genmovreg(c,reg,r);
		    goto done;
		}
		r++;
	    }

	    if (value == 0 && !(flags & 8))
		c = genclrreg(c,reg);		// CLR reg
	    else
	    {	/* See if we can just load a byte	*/
		if (regm & BYTEREGS &&
		    !(config.flags4 & CFG4speed && config.target_cpu >= TARGET_PentiumPro)
		   )
		{
		    if ((regv & 0xFFFFFF00) == (value & 0xFFFFFF00))
		    {	c = movregconst(c,reg,value,(flags & 8) |4|1);	// load regL
			return c;
		    }
		    if ((regv & 0xFFFF00FF) == (value & 0xFFFF00FF))
		    {	c = movregconst(c,4|reg,value >> 8,(flags & 8) |4|1); // load regH
			return c;
		    }
		}
		c = genc2(c,0xC7,modregrm(3,0,reg),value); /* MOV reg,value */
	    }
	}
    done:
	regimmed_set(reg,value);
    }
    return c;
}

/**********************************
 * Determine if one of the registers in regm has value in it.
 * If so, return !=0 and set *preg to which register it is.
 */

bool reghasvalue(regm_t regm,targ_int value,unsigned *preg)
{   unsigned r;
    regm_t mreg;

    /* See if another register has the right value	*/
    r = 0;
    for (mreg = regcon.immed.mval; mreg; mreg >>= 1)
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
 *	*preg	the register selected
 */

code *regwithvalue(code *c,regm_t regm,targ_int value,unsigned *preg,regm_t flags)
{   unsigned reg;

    if (!preg)
	preg = &reg;

    /* If we don't already have a register with the right value in it	*/
    if (!reghasvalue(regm,value,preg))
    {	regm_t save;

	save = regcon.immed.mval;
	c = cat(c,allocreg(&regm,preg,TYint));	// allocate register
	regcon.immed.mval = save;
	c = movregconst(c,*preg,value,flags);	// store value into reg
    }
    return c;
}

#endif // !SPP
