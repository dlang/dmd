
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/s2ir.c
 */

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "mars.h"
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

#include        "aav.h"
#include        "rmem.h"
#include        "target.h"
#include        "visitor.h"

Symbol *toStringSymbol(StringExp *se);
elem *exp2_copytotemp(elem *e);
elem *incUsageElem(IRState *irs, Loc loc);
elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);
type *Type_toCtype(Type *t);
elem *toElemDtor(Expression *e, IRState *irs);
Symbol *toSymbol(Type *t);
unsigned totym(Type *tx);
Symbol *toSymbol(Dsymbol *s);
RET retStyle(TypeFunction *tf);

#define elem_setLoc(e,loc)      srcpos_setLoc(&(e)->Esrcpos, loc)
#define block_setLoc(b,loc)     srcpos_setLoc(&(b)->Bsrcpos, loc)

#define srcpos_setLoc(s,loc)    ((s)->Sfilename = (char *)(loc).filename, \
                                 (s)->Slinnum = (loc).linnum, \
                                 (s)->Scharnum = (loc).charnum)

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

/****************************************
 * Our label symbol, with vector to keep track of forward references.
 */

struct Label
{
    block *lblock;      // The block to which the label is defined.
    block *fwdrefs;     // The first use of the label before it is defined.
};

/****************************************
 * Get or create a label declaration.
 */

static Label *getLabel(IRState *irs, Blockx *blx, Statement *s)
{
    Label **slot = (Label **)dmd_aaGet(irs->labels, (void *)s);

    if (*slot == NULL)
    {
        Label *label = new Label();
        label->lblock = blx ? block_calloc(blx) : block_calloc();
        label->fwdrefs = NULL;
        *slot = label;
    }
    return *slot;
}

/**************************************
 * Convert label to block.
 */

block *labelToBlock(IRState *irs, Loc loc, Blockx *blx, LabelDsymbol *label, int flag = 0)
{
    if (!label->statement)
    {
        error(loc, "undefined label %s", label->toChars());
        return NULL;
    }
    Label *l = getLabel(irs, NULL, label->statement);
    if (flag)
    {
        // Keep track of the forward reference to this block, so we can check it later
        if (!l->fwdrefs)
            l->fwdrefs = blx->curblock;
    }
    return l->lblock;
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

void Statement_toIR(Statement *s, IRState *irs);

class S2irVisitor : public Visitor
{
    IRState *irs;
public:
    S2irVisitor(IRState *irs) : irs(irs) {}

    /****************************************
     * This should be overridden by each statement class.
     */

    void visit(Statement *s)
    {
        s->print();
        assert(0);
    }

    /*************************************
     */

    void visit(OnScopeStatement *s)
    {
    }

    /****************************************
     */

    void visit(IfStatement *s)
    {
        elem *e;
        Blockx *blx = irs->blx;

        //printf("IfStatement::toIR('%s')\n", s->condition->toChars());

        IRState mystate(irs, s);

        // bexit is the block that gets control after this IfStatement is done
        block *bexit = mystate.breakBlock ? mystate.breakBlock : block_calloc();

        incUsage(irs, s->loc);
        e = toElemDtor(s->condition, &mystate);
        block_appendexp(blx->curblock, e);
        block *bcond = blx->curblock;
        block_next(blx, BCiftrue, NULL);

        bcond->appendSucc(blx->curblock);
        if (s->ifbody)
            Statement_toIR(s->ifbody, &mystate);
        blx->curblock->appendSucc(bexit);

        if (s->elsebody)
        {
            block_next(blx, BCgoto, NULL);
            bcond->appendSucc(blx->curblock);
            Statement_toIR(s->elsebody, &mystate);
            blx->curblock->appendSucc(bexit);
        }
        else
            bcond->appendSucc(bexit);

        block_next(blx, BCgoto, bexit);

    }

    /**************************************
     */

    void visit(PragmaStatement *s)
    {
        //printf("PragmaStatement::toIR()\n");
        if (s->ident == Id::startaddress)
        {
            assert(s->args && s->args->dim == 1);
            Expression *e = (*s->args)[0];
            Dsymbol *sa = getDsymbol(e);
            FuncDeclaration *f = sa->isFuncDeclaration();
            assert(f);
            Symbol *sym = toSymbol(f);
            while (irs->prev)
                irs = irs->prev;
            irs->startaddress = sym;
        }
    }

    /***********************
     */

    void visit(WhileStatement *s)
    {
        assert(0); // was "lowered"
    }

    /******************************************
     */

    void visit(DoStatement *s)
    {
        Blockx *blx = irs->blx;

        IRState mystate(irs,s);
        mystate.breakBlock = block_calloc(blx);
        mystate.contBlock = block_calloc(blx);

        block *bpre = blx->curblock;
        block_next(blx, BCgoto, NULL);
        bpre->appendSucc(blx->curblock);

        mystate.contBlock->appendSucc(blx->curblock);
        mystate.contBlock->appendSucc(mystate.breakBlock);

        if (s->_body)
            Statement_toIR(s->_body, &mystate);
        blx->curblock->appendSucc(mystate.contBlock);

        block_next(blx, BCgoto, mystate.contBlock);
        incUsage(irs, s->condition->loc);
        block_appendexp(mystate.contBlock, toElemDtor(s->condition, &mystate));
        block_next(blx, BCiftrue, mystate.breakBlock);

    }

    /*****************************************
     */

    void visit(ForStatement *s)
    {
        //printf("visit(ForStatement)) %u..%u\n", s->loc.linnum, s->endloc.linnum);
        Blockx *blx = irs->blx;

        IRState mystate(irs,s);
        mystate.breakBlock = block_calloc(blx);
        mystate.contBlock = block_calloc(blx);

        if (s->_init)
            Statement_toIR(s->_init, &mystate);
        block *bpre = blx->curblock;
        block_next(blx,BCgoto,NULL);
        block *bcond = blx->curblock;
        bpre->appendSucc(bcond);
        mystate.contBlock->appendSucc(bcond);
        if (s->condition)
        {
            incUsage(irs, s->condition->loc);
            block_appendexp(bcond, toElemDtor(s->condition, &mystate));
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

        if (s->_body)
            Statement_toIR(s->_body, &mystate);
        /* End of the body goes to the continue block
         */
        blx->curblock->appendSucc(mystate.contBlock);
        block_setLoc(blx->curblock, s->endloc);
        block_next(blx, BCgoto, mystate.contBlock);

        if (s->increment)
        {
            incUsage(irs, s->increment->loc);
            block_appendexp(mystate.contBlock, toElemDtor(s->increment, &mystate));
        }

        /* The 'break' block follows the for statement.
         */
        block_next(blx,BCgoto, mystate.breakBlock);
    }


    /**************************************
     */

    void visit(ForeachStatement *s)
    {
        printf("ForeachStatement::toIR() %s\n", s->toChars());
        assert(0);  // done by "lowering" in the front end
    }


    /**************************************
     */

    void visit(ForeachRangeStatement *s)
    {
        assert(0);
    }


    /****************************************
     */

    void visit(BreakStatement *s)
    {
        block *bbreak;
        block *b;
        Blockx *blx = irs->blx;

        bbreak = irs->getBreakBlock(s->ident);
        assert(bbreak);
        b = blx->curblock;
        incUsage(irs, s->loc);

        // Adjust exception handler scope index if in different try blocks
        if (b->Btry != bbreak->Btry)
        {
            //setScopeIndex(blx, b, bbreak->Btry ? bbreak->Btry->Bscope_index : -1);
        }

        /* Nothing more than a 'goto' to the current break destination
         */
        b->appendSucc(bbreak);
        block_setLoc(b, s->loc);
        block_next(blx, BCgoto, NULL);
    }

    /************************************
     */

    void visit(ContinueStatement *s)
    {
        block *bcont;
        block *b;
        Blockx *blx = irs->blx;

        //printf("ContinueStatement::toIR() %p\n", this);
        bcont = irs->getContBlock(s->ident);
        assert(bcont);
        b = blx->curblock;
        incUsage(irs, s->loc);

        // Adjust exception handler scope index if in different try blocks
        if (b->Btry != bcont->Btry)
        {
            //setScopeIndex(blx, b, bcont->Btry ? bcont->Btry->Bscope_index : -1);
        }

        /* Nothing more than a 'goto' to the current continue destination
         */
        b->appendSucc(bcont);
        block_setLoc(b, s->loc);
        block_next(blx, BCgoto, NULL);
    }


    /**************************************
     */

    void visit(GotoStatement *s)
    {
        Blockx *blx = irs->blx;

        assert(s->label->statement);
        assert(s->tf == s->label->statement->tf);

        block *bdest = labelToBlock(irs, s->loc, blx, s->label, 1);
        if (!bdest)
            return;
        block *b = blx->curblock;
        incUsage(irs, s->loc);
        b->appendSucc(bdest);
        block_setLoc(b, s->loc);

        // Check that bdest is in an enclosing try block
        for (block *bt = b->Btry; bt != bdest->Btry; bt = bt->Btry)
        {
            if (!bt)
            {
                //printf("b->Btry = %p, bdest->Btry = %p\n", b->Btry, bdest->Btry);
                s->error("cannot goto into try block");
                break;
            }
        }

        block_next(blx,BCgoto,NULL);
    }

    void visit(LabelStatement *s)
    {
        //printf("LabelStatement::toIR() %p, statement = %p\n", this, statement);
        Blockx *blx = irs->blx;
        block *bc = blx->curblock;
        IRState mystate(irs,s);
        mystate.ident = s->ident;

        Label *label = getLabel(irs, blx, s);
        // At last, we know which try block this label is inside
        label->lblock->Btry = blx->tryblock;

        // Go through the forward references and check.
        if (label->fwdrefs)
        {
            block *b = label->fwdrefs;

            if (b->Btry != label->lblock->Btry)
            {
                // Check that lblock is in an enclosing try block
                for (block *bt = b->Btry; bt != label->lblock->Btry; bt = bt->Btry)
                {
                    if (!bt)
                    {
                        //printf("b->Btry = %p, label->lblock->Btry = %p\n", b->Btry, label->lblock->Btry);
                        s->error("cannot goto into try block");
                        break;
                    }

                }
            }
        }
        block_next(blx, BCgoto, label->lblock);
        bc->appendSucc(blx->curblock);
        if (s->statement)
            Statement_toIR(s->statement, &mystate);
    }

    /**************************************
     */

    void visit(SwitchStatement *s)
    {
        int string;
        Blockx *blx = irs->blx;

        //printf("SwitchStatement::toIR()\n");
        IRState mystate(irs,s);

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
        mystate.defaultBlock = s->sdefault ? block_calloc(blx) : mystate.breakBlock;

        size_t numcases = 0;
        if (s->cases)
            numcases = s->cases->dim;

        incUsage(irs, s->loc);
        elem *econd = toElemDtor(s->condition, &mystate);
        if (s->hasVars)
        {   /* Generate a sequence of if-then-else blocks for the cases.
             */
            if (econd->Eoper != OPvar)
            {
                elem *e = exp2_copytotemp(econd);
                block_appendexp(mystate.switchBlock, e);
                econd = e->E2;
            }

            for (size_t i = 0; i < numcases; i++)
            {   CaseStatement *cs = (*s->cases)[i];

                elem *ecase = toElemDtor(cs->exp, &mystate);
                elem *e = el_bin(OPeqeq, TYbool, el_copytree(econd), ecase);
                block *b = blx->curblock;
                block_appendexp(b, e);
                Label *clabel = getLabel(irs, blx, cs);
                block_next(blx, BCiftrue, NULL);
                b->appendSucc(clabel->lblock);
                b->appendSucc(blx->curblock);
            }

            /* The final 'else' clause goes to the default
             */
            block *b = blx->curblock;
            block_next(blx, BCgoto, NULL);
            b->appendSucc(mystate.defaultBlock);

            Statement_toIR(s->_body, &mystate);

            /* Have the end of the switch body fall through to the block
             * following the switch statement.
             */
            block_goto(blx, BCgoto, mystate.breakBlock);
            return;
        }

        if (s->condition->type->isString())
        {
            // Number the cases so we can unscramble things after the sort()
            for (size_t i = 0; i < numcases; i++)
            {   CaseStatement *cs = (*s->cases)[i];
                cs->index = i;
            }

            s->cases->sort();

            /* Create a sorted array of the case strings, and si
             * will be the symbol for it.
             */
            dt_t *dt = NULL;
            Symbol *si = symbol_generate(SCstatic,type_fake(TYdarray));
            dtsize_t(&dt, numcases);
            dtxoff(&dt, si, Target::ptrsize * 2, TYnptr);

            for (size_t i = 0; i < numcases; i++)
            {   CaseStatement *cs = (*s->cases)[i];

                if (cs->exp->op != TOKstring)
                {   s->error("case '%s' is not a string", cs->exp->toChars()); // BUG: this should be an assert
                }
                else
                {
                    StringExp *se = (StringExp *)(cs->exp);
                    Symbol *si = toStringSymbol(se);
                    dtsize_t(&dt, se->numberOfCodeUnits());
                    dtxoff(&dt, si, 0);
                }
            }

            si->Sdt = dt;
            si->Sfl = FLdata;
            outdata(si);

            /* Call:
             *      _d_switch_string(string[] si, string econd)
             */
            if (config.exe == EX_WIN64)
                econd = addressElem(econd, s->condition->type, true);
            elem *eparam = el_param(econd, (config.exe == EX_WIN64) ? el_ptr(si) : el_var(si));
            switch (s->condition->type->nextOf()->ty)
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
            elem_setLoc(econd, s->loc);
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
            CaseStatement *cs = (*s->cases)[i];
            if (string)
            {
                pu[cs->index] = i;
            }
            else
            {
                pu[i] = cs->exp->toInteger();
            }
        }

        Statement_toIR(s->_body, &mystate);

        /* Have the end of the switch body fall through to the block
         * following the switch statement.
         */
        block_goto(blx, BCgoto, mystate.breakBlock);
    }

    void visit(CaseStatement *s)
    {
        Blockx *blx = irs->blx;
        block *bcase = blx->curblock;
        Label *clabel = getLabel(irs, blx, s);
        block_next(blx, BCgoto, clabel->lblock);
        block *bsw = irs->getSwitchBlock();
        if (bsw->BC == BCswitch)
            bsw->appendSucc(clabel->lblock);   // second entry in pair
        bcase->appendSucc(clabel->lblock);
        if (blx->tryblock != bsw->Btry)
            s->error("case cannot be in different try block level from switch");
        incUsage(irs, s->loc);
        if (s->statement)
            Statement_toIR(s->statement, irs);
    }

    void visit(DefaultStatement *s)
    {
        Blockx *blx = irs->blx;
        block *bcase = blx->curblock;
        block *bdefault = irs->getDefaultBlock();
        block_next(blx,BCgoto,bdefault);
        bcase->appendSucc(blx->curblock);
        if (blx->tryblock != irs->getSwitchBlock()->Btry)
            s->error("default cannot be in different try block level from switch");
        incUsage(irs, s->loc);
        if (s->statement)
            Statement_toIR(s->statement, irs);
    }

    void visit(GotoDefaultStatement *s)
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
                    s->error("cannot goto into try block");
                    break;
                }
            }

            //setScopeIndex(blx, b, bdest->Btry ? bdest->Btry->Bscope_index : -1);
        }

        b->appendSucc(bdest);
        incUsage(irs, s->loc);
        block_next(blx,BCgoto,NULL);
    }

    void visit(GotoCaseStatement *s)
    {
        Blockx *blx = irs->blx;
        Label *clabel = getLabel(irs, blx, s->cs);
        block *bdest = clabel->lblock;
        block *b = blx->curblock;

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
                    s->error("cannot goto into try block");
                    break;
                }
            }

            //setScopeIndex(blx, b, bdest->Btry ? bdest->Btry->Bscope_index : -1);
        }

        b->appendSucc(bdest);
        incUsage(irs, s->loc);
        block_next(blx,BCgoto,NULL);
    }

    void visit(SwitchErrorStatement *s)
    {
        Blockx *blx = irs->blx;

        //printf("SwitchErrorStatement::toIR()\n");

        elem *efilename = el_ptr(toSymbol(blx->module));
        elem *elinnum = el_long(TYint, s->loc.linnum);
        elem *e = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM_DSWITCHERR)), el_param(elinnum, efilename));
        block_appendexp(blx->curblock, e);
    }

    /**************************************
     */

    void visit(ReturnStatement *s)
    {
        Blockx *blx = irs->blx;
        enum BC bc;

        incUsage(irs, s->loc);
        if (s->exp)
        {
            elem *e;

            FuncDeclaration *func = irs->getFunc();
            assert(func);
            assert(func->type->ty == Tfunction);
            TypeFunction *tf = (TypeFunction *)(func->type);

            RET retmethod = retStyle(tf);
            if (retmethod == RETstack)
            {
                elem *es;

                /* If returning struct literal, write result
                 * directly into return value
                 */
                if (s->exp->op == TOKstructliteral)
                {
                    StructLiteralExp *se = (StructLiteralExp *)s->exp;
                    char save[sizeof(StructLiteralExp)];
                    memcpy(save, (void*)se, sizeof(StructLiteralExp));
                    se->sym = irs->shidden;
                    se->soffset = 0;
                    se->fillHoles = 1;
                    e = toElemDtor(s->exp, irs);
                    memcpy((void*)se, save, sizeof(StructLiteralExp));
                }
                else
                    e = toElemDtor(s->exp, irs);
                assert(e);

                if (s->exp->op == TOKstructliteral ||
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
                        es->ET = Type_toCtype(s->exp->type);
                }
                e = el_var(irs->shidden);
                e = el_bin(OPcomma, e->Ety, es, e);
            }
            else if (tf->isref)
            {
                // Reference return, so convert to a pointer
                e = toElemDtor(s->exp, irs);
                e = addressElem(e, s->exp->type->pointerTo());
            }
            else
            {
                e = toElemDtor(s->exp, irs);
                assert(e);
            }
            elem_setLoc(e, s->loc);
            block_appendexp(blx->curblock, e);
            bc = BCretexp;
        }
        else
            bc = BCret;

        if (block *finallyBlock = irs->getFinallyBlock())
        {
            assert(finallyBlock->BC == BC_finally);
            blx->curblock->appendSucc(finallyBlock);
        }

        block_next(blx, bc, NULL);
    }

    /**************************************
     */

    void visit(ExpStatement *s)
    {
        Blockx *blx = irs->blx;

        //printf("ExpStatement::toIR(), exp = %s\n", exp ? exp->toChars() : "");
        incUsage(irs, s->loc);
        if (s->exp)
            block_appendexp(blx->curblock,toElemDtor(s->exp, irs));
    }

    /**************************************
     */

    void visit(CompoundStatement *s)
    {
        if (s->statements)
        {
            size_t dim = s->statements->dim;
            for (size_t i = 0 ; i < dim ; i++)
            {
                Statement *s2 = (*s->statements)[i];
                if (s2 != NULL)
                {
                    Statement_toIR(s2, irs);
                }
            }
        }
    }


    /**************************************
     */

    void visit(UnrolledLoopStatement *s)
    {
        Blockx *blx = irs->blx;

        IRState mystate(irs, s);
        mystate.breakBlock = block_calloc(blx);

        block *bpre = blx->curblock;
        block_next(blx, BCgoto, NULL);

        block *bdo = blx->curblock;
        bpre->appendSucc(bdo);

        block *bdox;

        size_t dim = s->statements->dim;
        for (size_t i = 0 ; i < dim ; i++)
        {
            Statement *s2 = (*s->statements)[i];
            if (s2 != NULL)
            {
                mystate.contBlock = block_calloc(blx);

                Statement_toIR(s2, &mystate);

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

    void visit(ScopeStatement *s)
    {
        if (s->statement)
        {
            Blockx *blx = irs->blx;
            IRState mystate(irs,s);

            if (mystate.prev->ident)
                mystate.ident = mystate.prev->ident;

            Statement_toIR(s->statement, &mystate);

            if (mystate.breakBlock)
                block_goto(blx,BCgoto,mystate.breakBlock);
        }
    }

    /***************************************
     */

    void visit(WithStatement *s)
    {
        Symbol *sp;
        elem *e;
        elem *ei;
        ExpInitializer *ie;
        Blockx *blx = irs->blx;

        //printf("WithStatement::toIR()\n");
        if (s->exp->op == TOKimport || s->exp->op == TOKtype)
        {
        }
        else
        {
            // Declare with handle
            sp = toSymbol(s->wthis);
            symbol_add(sp);

            // Perform initialization of with handle
            ie = s->wthis->_init->isExpInitializer();
            assert(ie);
            ei = toElemDtor(ie->exp, irs);
            e = el_var(sp);
            e = el_bin(OPeq,e->Ety, e, ei);
            elem_setLoc(e, s->loc);
            incUsage(irs, s->loc);
            block_appendexp(blx->curblock,e);
        }
        // Execute with block
        if (s->_body)
            Statement_toIR(s->_body, irs);
    }


    /***************************************
     */

    void visit(ThrowStatement *s)
    {
        // throw(exp)

        Blockx *blx = irs->blx;

        incUsage(irs, s->loc);
        elem *e = toElemDtor(s->exp, irs);
        e = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM_THROWC)),e);
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

    void visit(TryCatchStatement *s)
    {
        Blockx *blx = irs->blx;

#if SEH
        if (!global.params.is64bit)
            nteh_declarvars(blx);
#endif

        IRState mystate(irs, s);

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
        if (s->_body)
        {
            Statement_toIR(s->_body, &mystate);
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

        assert(s->catches);
        for (size_t i = 0 ; i < s->catches->dim; i++)
        {
            Catch *cs = (*s->catches)[i];
            if (cs->var)
                cs->var->csym = tryblock->jcatchvar;
            block *bcatch = blx->curblock;
            if (cs->type)
                bcatch->Bcatchtype = toSymbol(cs->type->toBasetype());
            tryblock->appendSucc(bcatch);
            block_goto(blx, BCjcatch, NULL);
            if (cs->handler != NULL)
            {
                IRState catchState(irs, s);

                /* Append to block:
                 *   *(sclosure + cs.offset) = cs;
                 */
                if (cs->var && cs->var->offset)
                {
                    tym_t tym = totym(cs->var->type);
                    elem *ex = el_var(irs->sclosure);
                    ex = el_bin(OPadd, TYnptr, ex, el_long(TYsize_t, cs->var->offset));
                    ex = el_una(OPind, tym, ex);
                    ex = el_bin(OPeq, tym, ex, el_var(toSymbol(cs->var)));
                    block_appendexp(catchState.blx->curblock, ex);
                }
                Statement_toIR(cs->handler, &catchState);
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

    void visit(TryFinallyStatement *s)
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

        IRState bodyirs(irs, s);
        block *breakblock = block_calloc(blx);
        block *contblock = block_calloc(blx);
        tryblock->appendSucc(contblock);
        contblock->BC = BC_finally;
        bodyirs.finallyBlock = contblock;

        if (s->_body)
            Statement_toIR(s->_body, &bodyirs);
        blx->tryblock = tryblock->Btry;     // back to previous tryblock

        setScopeIndex(blx,blx->curblock,previndex);
        blx->scope_index = previndex;

        block_goto(blx,BCgoto, breakblock);
        block *finallyblock = block_goto(blx,BCgoto,contblock);
        assert(finallyblock == contblock);

        block_goto(blx,BC_finally,NULL);

        IRState finallyState(irs, s);
        breakblock = block_calloc(blx);
        contblock = block_calloc(blx);

        setScopeIndex(blx, blx->curblock, previndex);
        if (s->finalbody)
            Statement_toIR(s->finalbody, &finallyState);
        block_goto(blx, BCgoto, contblock);
        block_goto(blx, BCgoto, breakblock);

        block *retblock = blx->curblock;
        block_next(blx,BC_ret,NULL);

        finallyblock->appendSucc(blx->curblock);
        retblock->appendSucc(blx->curblock);

        /* The BCfinally..BC_ret blocks form a function that gets called from stack unwinding.
         * The successors to BC_ret blocks are both the next outer BCfinally and the destination
         * after the unwinding is complete.
         */
        for (block *b = tryblock; b != finallyblock; b = b->Bnext)
        {
            block *btry = b->Btry;

            if (b->BC == BCgoto && b->numSucc() == 1)
            {
                block *bdest = b->nthSucc(0);
                if (btry && bdest->Btry != btry)
                {
                    //printf("test1 b %p b->Btry %p bdest %p bdest->Btry %p\n", b, btry, bdest, bdest->Btry);
                    block *bfinally = btry->nthSucc(1);
                    if (bfinally == finallyblock)
                        b->appendSucc(finallyblock);
                }
            }

            // If the goto exits a try block, then the finally block is also a successor
            if (b->BC == BCgoto && b->numSucc() == 2) // if goto exited a tryblock
            {
                block *bdest = b->nthSucc(0);

                // If the last finally block executed by the goto
                if (bdest->Btry == tryblock->Btry)
                    // The finally block will exit and return to the destination block
                    retblock->appendSucc(bdest);
            }

            if (b->BC == BC_ret && b->Btry == tryblock)
            {
                // b is nested inside this TryFinally, and so this finally will be called next
                b->appendSucc(finallyblock);
            }
        }
    }

    /****************************************
     */

    void visit(SynchronizedStatement *s)
    {
        assert(0);
    }


    /****************************************
     */

    void visit(AsmStatement *s)
    {
        block *bpre;
        block *basm;
        Declaration *d;
        Symbol *sym;
        Blockx *blx = irs->blx;

        //printf("AsmStatement::toIR(asmcode = %x)\n", asmcode);
        bpre = blx->curblock;
        block_next(blx,BCgoto,NULL);
        basm = blx->curblock;
        bpre->appendSucc(basm);
        basm->Bcode = s->asmcode;
        basm->Balign = s->asmalign;

        // Loop through each instruction, fixing Dsymbols into Symbol's
        for (code *c = s->asmcode; c; c = c->next)
        {   LabelDsymbol *label;
            block *b;

            switch (c->IFL1)
            {
                case FLblockoff:
                case FLblock:
                    // FLblock and FLblockoff have LabelDsymbol's - convert to blocks
                    label = c->IEVlsym1;
                    b = labelToBlock(irs, s->loc, blx, label);
                    basm->appendSucc(b);
                    c->IEV1.Vblock = b;
                    break;

                case FLdsymbol:
                case FLfunc:
                    sym = toSymbol(c->IEVdsym1);
                    if (sym->Sclass == SCauto && sym->Ssymnum == -1)
                        symbol_add(sym);
                    c->IEVsym1 = sym;
                    c->IFL1 = sym->Sfl ? sym->Sfl : FLauto;
                    break;
            }

            // Repeat for second operand
            switch (c->IFL2)
            {
                case FLblockoff:
                case FLblock:
                    label = c->IEVlsym2;
                    b = labelToBlock(irs, s->loc, blx, label);
                    basm->appendSucc(b);
                    c->IEV2.Vblock = b;
                    break;

                case FLdsymbol:
                case FLfunc:
                    d = c->IEVdsym2;
                    sym = toSymbol(d);
                    if (sym->Sclass == SCauto && sym->Ssymnum == -1)
                        symbol_add(sym);
                    c->IEVsym2 = sym;
                    c->IFL2 = sym->Sfl ? sym->Sfl : FLauto;
                    if (d->isDataseg())
                        sym->Sflags |= SFLlivexit;
                    break;
            }
            //c->print();
        }

        basm->bIasmrefparam = s->refparam;             // are parameters reference?
        basm->usIasmregs = s->regs;                    // registers modified

        block_next(blx,BCasm, NULL);
        basm->prependSucc(blx->curblock);

        if (s->naked)
        {
            blx->funcsym->Stype->Tty |= mTYnaked;
        }
    }

    /****************************************
     */

    void visit(ImportStatement *s)
    {
    }

};

void Statement_toIR(Statement *s, IRState *irs)
{
    S2irVisitor v(irs);
    s->accept(&v);
}
