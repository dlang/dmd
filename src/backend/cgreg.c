// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


#if !SPP

#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>
#include	<time.h>
#include	"cc.h"
#include	"el.h"
#include	"oper.h"
#include	"code.h"
#include	"global.h"
#include	"type.h"

static char __file__[] = __FILE__;	/* for tassert.h		*/
#include	"tassert.h"

STATIC void el_weights(int bi,elem *e,unsigned weight);
static int __cdecl weight_compare(const void *e1,const void *e2);

static int nretblocks;

static vec_t regrange[REGMAX];

static int *weights;
#define WEIGHTS(bi,si)	weights[bi * globsym.top + si]

/******************************************
 */

void cgreg_init()
{   block *b;
    int bi;

    if (!config.flags4 & CFG4optimized)
	return;

    // Use calloc() instead because sometimes the alloc is too large
    //printf("1weights: dfotop = %d, globsym.top = %d\n", dfotop, globsym.top);
    weights = (int *) calloc(1,dfotop * globsym.top * sizeof(weights[0]));
    assert(weights);

    nretblocks = 0;
    for (bi = 0; bi < dfotop; bi++)
    {	b = dfo[bi];
	if (b->BC == BCret || b->BC == BCretexp)
	    nretblocks++;
	if (b->Belem)
	{
	    //printf("b->Bweight = x%x\n",b->Bweight);
	    el_weights(bi,b->Belem,b->Bweight);
	}
    }
    memset(regrange,0,sizeof(regrange));

    // Make adjustments to symbols we might stick in registers
    for (int i = 0; i < globsym.top; i++)
    {   unsigned sz;
	symbol *s;

	s = globsym.tab[i];

	if (s->Srange)
	    s->Srange = vec_realloc(s->Srange,dfotop);

	// Determine symbols that are not candidates
	if (!(s->Sflags & GTregcand) ||
	    !s->Srange ||
	    (sz = type_size(s->Stype)) == 0 ||
	    (tysize(s->ty()) == -1) ||
	    (!I32 && sz > REGSIZE) ||
	    (I32 && tyfloating(s->ty()))
	   )
	{
	    s->Sflags &= ~GTregcand;
	    continue;
	}

	switch (s->Sclass)
	{   case SCparameter:
	    case SCfastpar:
		// Do not put parameters in registers if they are not used
		// more than twice (otherwise we have a net loss).
		if (s->Sweight <= 2)
		{
		    #ifdef DEBUG
		    if (debugr)
			printf("parameter '%s' weight %d is not enough\n",s->Sident,s->Sweight);
		    #endif
		    s->Sflags &= ~GTregcand;
		    continue;
		}
		break;
	}

	if (sz == 1)
	    s->Sflags |= GTbyte;

	if (!s->Slvreg)
	    s->Slvreg = vec_calloc(dfotop);

	//printf("dfotop = %d, numbits = %d\n",dfotop,vec_numbits(s->Srange));
	assert(vec_numbits(s->Srange) == dfotop);
    }
}

/******************************************
 */

void cgreg_term()
{   int i;
    Symbol *s;

    if (config.flags4 & CFG4optimized)
    {
	for (i = 0; i < globsym.top; i++)
	{
	    s = globsym.tab[i];
	    vec_free(s->Srange);
	    vec_free(s->Slvreg);
	    s->Srange = NULL;
	    s->Slvreg = NULL;
	}

	for (i = 0; i < arraysize(regrange); i++)
	    if (regrange[i])
	    {   vec_free(regrange[i]);
		    regrange[i] = NULL;
	    }

	free(weights);
	weights = NULL;
    }
}

/*********************************
 */

void cgreg_reset()
{   unsigned j;

    for (j = 0; j < arraysize(regrange); j++)
	if (!regrange[j])
	    regrange[j] = vec_calloc(dfotop);
	else
	    vec_clear(regrange[j]);
}

/*******************************
 * Registers used in block bi.
 */

void cgreg_used(unsigned bi,regm_t used)
{   int j;

    for (j = 0; used; j++)
    {   if (used & 1)		// if register j is used
	    vec_setbit(bi,regrange[j]);
	used >>= 1;
    }
}

/*************************
 * Run through a tree calculating symbol weights.
 */

STATIC void el_weights(int bi,elem *e,unsigned weight)
{   int op;
    Symbol *s;

    while (1)
    {	elem_debug(e);

	op = e->Eoper;
	if (!OTleaf(op))
	{
	    // This prevents variable references within common subexpressions
	    // from adding to the variable's usage count.
	    if (e->Ecount)
	    {
		if (e->Ecomsub)
		    weight = 0;
		else
		    e->Ecomsub = 1;
	    }

	    if (OTbinary(op))
	    {	el_weights(bi,e->E2,weight);
		if ((OTopeq(op) || OTpost(op)) && e->E1->Eoper == OPvar)
		{
		    if (weight >= 10)
			weight += 10;
		    else
			weight++;
		}
	    }
	    e = e->E1;
	}
	else
	{
	    switch (op)
	    {
		case OPvar:
		    s = e->EV.sp.Vsym;
		    if (s->Ssymnum != -1 && s->Sflags & GTregcand)
		    {
			s->Sweight += weight;
			//printf("adding %d weight to '%s' (block %d, Ssymnum %d), giving Sweight %d\n",weight,s->Sident,bi,s->Ssymnum,s->Sweight);
			if (weights)
			    WEIGHTS(bi,s->Ssymnum) += weight;
		    }
		    break;
	    }
	    return;
	}
    }
}

/*****************************************
 * Determine 'benefit' of assigning symbol s to register reg.
 * Benefit is roughly the number of clocks saved.
 * A negative value means that s cannot or should not be assigned to reg.
 */

int cgreg_benefit(Symbol *s,int reg, Symbol *retsym)
{
    int benefit;
    int benefit2;
    block *b;
    list_t bl;
    int bi;
    int si;
    int gotoepilog;
    int retsym_cnt;

    //printf("cgreg_benefit(s = '%s', reg = %d)\n", s->Sident, reg);

    vec_sub(s->Slvreg,s->Srange,regrange[reg]);
    si = s->Ssymnum;

Lagain:
    //printf("again\n");
    benefit = 0;
    retsym_cnt = 0;

    // Make sure we have enough uses to justify
    // using a register we must save
    if (fregsaved & mask[reg] & mfuncreg)
	benefit -= 1 + nretblocks;

    foreach (bi,dfotop,s->Srange)
    {	int inoutp;
	int inout;

	b = dfo[bi];
	switch (b->BC)
	{
	    case BCjcatch:
	    case BCcatch:
	    case BC_except:
	    case BC_finally:
	    case BC_ret:
		s->Sflags &= ~GTregcand;
		goto Lcant;		// can't assign to register
	}
	if (vec_testbit(bi,s->Slvreg))
	{   benefit += WEIGHTS(bi,si);
	    //printf("WEIGHTS(%d,%d) = %d, benefit = %d\n",bi,si,WEIGHTS(bi,si),benefit);
	    inout = 1;

	    if (s == retsym && reg == AX && b->BC == BCretexp)
	    {	benefit += 1;
    		retsym_cnt++;
		//printf("retsym, benefit = %d\n",benefit);
		if (s->Sfl == FLreg && !vec_disjoint(s->Srange,regrange[reg]))
		    goto Lcant;				// don't spill if already in register
	    }
	}
	else
	    inout = -1;

	// Look at predecessors to see if we need to load in/out of register
	gotoepilog = 0;
    L2:
	inoutp = 0;
	benefit2 = 0;
	for (bl = b->Bpred; bl; bl = list_next(bl))
	{   block *bp;
	    int bpi;

	    bp = list_block(bl);
	    bpi = bp->Bdfoidx;
	    if (!vec_testbit(bpi,s->Srange))
		continue;
	    if (gotoepilog && bp->BC == BCgoto)
	    {
		if (vec_testbit(bpi,s->Slvreg))
		{
		    if (inout == -1)
			benefit2 -= bp->Bweight;	// need to mov into mem
		}
		else
		{
		    if (inout == 1)
			benefit2 -= bp->Bweight;	// need to mov into reg
		}
	    }
	    else if (vec_testbit(bpi,s->Slvreg))
	    {
		switch (inoutp)
		{
		    case 0:
			inoutp = 1;
			if (inout != 1)
			{   if (gotoepilog)
			    {	vec_clearbit(bpi,s->Slvreg);
				goto Lagain;
			    }
			    benefit2 -= b->Bweight;	// need to mov into mem
			}
			break;
		    case 1:
			break;
		    case -1:
			if (gotoepilog == 0)
			{   gotoepilog = 1;
			    goto L2;
			}
			vec_clearbit(bpi,s->Slvreg);
			goto Lagain;
		}
	    }
	    else
	    {
		switch (inoutp)
		{
		    case 0:
			inoutp = -1;
			if (inout != -1)
			{   if (gotoepilog)
			    {   vec_clearbit(bi,s->Slvreg);
				goto Lagain;
			    }
			    benefit2 -= b->Bweight;	// need to mov into reg
			}
			break;
		    case 1:
			if (gotoepilog == 0)
			{   gotoepilog = 1;
			    goto L2;
			}
			if (inout == 1)
			{   vec_clearbit(bi,s->Slvreg);
			    goto Lagain;
			}
			goto Lcant;
		    case -1:
			break;
		}
	    }
	}
	//printf("benefit2 = %d\n", benefit2);
	benefit += benefit2;
    }

#ifdef DEBUG
    //printf("2weights: dfotop = %d, globsym.top = %d\n", dfotop, globsym.top);
    if (benefit > s->Sweight + retsym_cnt)
	printf("s = '%s', benefit = %d, Sweight = %d, retsym_cnt = x%x\n",s->Sident,benefit,s->Sweight, retsym_cnt);
#endif
    assert(benefit <= s->Sweight + retsym_cnt);
    return benefit;

Lcant:
    return -1;			// can't assign to reg
}

/*********************************************
 * Determine if block gets symbol loaded by predecessor epilog (1),
 * or by prolog (0).
 */

int cgreg_gotoepilog(block *b,Symbol *s)
{
    list_t bl;
    int bi;
    int si;
    int gotoepilog;
    int inoutp;
    int inout;

    bi = b->Bdfoidx;
    si = s->Ssymnum;

    if (vec_testbit(bi,s->Slvreg))
	inout = 1;
    else
	inout = -1;

    // Look at predecessors to see if we need to load in/out of register
    gotoepilog = 0;
    inoutp = 0;
    for (bl = b->Bpred; bl; bl = list_next(bl))
    {   block *bp;
	int bpi;

	bp = list_block(bl);
	bpi = bp->Bdfoidx;
	if (!vec_testbit(bpi,s->Srange))
	    continue;
	if (vec_testbit(bpi,s->Slvreg))
	{
	    switch (inoutp)
	    {
		case 0:
		    inoutp = 1;
		    if (inout != 1)
		    {   if (gotoepilog)
			    goto Lcant;
		    }
		    break;
		case 1:
		    break;
		case -1:
		    if (gotoepilog == 0)
		    {   gotoepilog = 1;
			goto Lret;
		    }
		    goto Lcant;
	    }
	}
	else
	{
	    switch (inoutp)
	    {
		case 0:
		    inoutp = -1;
		    if (inout != -1)
		    {   if (gotoepilog)
			    goto Lcant;
		    }
		    break;
		case 1:
		    if (gotoepilog == 0)
		    {   gotoepilog = 1;
			goto Lret;
		    }
		    goto Lcant;
		case -1:
		    break;
	    }
	}
    }
Lret:
    return gotoepilog;

Lcant:
    assert(0);
    return -1;			// can't assign to reg
}

/**********************************
 * Determine block prolog code - it's either
 * assignments to register, or storing register back in memory.
 */

void cgreg_spillreg_prolog(block *b,Symbol *s,code **pcstore,code **pcload)
{
    list_t bl;
    code *cload;
    code *cstore;
    code *c;
    code cs;
    int inoutp;
    int sz;
    elem *e;
    regm_t keepmsk;
    int bi;

    e = NULL;
    cstore = *pcstore;
    cload = *pcload;
    bi = b->Bdfoidx;
    sz = type_size(s->Stype);

    //printf("cgreg_spillreg_prolog(block %d, s = '%s')\n",bi,s->Sident);

    if (vec_testbit(bi,s->Slvreg))
    {	inoutp = 1;
	// If it's startblock, and it's a spilled parameter, we
	// need to load it
	if (s->Sflags & SFLspill && bi == 0 &&
	    (s->Sclass == SCparameter || s->Sclass == SCfastpar))
	{
	    goto Lload;
	}
    }
    else
	inoutp = -1;

    if (cgreg_gotoepilog(b,s))
	return;

    // Look at predecessors to see if we need to load in/out of register
    for (bl = b->Bpred; bl; bl = list_next(bl))
    {	block *bp;
	int bpi;

	bp = list_block(bl);
	bpi = bp->Bdfoidx;
	if (!vec_testbit(bpi,s->Srange))
	    continue;
//	if (bp->BC == BCgoto)
//	    continue;			// already taken care of
	if (vec_testbit(bpi,s->Slvreg))
	{
	    if (inoutp == -1)
	    {	// MOV mem[ESP],reg
		cs.Iop = 0x89;
		keepmsk = RMstore;
		#ifdef DEBUG
		if (debugr)
		    printf("B%d: prolog moving %s into '%s'\n",bi,regstring[s->Sreglsw],s->Sident);
		#endif
	    }
	    else
		continue;
	}
	else
	{
	    if (inoutp == 1)
	    {
	Lload:
		// MOV reg,mem[ESP]
		cs.Iop = 0x8B;
		keepmsk = RMload;
		#ifdef DEBUG
		if (debugr)
		{   if (sz > REGSIZE)
			printf("B%d: prolog moving '%s' into %s:%s\n",bi,s->Sident,regstring[s->Sregmsw],regstring[s->Sreglsw]);
		    else
			printf("B%d: prolog moving '%s' into %s\n",bi,s->Sident,regstring[s->Sreglsw]);
		}
		#endif
	    }
	    else
		continue;
	}
	if (!e)
	    e = el_var(s);		// so we can trick getlvalue() into
					// working for us
	cs.Iop ^= (sz == 1);
	c = getlvalue(&cs,e,keepmsk);
	cs.Irm |= modregrm(0,s->Sreglsw,0);
	c = gen(c,&cs);
	if (sz > REGSIZE)
	{
	    NEWREG(cs.Irm,s->Sregmsw);
	    getlvalue_msw(&cs);
	    c = gen(c,&cs);
	}
	if (inoutp == -1)
	    cstore = cat(cstore,c);
	else
	    cload = cat(cload,c);
	break;
    }
    el_free(e);

    // Store old register values before loading in new ones
    *pcstore = cstore;
    *pcload = cload;
}

/**********************************
 * Determine block epilog code - it's either
 * assignments to register, or storing register back in memory.
 */

void cgreg_spillreg_epilog(block *b,Symbol *s,code **pcstore,code **pcload)
{
    list_t bl;
    code *cload;
    code *cstore;
    code *c;
    code cs;
    int inoutp;
    int sz;
    elem *e;
    regm_t keepmsk;
    int bi;

    e = NULL;
    cstore = *pcstore;
    cload = *pcload;
    bi = b->Bdfoidx;
    sz = type_size(s->Stype);

    //printf("cgreg_spillreg_epilog(block %d, s = '%s')\n",bi,s->Sident);
    //assert(b->BC == BCgoto);
    if (!cgreg_gotoepilog(list_block(b->Bsucc),s))
	return;

    if (vec_testbit(bi,s->Slvreg))
	inoutp = 1;
    else
	inoutp = -1;

    // Look at successors to see if we need to load in/out of register
    for (bl = b->Bsucc; bl; bl = list_next(bl))
    {	block *bp;
	int bpi;

	bp = list_block(bl);
	bpi = bp->Bdfoidx;
	if (!vec_testbit(bpi,s->Srange))
	    continue;
	if (vec_testbit(bpi,s->Slvreg))
	{
	    if (inoutp == -1)
	    {
		// MOV reg,mem[ESP]
		cs.Iop = 0x8B;
		keepmsk = RMload;
		#ifdef DEBUG
		if (debugr)
		    printf("B%d: epilog moving '%s' into %s\n",bi,s->Sident,regstring[s->Sreglsw]);
		#endif
	    }
	    else
		continue;
	}
	else
	{
	    if (inoutp == 1)
	    {	// MOV mem[ESP],reg
		cs.Iop = 0x89;
		keepmsk = RMstore;
		#ifdef DEBUG
		if (debugr)
		    printf("B%d: epilog moving %s into '%s'\n",bi,regstring[s->Sreglsw],s->Sident);
		#endif
	    }
	    else
		continue;
	}
	if (!e)
	    e = el_var(s);		// so we can trick getlvalue() into
					// working for us
	cs.Iop ^= (sz == 1);
	c = getlvalue(&cs,e,keepmsk);
	cs.Irm |= modregrm(0,s->Sreglsw,0);
	c = gen(c,&cs);
	if (sz > REGSIZE)
	{
	    NEWREG(cs.Irm,s->Sregmsw);
	    getlvalue_msw(&cs);
	    c = gen(c,&cs);
	}
	if (inoutp == 1)
	    cstore = cat(cstore,c);
	else
	    cload = cat(cload,c);
	break;
    }
    el_free(e);

    // Store old register values before loading in new ones
    *pcstore = cstore;
    *pcload = cload;
}

/***************************
 * Map symbol s into register reg.
 */

void cgreg_map(Symbol *s, unsigned regmsw, unsigned reglsw)
{
    assert(reglsw < 8);

    if (vec_disjoint(s->Srange,regrange[reglsw]) &&
	(regmsw == NOREG || vec_disjoint(s->Srange,regrange[regmsw]))
       )
    {
	s->Sfl = FLreg;
	vec_copy(s->Slvreg,s->Srange);
    }
    else
    {
	s->Sflags |= SFLspill;

	// Already computed by cgreg_benefit()
	//vec_sub(s->Slvreg,s->Srange,regrange[reglsw]);

	if (s->Sfl == FLreg)		// if reassigned
	{
	    switch (s->Sclass)
	    {
		case SCauto:
		case SCregister:
		case SCtmp:
		case SCfastpar:
		    s->Sfl = FLauto;
		    break;
		case SCbprel:
		    s->Sfl = FLbprel;
		    break;
		case SCparameter:
		    s->Sfl = FLpara;
		    break;
#if PSEUDO_REGS
		case SCpseudo:
		    s->Sfl = FLpseudo;
		    break;
#endif
		case SCstack:
		    s->Sfl = FLstack;
		    break;
		default:
#ifdef DEBUG
		    symbol_print(s);
#endif
		    assert(0);
	    }
	}
    }
    s->Sreglsw = reglsw;
    s->Sregm = mask[reglsw];
    mfuncreg &= ~mask[reglsw];
    if (regmsw != NOREG)
	vec_subass(s->Slvreg,regrange[regmsw]);
    vec_orass(regrange[reglsw],s->Slvreg);

    if (regmsw == NOREG)
    {
	#if DEBUG
	    if (debugr)
	    {
		printf("symbol '%s' %s in register %s\n    ",
		    s->Sident,
		    (s->Sflags & SFLspill) ? "spilled" : "put",
		    regstring[reglsw]);
		vec_println(s->Slvreg);
	    }
	#endif
    }
    else
    {
	assert(regmsw < 8);
	s->Sregmsw = regmsw;
	s->Sregm |= mask[regmsw];
	mfuncreg &= ~mask[regmsw];
	vec_orass(regrange[regmsw],s->Slvreg);

	#if DEBUG
	    if (debugr)
		printf("symbol '%s' %s in register pair %s\n",
		    s->Sident,
		    (s->Sflags & SFLspill) ? "spilled" : "put",
		    regm_str(s->Sregm));
	#endif
    }
}

/******************************************
 * Do register assignments.
 * Returns:
 *	!=0	redo code generation
 *	0	no more register assignments
 */

struct Reg		// data for trial register assignment
{
    Symbol *sym;
    int reglsw;
    int regmsw;
    int benefit;
};

int cgreg_assign(Symbol *retsym)
{
    Reg t;
    vec_t v;

    int si;
    int flag;

    flag = FALSE;
    v = vec_calloc(dfotop);

    // Find symbol t, which is the most 'deserving' symbol that should be
    // placed into a register.
    t.sym = NULL;
    t.benefit = 0;
    for (si = 0; si < globsym.top; si++)
    {
	Reg u;
	symbol *s;
	unsigned reg;
	tym_t ty;
	unsigned sz;


	s = globsym.tab[si];
	u.sym = s;
	if (!(s->Sflags & GTregcand) ||
	    s->Sflags & SFLspill ||
	    // Keep trying to reassign retsym into AX
	    (s->Sfl == FLreg && !(s == retsym && s->Sregm != mAX))
	   )
	{
	    #ifdef DEBUG
	    if (debugr)
	    if (s->Sfl == FLreg)
		printf("symbol '%s' is in reg %s\n",s->Sident,regm_str(s->Sregm));
	    else if (s->Sflags & SFLspill)
		printf("symbol '%s' spilled in reg %s\n",s->Sident,regm_str(s->Sregm));
	    else
		printf("symbol '%s' is not a candidate\n",s->Sident);
	    #endif
	    continue;
	}

	// For pointer types, try to pick index register first
	static char seqidx[] = {BX,SI,DI,AX,CX,DX,BP,NOREG};
	// Otherwise, try to pick index registers last
	static char sequence[] = {AX,CX,DX,BX,SI,DI,BP,NOREG};
#if 0
	static char seqlsw[] = {AX,BX,SI,NOREG};
	static char seqmsw[] = {CX,DX,DI};
#else
	static char seqlsw[] = {AX,BX,SI,DI,NOREG};
	static char seqmsw[] = {CX,DX};
#endif
	char *pseq;

	ty = s->ty();
	sz = tysize(ty);

	#ifdef DEBUG
	    if (debugr)
	    {   printf("symbol '%3s', ty x%x weight x%x sz %d\n   ",
		s->Sident,ty,s->Sweight,sz);
		vec_println(s->Srange);
	    }
	#endif

	if (I32)
	    pseq = (sz == REGSIZE * 2) ? seqlsw : sequence;
	else
	    pseq = typtr(ty) ? seqidx : sequence;

	u.benefit = 0;
	for (int i = 0; pseq[i] != NOREG; i++)
	{   int benefit;

	    reg = pseq[i];

	    if (reg != AX && s == retsym)
		continue;
	    if (reg == BP && !(allregs & mBP))
		continue;
#if 0 && TARGET_LINUX
	    // Need EBX for static pointer
	    if (reg == BX && !(allregs & mBX))
		continue;
#endif

	    if (s->Sflags & GTbyte &&
		!(mask[reg] & BYTEREGS))
		    continue;

	    benefit = cgreg_benefit(s,reg,retsym);

	    #ifdef DEBUG
	    if (debugr)
	    {   printf(" %s",regstring[reg]);
		vec_print(regrange[reg]);
		printf(" %d\n",benefit);
	    }
	    #endif

	    if (benefit > u.benefit)
	    {   // successful assigning of lsw
		unsigned regmsw = NOREG;

		// Now assign in MSW
		if (sz > REGSIZE && sz <= 2 * REGSIZE)
		{   unsigned regj;

		    for (regj = 0; 1; regj++)
		    {   if (regj == arraysize(seqmsw))
			    goto Ltried;
			regmsw = seqmsw[regj];
			if (regmsw == reg)
			    continue;
			#ifdef DEBUG
			if (debugr)
			{   printf(".%s",regstring[regmsw]);
			    vec_println(regrange[regmsw]);
			}
			#endif
			if (vec_disjoint(s->Slvreg,regrange[regmsw]))
			    break;
		    }
		}
		vec_copy(v,s->Slvreg);
		u.benefit = benefit;
		u.reglsw = reg;
		u.regmsw = regmsw;
	    }
Ltried:	    ;
	}

	if (u.benefit > t.benefit)
	{   t = u;
	    vec_copy(t.sym->Slvreg,v);
	}
    }

    if (t.sym && t.benefit > 0)
    {
	cgreg_map(t.sym,t.regmsw,t.reglsw);
	flag = TRUE;
    }

    // See if any registers have become available that we can use.
    if (I32 && !flag && (mfuncreg & ~fregsaved) & ALLREGS &&
	!(funcsym_p->Sflags & SFLexit))
    {
	for (int i = 0; i < globsym.top; i++)
	{   symbol *s;

	    s = globsym.tab[i];
	    if (s->Sfl == FLreg && mask[s->Sreglsw] & fregsaved &&
		type_size(s->Stype) <= REGSIZE)
	    {
		s->Sreglsw = findreg((mfuncreg & ~fregsaved) & ALLREGS);
		s->Sregm = mask[s->Sreglsw];
		flag = TRUE;
#ifdef DEBUG
		if (debugr)
		    printf("re-assigned '%s' to %s\n",s->Sident,regstring[s->Sreglsw]);
#endif
		break;
	    }
	}
    }
    vec_free(v);

    return flag;
}

//////////////////////////////////////
// Qsort() comparison routine for array of pointers to Symbol's.

static int __cdecl weight_compare(const void *e1,const void *e2)
{   Symbol **psp1;
    Symbol **psp2;

    psp1 = (Symbol **)e1;
    psp2 = (Symbol **)e2;

    return (*psp2)->Sweight - (*psp1)->Sweight;
}


#endif
