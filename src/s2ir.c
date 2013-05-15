
// Compiler implementation of the D programming language
// Copyright (c) 2000-2013 by Digital Mars
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

elem *callfunc(Loc loc,
        IRState *irs,
        int directcall,         // 1: don't do virtual call
        Type *tret,             // return type
        elem *ec,               // evaluates to function address
        Type *ectype,           // original type of ec
        FuncDeclaration *fd,    // if !=NULL, this is the function being called
        Type *t,                // TypeDelegate or TypeFunction for this function
        elem *ehidden,          // if !=NULL, this is the 'hidden' argument
        Expressions *arguments);

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
    e = condition->toElemDtor(&mystate);
    block_appendexp(blx->curblock, e);
    block *bcond = blx->curblock;
    block_next(blx, BCiftrue, NULL);

    bcond->appendSucc(blx->curblock);
    if (ifbody)
        ifbody->toIR(&mystate);
    blx->curblock->appendSucc(bexit);

    if (elsebody)
    {
        block_next(blx, BCgoto, NULL);
        bcond->appendSucc(blx->curblock);
        elsebody->toIR(&mystate);
        blx->curblock->appendSucc(bexit);
    }
    else
        bcond->appendSucc(bexit);

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
    bpre->appendSucc(blx->curblock);

    mystate.contBlock->appendSucc(blx->curblock);
    mystate.contBlock->appendSucc(mystate.breakBlock);

    if (body)
        body->toIR(&mystate);
    blx->curblock->appendSucc(mystate.contBlock);

    block_next(blx, BCgoto, mystate.contBlock);
    incUsage(irs, condition->loc);
    block_appendexp(mystate.contBlock, condition->toElemDtor(&mystate));
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
    bpre->appendSucc(bcond);
    mystate.contBlock->appendSucc(bcond);
    if (condition)
    {
        incUsage(irs, condition->loc);
        block_appendexp(bcond, condition->toElemDtor(&mystate));
        block_next(blx,BCiftrue,NULL);
        bcond->appendSucc(blx->curblock);
        bcond->appendSucc(mystate.breakBlock);
    }
    else
    {   /* No conditional, it's a straight goto
         */
        block_next(blx,BCgoto,NULL);
        bcond->appendSucc(blx->curblock);
    }

    if (body)
        body->toIR(&mystate);
    /* End of the body goes to the continue block
     */
    blx->curblock->appendSucc(mystate.contBlock);
    block_next(blx, BCgoto, mystate.contBlock);

    if (increment)
    {
        incUsage(irs, increment->loc);
        block_appendexp(mystate.contBlock, increment->toElemDtor(&mystate));
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
}


/**************************************
 */

#if DMDV2
void ForeachRangeStatement::toIR(IRState *irs)
{
    assert(0);
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
    b->appendSucc(bbreak);
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
    b->appendSucc(bcont);
    block_next(blx, BCgoto, NULL);
}


/**************************************
 */

void GotoStatement::toIR(IRState *irs)
{
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
    }

    b->appendSucc(bdest);
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
            {   block *b = (*fwdrefs)[i];

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
    bc->appendSucc(blx->curblock);
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

    size_t numcases = 0;
    if (cases)
        numcases = cases->dim;

    incUsage(irs, loc);
    elem *econd = condition->toElemDtor(&mystate);
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

        for (size_t i = 0; i < numcases; i++)
        {   CaseStatement *cs = (*cases)[i];

            elem *ecase = cs->exp->toElemDtor(&mystate);
            elem *e = el_bin(OPeqeq, TYbool, el_copytree(econd), ecase);
            block *b = blx->curblock;
            block_appendexp(b, e);
            block *bcase = block_calloc(blx);
            cs->cblock = bcase;
            block_next(blx, BCiftrue, NULL);
            b->appendSucc(bcase);
            b->appendSucc(blx->curblock);
        }

        /* The final 'else' clause goes to the default
         */
        block *b = blx->curblock;
        block_next(blx, BCgoto, NULL);
        b->appendSucc(mystate.defaultBlock);

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
        for (size_t i = 0; i < numcases; i++)
        {   CaseStatement *cs = (*cases)[i];
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

        for (size_t i = 0; i < numcases; i++)
        {   CaseStatement *cs = (*cases)[i];

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
                econd = el_bin(OPcall, TYint, el_var(rtlsym[RTLSYM_SWITCH_STRING]), eparam);
                break;
            case Twchar:
                econd = el_bin(OPcall, TYint, el_var(rtlsym[RTLSYM_SWITCH_USTRING]), eparam);
                break;
            case Tdchar:        // BUG: implement
                econd = el_bin(OPcall, TYint, el_var(rtlsym[RTLSYM_SWITCH_DSTRING]), eparam);
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
    mystate.switchBlock->appendSucc(mystate.defaultBlock);

    /* Fill in the first entry in each pair, which is the case value.
     * CaseStatement::toIR() will fill in
     * the second entry for each pair with the block.
     */
    for (size_t i = 0; i < numcases; i++)
    {
        CaseStatement *cs = (*cases)[i];
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
        bsw->appendSucc(cblock);        // second entry in pair
    bcase->appendSucc(cblock);
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
    bcase->appendSucc(blx->curblock);
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

    b->appendSucc(bdest);
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

    b->appendSucc(bdest);
    incUsage(irs, loc);
    block_next(blx,BCgoto,NULL);
}

void SwitchErrorStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;

    //printf("SwitchErrorStatement::toIR()\n");

    elem *efilename = el_ptr(blx->module->toSymbol());
    elem *elinnum = el_long(TYint, loc.linnum);
    elem *e = el_bin(OPcall, TYvoid, el_var(rtlsym[RTLSYM_DSWITCHERR]), el_param(elinnum, efilename));
    block_appendexp(blx->curblock, e);
}

/**************************************
 */

void ReturnStatement::toIR(IRState *irs)
{
    Blockx *blx = irs->blx;
    enum BC bc;

    incUsage(irs, loc);
    if (exp)
    {   elem *e;

        FuncDeclaration *func = irs->getFunc();
        assert(func);
        assert(func->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)(func->type);

        RET retmethod = tf->retStyle();
        if (retmethod == RETstack)
        {
            elem *es;

            /* If returning struct literal, write result
             * directly into return value
             */
            if (exp->op == TOKstructliteral)
            {   StructLiteralExp *se = (StructLiteralExp *)exp;
                char save[sizeof(StructLiteralExp)];
                memcpy(save, se, sizeof(StructLiteralExp));
                se->sym = irs->shidden;
                se->soffset = 0;
                se->fillHoles = 1;
                e = exp->toElemDtor(irs);
                memcpy(se, save, sizeof(StructLiteralExp));

            }
            else
                e = exp->toElemDtor(irs);
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
                int op;
                tym_t ety;

                ety = e->Ety;
                es = el_una(OPind,ety,el_var(irs->shidden));
                op = (tybasic(ety) == TYstruct) ? OPstreq : OPeq;
                es = el_bin(op, ety, es, e);
                if (op == OPstreq)
                    es->ET = exp->type->toCtype();
#if 0//DMDV2
                /* Call postBlit() on *shidden
                 */
                Type *tb = exp->type->toBasetype();
                //if (tb->ty == Tstruct) exp->dump(0);
                if (exp->isLvalue() && tb->ty == Tstruct)
                {   StructDeclaration *sd = ((TypeStruct *)tb)->sym;
                    if (sd->postblit)
                    {   FuncDeclaration *fd = sd->postblit;
                        if (fd->storage_class & STCdisable)
                        {
                            fd->toParent()->error(loc, "is not copyable because it is annotated with @disable");
                        }
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
            e = exp->toElemDtor(irs);
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
        if (btry->numSucc() == 2)      // try-finally
        {
            block *bfinally = btry->nthSucc(1);
            assert(bfinally->BC == BC_finally);
            blx->curblock->appendSucc(bfinally);
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
        block_appendexp(blx->curblock,exp->toElemDtor(irs));
}

/**************************************
 */

void DtorExpStatement::toIR(IRState *irs)
{
    //printf("DtorExpStatement::toIR(), exp = %s\n", exp ? exp->toChars() : "");

    FuncDeclaration *fd = irs->getFunc();
    assert(fd);
    if (fd->nrvo_can && fd->nrvo_var == var)
        /* Do not call destructor, because var is returned as the nrvo variable.
         * This is done at this stage because nrvo can be turned off at a
         * very late stage in semantic analysis.
         */
        ;
    else
    {
        ExpStatement::toIR(irs);
    }
}

/**************************************
 */

void CompoundStatement::toIR(IRState *irs)
{
    if (statements)
    {
        size_t dim = statements->dim;
        for (size_t i = 0 ; i < dim ; i++)
        {
            Statement *s = (*statements)[i];
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
    bpre->appendSucc(bdo);

    block *bdox;

    size_t dim = statements->dim;
    for (size_t i = 0 ; i < dim ; i++)
    {
        Statement *s = (*statements)[i];
        if (s != NULL)
        {
            mystate.contBlock = block_calloc(blx);

            s->toIR(&mystate);

            bdox = blx->curblock;
            block_next(blx, BCgoto, mystate.contBlock);
            bdox->appendSucc(mystate.contBlock);
        }
    }

    bdox = blx->curblock;
    block_next(blx, BCgoto, mystate.breakBlock);
    bdox->appendSucc(mystate.breakBlock);
}


/**************************************
 */

void ScopeStatement::toIR(IRState *irs)
{
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
        ei = ie->exp->toElemDtor(irs);
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
    elem *e = exp->toElemDtor(irs);
    e = el_bin(OPcall, TYvoid, el_var(rtlsym[RTLSYM_THROWC]),e);
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

    blx->curblock->appendSucc(breakblock);
    block_next(blx,BCgoto,NULL);

    assert(catches);
    for (size_t i = 0 ; i < catches->dim; i++)
    {
        Catch *cs = (*catches)[i];
        if (cs->var)
            cs->var->csym = tryblock->jcatchvar;
        block *bcatch = blx->curblock;
        if (cs->type)
            bcatch->Bcatchtype = cs->type->toBasetype()->toSymbol();
        tryblock->appendSucc(bcatch);
        block_goto(blx,BCjcatch,NULL);
        if (cs->handler != NULL)
        {
            IRState catchState(irs, this);
            cs->handler->toIR(&catchState);
        }
        blx->curblock->appendSucc(breakblock);
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
    tryblock->appendSucc(contblock);
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

    finallyblock->appendSucc(blx->curblock);
    retblock->appendSucc(blx->curblock);
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
    bpre->appendSucc(basm);
    basm->Bcode = asmcode;
    basm->Balign = asmalign;
#if 0
    if (label)
    {   block *b;

        b = labelToBlock(loc, blx, label);
        printf("AsmStatement::toIR() %p\n", b);
        if (b)
            basm->appendSucc(b);
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
                basm->appendSucc(b);
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
                basm->appendSucc(b);
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
    basm->prependSucc(blx->curblock);

    if (naked)
    {
        blx->funcsym->Stype->Tty |= mTYnaked;
    }
}

/****************************************
 */

void ImportStatement::toIR(IRState *irs)
{
}



