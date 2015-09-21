
// Compiler implementation of the D programming language
// Copyright (c) 2000-2012 by Digital Mars
// All Rights Reserved
// Written by Walter Bright
// http://www.digitalmars.com

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "mars.h"
#include        "lexer.h"
#include        "statement.h"
#include        "expression.h"
#include        "mtype.h"
#include        "dsymbol.h"
#include        "declaration.h"
#include        "irstate.h"
#include        "init.h"
#include        "module.h"
#include        "enum.h"
#include        "aggregate.h"
#include        "template.h"
#include        "id.h"

// Back end
#include        "cc.h"
#include        "type.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "dt.h"

#include        "rmem.h"
#include        "target.h"

static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"

elem *bit_assign(enum OPER op, elem *eb, elem *ei, elem *ev, int result);
elem *bit_read(elem *eb, elem *ei, int result);
elem *callfunc(Loc loc,
        IRState *irs,
        int directcall,         // 1: don't do virtual call
        Type *tret,             // return type
        elem *ec,               // evaluates to function address
        Type *ectype,           // original type of ec
        FuncDeclaration *fd,    // if !=NULL, this is the function being called
        Type *t,                // TypeDelegate or TypeFunction for this function
        elem *ehidden,          // if !=NULL, this is the 'hidden' argument
        Array *arguments);

elem *exp2_copytotemp(elem *e);
elem *incUsageElem(IRState *irs, Loc loc);
StructDeclaration *needsPostblit(Type *t);
elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);


#define elem_setLoc(e,loc)      ((e)->Esrcpos.Sfilename = (char *)(loc).filename, \
                                 (e)->Esrcpos.Slinnum = (loc).linnum)

#define SEH     (TARGET_WINDOS)

/***********************************************
 * Generate code to set index into scope table.
 */

#if SEH
void setScopeIndex(Blockx *blx, block *b, int scope_index)
{
    if (!global.params.is64bit)
        block_appendexp(b, nteh_setScopeTableIndex(blx, scope_index));
}
#else
#define setScopeIndex(blx, b, scope_index) ;
#endif

/****************************************
 * Allocate a new block, and set the tryblock.
 */

block *block_calloc(Blockx *blx)
{
    block *b = block_calloc();
    b->Btry = blx->tryblock;
    return b;
}

/**************************************
 * Convert label to block.
 */

block *labelToBlock(Loc loc, Blockx *blx, LabelDsymbol *label, int flag = 0)
{
    if (!label->statement)
    {
        error(loc, "undefined label %s", label->toChars());
        return NULL;
    }
    LabelStatement *s = label->statement;
    if (!s->lblock)
    {   s->lblock = block_calloc(blx);
        s->lblock->Btry = NULL;         // fill this in later

        if (flag)
        {
            // Keep track of the forward reference to this block, so we can check it later
            if (!s->fwdrefs)
                s->fwdrefs = new Blocks();
            s->fwdrefs->push(blx->curblock);
        }
    }
    return s->lblock;
}

/**************************************
 * Add in code to increment usage count for linnum.
 */

void incUsage(IRState *irs, Loc loc)
{

    if (global.params.cov && loc.linnum)
    {
        block_appendexp(irs->blx->curblock, incUsageElem(irs, loc));
    }
}

/****************************************
 * This should be overridden by each statement class.
 */

void Statement::toIR(IRState *irs)
{
    print();
    assert(0);
}

/*************************************
 */

void OnScopeStatement::toIR(IRState *irs)
{
    //printf("OnScopeStatement::toIR() %p\n", this);
}

/****************************************
 */

void IfStatement::toIR(IRState *irs)
{
    elem *e;
    Blockx *blx = irs->blx;

    //printf("IfStatement::toIR('%s')\n", condition->toChars());

    IRState mystate(irs, this);

    // bexit is the block that gets control after this IfStatement is done
    block *bexit = mystate.breakBlock ? mystate.breakBlock : block_calloc();

    incUsage(irs, loc);
#if 0
    if (match)
    {   /* Generate:
         *  if (match = RTLSYM_IFMATCH(string, pattern)) ...
         */
        assert(condition->op == TOKmatch);
        e = matchexp_toelem((MatchExp *)condition, &mystate, RTLSYM_IFMATCH);
        Symbol *s = match->toSymbol();
        symbol_add(s);
        e = el_bin(OPeq, TYnptr, el_var(s), e);
    }
    else
#endif
        e = condition->toElem(&mystate);
    block_appendexp(blx->curblock, e);
    block *bcond = blx->curblock;
    block_next(blx, BCiftrue, NULL);

    list_append(&bcond->Bsucc, blx->curblock);
    if (ifbody)
        ifbody->toIR(&mystate);
    list_append(&blx->curblock->Bsucc, bexit);

    if (elsebody)
    {
        block_next(blx, BCgoto, NULL);
        list_append(&bcond->Bsucc, blx->curblock);
        elsebody->toIR(&mystate);
        list_append(&blx->curblock->Bsucc, bexit);
    }
    else
        list_append(&bcond->Bsucc, bexit);

    block_next(blx, BCgoto, bexit);

}

/**************************************
 */

#if DMDV2
void PragmaStatement::toIR(IRState *irs)
{
    //printf("PragmaStatement::toIR()\n");
    if (ident == Id::startaddress)
    {
        assert(args && args->dim == 1);
        Expression *e = (*args)[0];
        Dsymbol *sa = getDsymbol(e);
        FuncDeclaration *f = sa->isFuncDeclaration();
        assert(f);
        Symbol *s = f->toSymbol();
        while (irs->prev)
            irs = irs->prev;
        irs->startaddress = s;
    }
}
#endif

/***********************
 */

void WhileStatement::toIR(IRState *irs)
{
    assert(0); // was "lowered"
#if 0
    Blockx *blx = irs->blx;

    /* Create a new state, because we need a new continue and break target
     */
    IRState mystate(irs,this);
    mystate.breakBlock = block_calloc(blx);
    mystate.contBlock = block_calloc(blx);

    list_append(&blx->curblock->Bsucc, mystate.contBlock);
    block_next(blx, BCgoto, mystate.contBlock);
    incUsage(irs, loc);
    block_appendexp(mystate.contBlock, condition->toElem(&mystate));

    block_next(blx, BCiftrue, NULL);

    /* curblock is the start of the while loop body
     */
    list_append(&mystate.contBlock->Bsucc, blx->curblock);
    if (body)
        body->toIR(&mystate);
    list_append(&blx->curblock->Bsucc, mystate.contBlock);
    block_next(blx, BCgoto, mystate.breakBlock);

    list_append(&mystate.contBlock->Bsucc, mystate.breakBlock);
#endif
}

/******************************************
 */

void DoStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

    IRState mystate(irs,this);
    mystate.breakBlock = block_calloc(blx);
    mystate.contBlock = block_calloc(blx);

    block *bpre = blx->curblock;
    block_next(blx, BCgoto, NULL);
    list_append(&bpre->Bsucc, blx->curblock);

    list_append(&mystate.contBlock->Bsucc, blx->curblock);
    list_append(&mystate.contBlock->Bsucc, mystate.breakBlock);

    if (body)
        body->toIR(&mystate);
    list_append(&blx->curblock->Bsucc, mystate.contBlock);

    block_next(blx, BCgoto, mystate.contBlock);
    incUsage(irs, condition->loc);
    block_appendexp(mystate.contBlock, condition->toElem(&mystate));
    block_next(blx, BCiftrue, mystate.breakBlock);

}

/*****************************************
 */

void ForStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

    IRState mystate(irs,this);
    mystate.breakBlock = block_calloc(blx);
    mystate.contBlock = block_calloc(blx);

    if (init)
        init->toIR(&mystate);
    block *bpre = blx->curblock;
    block_next(blx,BCgoto,NULL);
    block *bcond = blx->curblock;
    list_append(&bpre->Bsucc, bcond);
    list_append(&mystate.contBlock->Bsucc, bcond);
    if (condition)
    {
        incUsage(irs, condition->loc);
        block_appendexp(bcond, condition->toElem(&mystate));
        block_next(blx,BCiftrue,NULL);
        list_append(&bcond->Bsucc, blx->curblock);
        list_append(&bcond->Bsucc, mystate.breakBlock);
    }
    else
    {   /* No conditional, it's a straight goto
         */
        block_next(blx,BCgoto,NULL);
        list_append(&bcond->Bsucc, blx->curblock);
    }

    if (body)
        body->toIR(&mystate);
    /* End of the body goes to the continue block
     */
    list_append(&blx->curblock->Bsucc, mystate.contBlock);
    block_next(blx, BCgoto, mystate.contBlock);

    if (increment)
    {
        incUsage(irs, increment->loc);
        block_appendexp(mystate.contBlock, increment->toElem(&mystate));
    }

    /* The 'break' block follows the for statement.
     */
    block_next(blx,BCgoto, mystate.breakBlock);
}


/**************************************
 */

void ForeachStatement::toIR(IRState *irs)
{
    printf("ForeachStatement::toIR() %s\n", toChars());
    assert(0);  // done by "lowering" in the front end
#if 0
    Type *tab;
    elem *eaggr;
    elem *e;
    elem *elength;
    tym_t keytym;
    int isbit;

    //printf("ForeachStatement::toIR()\n");
    block *bpre;
    block *bcond;
    block *bbody;
    block *bbodyx;
    Blockx *blx = irs->blx;

    IRState mystate(irs,this);
    mystate.breakBlock = block_calloc(blx);
    mystate.contBlock = block_calloc(blx);

    tab = aggr->type->toBasetype();
    assert(tab->ty == Tarray || tab->ty == Tsarray);
    isbit = 0;

    incUsage(irs, aggr->loc);
    eaggr = aggr->toElem(irs);

    /* Create sp: pointer to start of array data
     */

    Symbol *sp = symbol_genauto(TYnptr);

    if (tab->ty == Tarray)
    {
        // stmp is copy of eaggr (the array), so eaggr is evaluated only once
        Symbol *stmp;

        // Initialize stmp
        stmp = symbol_genauto(eaggr);
        e = el_bin(OPeq, eaggr->Ety, el_var(stmp), eaggr);
        block_appendexp(blx->curblock, e);

        // Initialize sp
        e = el_una(OPmsw, TYnptr, el_var(stmp));
        e = el_bin(OPeq, TYnptr, el_var(sp), e);
        block_appendexp(blx->curblock, e);

        // Get array.length
        elength = el_var(stmp);
        elength->Ety = TYsize_t;
    }
    else // Tsarray
    {
        // Initialize sp
        e = el_una(OPaddr, TYnptr, eaggr);
        e = el_bin(OPeq, TYnptr, el_var(sp), e);
        block_appendexp(blx->curblock, e);

        // Get array.length
        elength = el_long(TYsize_t, ((TypeSArray *)tab)->dim->toInteger());
    }

    Symbol *spmax;
    Symbol *skey;

    if (key)
    {
        /* Create skey, the index to the array.
         * Initialize skey to 0 (foreach) or .length (foreach_reverse).
         */
        skey = key->toSymbol();
        symbol_add(skey);
        keytym = key->type->totym();
        elem *einit = (op == TOKforeach_reverse) ? elength : el_long(keytym, 0);
        e = el_bin(OPeq, keytym, el_var(skey), einit);
    }
    else
    {
        /* Create spmax, pointer past end of data.
         * Initialize spmax = sp + array.length * size
         */
        spmax = symbol_genauto(TYnptr);
        e = el_bin(OPmul, TYsize_t, elength, el_long(TYsize_t, tab->nextOf()->size()));
        e = el_bin(OPadd, TYnptr, el_var(sp), e);
        e = el_bin(OPeq, TYnptr, el_var(spmax), e);

        /* For foreach_reverse, swap sp and spmax
         */
        if (op == TOKforeach_reverse)
        {   Symbol *s = sp;
            sp = spmax;
            spmax = s;
        }
    }
    block_appendexp(blx->curblock, e);

    bpre = blx->curblock;
    block_next(blx,BCgoto,NULL);
    bcond = blx->curblock;

    if (key)
    {
        if (op == TOKforeach_reverse)
        {
            // Construct (key != 0)
            e = el_bin(OPne, TYint, el_var(skey), el_long(keytym, 0));
        }
        else
        {
            // Construct (key < elength)
            e = el_bin(OPlt, TYint, el_var(skey), elength);
        }
    }
    else
    {
        if (op == TOKforeach_reverse)
        {
            // Construct (sp > spmax)
            e = el_bin(OPgt, TYint, el_var(sp), el_var(spmax));
        }
        else
        {
            // Construct (sp < spmax)
            e = el_bin(OPlt, TYint, el_var(sp), el_var(spmax));
        }
    }
    bcond->Belem = e;
    block_next(blx, BCiftrue, NULL);

    if (op == TOKforeach_reverse)
    {
        if (key)
        {   // Construct (skey -= 1)
            e = el_bin(OPminass, keytym, el_var(skey), el_long(keytym, 1));
        }
        else
        {   // Construct (sp--)
            e = el_bin(OPminass, TYnptr, el_var(sp), el_long(TYsize_t, tab->nextOf()->size()));
        }
        block_appendexp(blx->curblock, e);
    }

    Symbol *s;
    FuncDeclaration *fd = NULL;
    if (value->toParent2())
        fd = value->toParent2()->isFuncDeclaration();
    int nrvo = 0;
    if (fd && fd->nrvo_can && fd->nrvo_var == value)
    {
        s = fd->shidden;
        nrvo = 1;
    }
    else
    {   s = value->toSymbol();
        symbol_add(s);
    }

    // Construct (value = *sp) or (value = sp[skey * elemsize])
    tym_t tym = value->type->totym();
    if (key)
    {   // sp + skey * elemsize
        e = el_bin(OPmul, keytym, el_var(skey), el_long(keytym, tab->nextOf()->size()));
        e = el_bin(OPadd, TYnptr, el_var(sp), e);
    }
    else
        e = el_var(sp);

    elem *evalue;
#if DMDV2
    if (value->offset)  // if value is a member of a closure
    {
        assert(irs->sclosure);
        evalue = el_var(irs->sclosure);
        evalue = el_bin(OPadd, TYnptr, evalue, el_long(TYsize_t, value->offset));
        evalue = el_una(OPind, value->type->totym(), evalue);
    }
    else
#endif
        evalue = el_var(s);

    if (value->isOut() || value->isRef())
    {
        assert(value->storage_class & (STCout | STCref));
        e = el_bin(OPeq, TYnptr, evalue, e);
    }
    else
    {
        if (nrvo)
            evalue = el_una(OPind, tym, evalue);
        e = el_bin(OPeq, tym, evalue, el_una(OPind, tym, e));
        if (tybasic(tym) == TYstruct)
        {
            e->Eoper = OPstreq;
            e->ET = value->type->toCtype();
#if DMDV2
            // Call postblit on e
            if (sd)
            {   FuncDeclaration *fd = sd->postblit;
                elem *ec = el_copytree(evalue);
                ec = el_una(OPaddr, TYnptr, ec);
                ec = callfunc(loc, irs, 1, Type::tvoid, ec, sd->type->pointerTo(), fd, fd->type, NULL, NULL);
                e = el_combine(e, ec);
            }
#endif
        }
        else if (tybasic(tym) == TYarray)
        {
            e->Eoper = OPstreq;
            e->Ejty = e->Ety = TYstruct;
            e->ET = value->type->toCtype();
        }
    }
    incUsage(irs, loc);
    block_appendexp(blx->curblock, e);

    bbody = blx->curblock;
    if (body)
        body->toIR(&mystate);
    bbodyx = blx->curblock;
    block_next(blx,BCgoto,mystate.contBlock);

    if (op == TOKforeach)
    {
        if (key)
        {   // Construct (skey += 1)
            e = el_bin(OPaddass, keytym, el_var(skey), el_long(keytym, 1));
        }
        else
        {   // Construct (sp++)
            e = el_bin(OPaddass, TYnptr, el_var(sp), el_long(TYsize_t, tab->nextOf()->size()));
        }
        mystate.contBlock->Belem = e;
    }
    block_next(blx,BCgoto,mystate.breakBlock);

    list_append(&bpre->Bsucc,bcond);
    list_append(&bcond->Bsucc,bbody);
    list_append(&bcond->Bsucc,mystate.breakBlock);
    list_append(&bbodyx->Bsucc,mystate.contBlock);
    list_append(&mystate.contBlock->Bsucc,bcond);
#endif
}


/**************************************
 */

#if DMDV2
void ForeachRangeStatement::toIR(IRState *irs)
{
    assert(0);
#if 0
    Type *tab;
    elem *eaggr;
    elem *elwr;
    elem *eupr;
    elem *e;
    elem *elength;
    tym_t keytym;
    int isbit;

    //printf("ForeachStatement::toIR()\n");
    block *bpre;
    block *bcond;
    block *bbody;
    block *bbodyx;
    Blockx *blx = irs->blx;

    IRState mystate(irs,this);
    mystate.breakBlock = block_calloc(blx);
    mystate.contBlock = block_calloc(blx);

    incUsage(irs, lwr->loc);
    elwr = lwr->toElem(irs);

    incUsage(irs, upr->loc);
    eupr = upr->toElem(irs);

    /* Create skey, the index to the array.
     * Initialize skey to elwr (foreach) or eupr (foreach_reverse).
     */
    Symbol *skey = key->toSymbol();
    symbol_add(skey);
    keytym = key->type->totym();

    elem *ekey;
    if (key->offset)            // if key is member of a closure
    {
        assert(irs->sclosure);
        ekey = el_var(irs->sclosure);
        ekey = el_bin(OPadd, TYnptr, ekey, el_long(TYsize_t, key->offset));
        ekey = el_una(OPind, keytym, ekey);
    }
    else
        ekey = el_var(skey);

    elem *einit = (op == TOKforeach_reverse) ? eupr : elwr;
    e = el_bin(OPeq, keytym, ekey, einit);   // skey = einit;
    block_appendexp(blx->curblock, e);

    /* Make a copy of the end condition, so it only
     * gets evaluated once.
     */
    elem *eend = (op == TOKforeach_reverse) ? elwr : eupr;
    Symbol *send = symbol_genauto(eend);
    e = el_bin(OPeq, eend->Ety, el_var(send), eend);
    assert(tybasic(e->Ety) != TYstruct);
    block_appendexp(blx->curblock, e);

    bpre = blx->curblock;
    block_next(blx,BCgoto,NULL);
    bcond = blx->curblock;

    if (op == TOKforeach_reverse)
    {
        // Construct (key > elwr)
        e = el_bin(OPgt, TYint, el_copytree(ekey), el_var(send));
    }
    else
    {
        // Construct (key < eupr)
        e = el_bin(OPlt, TYint, el_copytree(ekey), el_var(send));
    }

    // The size of the increment
    size_t sz = 1;
    Type *tkeyb = key->type->toBasetype();
    if (tkeyb->ty == Tpointer)
        sz = tkeyb->nextOf()->size();

    bcond->Belem = e;
    block_next(blx, BCiftrue, NULL);

    if (op == TOKforeach_reverse)
    {
        // Construct (skey -= 1)
        e = el_bin(OPminass, keytym, el_copytree(ekey), el_long(keytym, sz));
        block_appendexp(blx->curblock, e);
    }

    bbody = blx->curblock;
    if (body)
        body->toIR(&mystate);
    bbodyx = blx->curblock;
    block_next(blx,BCgoto,mystate.contBlock);

    if (op == TOKforeach)
    {
        // Construct (skey += 1)
        e = el_bin(OPaddass, keytym, el_copytree(ekey), el_long(keytym, sz));
        mystate.contBlock->Belem = e;
    }
    block_next(blx,BCgoto,mystate.breakBlock);

    list_append(&bpre->Bsucc,bcond);
    list_append(&bcond->Bsucc,bbody);
    list_append(&bcond->Bsucc,mystate.breakBlock);
    list_append(&bbodyx->Bsucc,mystate.contBlock);
    list_append(&mystate.contBlock->Bsucc,bcond);
#endif
}
#endif


/****************************************
 */

void BreakStatement::toIR(IRState *irs)
{
    block *bbreak;
    block *b;
    Blockx *blx = irs->blx;

    bbreak = irs->getBreakBlock(ident);
    assert(bbreak);
    b = blx->curblock;
    incUsage(irs, loc);

    // Adjust exception handler scope index if in different try blocks
    if (b->Btry != bbreak->Btry)
    {
        //setScopeIndex(blx, b, bbreak->Btry ? bbreak->Btry->Bscope_index : -1);
    }

    /* Nothing more than a 'goto' to the current break destination
     */
    list_append(&b->Bsucc, bbreak);
    block_next(blx, BCgoto, NULL);
}

/************************************
 */

void ContinueStatement::toIR(IRState *irs)
{
    block *bcont;
    block *b;
    Blockx *blx = irs->blx;

    //printf("ContinueStatement::toIR() %p\n", this);
    bcont = irs->getContBlock(ident);
    assert(bcont);
    b = blx->curblock;
    incUsage(irs, loc);

    // Adjust exception handler scope index if in different try blocks
    if (b->Btry != bcont->Btry)
    {
        //setScopeIndex(blx, b, bcont->Btry ? bcont->Btry->Bscope_index : -1);
    }

    /* Nothing more than a 'goto' to the current continue destination
     */
    list_append(&b->Bsucc, bcont);
    block_next(blx, BCgoto, NULL);
}

/**************************************
 */

void el_setVolatile(elem *e)
{
    elem_debug(e);
    while (1)
    {
        e->Ety |= mTYvolatile;
        if (OTunary(e->Eoper))
            e = e->E1;
        else if (OTbinary(e->Eoper))
        {   el_setVolatile(e->E2);
            e = e->E1;
        }
        else
            break;
    }
}

void VolatileStatement::toIR(IRState *irs)
{
    block *b;

    if (statement)
    {
        Blockx *blx = irs->blx;

        block_goto(blx, BCgoto, NULL);
        b = blx->curblock;

        statement->toIR(irs);

        block_goto(blx, BCgoto, NULL);

        // Mark the blocks generated as volatile
        for (; b != blx->curblock; b = b->Bnext)
        {   b->Bflags |= BFLvolatile;
            if (b->Belem)
                el_setVolatile(b->Belem);
        }
    }
}

/**************************************
 */

void GotoStatement::toIR(IRState *irs)
{
    //printf("GotoStatement::toIR() %p\n", this);
    Blockx *blx = irs->blx;

    if (!label->statement)
    {   error("label %s is undefined", label->toChars());
        return;
    }
    if (tf != label->statement->tf)
        error("cannot goto forward out of or into finally block");

    block *bdest = labelToBlock(loc, blx, label, 1);
    if (!bdest)
        return;
    block *b = blx->curblock;
    incUsage(irs, loc);

    // Adjust exception handler scope index if in different try blocks
    if (b->Btry != bdest->Btry)
    {
        // Check that bdest is in an enclosing try block
        for (block *bt = b->Btry; bt != bdest->Btry; bt = bt->Btry)
        {
            if (!bt)
            {
                //printf("b->Btry = %p, bdest->Btry = %p\n", b->Btry, bdest->Btry);
                error("cannot goto into try block");
                break;
            }
        }

        //setScopeIndex(blx, b, bdest->Btry ? bdest->Btry->Bscope_index : -1);
    }

    list_append(&b->Bsucc,bdest);
    block_next(blx,BCgoto,NULL);
}

void LabelStatement::toIR(IRState *irs)
{
    //printf("LabelStatement::toIR() %p, statement = %p\n", this, statement);
    Blockx *blx = irs->blx;
    block *bc = blx->curblock;
    IRState mystate(irs,this);
    mystate.ident = ident;

    if (lblock)
    {
        // At last, we know which try block this label is inside
        lblock->Btry = blx->tryblock;

        /* Go through the forward references and check.
         */
        if (fwdrefs)
        {
            for (size_t i = 0; i < fwdrefs->dim; i++)
            {   block *b = (block *)fwdrefs->data[i];

                if (b->Btry != lblock->Btry)
                {
                    // Check that lblock is in an enclosing try block
                    for (block *bt = b->Btry; bt != lblock->Btry; bt = bt->Btry)
                    {
                        if (!bt)
                        {
                            //printf("b->Btry = %p, lblock->Btry = %p\n", b->Btry, lblock->Btry);
                            error("cannot goto into try block");
                            break;
                        }
                    }
                }

            }
            delete fwdrefs;
            fwdrefs = NULL;
        }
    }
    else
        lblock = block_calloc(blx);
    block_next(blx,BCgoto,lblock);
    list_append(&bc->Bsucc,blx->curblock);
    if (statement)
        statement->toIR(&mystate);
}

/**************************************
 */

void SwitchStatement::toIR(IRState *irs)
{
    int string;
    Blockx *blx = irs->blx;

    //printf("SwitchStatement::toIR()\n");
    IRState mystate(irs,this);

    mystate.switchBlock = blx->curblock;

    /* Block for where "break" goes to
     */
    mystate.breakBlock = block_calloc(blx);

    /* Block for where "default" goes to.
     * If there is a default statement, then that is where default goes.
     * If not, then do:
     *   default: break;
     * by making the default block the same as the break block.
     */
    mystate.defaultBlock = sdefault ? block_calloc(blx) : mystate.breakBlock;

    int numcases = 0;
    if (cases)
        numcases = cases->dim;

    incUsage(irs, loc);
    elem *econd = condition->toElem(&mystate);
#if DMDV2
    if (hasVars)
    {   /* Generate a sequence of if-then-else blocks for the cases.
         */
        if (econd->Eoper != OPvar)
        {
            elem *e = exp2_copytotemp(econd);
            block_appendexp(mystate.switchBlock, e);
            econd = e->E2;
        }

        for (int i = 0; i < numcases; i++)
        {   CaseStatement *cs = (CaseStatement *)cases->data[i];

            elem *ecase = cs->exp->toElem(&mystate);
            elem *e = el_bin(OPeqeq, TYbool, el_copytree(econd), ecase);
            block *b = blx->curblock;
            block_appendexp(b, e);
            block *bcase = block_calloc(blx);
            cs->cblock = bcase;
            block_next(blx, BCiftrue, NULL);
            list_append(&b->Bsucc, bcase);
            list_append(&b->Bsucc, blx->curblock);
        }

        /* The final 'else' clause goes to the default
         */
        block *b = blx->curblock;
        block_next(blx, BCgoto, NULL);
        list_append(&b->Bsucc, mystate.defaultBlock);

        body->toIR(&mystate);

        /* Have the end of the switch body fall through to the block
         * following the switch statement.
         */
        block_goto(blx, BCgoto, mystate.breakBlock);
        return;
    }
#endif

    if (condition->type->isString())
    {
        // Number the cases so we can unscramble things after the sort()
        for (int i = 0; i < numcases; i++)
        {   CaseStatement *cs = (CaseStatement *)cases->data[i];
            cs->index = i;
        }

        cases->sort();

        /* Create a sorted array of the case strings, and si
         * will be the symbol for it.
         */
        dt_t *dt = NULL;
        Symbol *si = symbol_generate(SCstatic,type_fake(TYdarray));
        dtsize_t(&dt, numcases);
        dtxoff(&dt, si, Target::ptrsize * 2, TYnptr);

        for (int i = 0; i < numcases; i++)
        {   CaseStatement *cs = (CaseStatement *)cases->data[i];

            if (cs->exp->op != TOKstring)
            {   error("case '%s' is not a string", cs->exp->toChars()); // BUG: this should be an assert
            }
            else
            {
                StringExp *se = (StringExp *)(cs->exp);
                unsigned len = se->len;
                dtsize_t(&dt, len);
                dtabytes(&dt, TYnptr, 0, se->len * se->sz, (char *)se->string);
            }
        }

        si->Sdt = dt;
        si->Sfl = FLdata;
        outdata(si);

        /* Call:
         *      _d_switch_string(string[] si, string econd)
         */
        if (config.exe == EX_WIN64)
            econd = addressElem(econd, condition->type, true);
        elem *eparam = el_param(econd, (config.exe == EX_WIN64) ? el_ptr(si) : el_var(si));
        switch (condition->type->nextOf()->ty)
        {
            case Tchar:
                econd = el_bin(OPcall, TYint, el_var(getRtlsym(RTLSYM_SWITCH_STRING)), eparam);
                break;
            case Twchar:
                econd = el_bin(OPcall, TYint, el_var(getRtlsym(RTLSYM_SWITCH_USTRING)), eparam);
                break;
            case Tdchar:        // BUG: implement
                econd = el_bin(OPcall, TYint, el_var(getRtlsym(RTLSYM_SWITCH_DSTRING)), eparam);
                break;
            default:
                assert(0);
        }
        elem_setLoc(econd, loc);
        string = 1;
    }
    else
        string = 0;
    block_appendexp(mystate.switchBlock, econd);
    block_next(blx,BCswitch,NULL);

    // Corresponding free is in block_free
    targ_llong *pu = (targ_llong *) ::malloc(sizeof(*pu) * (numcases + 1));
    mystate.switchBlock->BS.Bswitch = pu;
    /* First pair is the number of cases, and the default block
     */
    *pu++ = numcases;
    list_append(&mystate.switchBlock->Bsucc, mystate.defaultBlock);

    /* Fill in the first entry in each pair, which is the case value.
     * CaseStatement::toIR() will fill in
     * the second entry for each pair with the block.
     */
    for (int i = 0; i < numcases; i++)
    {
        CaseStatement *cs = (CaseStatement *)cases->data[i];
        if (string)
        {
            pu[cs->index] = i;
        }
        else
        {
            pu[i] = cs->exp->toInteger();
        }
    }

    body->toIR(&mystate);

    /* Have the end of the switch body fall through to the block
     * following the switch statement.
     */
    block_goto(blx, BCgoto, mystate.breakBlock);
}

void CaseStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;
    block *bcase = blx->curblock;
    if (!cblock)
        cblock = block_calloc(blx);
    block_next(blx,BCgoto,cblock);
    block *bsw = irs->getSwitchBlock();
    if (bsw->BC == BCswitch)
        list_append(&bsw->Bsucc,cblock);        // second entry in pair
    list_append(&bcase->Bsucc,cblock);
    if (blx->tryblock != bsw->Btry)
        error("case cannot be in different try block level from switch");
    incUsage(irs, loc);
    if (statement)
        statement->toIR(irs);
}

void DefaultStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;
    block *bcase = blx->curblock;
    block *bdefault = irs->getDefaultBlock();
    block_next(blx,BCgoto,bdefault);
    list_append(&bcase->Bsucc,blx->curblock);
    if (blx->tryblock != irs->getSwitchBlock()->Btry)
        error("default cannot be in different try block level from switch");
    incUsage(irs, loc);
    if (statement)
        statement->toIR(irs);
}

void GotoDefaultStatement::toIR(IRState *irs)
{
    block *b;
    Blockx *blx = irs->blx;
    block *bdest = irs->getDefaultBlock();

    b = blx->curblock;

    // The rest is equivalent to GotoStatement

    // Adjust exception handler scope index if in different try blocks
    if (b->Btry != bdest->Btry)
    {
        // Check that bdest is in an enclosing try block
        for (block *bt = b->Btry; bt != bdest->Btry; bt = bt->Btry)
        {
            if (!bt)
            {
                //printf("b->Btry = %p, bdest->Btry = %p\n", b->Btry, bdest->Btry);
                error("cannot goto into try block");
                break;
            }
        }

        //setScopeIndex(blx, b, bdest->Btry ? bdest->Btry->Bscope_index : -1);
    }

    list_append(&b->Bsucc,bdest);
    incUsage(irs, loc);
    block_next(blx,BCgoto,NULL);
}

void GotoCaseStatement::toIR(IRState *irs)
{
    block *b;
    Blockx *blx = irs->blx;
    block *bdest = cs->cblock;

    if (!bdest)
    {
        bdest = block_calloc(blx);
        cs->cblock = bdest;
    }

    b = blx->curblock;

    // The rest is equivalent to GotoStatement

    // Adjust exception handler scope index if in different try blocks
    if (b->Btry != bdest->Btry)
    {
        // Check that bdest is in an enclosing try block
        for (block *bt = b->Btry; bt != bdest->Btry; bt = bt->Btry)
        {
            if (!bt)
            {
                //printf("b->Btry = %p, bdest->Btry = %p\n", b->Btry, bdest->Btry);
                error("cannot goto into try block");
                break;
            }
        }

        //setScopeIndex(blx, b, bdest->Btry ? bdest->Btry->Bscope_index : -1);
    }

    list_append(&b->Bsucc,bdest);
    incUsage(irs, loc);
    block_next(blx,BCgoto,NULL);
}

void SwitchErrorStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

    //printf("SwitchErrorStatement::toIR()\n");

    elem *efilename = blx->module->toEmodulename();
    elem *elinnum = el_long(TYint, loc.linnum);
    elem *e = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM_DSWITCHERR)), el_param(elinnum, efilename));
    block_appendexp(blx->curblock, e);
}

/**************************************
 */

void ReturnStatement::toIR(IRState *irs)
{
    //printf("ReturnStatement::toIR()\n");
    Blockx *blx = irs->blx;
    enum BC bc;

    incUsage(irs, loc);
    if (exp)
    {   elem *e;

        FuncDeclaration *func = irs->getFunc();
        assert(func);
        assert(func->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)(func->type);

        enum RET retmethod = tf->retStyle();
        if (retmethod == RETstack)
        {
            elem *es;

            /* If returning struct literal, write result
             * directly into return value
             */
            if (exp->op == TOKstructliteral)
            {   StructLiteralExp *se = (StructLiteralExp *)exp;
                char save[sizeof(StructLiteralExp)];
                memcpy(save, (void*)se, sizeof(StructLiteralExp));
                se->sym = irs->shidden;
                se->soffset = 0;
                se->fillHoles = 1;
                e = exp->toElem(irs);
                memcpy((void*)se, save, sizeof(StructLiteralExp));

            }
            else
                e = exp->toElem(irs);
            assert(e);

            if (exp->op == TOKstructliteral ||
                (func->nrvo_can && func->nrvo_var))
            {
                // Return value via hidden pointer passed as parameter
                // Write exp; return shidden;
                es = e;
            }
            else
            {
                // Return value via hidden pointer passed as parameter
                // Write *shidden=exp; return shidden;
                tym_t ety = e->Ety;
                es = el_una(OPind,ety,el_var(irs->shidden));
                int op = (tybasic(ety) == TYstruct) ? OPstreq : OPeq;
                es = el_bin(op, ety, es, e);
                if (op == OPstreq)
                    es->ET = exp->type->toCtype();
#if DMDV2
                /* Call postBlit() on *shidden
                 */
                Type *tb = exp->type->toBasetype();
                if (tb->ty == Tstruct)
                {   StructDeclaration *sd = ((TypeStruct *)tb)->sym;
                    if (sd->postblit)
                    {   FuncDeclaration *fd = sd->postblit;
                        elem *ec = el_var(irs->shidden);
                        ec = callfunc(loc, irs, 1, Type::tvoid, ec, tb->pointerTo(), fd, fd->type, NULL, NULL);
                        es = el_bin(OPcomma, ec->Ety, es, ec);
                    }
                }
#endif
            }
            e = el_var(irs->shidden);
            e = el_bin(OPcomma, e->Ety, es, e);
        }
#if DMDV2
        else if (tf->isref)
        {   // Reference return, so convert to a pointer
            Expression *ae = exp->addressOf(NULL);
            e = ae->toElemDtor(irs);
        }
#endif
        else
        {
            e = exp->toElem(irs);
            assert(e);
        }

        elem_setLoc(e, loc);
        block_appendexp(blx->curblock, e);
        bc = BCretexp;
    }
    else
        bc = BCret;

    block *btry = blx->curblock->Btry;
    if (btry)
    {
        // A finally block is a successor to a return block inside a try-finally
        if (list_nitems(btry->Bsucc) == 2)      // try-finally
        {
            block *bfinally = list_block(list_next(btry->Bsucc));
            assert(bfinally->BC == BC_finally);
            list_append(&blx->curblock->Bsucc, bfinally);
        }
    }
    block_next(blx, bc, NULL);
}

/**************************************
 */

void ExpStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

    //printf("ExpStatement::toIR(), exp = %s\n", exp ? exp->toChars() : "");
    incUsage(irs, loc);
    if (exp)
        block_appendexp(blx->curblock,exp->toElem(irs));
}

/**************************************
 */

void CompoundStatement::toIR(IRState *irs)
{
    //printf("CompoundStatement::toIR() %p\n", this);
    if (statements)
    {
        size_t dim = statements->dim;
        for (size_t i = 0 ; i < dim ; i++)
        {
            Statement *s = (Statement *)statements->data[i];
            if (s != NULL)
            {
                s->toIR(irs);
            }
        }
    }
}


/**************************************
 */

void UnrolledLoopStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

    IRState mystate(irs, this);
    mystate.breakBlock = block_calloc(blx);

    block *bpre = blx->curblock;
    block_next(blx, BCgoto, NULL);

    block *bdo = blx->curblock;
    list_append(&bpre->Bsucc, bdo);

    block *bdox;

    size_t dim = statements->dim;
    for (size_t i = 0 ; i < dim ; i++)
    {
        Statement *s = (Statement *)statements->data[i];
        if (s != NULL)
        {
            mystate.contBlock = block_calloc(blx);

            s->toIR(&mystate);

            bdox = blx->curblock;
            block_next(blx, BCgoto, mystate.contBlock);
            list_append(&bdox->Bsucc, mystate.contBlock);
        }
    }

    bdox = blx->curblock;
    block_next(blx, BCgoto, mystate.breakBlock);
    list_append(&bdox->Bsucc, mystate.breakBlock);
}


/**************************************
 */

void ScopeStatement::toIR(IRState *irs)
{
    //printf("ScopeStatement::toIR() %p\n", this);
    if (statement)
    {
        Blockx *blx = irs->blx;
        IRState mystate(irs,this);

        if (mystate.prev->ident)
            mystate.ident = mystate.prev->ident;

        statement->toIR(&mystate);

        if (mystate.breakBlock)
            block_goto(blx,BCgoto,mystate.breakBlock);
    }
}

/***************************************
 */

void WithStatement::toIR(IRState *irs)
{
    Symbol *sp;
    elem *e;
    elem *ei;
    ExpInitializer *ie;
    Blockx *blx = irs->blx;

    //printf("WithStatement::toIR()\n");
    if (exp->op == TOKimport || exp->op == TOKtype)
    {
    }
    else
    {
        // Declare with handle
        sp = wthis->toSymbol();
        symbol_add(sp);

        // Perform initialization of with handle
        ie = wthis->init->isExpInitializer();
        assert(ie);
        ei = ie->exp->toElem(irs);
        e = el_var(sp);
        e = el_bin(OPeq,e->Ety, e, ei);
        elem_setLoc(e, loc);
        incUsage(irs, loc);
        block_appendexp(blx->curblock,e);
    }
    // Execute with block
    if (body)
        body->toIR(irs);
}


/***************************************
 */

void ThrowStatement::toIR(IRState *irs)
{
    // throw(exp)

    Blockx *blx = irs->blx;

    incUsage(irs, loc);
    elem *e = exp->toElem(irs);
#if 0 && TARGET_WINDOS
    int rtl = config.exe == EX_WIN64 ? RTLSYM_THROWC : RTLSYM_THROW;
#else
    int rtl = RTLSYM_THROWC;
#endif
    e = el_bin(OPcall, TYvoid, el_var(getRtlsym(rtl)),e);
    block_appendexp(blx->curblock, e);
}

/***************************************
 * Builds the following:
 *      _try
 *      block
 *      jcatch
 *      handler
 * A try-catch statement.
 */

void TryCatchStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

#if SEH
    if (!global.params.is64bit)
        nteh_declarvars(blx);
#endif

    IRState mystate(irs, this);

    block *tryblock = block_goto(blx,BCgoto,NULL);

    int previndex = blx->scope_index;
    tryblock->Blast_index = previndex;
    blx->scope_index = tryblock->Bscope_index = blx->next_index++;

    // Set the current scope index
    setScopeIndex(blx,tryblock,tryblock->Bscope_index);

    // This is the catch variable
    tryblock->jcatchvar = symbol_genauto(type_fake(mTYvolatile | TYnptr));

    blx->tryblock = tryblock;
    block *breakblock = block_calloc(blx);
    block_goto(blx,BC_try,NULL);
    if (body)
    {
        body->toIR(&mystate);
    }
    blx->tryblock = tryblock->Btry;

    // break block goes here
    block_goto(blx, BCgoto, breakblock);

    setScopeIndex(blx,blx->curblock, previndex);
    blx->scope_index = previndex;

    // create new break block that follows all the catches
    breakblock = block_calloc(blx);

    list_append(&blx->curblock->Bsucc, breakblock);
    block_next(blx,BCgoto,NULL);

    assert(catches);
    for (size_t i = 0 ; i < catches->dim; i++)
    {
        Catch *cs = (Catch *)(catches->data[i]);
        if (cs->var)
            cs->var->csym = tryblock->jcatchvar;
        block *bcatch = blx->curblock;
        if (cs->type)
            bcatch->Bcatchtype = cs->type->toBasetype()->toSymbol();
        list_append(&tryblock->Bsucc,bcatch);
        block_goto(blx,BCjcatch,NULL);
        if (cs->handler != NULL)
        {
            IRState catchState(irs, this);
            cs->handler->toIR(&catchState);
        }
        list_append(&blx->curblock->Bsucc, breakblock);
        block_next(blx, BCgoto, NULL);
    }

    block_next(blx,(enum BC)blx->curblock->BC, breakblock);
}

/****************************************
 * A try-finally statement.
 * Builds the following:
 *      _try
 *      block
 *      _finally
 *      finalbody
 *      _ret
 */

void TryFinallyStatement::toIR(IRState *irs)
{
    //printf("TryFinallyStatement::toIR()\n");

    Blockx *blx = irs->blx;

#if SEH
    if (!global.params.is64bit)
        nteh_declarvars(blx);
#endif

    block *tryblock = block_goto(blx, BCgoto, NULL);

    int previndex = blx->scope_index;
    tryblock->Blast_index = previndex;
    tryblock->Bscope_index = blx->next_index++;
    blx->scope_index = tryblock->Bscope_index;

    // Current scope index
    setScopeIndex(blx,tryblock,tryblock->Bscope_index);

    blx->tryblock = tryblock;
    block_goto(blx,BC_try,NULL);

    IRState bodyirs(irs, this);
    block *breakblock = block_calloc(blx);
    block *contblock = block_calloc(blx);
    list_append(&tryblock->Bsucc,contblock);
    contblock->BC = BC_finally;

    if (body)
        body->toIR(&bodyirs);
    blx->tryblock = tryblock->Btry;     // back to previous tryblock

    setScopeIndex(blx,blx->curblock,previndex);
    blx->scope_index = previndex;

    block_goto(blx,BCgoto, breakblock);
    block *finallyblock = block_goto(blx,BCgoto,contblock);
    assert(finallyblock == contblock);

    block_goto(blx,BC_finally,NULL);

    IRState finallyState(irs, this);
    breakblock = block_calloc(blx);
    contblock = block_calloc(blx);

    setScopeIndex(blx, blx->curblock, previndex);
    if (finalbody)
        finalbody->toIR(&finallyState);
    block_goto(blx, BCgoto, contblock);
    block_goto(blx, BCgoto, breakblock);

    block *retblock = blx->curblock;
    block_next(blx,BC_ret,NULL);

    list_append(&finallyblock->Bsucc, blx->curblock);
    list_append(&retblock->Bsucc, blx->curblock);
}

/****************************************
 */

void SynchronizedStatement::toIR(IRState *irs)
{
    assert(0);
}


/****************************************
 */

void AsmStatement::toIR(IRState *irs)
{
    block *bpre;
    block *basm;
    Declaration *d;
    Symbol *s;
    Blockx *blx = irs->blx;

    //printf("AsmStatement::toIR(asmcode = %x)\n", asmcode);
    bpre = blx->curblock;
    block_next(blx,BCgoto,NULL);
    basm = blx->curblock;
    list_append(&bpre->Bsucc, basm);
    basm->Bcode = asmcode;
    basm->Balign = asmalign;
#if 0
    if (label)
    {   block *b;

        b = labelToBlock(loc, blx, label);
        printf("AsmStatement::toIR() %p\n", b);
        if (b)
            list_append(&basm->Bsucc, b);
    }
#endif
    // Loop through each instruction, fixing Dsymbols into Symbol's
    for (code *c = asmcode; c; c = c->next)
    {   LabelDsymbol *label;
        block *b;

        switch (c->IFL1)
        {
            case FLblockoff:
            case FLblock:
                // FLblock and FLblockoff have LabelDsymbol's - convert to blocks
                label = c->IEVlsym1;
                b = labelToBlock(loc, blx, label);
                list_append(&basm->Bsucc, b);
                c->IEV1.Vblock = b;
                break;

            case FLdsymbol:
            case FLfunc:
                s = c->IEVdsym1->toSymbol();
                if (s->Sclass == SCauto && s->Ssymnum == -1)
                    symbol_add(s);
                c->IEVsym1 = s;
                c->IFL1 = s->Sfl ? s->Sfl : FLauto;
                break;
        }

#if TX86
        // Repeat for second operand
        switch (c->IFL2)
        {
            case FLblockoff:
            case FLblock:
                label = c->IEVlsym2;
                b = labelToBlock(loc, blx, label);
                list_append(&basm->Bsucc, b);
                c->IEV2.Vblock = b;
                break;

            case FLdsymbol:
            case FLfunc:
                d = c->IEVdsym2;
                s = d->toSymbol();
                if (s->Sclass == SCauto && s->Ssymnum == -1)
                    symbol_add(s);
                c->IEVsym2 = s;
                c->IFL2 = s->Sfl ? s->Sfl : FLauto;
                if (d->isDataseg())
                    s->Sflags |= SFLlivexit;
                break;
        }
#endif
        //c->print();
    }

    basm->bIasmrefparam = refparam;             // are parameters reference?
    basm->usIasmregs = regs;                    // registers modified

    block_next(blx,BCasm, NULL);
    list_prepend(&basm->Bsucc, blx->curblock);

    if (naked)
    {
        blx->funcsym->Stype->Tty |= mTYnaked;
    }
}
