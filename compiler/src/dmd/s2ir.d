/**
 * Convert statements to Intermediate Representation (IR) for the back-end.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/s2ir.d, _s2ir.d)
 * Documentation: $(LINK https://dlang.org/phobos/dmd_s2ir.html)
 * Coverage:    $(LINK https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/s2ir.d)
 */

module dmd.s2ir;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;
import core.stdc.stdlib;
import core.stdc.time;

import dmd.root.array;
import dmd.root.rmem;
import dmd.rootobject;

import dmd.aggregate;
import dmd.astenums;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dmdparams;
import dmd.dmodule;
import dmd.dsymbol;
import dmd.dstruct;
import dmd.dtemplate;
import dmd.e2ir;
import dmd.expression;
import dmd.func;
import dmd.glue;
import dmd.id;
import dmd.init;
import dmd.location;
import dmd.mtype;
import dmd.statement;
import dmd.stmtstate;
import dmd.target;
import dmd.toctype;
import dmd.tocsym;
import dmd.toir;
import dmd.tokens;
import dmd.typesem : pointerTo;
import dmd.visitor;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.cv4;
import dmd.backend.dlist;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

alias StmtState = dmd.stmtstate.StmtState!block;


void elem_setLoc(elem* e, Loc loc) nothrow
{
    e.Esrcpos = toSrcpos(loc);
}

void Statement_toIR(Statement s, ref IRState irs)
{
    /* Generate a block for each label
     */
    FuncDeclaration fd = irs.getFunc();
    if (auto labtab = fd.labtab)
        foreach (keyValue; labtab.tab.asRange)
        {
            //printf("  KV: %s = %s\n", keyValue.key.toChars(), keyValue.value.toChars());
            LabelDsymbol label = cast(LabelDsymbol)keyValue.value;
            if (label.statement)
                label.statement.extra = dmd.backend.global.block_calloc();
        }

    StmtState stmtstate;
    Statement_toIR(s, irs, &stmtstate);
}

void Statement_toIR(Statement s, ref IRState irs, StmtState* stmtstate)
{
    /****************************************
     * This should be overridden by each statement class.
     */

    void visitDefaultCase(Statement s)
    {
        irs.eSink.error(s.loc, "visitDefaultCase() %d for %s\n", s.stmt, s.toChars());
        assert(0);
    }

    /*************************************
     */

    void visitScopeGuard(ScopeGuardStatement s)
    {
    }

    /****************************************
     */

    void visitIf(IfStatement s)
    {
        elem* e;
        BlockState* blx = irs.blx;

        //printf("IfStatement.toIR('%s')\n", s.condition.toChars());

        StmtState mystate = StmtState(stmtstate, s);

        // bexit is the block that gets control after this IfStatement is done
        block* bexit = mystate.breakBlock ? mystate.breakBlock : dmd.backend.global.block_calloc();

        incUsage(irs, s.loc);
        e = toElemDtor(s.condition, irs);
        block_appendexp(blx.curblock, e);
        block* bcond = blx.curblock;
        block_next(blx, BC.iftrue, null);

        bcond.appendSucc(blx.curblock);
        if (s.ifbody)
        {
            if (!s.isIfCtfeBlock())         // __ctfe is always false at runtime
                Statement_toIR(s.ifbody, irs, &mystate);
        }
        blx.curblock.appendSucc(bexit);

        if (s.elsebody)
        {
            block_next(blx, BC.goto_, null);
            bcond.appendSucc(blx.curblock);
            Statement_toIR(s.elsebody, irs, &mystate);
            blx.curblock.appendSucc(bexit);
        }
        else
            bcond.appendSucc(bexit);

        block_next(blx, BC.goto_, bexit);

    }

    /**************************************
     */

    void visitPragma(PragmaStatement s)
    {
        //printf("PragmaStatement.toIR()\n");
        if (s.ident == Id.startaddress)
        {
            assert(s.args && s.args.length == 1);
            Expression e = (*s.args)[0];
            Dsymbol sa = getDsymbol(e);
            FuncDeclaration f = sa.isFuncDeclaration();
            assert(f);
            Symbol* sym = toSymbol(f);
            irs.startaddress = sym;
        }
    }

    /******************************************
     */

    void visitDo(DoStatement s)
    {
        BlockState* blx = irs.blx;

        StmtState mystate = StmtState(stmtstate, s);
        mystate.breakBlock = block_calloc(blx);
        mystate.contBlock = block_calloc(blx);

        block* bpre = blx.curblock;
        block_next(blx, BC.goto_, null);
        bpre.appendSucc(blx.curblock);

        mystate.contBlock.appendSucc(blx.curblock);
        mystate.contBlock.appendSucc(mystate.breakBlock);

        if (s._body)
            Statement_toIR(s._body, irs, &mystate);
        blx.curblock.appendSucc(mystate.contBlock);

        block_next(blx, BC.goto_, mystate.contBlock);
        incUsage(irs, s.condition.loc);
        block_appendexp(mystate.contBlock, toElemDtor(s.condition, irs));
        block_next(blx, BC.iftrue, mystate.breakBlock);

    }

    /*****************************************
     */

    void visitFor(ForStatement s)
    {
        //printf("visit(ForStatement)) %u..%u\n", s.loc.linnum, s.endloc.linnum);
        BlockState* blx = irs.blx;

        StmtState mystate = StmtState(stmtstate, s);
        mystate.breakBlock = block_calloc(blx);
        mystate.contBlock = block_calloc(blx);

        if (s._init)
            Statement_toIR(s._init, irs, &mystate);
        block* bpre = blx.curblock;
        block_next(blx,BC.goto_,null);
        block* bcond = blx.curblock;
        bpre.appendSucc(bcond);
        mystate.contBlock.appendSucc(bcond);
        if (s.condition)
        {
            incUsage(irs, s.condition.loc);
            block_appendexp(bcond, toElemDtor(s.condition, irs));
            block_next(blx,BC.iftrue,null);
            bcond.appendSucc(blx.curblock);
            bcond.appendSucc(mystate.breakBlock);
        }
        else
        {   /* No conditional, it's a straight goto
             */
            block_next(blx,BC.goto_,null);
            bcond.appendSucc(blx.curblock);
        }

        if (s._body)
            Statement_toIR(s._body, irs, &mystate);
        /* End of the body goes to the continue block
         */
        blx.curblock.appendSucc(mystate.contBlock);
        block_setLoc(blx.curblock, s.endloc);
        block_next(blx, BC.goto_, mystate.contBlock);

        if (s.increment)
        {
            incUsage(irs, s.increment.loc);
            block_appendexp(mystate.contBlock, toElemDtor(s.increment, irs));
        }

        /* The 'break' block follows the for statement.
         */
        block_next(blx,BC.goto_, mystate.breakBlock);
    }

    /****************************************
     */

    void visitBreak(BreakStatement s)
    {
        block* bbreak;
        block* b;
        BlockState* blx = irs.blx;

        bbreak = stmtstate.getBreakBlock(s.ident);
        assert(bbreak);
        b = blx.curblock;
        incUsage(irs, s.loc);

        // Adjust exception handler scope index if in different try blocks
        if (b.Btry != bbreak.Btry)
        {
            //setScopeIndex(blx, b, bbreak.Btry ? bbreak.Btry.Bscope_index : -1);
        }

        /* Nothing more than a 'goto' to the current break destination
         */
        b.appendSucc(bbreak);
        block_setLoc(b, s.loc);
        block_next(blx, BC.goto_, null);
    }

    /************************************
     */

    void visitContinue(ContinueStatement s)
    {
        block* bcont;
        block* b;
        BlockState* blx = irs.blx;

        //printf("ContinueStatement.toIR() %p\n", this);
        bcont = stmtstate.getContBlock(s.ident);
        assert(bcont);
        b = blx.curblock;
        incUsage(irs, s.loc);

        // Adjust exception handler scope index if in different try blocks
        if (b.Btry != bcont.Btry)
        {
            //setScopeIndex(blx, b, bcont.Btry ? bcont.Btry.Bscope_index : -1);
        }

        /* Nothing more than a 'goto' to the current continue destination
         */
        b.appendSucc(bcont);
        block_setLoc(b, s.loc);
        block_next(blx, BC.goto_, null);
    }


    /**************************************
     */

    void visitGoto(GotoStatement s)
    {
        BlockState* blx = irs.blx;

        assert(s.label.statement);
        assert(s.tf == s.label.statement.tf);

        block* bdest = cast(block*)s.label.statement.extra;
        block* b = blx.curblock;
        incUsage(irs, s.loc);
        b.appendSucc(bdest);
        block_setLoc(b, s.loc);

        block_next(blx,BC.goto_,null);
    }

    void visitLabel(LabelStatement s)
    {
        //printf("LabelStatement.toIR() %p, statement: `%s`\n", this, s.statement.toChars());
        BlockState* blx = irs.blx;
        block* bc = blx.curblock;
        StmtState mystate = StmtState(stmtstate, s);
        mystate.ident = s.ident;

        block* bdest = cast(block*)s.extra;
        // At last, we know which try block this label is inside
        bdest.Btry = blx.tryblock;

        block_next(blx, BC.goto_, bdest);
        bc.appendSucc(blx.curblock);
        if (s.statement)
            Statement_toIR(s.statement, irs, &mystate);
    }

    /**************************************
     */

    void visitSwitch(SwitchStatement s)
    {
        BlockState* blx = irs.blx;

        //printf("SwitchStatement.toIR()\n");
        StmtState mystate = StmtState(stmtstate, s);

        mystate.switchBlock = blx.curblock;

        /* Block for where "break" goes to
         */
        mystate.breakBlock = block_calloc(blx);

        /* Block for where "default" goes to.
         * If there is a default statement, then that is where default goes.
         * If not, then do:
         *   default: break;
         * by making the default block the same as the break block.
         */
        mystate.defaultBlock = s.sdefault ? block_calloc(blx) : mystate.breakBlock;

        const numcases = s.cases ? s.cases.length : 0;

        /* allocate a block for each case
         */
        if (numcases)
            foreach (cs; *s.cases)
            {
                cs.extra = cast(void*)block_calloc(blx);
            }

        incUsage(irs, s.loc);
        elem* econd = toElemDtor(s.condition, irs);
        if (s.hasVars)
        {   /* Generate a sequence of if-then-else blocks for the cases.
             */
            if (econd.Eoper != OPvar)
            {
                elem* e = exp2_copytotemp(econd);
                block_appendexp(mystate.switchBlock, e);
                econd = e.E2;
            }

            if (numcases)
                foreach (cs; *s.cases)
                {
                    elem* ecase = toElemDtor(cs.exp, irs);
                    elem* e = el_bin(OPeqeq, TYbool, el_copytree(econd), ecase);
                    block* b = blx.curblock;
                    block_appendexp(b, e);
                    block* cb = cast(block*)cs.extra;
                    block_next(blx, BC.iftrue, null);
                    b.appendSucc(cb);
                    b.appendSucc(blx.curblock);
                }

            /* The final 'else' clause goes to the default
             */
            block* b = blx.curblock;
            block_next(blx, BC.goto_, null);
            b.appendSucc(mystate.defaultBlock);

            Statement_toIR(s._body, irs, &mystate);

            /* Have the end of the switch body fall through to the block
             * following the switch statement.
             */
            block_goto(blx, BC.goto_, mystate.breakBlock);
            return;
        }

        if (s.condition.type.isString())
        {
            // This codepath was replaced by lowering during semantic
            // to object.__switch in druntime.
            assert(0);
        }

        block_appendexp(mystate.switchBlock, econd);
        block_next(blx,BC.switch_,null);

        /* First successor is the default block
         */
        mystate.switchBlock.appendSucc(mystate.defaultBlock);

        if (numcases)
        {
            // Corresponding free is in block_free
            alias TCase = typeof(mystate.switchBlock.Bswitch[0]);
            auto pu = cast(TCase *)Mem.check(.malloc(TCase.sizeof * numcases));
            mystate.switchBlock.Bswitch = pu[0 .. numcases];

            /* Fill in the first entry for each pair, which is the case value.
             * CaseStatement.toIR() will fill in
             * the second entry for each pair with the block.
             */
            foreach (i, cs; *s.cases)
                mystate.switchBlock.Bswitch[i] = cs.exp.toInteger();
        }

        Statement_toIR(s._body, irs, &mystate);

        /* Have the end of the switch body fall through to the block
         * following the switch statement.
         */
        block_goto(blx, BC.goto_, mystate.breakBlock);
    }

    void visitCase(CaseStatement s)
    {
        BlockState* blx = irs.blx;
        block* bcase = blx.curblock;
        block* cb = cast(block*)s.extra;
        block_next(blx, BC.goto_, cb);
        block* bsw = stmtstate.getSwitchBlock();
        if (bsw.bc == BC.switch_)
            bsw.appendSucc(cb);   // second entry in pair
        bcase.appendSucc(cb);
        if (!isAssertFalse(s.statement))
            incUsage(irs, s.loc);
        if (s.statement)
            Statement_toIR(s.statement, irs, stmtstate);
    }

    void visitDefault(DefaultStatement s)
    {
        BlockState* blx = irs.blx;
        block* bcase = blx.curblock;
        block* bdefault = stmtstate.getDefaultBlock();
        block_next(blx,BC.goto_,bdefault);
        bcase.appendSucc(blx.curblock);
        if (!isAssertFalse(s.statement))
            incUsage(irs, s.loc);
        if (s.statement)
            Statement_toIR(s.statement, irs, stmtstate);
    }

    void visitGotoDefault(GotoDefaultStatement s)
    {
        block* b;
        BlockState* blx = irs.blx;
        block* bdest = stmtstate.getDefaultBlock();

        b = blx.curblock;

        // The rest is equivalent to GotoStatement

        b.appendSucc(bdest);
        incUsage(irs, s.loc);
        block_next(blx,BC.goto_,null);
    }

    void visitGotoCase(GotoCaseStatement s)
    {
        BlockState* blx = irs.blx;
        block* bdest = cast(block*)s.cs.extra;
        block* b = blx.curblock;

        // The rest is equivalent to GotoStatement

        b.appendSucc(bdest);
        incUsage(irs, s.loc);
        block_next(blx,BC.goto_,null);
    }

    void visitSwitchError(SwitchErrorStatement s)
    {
        // SwitchErrors are lowered to a CallExpression to object.__switch_error() in druntime
        // We still need the call wrapped in SwitchErrorStatement to pass compiler error checks.
        assert(s.exp !is null, "SwitchErrorStatement needs to have a valid Expression.");

        BlockState* blx = irs.blx;

        //printf("SwitchErrorStatement.toIR(), exp = %s\n", s.exp ? s.exp.toChars() : "");
        incUsage(irs, s.loc);
        block_appendexp(blx.curblock, toElemDtor(s.exp, irs));
    }

    /**************************************
     */

    void visitReturn(ReturnStatement s)
    {
        //printf("s2ir.ReturnStatement: %s\n", toChars(s.exp));
        BlockState* blx = irs.blx;
        BC bc;

        incUsage(irs, s.loc);
        void finish()
        {
            block* finallyBlock;
            if (config.ehmethod != EHmethod.EH_DWARF &&
                !irs.isNothrow() &&
                (finallyBlock = stmtstate.getFinallyBlock()) != null)
            {
                assert(finallyBlock.bc == BC._finally);
                blx.curblock.appendSucc(finallyBlock);
            }

            block_next(blx, bc, null);
        }
        if (!s.exp)
        {
            bc = BC.ret;
            return finish();
        }

        elem* e;

        FuncDeclaration func = irs.getFunc();
        assert(func);
        auto tf = func.type.isTypeFunction();
        assert(tf);

        RET retmethod = retStyle(tf, func.needThis());
        if (retmethod == RET.stack)
        {
            elem* es;
            bool writetohp;

            /* If returning struct literal, write result
             * directly into return value
             */
            if (auto sle = s.exp.isStructLiteralExp())
            {
                sle.sym = irs.shidden;
                writetohp = true;
            }
            /* Detect function call that returns the same struct
             * and construct directly into *shidden
             */
            else if (auto ce = s.exp.isCallExp())
            {
                if (ce.e1.op == EXP.variable || ce.e1.op == EXP.star)
                {
                    Type t = ce.e1.type.toBasetype();
                    if (t.ty == Tdelegate)
                        t = t.nextOf();
                    if (t.ty == Tfunction && retStyle(cast(TypeFunction)t, ce.f && ce.f.needThis()) == RET.stack)
                    {
                        irs.ehidden = el_var(irs.shidden);
                        e = toElemDtor(s.exp, irs);
                        e = el_una(OPaddr, TYnptr, e);
                        goto L1;
                    }
                }
                else if (auto dve = ce.e1.isDotVarExp())
                {
                    auto fd = dve.var.isFuncDeclaration();
                    if (fd && fd.isCtorDeclaration())
                    {
                        if (auto sle = dve.e1.isStructLiteralExp())
                        {
                            sle.sym = irs.shidden;
                            writetohp = true;
                        }
                    }
                    Type t = ce.e1.type.toBasetype();
                    if (t.ty == Tdelegate)
                        t = t.nextOf();
                    if (t.ty == Tfunction && retStyle(cast(TypeFunction)t, fd && fd.needThis()) == RET.stack)
                    {
                        irs.ehidden = el_var(irs.shidden);
                        e = toElemDtor(s.exp, irs);
                        e = el_una(OPaddr, TYnptr, e);
                        goto L1;
                    }
                }
            }
            e = toElemDtor(s.exp, irs);
            assert(e);

            if (writetohp ||
                (func.isNRVO() && func.nrvo_var))
            {
                // Return value via hidden pointer passed as parameter
                // Write exp; return shidden;
                es = e;
            }
            else
            {
                // Return value via hidden pointer passed as parameter
                // Write *shidden=exp; return shidden;
                es = el_una(OPind,e.Ety,el_var(irs.shidden));
                es = elAssign(es, e, s.exp.type, null);
            }
            e = el_var(irs.shidden);
            e = el_bin(OPcomma, e.Ety, es, e);
        }
        else if (tf.isRef)
        {
            // Reference return, so convert to a pointer
            e = toElemDtor(s.exp, irs);

            /* already taken care of for vresult in buildResultVar() and semantic3.d
             * https://issues.dlang.org/show_bug.cgi?id=19384
             */
            if (func.vresult)
                if (BlitExp be = s.exp.isBlitExp())
                {
                     if (VarExp ve = be.e1.isVarExp())
                     {
                        if (ve.var == func.vresult)
                            goto Lskip;
                     }
                }

            e = addressElem(e, s.exp.type.pointerTo());
         Lskip:
        }
        else
        {
            e = toElemDtor(s.exp, irs);
            assert(e);
        }
    L1:
        elem_setLoc(e, s.loc);
        block_appendexp(blx.curblock, e);
        bc = BC.retexp;
//        if (type_zeroCopy(Type_toCtype(s.exp.type)))
//            bc = BC.ret;
        finish();
    }

    /**************************************
     */

    void visitExp(ExpStatement s)
    {
        BlockState* blx = irs.blx;

        //printf("ExpStatement.toIR(), exp: %p %s\n", s.exp, s.exp ? s.exp.toChars() : "");
        if (!s.exp)
            return;
        if (s.exp.hasCode &&
            !(isAssertFalse(s.exp))) // `assert(0)` not meant to be covered
            incUsage(irs, s.loc);

        block_appendexp(blx.curblock, toElemDtor(s.exp, irs));

        // goto the next block
        block* b = blx.curblock;
        block_next(blx, BC.goto_, null);
        b.appendSucc(blx.curblock);
    }

    /**************************************
     */

    void visitDtorExp(DtorExpStatement s)
    {
        return visitExp(s);
    }

    /**************************************
     */

    void visitCompound(CompoundStatement s)
    {
        if (!s.statements)
            return;
        foreach (s2; *s.statements)
        {
            if (s2)
                Statement_toIR(s2, irs, stmtstate);
        }
    }

    /**************************************
     */

    void visitCompoundAsm(CompoundAsmStatement s)
    {
        return visitCompound(s);
    }

    /**************************************
     */

    void visitUnrolledLoop(UnrolledLoopStatement s)
    {
        BlockState* blx = irs.blx;

        StmtState mystate = StmtState(stmtstate, s);
        mystate.breakBlock = block_calloc(blx);

        block* bpre = blx.curblock;
        block_next(blx, BC.goto_, null);

        block* bdo = blx.curblock;
        bpre.appendSucc(bdo);

        block* bdox;

        foreach (s2; *s.statements)
        {
            if (s2)
            {
                mystate.contBlock = block_calloc(blx);

                Statement_toIR(s2, irs, &mystate);

                bdox = blx.curblock;
                block_next(blx, BC.goto_, mystate.contBlock);
                bdox.appendSucc(mystate.contBlock);
            }
        }

        bdox = blx.curblock;
        block_next(blx, BC.goto_, mystate.breakBlock);
        bdox.appendSucc(mystate.breakBlock);
    }


    /**************************************
     */

    void visitScope(ScopeStatement s)
    {
        if (!s.statement)
            return;
        BlockState* blx = irs.blx;
        StmtState mystate = StmtState(stmtstate, s);

        if (mystate.prev.ident)
            mystate.ident = mystate.prev.ident;

        Statement_toIR(s.statement, irs, &mystate);

        if (mystate.breakBlock)
            block_goto(blx,BC.goto_,mystate.breakBlock);
    }

    /***************************************
     */

    void visitWith(WithStatement s)
    {
        //printf("WithStatement.toIR()\n");
        if (s.exp.op == EXP.scope_ || s.exp.op == EXP.type)
        {
        }
        else
        {
            // Declare with handle
            auto sp = toSymbol(s.wthis);
            symbol_add(sp);

            // Perform initialization of with handle
            auto ie = s.wthis._init.isExpInitializer();
            assert(ie);
            auto ei = toElemDtor(ie.exp, irs);
            auto e = el_var(sp);
            e = el_bin(OPeq,e.Ety, e, ei);
            elem_setLoc(e, s.loc);
            incUsage(irs, s.loc);
            block_appendexp(irs.blx.curblock,e);
        }
        // Execute with block
        if (s._body)
            Statement_toIR(s._body, irs, stmtstate);
    }


    /***************************************
     */

    void visitThrow(ThrowStatement s)
    {
        // throw(exp)

        BlockState* blx = irs.blx;

        incUsage(irs, s.loc);
        elem* e = toElemDtor(s.exp, irs);
        const rtlthrow = config.ehmethod == EHmethod.EH_DWARF ? RTLSYM.THROWDWARF : RTLSYM.THROWC;
        e = el_bin(OPcall, TYvoid, el_var(getRtlsym(rtlthrow)),e);
        block_appendexp(blx.curblock, e);
        block_next(blx, BC.exit, null);          // throw never returns
    }

    /***************************************
     * Builds the following:
     *      _try
     *      block
     *      jcatch
     *      handler
     * A try-catch statement.
     */

    void visitTryCatch(TryCatchStatement s)
    {
        BlockState* blx = irs.blx;

        if (blx.funcsym.Sfunc.Fflags3 & Feh_none) printf("visit %s\n", blx.funcsym.Sident.ptr);
        if (blx.funcsym.Sfunc.Fflags3 & Feh_none) assert(0);

        if (config.ehmethod == EHmethod.EH_WIN32)
            nteh_declarvars(blx);

        StmtState mystate = StmtState(stmtstate, s);

        block* tryblock = block_goto(blx,BC.goto_,null);

        int previndex = blx.scope_index;
        tryblock.Blast_index = previndex;
        blx.scope_index = tryblock.Bscope_index = blx.next_index++;

        // Set the current scope index
        setScopeIndex(blx,tryblock,tryblock.Bscope_index);

        // This is the catch variable
        tryblock.jcatchvar = symbol_genauto(type_fake(mTYvolatile | TYnptr));

        blx.tryblock = tryblock;
        block* breakblock = block_calloc(blx);
        block_goto(blx,BC._try,null);
        if (s._body)
        {
            Statement_toIR(s._body, irs, &mystate);
        }
        blx.tryblock = tryblock.Btry;

        // break block goes here
        block_goto(blx, BC.goto_, breakblock);

        setScopeIndex(blx,blx.curblock, previndex);
        blx.scope_index = previndex;

        // create new break block that follows all the catches
        block* breakblock2 = block_calloc(blx);

        blx.curblock.appendSucc(breakblock2);
        block_next(blx,BC.goto_,null);

        assert(s.catches);
        if (config.ehmethod == EHmethod.EH_DWARF)
        {
            /*
             * BC.jcatch:
             *  __hander = __RDX;
             *  __exception_object = __RAX;
             *  jcatchvar = *(__exception_object - target.ptrsize); // old way
             *  jcatchvar = __dmd_catch_begin(__exception_object);   // new way
             *  switch (__handler)
             *      case 1:     // first catch handler
             *          *(sclosure + cs.var.offset) = cs.var;
             *          ...handler body ...
             *          break;
             *      ...
             *      default:
             *          HALT
             */
            // volatile so optimizer won't delete it
            Symbol* seax = symbol_name("__EAX", SC.pseudo, type_fake(mTYvolatile | TYnptr));
            seax.Sreglsw = 0;          // EAX, RAX, whatevs
            symbol_add(seax);
            Symbol* sedx = symbol_name("__EDX", SC.pseudo, type_fake(mTYvolatile | TYint));
            sedx.Sreglsw = 2;          // EDX, RDX, whatevs
            symbol_add(sedx);
            Symbol* shandler = symbol_name("__handler", SC.auto_, tstypes[TYint]);
            symbol_add(shandler);
            Symbol* seo = symbol_name("__exception_object", SC.auto_, tspvoid);
            symbol_add(seo);

            elem* e1 = el_bin(OPeq, TYvoid, el_var(shandler), el_var(sedx)); // __handler = __RDX
            elem* e2 = el_bin(OPeq, TYvoid, el_var(seo), el_var(seax)); // __exception_object = __RAX

            version (none)
            {
                // jcatchvar = *(__exception_object - target.ptrsize)
                elem* e = el_bin(OPmin, TYnptr, el_var(seo), el_long(TYsize_t, target.ptrsize));
                elem* e3 = el_bin(OPeq, TYvoid, el_var(tryblock.jcatchvar), el_una(OPind, TYnptr, e));
            }
            else
            {
                //  jcatchvar = __dmd_catch_begin(__exception_object);
                elem* ebegin = el_var(getRtlsym(RTLSYM.BEGIN_CATCH));
                elem* e = el_bin(OPcall, TYnptr, ebegin, el_var(seo));
                elem* e3 = el_bin(OPeq, TYvoid, el_var(tryblock.jcatchvar), e);
            }

            block* bcatch = blx.curblock;
            tryblock.appendSucc(bcatch);
            block_goto(blx, BC.jcatch, null);

            block* defaultblock = block_calloc(blx);

            block* bswitch = blx.curblock;
            bswitch.Belem = el_combine(el_combine(e1, e2),
                                        el_combine(e3, el_var(shandler)));

            const numcases = s.catches.length;
            if (numcases)
            {
                long* pu = cast(long*) Mem.check(.malloc(long.sizeof * numcases));
                bswitch.Bswitch = pu[0 .. numcases];
            }
            bswitch.appendSucc(defaultblock);
            block_next(blx, BC.switch_, null);

            foreach (i, cs; *s.catches)
            {
                bswitch.Bswitch[i] = i;

                if (cs.var)
                    cs.var.csym = tryblock.jcatchvar;

                assert(cs.type);

                /* The catch type can be a C++ class or a D class.
                 * If a D class, insert a pointer to TypeInfo into the typesTable[].
                 * If a C++ class, insert a pointer to __cpp_type_info_ptr into the typesTable[].
                 */
                Type tcatch = cs.type.toBasetype();
                ClassDeclaration cd = tcatch.isClassHandle();
                bool isCPPclass = cd.isCPPclass();
                Symbol* catchtype;
                if (isCPPclass)
                {
                    catchtype = toSymbolCpp(cd);
                    if (i == 0)
                    {
                        // rewrite ebegin to use __cxa_begin_catch
                        Symbol* s2 = getRtlsym(RTLSYM.CXA_BEGIN_CATCH);
                        ebegin.Vsym = s2;
                    }
                }
                else
                    catchtype = toSymbol(tcatch);

                /* Look for catchtype in typesTable[] using linear search,
                 * insert if not already there,
                 * log index in Action Table (i.e. switch case table)
                 */
                func_t* f = blx.funcsym.Sfunc;

                foreach (j, ct; f.typesTable[])
                {
                    if (ct == catchtype)
                    {
                        bswitch.Bswitch[i] = 1 + j;  // index starts at 1
                        goto L1;
                    }
                }
                f.typesTable.push(catchtype);
                bswitch.Bswitch[i] = f.typesTable.length;  // index starts at 1
           L1:
                block* bcase = blx.curblock;
                bswitch.appendSucc(bcase);

                if (cs.handler !is null)
                {
                    StmtState catchState = StmtState(stmtstate, s);

                    /* Append to block:
                     *   *(sclosure + cs.var.offset) = cs.var;
                     */
                    if (cs.var && cs.var.offset) // if member of a closure
                    {
                        tym_t tym = totym(cs.var.type);
                        elem* ex = el_var(irs.sclosure);
                        ex = el_bin(OPadd, TYnptr, ex, el_long(TYsize_t, cs.var.offset));
                        ex = el_una(OPind, tym, ex);
                        ex = el_bin(OPeq, tym, ex, el_var(toSymbol(cs.var)));
                        block_appendexp(irs.blx.curblock, ex);
                    }
                    if (isCPPclass)
                    {
                        /* C++ catches need to end with call to __cxa_end_catch().
                         * Create:
                         *   try { handler } finally { __cxa_end_catch(); }
                         * Note that this is worst case code because it always sets up an exception handler.
                         * At some point should try to do better.
                         */
                        FuncDeclaration fdend = FuncDeclaration.genCfunc(null, Type.tvoid, "__cxa_end_catch");
                        Expression ec = VarExp.create(Loc.initial, fdend);
                        Expression ecc = CallExp.create(Loc.initial, ec);
                        ecc.type = Type.tvoid;
                        Statement sf = ExpStatement.create(Loc.initial, ecc);
                        Statement stf = TryFinallyStatement.create(Loc.initial, cs.handler, sf);
                        Statement_toIR(stf, irs, &catchState);
                    }
                    else
                        Statement_toIR(cs.handler, irs, &catchState);
                }
                blx.curblock.appendSucc(breakblock2);
                if (i + 1 == numcases)
                {
                    block_next(blx, BC.goto_, defaultblock);
                    defaultblock.Belem = el_calloc();
                    defaultblock.Belem.Ety = TYvoid;
                    defaultblock.Belem.Eoper = OPhalt;
                    block_next(blx, BC.exit, null);
                }
                else
                    block_next(blx, BC.goto_, null);
            }

            /* Make a copy of the switch case table, which will later become the Action Table.
             * Need a copy since the bswitch may get rewritten by the optimizer.
             */
            alias TAction = typeof((*bcatch.actionTable)[0]);
            bcatch.actionTable = cast(Barray!TAction*)Mem.check(.calloc(Barray!TAction.sizeof, 1));
            bcatch.actionTable.setLength(numcases);
            foreach (i; 0 .. numcases)
                (*bcatch.actionTable)[i] = cast(TAction)bswitch.Bswitch[i];
        }
        else
        {
            foreach (cs; *s.catches)
            {
                if (cs.var)
                    cs.var.csym = tryblock.jcatchvar;
                block* bcatch = blx.curblock;
                if (cs.type)
                    bcatch.Bcatchtype = toSymbol(cs.type.toBasetype());
                tryblock.appendSucc(bcatch);
                block_goto(blx, BC.jcatch, null);

                if (cs.type && irs.target.os == Target.OS.Windows && irs.target.isX86_64) // Win64
                {
                    /* The linker will attempt to merge together identical functions,
                     * even if the catch types differ. So add a reference to the
                     * catch type here.
                     * https://issues.dlang.org/show_bug.cgi?id=10664
                     */
                    auto tc = cs.type.toBasetype().isTypeClass();
                    if (!tc.sym.vclassinfo)
                        tc.sym.vclassinfo = TypeInfoClassDeclaration.create(tc);
                    auto sinfo = toSymbol(tc.sym.vclassinfo);
                    elem* ex = el_var(sinfo);
                    ex.Ety = mTYvolatile | TYnptr;
                    ex = el_una(OPind, TYint, ex);
                    block_appendexp(irs.blx.curblock, ex);
                }

                if (cs.handler !is null)
                {
                    StmtState catchState = StmtState(stmtstate, s);

                    /* Append to block:
                     *   *(sclosure + cs.var.offset) = cs.var;
                     */
                    if (cs.var && cs.var.offset) // if member of a closure
                    {
                        tym_t tym = totym(cs.var.type);
                        elem* ex = el_var(irs.sclosure);
                        ex = el_bin(OPadd, TYnptr, ex, el_long(TYsize_t, cs.var.offset));
                        ex = el_una(OPind, tym, ex);
                        ex = el_bin(OPeq, tym, ex, el_var(toSymbol(cs.var)));
                        block_appendexp(irs.blx.curblock, ex);
                    }
                    Statement_toIR(cs.handler, irs, &catchState);
                }
                blx.curblock.appendSucc(breakblock2);
                block_next(blx, BC.goto_, null);
            }
        }

        block_next(blx,cast(BC)blx.curblock.bc, breakblock2);
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

    void visitTryFinally(TryFinallyStatement s)
    {
        //printf("TryFinallyStatement.toIR()\n");

        BlockState* blx = irs.blx;

        if (config.ehmethod == EHmethod.EH_WIN32 && !(blx.funcsym.Sfunc.Fflags3 & Feh_none))
            nteh_declarvars(blx);

        /* Successors to BC._try block:
         *      [0] start of try block code
         *      [1] BC._finally
         */
        block* tryblock = block_goto(blx, BC.goto_, null);

        int previndex = blx.scope_index;
        tryblock.Blast_index = previndex;
        tryblock.Bscope_index = blx.next_index++;
        blx.scope_index = tryblock.Bscope_index;

        // Current scope index
        setScopeIndex(blx,tryblock,tryblock.Bscope_index);

        blx.tryblock = tryblock;
        block_goto(blx,BC._try,null);

        StmtState bodyirs = StmtState(stmtstate, s);

        block* finallyblock = block_calloc(blx);

        tryblock.appendSucc(finallyblock);
        finallyblock.bc = BC._finally;
        bodyirs.finallyBlock = finallyblock;

        if (s._body)
            Statement_toIR(s._body, irs, &bodyirs);
        blx.tryblock = tryblock.Btry;     // back to previous tryblock

        setScopeIndex(blx,blx.curblock,previndex);
        blx.scope_index = previndex;

        block* breakblock = block_calloc(blx);
        block* retblock = block_calloc(blx);

        if (config.ehmethod == EHmethod.EH_DWARF && !(blx.funcsym.Sfunc.Fflags3 & Feh_none))
        {
            /* Build this:
             *  BC.goto_     [BC._try]
             *  BC._try     [body] [BC._finally]
             *  body
             *  BC.goto_     [breakblock]
             *  BC._finally [BC._lpad] [finalbody] [breakblock]
             *  BC._lpad    [finalbody]
             *  finalbody
             *  BC.goto_     [BC._ret]
             *  BC._ret
             *  breakblock
             */
            blx.curblock.appendSucc(breakblock);
            block_next(blx,BC.goto_,finallyblock);

            block* landingPad = block_goto(blx,BC._finally,null);
            block_goto(blx,BC._lpad,null);               // lpad is [0]
            finallyblock.appendSucc(blx.curblock);    // start of finalybody is [1]
            finallyblock.appendSucc(breakblock);       // breakblock is [2]

            /* Declare flag variable
             */
            Symbol* sflag = symbol_name("__flag", SC.auto_, tstypes[TYint]);
            symbol_add(sflag);
            finallyblock.flag = sflag;
            finallyblock.b_ret = retblock;
            assert(!finallyblock.Belem);

            /* Add code to landingPad block:
             *  exception_object = RAX;
             *  _flag = 0;
             */
            // Make it volatile so optimizer won't delete it
            Symbol* sreg = symbol_name("__EAX", SC.pseudo, type_fake(mTYvolatile | TYnptr));
            sreg.Sreglsw = 0;          // EAX, RAX, whatevs
            symbol_add(sreg);
            Symbol* seo = symbol_name("__exception_object", SC.auto_, tspvoid);
            symbol_add(seo);
            assert(!landingPad.Belem);
            elem* e = el_bin(OPeq, TYvoid, el_var(seo), el_var(sreg));
            landingPad.Belem = el_combine(e, el_bin(OPeq, TYvoid, el_var(sflag), el_long(TYint, 0)));

            /* Add code to BC._ret block:
             *  (!_flag && _Unwind_Resume(exception_object));
             */
            elem* eu = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM.UNWIND_RESUME)), el_var(seo));
            eu = el_bin(OPandand, TYvoid, el_una(OPnot, TYbool, el_var(sflag)), eu);
            assert(!retblock.Belem);
            retblock.Belem = eu;

            StmtState finallyState = StmtState(stmtstate, s);

            setScopeIndex(blx, blx.curblock, previndex);
            if (s.finalbody)
                Statement_toIR(s.finalbody, irs, &finallyState);
            block_goto(blx, BC.goto_, retblock);

            block_next(blx,BC._ret,breakblock);
        }
        else if (config.ehmethod == EHmethod.EH_NONE || blx.funcsym.Sfunc.Fflags3 & Feh_none)
        {
            /* Build this:
             *  BC.goto_     [BC._try]
             *  BC._try     [body] [BC._finally]
             *  body
             *  BC.goto_     [breakblock]
             *  BC._finally [BC._lpad] [finalbody] [breakblock]
             *  BC._lpad    [finalbody]
             *  finalbody
             *  BC.goto_     [BC._ret]
             *  BC._ret
             *  breakblock
             */
            if (s.bodyFallsThru)
            {
                // BC.goto_ [breakblock]
                blx.curblock.appendSucc(breakblock);
                block_next(blx,BC.goto_,finallyblock);
            }
            else
            {
                if (!driverParams.optimize)
                {
                    /* If this is reached at runtime, there's a bug
                     * in the computation of s.bodyFallsThru. Inserting a HALT
                     * makes it far easier to track down such failures.
                     * But it makes for slower code, so only generate it for
                     * non-optimized code.
                     */
                    elem* e = el_calloc();
                    e.Ety = TYvoid;
                    e.Eoper = OPhalt;
                    elem_setLoc(e, s.loc);
                    block_appendexp(blx.curblock, e);
                }

                block_next(blx,BC.exit,finallyblock);
            }

            block* landingPad = block_goto(blx,BC._finally,null);
            block_goto(blx,BC._lpad,null);               // lpad is [0]
            finallyblock.appendSucc(blx.curblock);    // start of finalybody is [1]
            finallyblock.appendSucc(breakblock);       // breakblock is [2]

            /* Declare flag variable
             */
            Symbol* sflag = symbol_name("__flag", SC.auto_, tstypes[TYint]);
            symbol_add(sflag);
            finallyblock.flag = sflag;
            finallyblock.b_ret = retblock;
            assert(!finallyblock.Belem);

            landingPad.Belem = el_bin(OPeq, TYvoid, el_var(sflag), el_long(TYint, 0)); // __flag = 0;

            StmtState finallyState = StmtState(stmtstate, s);

            setScopeIndex(blx, blx.curblock, previndex);
            if (s.finalbody)
                Statement_toIR(s.finalbody, irs, &finallyState);
            block_goto(blx, BC.goto_, retblock);

            block_next(blx,BC._ret,breakblock);
        }
        else
        {
            block_goto(blx,BC.goto_, breakblock);
            block_goto(blx,BC.goto_,finallyblock);

            /* Successors to BC._finally block:
             *  [0] landing pad, same as start of finally code
             *  [1] block that comes after BC._ret
             */
            block_goto(blx,BC._finally,null);

            StmtState finallyState = StmtState(stmtstate, s);

            setScopeIndex(blx, blx.curblock, previndex);
            if (s.finalbody)
                Statement_toIR(s.finalbody, irs, &finallyState);
            block_goto(blx, BC.goto_, retblock);

            block_next(blx,BC._ret,null);

            /* Append the last successor to finallyblock, which is the first block past the BC._ret block.
             */
            finallyblock.appendSucc(blx.curblock);

            retblock.appendSucc(blx.curblock);

            /* The BC.finally..bc._ret blocks form a function that gets called from stack unwinding.
             * The successors to BC._ret blocks are both the next outer BC.finally and the destination
             * after the unwinding is complete.
             */
            for (block* b = tryblock; b != finallyblock; b = b.Bnext)
            {
                block* btry = b.Btry;

                if (b.bc == BC.goto_ && b.numSucc() == 1)
                {
                    block* bdest = b.nthSucc(0);
                    if (btry && bdest.Btry != btry)
                    {
                        //printf("test1 b %p b.Btry %p bdest %p bdest.Btry %p\n", b, btry, bdest, bdest.Btry);
                        block* bfinally = btry.nthSucc(1);
                        if (bfinally == finallyblock)
                        {
                            b.appendSucc(finallyblock);
                        }
                    }
                }

                // If the goto exits a try block, then the finally block is also a successor
                if (b.bc == BC.goto_ && b.numSucc() == 2) // if goto exited a tryblock
                {
                    block* bdest = b.nthSucc(0);

                    // If the last finally block executed by the goto
                    if (bdest.Btry == tryblock.Btry)
                    {
                        // The finally block will exit and return to the destination block
                        retblock.appendSucc(bdest);
                    }
                }

                if (b.bc == BC._ret && b.Btry == tryblock)
                {
                    // b is nested inside this TryFinally, and so this finally will be called next
                    b.appendSucc(finallyblock);
                }
            }
        }
    }

    /****************************************
     */

    void visitInlineAsm(InlineAsmStatement s)
//    { .visit(irs, s); }
    {
        block* bpre;
        block* basm;
        Symbol* sym;
        BlockState* blx = irs.blx;

        //printf("AsmStatement.toIR(asmcode = %x)\n", asmcode);
        bpre = blx.curblock;
        block_next(blx,BC.goto_,null);
        basm = blx.curblock;
        bpre.appendSucc(basm);
        basm.Bcode = cast(code*)s.asmcode;
        basm.Balign = cast(ubyte)s.asmalign;

        // Loop through each instruction, fixing Dsymbols into Symbol's
        for (code* c = cast(code*)s.asmcode; c; c = c.next)
        {
            switch (c.IFL1)
            {
                case FL.blockoff:
                case FL.block:
                {
                    // FL.block and FL.blockoff have LabelDsymbol's - convert to blocks
                    LabelDsymbol label = cast(LabelDsymbol)c.IEV1.Vlsym;
                    block* b = cast(block*)label.statement.extra;
                    basm.appendSucc(b);
                    c.IEV1.Vblock = b;
                    break;
                }

                case FL.dsymbol:
                case FL.func:
                    sym = toSymbol(cast(Dsymbol)c.IEV1.Vdsym);
                    if (sym.Sclass == SC.auto_ && sym.Ssymnum == SYMIDX.max)
                        symbol_add(sym);
                    c.IEV1.Vsym = sym;
                    c.IFL1 = sym.Sfl ? sym.Sfl : FL.auto_;
                    break;

                default:
                    break;
            }

            // Repeat for second operand
            switch (c.IFL2)
            {
                case FL.blockoff:
                case FL.block:
                {
                    LabelDsymbol label = cast(LabelDsymbol)c.IEV2.Vlsym;
                    block* b = cast(block*)label.statement.extra;
                    basm.appendSucc(b);
                    c.IEV2.Vblock = b;
                    break;
                }

                case FL.dsymbol:
                case FL.func:
                {
                    Declaration d = cast(Declaration)c.IEV2.Vdsym;
                    sym = toSymbol(cast(Dsymbol)d);
                    if (sym.Sclass == SC.auto_ && sym.Ssymnum == SYMIDX.max)
                        symbol_add(sym);
                    c.IEV2.Vsym = sym;
                    c.IFL2 = sym.Sfl ? sym.Sfl : FL.auto_;
                    if (d.isDataseg())
                        sym.Sflags |= SFLlivexit;
                    break;
                }

                default:
                    break;
            }
        }

        basm.bIasmrefparam = s.refparam;             // are parameters reference?
        basm.usIasmregs = s.regs;                    // registers modified

        block_next(blx,BC.asm_, null);
        basm.prependSucc(blx.curblock);

        if (s.naked)
        {
            blx.funcsym.Stype.Tty |= mTYnaked;
        }
    }

    /****************************************
     */

    void visitImport(ImportStatement s)
    {
    }

    mixin VisitStatement!void visit;
    visit.VisitStatement(s);
}

/***************************************************
 * Insert finally block calls when doing a goto from
 * inside a try block to outside.
 * Done after blocks are generated because then we know all
 * the edges of the graph, but before the Bpred's are computed.
 * Only for EH_DWARF exception unwinding.
 * Params:
 *      startblock = first block in function
 */

void insertFinallyBlockCalls(block* startblock)
{
    int flagvalue = 0;          // 0 is forunwind_resume
    block* bcret = null;

    block* bcretexp = null;
    Symbol* stmp;

    enum log = false;

    static if (log)
    {
        printf("------- before ----------\n");
        numberBlocks(startblock);
        foreach (b; BlockRange(startblock)) WRblock(b);
        printf("-------------------------\n");
    }

    block **pb;
    block **pbnext;
    for (pb = &startblock; *pb; pb = pbnext)
    {
        block* b = *pb;
        pbnext = &b.Bnext;
        if (!b.Btry)
            continue;

        switch (b.bc)
        {
            case BC.ret:
                // Rewrite into a BC.goto_ => BC.ret
                if (!bcret)
                {
                    bcret = dmd.backend.global.block_calloc();
                    bcret.bc = BC.ret;
                }
                b.bc = BC.goto_;
                b.appendSucc(bcret);
                goto case_goto;

            case BC.retexp:
            {
                // Rewrite into a BC.goto_ => BC.retexp
                elem* e = b.Belem;
                tym_t ty = tybasic(e.Ety);
                if (ty == TYvoid)
                    goto case BC.ret;
                if (!bcretexp)
                {
                    bcretexp = dmd.backend.global.block_calloc();
                    bcretexp.bc = BC.retexp;
                    type* t;
                    if ((ty == TYstruct || ty == TYarray) && e.ET)
                        t = e.ET;
                    else
                        t = type_fake(ty);
                    stmp = symbol_genauto(t);
                    bcretexp.Belem = el_var(stmp);
                    if ((ty == TYstruct || ty == TYarray) && e.ET)
                        bcretexp.Belem.ET = t;
                }
                b.bc = BC.goto_;
                b.appendSucc(bcretexp);
                b.Belem = elAssign(el_var(stmp), e, null, e.ET);
                goto case_goto;
            }

            case BC.goto_:
            case_goto:
            {
                /* From this:
                 *  BC.goto_     [breakblock]
                 *  BC._try     [body] [BC._finally]
                 *  body
                 *  BC.goto_     [breakblock]
                 *  BC._finally [BC._lpad] [finalbody] [breakblock]
                 *  BC._lpad    [finalbody]
                 *  finalbody
                 *  BC.goto_     [BC._ret]
                 *  BC._ret
                 *  breakblock
                 *
                 * Build this:
                 *  BC.goto_     [BC._try]
                 *  BC._try     [body] [BC._finally]
                 *  body
                 *x BC.goto_     sflag=n; [finalbody]
                 *  BC._finally [BC._lpad] [finalbody] [breakblock]
                 *  BC._lpad    [finalbody]
                 *  finalbody
                 *  BC.goto_     [BC.iftrue]
                 *x BC.iftrue   (sflag==n) [breakblock]
                 *x BC._ret
                 *  breakblock
                 */
                block* breakblock = b.nthSucc(0);
                block* lasttry = breakblock.Btry;
                block* blast = b;
                ++flagvalue;
                for (block* bt = b.Btry; bt != lasttry; bt = bt.Btry)
                {
                    assert(bt.bc == BC._try);
                    block* bf = bt.nthSucc(1);
                    if (bf.bc == BC.jcatch)
                        continue;                       // skip try-catch
                    assert(bf.bc == BC._finally);

                    block* retblock = bf.b_ret;
                    assert(retblock.bc == BC._ret);
                    assert(retblock.numSucc() == 0);

                    // Append (_flag = flagvalue) to b.Belem
                    Symbol* sflag = bf.flag;
                    elem* e = el_bin(OPeq, TYint, el_var(sflag), el_long(TYint, flagvalue));
                    b.Belem = el_combine(b.Belem, e);

                    if (blast.bc == BC.iftrue)
                    {
                        blast.setNthSucc(0, bf.nthSucc(1));
                    }
                    else
                    {
                        assert(blast.bc == BC.goto_);
                        blast.setNthSucc(0, bf.nthSucc(1));
                    }

                    // Create new block, bnew, which will replace retblock
                    block* bnew = dmd.backend.global.block_calloc();

                    /* Rewrite BC._ret block as:
                     *  if (sflag == flagvalue) goto breakblock; else goto bnew;
                     */
                    e = el_bin(OPeqeq, TYbool, el_var(sflag), el_long(TYint, flagvalue));
                    retblock.Belem = el_combine(retblock.Belem, e);
                    retblock.bc = BC.iftrue;
                    retblock.appendSucc(breakblock);
                    retblock.appendSucc(bnew);

                    bnew.Bnext = retblock.Bnext;
                    retblock.Bnext = bnew;

                    bnew.bc = BC._ret;
                    bnew.Btry = retblock.Btry;
                    bf.b_ret = bnew;

                    blast = retblock;
                }
                break;
            }

            default:
                break;
        }
    }
    if (bcret)
    {
        *pb = bcret;
        pb = &(*pb).Bnext;
    }
    if (bcretexp)
        *pb = bcretexp;

    static if (log)
    {
        printf("------- after ----------\n");
        numberBlocks(startblock);
        foreach (b; BlockRange(startblock)) WRblock(b);
        printf("-------------------------\n");
    }
}

/***************************************************
 * Insert gotos to finally blocks when doing a return or goto from
 * inside a try block to outside.
 * Done after blocks are generated because then we know all
 * the edges of the graph, but before the Bpred's are computed.
 * Only for functions with no exception handling.
 * Very similar to insertFinallyBlockCalls().
 * Params:
 *      startblock = first block in function
 */

void insertFinallyBlockGotos(block* startblock)
{
    enum log = false;

    // Insert all the goto's
    insertFinallyBlockCalls(startblock);

    /* Remove all the BC._try, BC._finally, BC._lpad and BC._ret
     * blocks.
     * Actually, just make them into no-ops and let the optimizer
     * delete them.
     */
    foreach (b; BlockRange(startblock))
    {
        b.Btry = null;
        switch (b.bc)
        {
            case BC._try:
                b.bc = BC.goto_;
                list_subtract(&b.Bsucc, b.nthSucc(1));
                break;

            case BC._finally:
                b.bc = BC.goto_;
                list_subtract(&b.Bsucc, b.nthSucc(2));
                list_subtract(&b.Bsucc, b.nthSucc(0));
                break;

            case BC._lpad:
                b.bc = BC.goto_;
                break;

            case BC._ret:
                b.bc = BC.exit;
                break;

            default:
                break;
        }
    }

    static if (log)
    {
        printf("------- after ----------\n");
        numberBlocks(startblock);
        foreach (b; BlockRange(startblock)) WRblock(b);
        printf("-------------------------\n");
    }
}

private void block_setLoc(block* b, Loc loc) nothrow
{
    b.Bsrcpos = toSrcpos(loc);
}

private bool isAssertFalse(const Expression e) nothrow
{
    return e ? e.type == Type.tnoreturn && (e.op == EXP.halt || e.op == EXP.assert_) : false;
}

private bool isAssertFalse(const Statement s) nothrow
{
    if (!s)
        return false;
    if (auto es = s.isExpStatement())
        return isAssertFalse(es.exp);
    if (auto ss = s.isScopeStatement())
        return isAssertFalse(ss.statement);
    return false;
}

/***********************************************
 * Generate code to set index into scope table.
 */

private void setScopeIndex(BlockState* blx, block* b, int scope_index)
{
    if (config.ehmethod == EHmethod.EH_WIN32 && !(blx.funcsym.Sfunc.Fflags3 & Feh_none))
        block_appendexp(b, nteh_setScopeTableIndex(blx, scope_index));
}

/****************************************
 * Allocate a new block, and set the tryblock.
 */

private block* block_calloc(BlockState* blx) @safe
{
    block* b = dmd.backend.global.block_calloc();
    b.Btry = blx.tryblock;
    return b;
}

/**************************************
 * Add in code to increment usage count for linnum.
 */

private void incUsage(ref IRState irs, Loc loc)
{

    if (irs.params.cov && loc.linnum)
    {
        block_appendexp(irs.blx.curblock, incUsageElem(irs, loc));
    }
}
