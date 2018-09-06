/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/statementsem.d, _statementsem.d)
 * Documentation:  https://dlang.org/phobos/dmd_statementsem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/statementsem.d
 */

module dmd.statementsem;

import core.stdc.stdio;

import dmd.aggregate;
import dmd.aliasthis;
import dmd.arrayop;
import dmd.arraytypes;
import dmd.blockexit;
import dmd.clone;
import dmd.cond;
import dmd.ctorflow;
import dmd.dcast;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dimport;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errors;
import dmd.escape;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.gluelayer;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.intrange;
import dmd.mtype;
import dmd.nogc;
import dmd.opover;
import dmd.root.outbuffer;
import dmd.semantic2;
import dmd.sideeffect;
import dmd.statement;
import dmd.target;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

/*****************************************
 * CTFE requires FuncDeclaration::labtab for the interpretation.
 * So fixing the label name inside in/out contracts is necessary
 * for the uniqueness in labtab.
 * Params:
 *      sc = context
 *      ident = statement label name to be adjusted
 * Returns:
 *      adjusted label name
 */
private Identifier fixupLabelName(Scope* sc, Identifier ident)
{
    uint flags = (sc.flags & SCOPE.contract);
    const id = ident.toString();
    if (flags && flags != SCOPE.invariant_ &&
        !(id.length >= 2 && id[0] == '_' && id[1] == '_'))  // does not start with "__"
    {
        OutBuffer buf;
        buf.writestring(flags == SCOPE.require ? "__in_" : "__out_");
        buf.writestring(ident.toString());

        ident = Identifier.idPool(buf.peekSlice());
    }
    return ident;
}

/*******************************************
 * Check to see if statement is the innermost labeled statement.
 * Params:
 *      sc = context
 *      statement = Statement to check
 * Returns:
 *      if `true`, then the `LabelStatement`, otherwise `null`
 */
private LabelStatement checkLabeledLoop(Scope* sc, Statement statement)
{
    if (sc.slabel && sc.slabel.statement == statement)
    {
        return sc.slabel;
    }
    return null;
}

/***********************************************************
 * Check an assignment is used as a condition.
 * Intended to be use before the `semantic` call on `e`.
 * Params:
 *  e = condition expression which is not yet run semantic analysis.
 * Returns:
 *  `e` or ErrorExp.
 */
private Expression checkAssignmentAsCondition(Expression e)
{
    auto ec = lastComma(e);
    if (ec.op == TOK.assign)
    {
        ec.error("assignment cannot be used as a condition, perhaps `==` was meant?");
        return new ErrorExp();
    }
    return e;
}

// Performs semantic analysis in Statement AST nodes
extern(C++) Statement statementSemantic(Statement s, Scope* sc)
{
    scope v = new StatementSemanticVisitor(sc);
    s.accept(v);
    return v.result;
}

private extern (C++) final class StatementSemanticVisitor : Visitor
{
    alias visit = Visitor.visit;

    Statement result;
    Scope* sc;

    this(Scope* sc)
    {
        this.sc = sc;
    }

    private void setError()
    {
        result = new ErrorStatement();
    }

    override void visit(Statement s)
    {
        result = s;
    }

    override void visit(ErrorStatement s)
    {
        result = s;
    }

    override void visit(PeelStatement s)
    {
        /* "peel" off this wrapper, and don't run semantic()
         * on the result.
         */
        result = s.s;
    }

    override void visit(ExpStatement s)
    {
        /* https://dlang.org/spec/statement.html#expression-statement
         */

        if (s.exp)
        {
            //printf("ExpStatement::semantic() %s\n", exp.toChars());

            // Allow CommaExp in ExpStatement because return isn't used
            CommaExp.allow(s.exp);

            s.exp = s.exp.expressionSemantic(sc);
            s.exp = resolveProperties(sc, s.exp);
            s.exp = s.exp.addDtorHook(sc);
            if (checkNonAssignmentArrayOp(s.exp))
                s.exp = new ErrorExp();
            if (auto f = isFuncAddress(s.exp))
            {
                if (f.checkForwardRef(s.exp.loc))
                    s.exp = new ErrorExp();
            }
            if (discardValue(s.exp))
                s.exp = new ErrorExp();

            s.exp = s.exp.optimize(WANTvalue);
            s.exp = checkGC(sc, s.exp);
            if (s.exp.op == TOK.error)
                return setError();
        }
        result = s;
    }

    override void visit(CompileStatement cs)
    {
        /* https://dlang.org/spec/statement.html#mixin-statement
         */

        //printf("CompileStatement::semantic() %s\n", exp.toChars());
        Statements* a = cs.flatten(sc);
        if (!a)
            return;
        Statement s = new CompoundStatement(cs.loc, a);
        result = s.statementSemantic(sc);
    }

    override void visit(CompoundStatement cs)
    {
        //printf("CompoundStatement::semantic(this = %p, sc = %p)\n", cs, sc);
        version (none)
        {
            foreach (i, s; cs.statements)
            {
                if (s)
                    printf("[%d]: %s", i, s.toChars());
            }
        }

        for (size_t i = 0; i < cs.statements.dim;)
        {
            Statement s = (*cs.statements)[i];
            if (s)
            {
                Statements* flt = s.flatten(sc);
                if (flt)
                {
                    cs.statements.remove(i);
                    cs.statements.insert(i, flt);
                    continue;
                }
                s = s.statementSemantic(sc);
                (*cs.statements)[i] = s;
                if (s)
                {
                    Statement sentry;
                    Statement sexception;
                    Statement sfinally;

                    (*cs.statements)[i] = s.scopeCode(sc, &sentry, &sexception, &sfinally);
                    if (sentry)
                    {
                        sentry = sentry.statementSemantic(sc);
                        cs.statements.insert(i, sentry);
                        i++;
                    }
                    if (sexception)
                        sexception = sexception.statementSemantic(sc);
                    if (sexception)
                    {
                        if (i + 1 == cs.statements.dim && !sfinally)
                        {
                        }
                        else
                        {
                            /* Rewrite:
                             *      s; s1; s2;
                             * As:
                             *      s;
                             *      try { s1; s2; }
                             *      catch (Throwable __o)
                             *      { sexception; throw __o; }
                             */
                            auto a = new Statements();
                            foreach (j; i + 1 .. cs.statements.dim)
                            {
                                a.push((*cs.statements)[j]);
                            }
                            Statement _body = new CompoundStatement(Loc.initial, a);
                            _body = new ScopeStatement(Loc.initial, _body, Loc.initial);

                            Identifier id = Identifier.generateId("__o");

                            Statement handler = new PeelStatement(sexception);
                            if (sexception.blockExit(sc.func, false) & BE.fallthru)
                            {
                                auto ts = new ThrowStatement(Loc.initial, new IdentifierExp(Loc.initial, id));
                                ts.internalThrow = true;
                                handler = new CompoundStatement(Loc.initial, handler, ts);
                            }

                            auto catches = new Catches();
                            auto ctch = new Catch(Loc.initial, getThrowable(), id, handler);
                            ctch.internalCatch = true;
                            catches.push(ctch);

                            s = new TryCatchStatement(Loc.initial, _body, catches);
                            if (sfinally)
                                s = new TryFinallyStatement(Loc.initial, s, sfinally);
                            s = s.statementSemantic(sc);

                            cs.statements.setDim(i + 1);
                            cs.statements.push(s);
                            break;
                        }
                    }
                    else if (sfinally)
                    {
                        if (0 && i + 1 == cs.statements.dim)
                        {
                            cs.statements.push(sfinally);
                        }
                        else
                        {
                            /* Rewrite:
                             *      s; s1; s2;
                             * As:
                             *      s; try { s1; s2; } finally { sfinally; }
                             */
                            auto a = new Statements();
                            foreach (j; i + 1 .. cs.statements.dim)
                            {
                                a.push((*cs.statements)[j]);
                            }
                            Statement _body = new CompoundStatement(Loc.initial, a);
                            s = new TryFinallyStatement(Loc.initial, _body, sfinally);
                            s = s.statementSemantic(sc);
                            cs.statements.setDim(i + 1);
                            cs.statements.push(s);
                            break;
                        }
                    }
                }
                else
                {
                    /* Remove NULL statements from the list.
                     */
                    cs.statements.remove(i);
                    continue;
                }
            }
            i++;
        }
        foreach (i; 0 .. cs.statements.dim)
        {
        Lagain:
            Statement s = (*cs.statements)[i];
            if (!s)
                continue;

            Statement se = s.isErrorStatement();
            if (se)
            {
                result = se;
                return;
            }

            /* https://issues.dlang.org/show_bug.cgi?id=11653
             * 'semantic' may return another CompoundStatement
             * (eg. CaseRangeStatement), so flatten it here.
             */
            Statements* flt = s.flatten(sc);
            if (flt)
            {
                cs.statements.remove(i);
                cs.statements.insert(i, flt);
                if (cs.statements.dim <= i)
                    break;
                goto Lagain;
            }
        }
        if (cs.statements.dim == 1)
        {
            result = (*cs.statements)[0];
            return;
        }
        result = cs;
    }

    override void visit(UnrolledLoopStatement uls)
    {
        //printf("UnrolledLoopStatement::semantic(this = %p, sc = %p)\n", uls, sc);
        Scope* scd = sc.push();
        scd.sbreak = uls;
        scd.scontinue = uls;

        Statement serror = null;
        foreach (i, ref s; *uls.statements)
        {
            if (s)
            {
                //printf("[%d]: %s\n", i, s.toChars());
                s = s.statementSemantic(scd);
                if (s && !serror)
                    serror = s.isErrorStatement();
            }
        }

        scd.pop();
        result = serror ? serror : uls;
    }

    override void visit(ScopeStatement ss)
    {
        //printf("ScopeStatement::semantic(sc = %p)\n", sc);
        if (ss.statement)
        {
            ScopeDsymbol sym = new ScopeDsymbol();
            sym.parent = sc.scopesym;
            sym.endlinnum = ss.endloc.linnum;
            sc = sc.push(sym);

            Statements* a = ss.statement.flatten(sc);
            if (a)
            {
                ss.statement = new CompoundStatement(ss.loc, a);
            }

            ss.statement = ss.statement.statementSemantic(sc);
            if (ss.statement)
            {
                if (ss.statement.isErrorStatement())
                {
                    sc.pop();
                    result = ss.statement;
                    return;
                }

                Statement sentry;
                Statement sexception;
                Statement sfinally;
                ss.statement = ss.statement.scopeCode(sc, &sentry, &sexception, &sfinally);
                assert(!sentry);
                assert(!sexception);
                if (sfinally)
                {
                    //printf("adding sfinally\n");
                    sfinally = sfinally.statementSemantic(sc);
                    ss.statement = new CompoundStatement(ss.loc, ss.statement, sfinally);
                }
            }

            sc.pop();
        }
        result = ss;
    }

    override void visit(ForwardingStatement ss)
    {
        assert(ss.sym);
        for (Scope* csc = sc; !ss.sym.forward; csc = csc.enclosing)
        {
            assert(csc);
            ss.sym.forward = csc.scopesym;
        }
        sc = sc.push(ss.sym);
        sc.sbreak = ss;
        sc.scontinue = ss;
        ss.statement = ss.statement.statementSemantic(sc);
        sc = sc.pop();
        result = ss.statement;
    }

    override void visit(WhileStatement ws)
    {
        /* Rewrite as a for(;condition;) loop
         * https://dlang.org/spec/statement.html#while-statement
         */
        Statement s = new ForStatement(ws.loc, null, ws.condition, null, ws._body, ws.endloc);
        s = s.statementSemantic(sc);
        result = s;
    }

    override void visit(DoStatement ds)
    {
        /* https://dlang.org/spec/statement.html#do-statement
         */
        const inLoopSave = sc.inLoop;
        sc.inLoop = true;
        if (ds._body)
            ds._body = ds._body.semanticScope(sc, ds, ds);
        sc.inLoop = inLoopSave;

        if (ds.condition.op == TOK.dotIdentifier)
            (cast(DotIdExp)ds.condition).noderef = true;

        // check in syntax level
        ds.condition = checkAssignmentAsCondition(ds.condition);

        ds.condition = ds.condition.expressionSemantic(sc);
        ds.condition = resolveProperties(sc, ds.condition);
        if (checkNonAssignmentArrayOp(ds.condition))
            ds.condition = new ErrorExp();
        ds.condition = ds.condition.optimize(WANTvalue);
        ds.condition = checkGC(sc, ds.condition);

        ds.condition = ds.condition.toBoolean(sc);

        if (ds.condition.op == TOK.error)
            return setError();
        if (ds._body && ds._body.isErrorStatement())
        {
            result = ds._body;
            return;
        }

        result = ds;
    }

    override void visit(ForStatement fs)
    {
        /* https://dlang.org/spec/statement.html#for-statement
         */
        //printf("ForStatement::semantic %s\n", fs.toChars());

        if (fs._init)
        {
            /* Rewrite:
             *  for (auto v1 = i1, v2 = i2; condition; increment) { ... }
             * to:
             *  { auto v1 = i1, v2 = i2; for (; condition; increment) { ... } }
             * then lowered to:
             *  auto v1 = i1;
             *  try {
             *    auto v2 = i2;
             *    try {
             *      for (; condition; increment) { ... }
             *    } finally { v2.~this(); }
             *  } finally { v1.~this(); }
             */
            auto ainit = new Statements();
            ainit.push(fs._init);
            fs._init = null;
            ainit.push(fs);
            Statement s = new CompoundStatement(fs.loc, ainit);
            s = new ScopeStatement(fs.loc, s, fs.endloc);
            s = s.statementSemantic(sc);
            if (!s.isErrorStatement())
            {
                if (LabelStatement ls = checkLabeledLoop(sc, fs))
                    ls.gotoTarget = fs;
                fs.relatedLabeled = s;
            }
            result = s;
            return;
        }
        assert(fs._init is null);

        auto sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        sym.endlinnum = fs.endloc.linnum;
        sc = sc.push(sym);
        sc.inLoop = true;

        if (fs.condition)
        {
            if (fs.condition.op == TOK.dotIdentifier)
                (cast(DotIdExp)fs.condition).noderef = true;

            // check in syntax level
            fs.condition = checkAssignmentAsCondition(fs.condition);

            fs.condition = fs.condition.expressionSemantic(sc);
            fs.condition = resolveProperties(sc, fs.condition);
            if (checkNonAssignmentArrayOp(fs.condition))
                fs.condition = new ErrorExp();
            fs.condition = fs.condition.optimize(WANTvalue);
            fs.condition = checkGC(sc, fs.condition);

            fs.condition = fs.condition.toBoolean(sc);
        }
        if (fs.increment)
        {
            CommaExp.allow(fs.increment);
            fs.increment = fs.increment.expressionSemantic(sc);
            fs.increment = resolveProperties(sc, fs.increment);
            if (checkNonAssignmentArrayOp(fs.increment))
                fs.increment = new ErrorExp();
            fs.increment = fs.increment.optimize(WANTvalue);
            fs.increment = checkGC(sc, fs.increment);
        }

        sc.sbreak = fs;
        sc.scontinue = fs;
        if (fs._body)
            fs._body = fs._body.semanticNoScope(sc);

        sc.pop();

        if (fs.condition && fs.condition.op == TOK.error ||
            fs.increment && fs.increment.op == TOK.error ||
            fs._body && fs._body.isErrorStatement())
            return setError();
        result = fs;
    }

    /*******************
     * Determines the return type of makeTupleForeach.
     */
    private static template MakeTupleForeachRet(bool isDecl)
    {
        static if(isDecl)
        {
            alias MakeTupleForeachRet = Dsymbols*;
        }
        else
        {
            alias MakeTupleForeachRet = void;
        }
    }

    /*******************
     * Type check and unroll `foreach` over an expression tuple as well
     * as `static foreach` statements and `static foreach`
     * declarations. For `static foreach` statements and `static
     * foreach` declarations, the visitor interface is used (and the
     * result is written into the `result` field.) For `static
     * foreach` declarations, the resulting Dsymbols* are returned
     * directly.
     *
     * The unrolled body is wrapped into a
     *  - UnrolledLoopStatement, for `foreach` over an expression tuple.
     *  - ForwardingStatement, for `static foreach` statements.
     *  - ForwardingAttribDeclaration, for `static foreach` declarations.
     *
     * `static foreach` variables are declared as `STC.local`, such
     * that they are inserted into the local symbol tables of the
     * forwarding constructs instead of forwarded. For `static
     * foreach` with multiple foreach loop variables whose aggregate
     * has been lowered into a sequence of tuples, this function
     * expands the tuples into multiple `STC.local` `static foreach`
     * variables.
     */
    MakeTupleForeachRet!isDecl makeTupleForeach(bool isStatic, bool isDecl)(ForeachStatement fs, TupleForeachArgs!(isStatic, isDecl) args)
    {
        auto returnEarly()
        {
            static if (isDecl)
            {
                return null;
            }
            else
            {
                result = new ErrorStatement();
                return;
            }
        }
        static if(isDecl)
        {
            static assert(isStatic);
            auto dbody = args[0];
        }
        static if(isStatic)
        {
            auto needExpansion = args[$-1];
            assert(sc);
            auto previous = sc.scopesym;
        }
        alias s = fs;

        auto loc = fs.loc;
        size_t dim = fs.parameters.dim;
        static if(isStatic) bool skipCheck = needExpansion;
        else enum skipCheck = false;
        if (!skipCheck && (dim < 1 || dim > 2))
        {
            fs.error("only one (value) or two (key,value) arguments for tuple `foreach`");
            setError();
            return returnEarly();
        }

        Type paramtype = (*fs.parameters)[dim - 1].type;
        if (paramtype)
        {
            paramtype = paramtype.typeSemantic(loc, sc);
            if (paramtype.ty == Terror)
            {
                setError();
                return returnEarly();
            }
        }

        Type tab = fs.aggr.type.toBasetype();
        TypeTuple tuple = cast(TypeTuple)tab;
        static if(!isDecl)
        {
            auto statements = new Statements();
        }
        else
        {
            auto declarations = new Dsymbols();
        }
        //printf("aggr: op = %d, %s\n", fs.aggr.op, fs.aggr.toChars());
        size_t n;
        TupleExp te = null;
        if (fs.aggr.op == TOK.tuple) // expression tuple
        {
            te = cast(TupleExp)fs.aggr;
            n = te.exps.dim;
        }
        else if (fs.aggr.op == TOK.type) // type tuple
        {
            n = Parameter.dim(tuple.arguments);
        }
        else
            assert(0);
        foreach (j; 0 .. n)
        {
            size_t k = (fs.op == TOK.foreach_) ? j : n - 1 - j;
            Expression e = null;
            Type t = null;
            if (te)
                e = (*te.exps)[k];
            else
                t = Parameter.getNth(tuple.arguments, k).type;
            Parameter p = (*fs.parameters)[0];
            static if(!isDecl)
            {
                auto st = new Statements();
            }
            else
            {
                auto st = new Dsymbols();
            }

            static if(isStatic) bool skip = needExpansion;
            else enum skip = false;
            if (!skip && dim == 2)
            {
                // Declare key
                if (p.storageClass & (STC.out_ | STC.ref_ | STC.lazy_))
                {
                    fs.error("no storage class for key `%s`", p.ident.toChars());
                    setError();
                    return returnEarly();
                }
                static if(isStatic)
                {
                    if(!p.type)
                    {
                        p.type = Type.tsize_t;
                    }
                }
                p.type = p.type.typeSemantic(loc, sc);
                TY keyty = p.type.ty;
                if (keyty != Tint32 && keyty != Tuns32)
                {
                    if (global.params.isLP64)
                    {
                        if (keyty != Tint64 && keyty != Tuns64)
                        {
                            fs.error("`foreach`: key type must be `int` or `uint`, `long` or `ulong`, not `%s`", p.type.toChars());
                            setError();
                            return returnEarly();
                        }
                    }
                    else
                    {
                        fs.error("`foreach`: key type must be `int` or `uint`, not `%s`", p.type.toChars());
                        setError();
                        return returnEarly();
                    }
                }
                Initializer ie = new ExpInitializer(Loc.initial, new IntegerExp(k));
                auto var = new VarDeclaration(loc, p.type, p.ident, ie);
                var.storage_class |= STC.manifest;
                static if(isStatic) var.storage_class |= STC.local;
                static if(!isDecl)
                {
                    st.push(new ExpStatement(loc, var));
                }
                else
                {
                    st.push(var);
                }
                p = (*fs.parameters)[1]; // value
            }
            /***********************
             * Declares a unrolled `foreach` loop variable or a `static foreach` variable.
             *
             * Params:
             *     storageClass = The storage class of the variable.
             *     type = The declared type of the variable.
             *     ident = The name of the variable.
             *     e = The initializer of the variable (i.e. the current element of the looped over aggregate).
             *     t = The type of the initializer.
             * Returns:
             *     `true` iff the declaration was successful.
             */
            bool declareVariable(StorageClass storageClass, Type type, Identifier ident, Expression e, Type t)
            {
                if (storageClass & (STC.out_ | STC.lazy_) ||
                    storageClass & STC.ref_ && !te)
                {
                    fs.error("no storage class for value `%s`", ident.toChars());
                    setError();
                    return false;
                }
                Declaration var;
                if (e)
                {
                    Type tb = e.type.toBasetype();
                    Dsymbol ds = null;
                    if (!(storageClass & STC.manifest))
                    {
                        if ((isStatic || tb.ty == Tfunction || tb.ty == Tsarray || storageClass&STC.alias_) && e.op == TOK.variable)
                            ds = (cast(VarExp)e).var;
                        else if (e.op == TOK.template_)
                            ds = (cast(TemplateExp)e).td;
                        else if (e.op == TOK.scope_)
                            ds = (cast(ScopeExp)e).sds;
                        else if (e.op == TOK.function_)
                        {
                            auto fe = cast(FuncExp)e;
                            ds = fe.td ? cast(Dsymbol)fe.td : fe.fd;
                        }
                        else if (e.op == TOK.overloadSet)
                            ds = (cast(OverExp)e).vars;
                    }
                    else if (storageClass & STC.alias_)
                    {
                        fs.error("`foreach` loop variable cannot be both `enum` and `alias`");
                        setError();
                        return false;
                    }

                    if (ds)
                    {
                        var = new AliasDeclaration(loc, ident, ds);
                        if (storageClass & STC.ref_)
                        {
                            fs.error("symbol `%s` cannot be `ref`", ds.toChars());
                            setError();
                            return false;
                        }
                        if (paramtype)
                        {
                            fs.error("cannot specify element type for symbol `%s`", ds.toChars());
                            setError();
                            return false;
                        }
                    }
                    else if (e.op == TOK.type)
                    {
                        var = new AliasDeclaration(loc, ident, e.type);
                        if (paramtype)
                        {
                            fs.error("cannot specify element type for type `%s`", e.type.toChars());
                            setError();
                            return false;
                        }
                    }
                    else
                    {
                        e = resolveProperties(sc, e);
                        type = e.type;
                        if (paramtype)
                            type = paramtype;
                        Initializer ie = new ExpInitializer(Loc.initial, e);
                        auto v = new VarDeclaration(loc, type, ident, ie);
                        if (storageClass & STC.ref_)
                            v.storage_class |= STC.ref_ | STC.foreach_;
                        if (isStatic || storageClass&STC.manifest || e.isConst() ||
                            e.op == TOK.string_ ||
                            e.op == TOK.structLiteral ||
                            e.op == TOK.arrayLiteral)
                        {
                            if (v.storage_class & STC.ref_)
                            {
                                static if (!isStatic)
                                {
                                    fs.error("constant value `%s` cannot be `ref`", ie.toChars());
                                }
                                else
                                {
                                    if (!needExpansion)
                                    {
                                        fs.error("constant value `%s` cannot be `ref`", ie.toChars());
                                    }
                                    else
                                    {
                                        fs.error("constant value `%s` cannot be `ref`", ident.toChars());
                                    }
                                }
                                setError();
                                return false;
                            }
                            else
                                v.storage_class |= STC.manifest;
                        }
                        var = v;
                    }
                }
                else
                {
                    var = new AliasDeclaration(loc, ident, t);
                    if (paramtype)
                    {
                        fs.error("cannot specify element type for symbol `%s`", s.toChars());
                        setError();
                        return false;
                    }
                }
                static if (isStatic)
                {
                    var.storage_class |= STC.local;
                }
                static if (!isDecl)
                {
                    st.push(new ExpStatement(loc, var));
                }
                else
                {
                    st.push(var);
                }
                return true;
            }
            static if (!isStatic)
            {
                // Declare value
                if (!declareVariable(p.storageClass, p.type, p.ident, e, t))
                {
                    return returnEarly();
                }
            }
            else
            {
                if (!needExpansion)
                {
                    // Declare value
                    if (!declareVariable(p.storageClass, p.type, p.ident, e, t))
                    {
                        return returnEarly();
                    }
                }
                else
                { // expand tuples into multiple `static foreach` variables.
                    assert(e && !t);
                    auto ident = Identifier.generateId("__value");
                    declareVariable(0, e.type, ident, e, null);
                    import dmd.cond: StaticForeach;
                    auto field = Identifier.idPool(StaticForeach.tupleFieldName.ptr,StaticForeach.tupleFieldName.length);
                    Expression access = new DotIdExp(loc, e, field);
                    access = expressionSemantic(access, sc);
                    if (!tuple) return returnEarly();
                    //printf("%s\n",tuple.toChars());
                    foreach (l; 0 .. dim)
                    {
                        auto cp = (*fs.parameters)[l];
                        Expression init_ = new IndexExp(loc, access, new IntegerExp(loc, l, Type.tsize_t));
                        init_ = init_.expressionSemantic(sc);
                        assert(init_.type);
                        declareVariable(p.storageClass, init_.type, cp.ident, init_, null);
                    }
                }
            }

            static if (!isDecl)
            {
                if (fs._body) // https://issues.dlang.org/show_bug.cgi?id=17646
                    st.push(fs._body.syntaxCopy());
                Statement res = new CompoundStatement(loc, st);
            }
            else
            {
                st.append(Dsymbol.arraySyntaxCopy(dbody));
            }
            static if (!isStatic)
            {
                res = new ScopeStatement(loc, res, fs.endloc);
            }
            else static if (!isDecl)
            {
                auto fwd = new ForwardingStatement(loc, res);
                previous = fwd.sym;
                res = fwd;
            }
            else
            {
                import dmd.attrib: ForwardingAttribDeclaration;
                auto res = new ForwardingAttribDeclaration(st);
                previous = res.sym;
            }
            static if (!isDecl)
            {
                statements.push(res);
            }
            else
            {
                declarations.push(res);
            }
        }

        static if (!isStatic)
        {
            Statement res = new UnrolledLoopStatement(loc, statements);
            if (LabelStatement ls = checkLabeledLoop(sc, fs))
                ls.gotoTarget = res;
            if (te && te.e0)
                res = new CompoundStatement(loc, new ExpStatement(te.e0.loc, te.e0), res);
        }
        else static if (!isDecl)
        {
            Statement res = new CompoundStatement(loc, statements);
        }
        else
        {
            auto res = declarations;
        }
        static if (!isDecl)
        {
            result = res;
        }
        else
        {
            return res;
        }
    }

    override void visit(ForeachStatement fs)
    {
        /* https://dlang.org/spec/statement.html#foreach-statement
         */

        //printf("ForeachStatement::semantic() %p\n", fs);

        /******
         * Issue error if any of the ForeachTypes were not supplied and could not be inferred.
         * Returns:
         *      true if error issued
         */
        static bool checkForArgTypes(ForeachStatement fs)
        {
            bool result = false;
            foreach (p; *fs.parameters)
            {
                if (!p.type)
                {
                    fs.error("cannot infer type for `foreach` variable `%s`, perhaps set it explicitly", p.ident.toChars());
                    p.type = Type.terror;
                    result = true;
                }
            }
            return result;
        }

        const loc = fs.loc;
        const dim = fs.parameters.dim;
        TypeAArray taa = null;

        Type tn = null;
        Type tnv = null;

        fs.func = sc.func;
        if (fs.func.fes)
            fs.func = fs.func.fes.func;

        VarDeclaration vinit = null;
        fs.aggr = fs.aggr.expressionSemantic(sc);
        fs.aggr = resolveProperties(sc, fs.aggr);
        fs.aggr = fs.aggr.optimize(WANTvalue);
        if (fs.aggr.op == TOK.error)
            return setError();
        Expression oaggr = fs.aggr;
        if (fs.aggr.type && fs.aggr.type.toBasetype().ty == Tstruct &&
            (cast(TypeStruct)(fs.aggr.type.toBasetype())).sym.dtor &&
            fs.aggr.op != TOK.type && !fs.aggr.isLvalue())
        {
            // https://issues.dlang.org/show_bug.cgi?id=14653
            // Extend the life of rvalue aggregate till the end of foreach.
            vinit = copyToTemp(STC.rvalue, "__aggr", fs.aggr);
            vinit.endlinnum = fs.endloc.linnum;
            vinit.dsymbolSemantic(sc);
            fs.aggr = new VarExp(fs.aggr.loc, vinit);
        }

        Dsymbol sapply = null;                  // the inferred opApply() or front() function
        if (!inferForeachAggregate(sc, fs.op == TOK.foreach_, fs.aggr, sapply))
        {
            const(char)* msg = "";
            if (fs.aggr.type && isAggregate(fs.aggr.type))
            {
                msg = ", define `opApply()`, range primitives, or use `.tupleof`";
            }
            fs.error("invalid `foreach` aggregate `%s`%s", oaggr.toChars(), msg);
            return setError();
        }

        Dsymbol sapplyOld = sapply; // 'sapply' will be NULL if and after 'inferApplyArgTypes' errors

        /* Check for inference errors
         */
        if (!inferApplyArgTypes(fs, sc, sapply))
        {
            /**
             Try and extract the parameter count of the opApply callback function, e.g.:
             int opApply(int delegate(int, float)) => 2 args
             */
            bool foundMismatch = false;
            size_t foreachParamCount = 0;
            if (sapplyOld)
            {
                if (FuncDeclaration fd = sapplyOld.isFuncDeclaration())
                {
                    int fvarargs; // ignored (opApply shouldn't take variadics)
                    Parameters* fparameters = fd.getParameters(&fvarargs);

                    if (Parameter.dim(fparameters) == 1)
                    {
                        // first param should be the callback function
                        Parameter fparam = Parameter.getNth(fparameters, 0);
                        if ((fparam.type.ty == Tpointer ||
                             fparam.type.ty == Tdelegate) &&
                            fparam.type.nextOf().ty == Tfunction)
                        {
                            TypeFunction tf = cast(TypeFunction)fparam.type.nextOf();
                            foreachParamCount = Parameter.dim(tf.parameters);
                            foundMismatch = true;
                        }
                    }
                }
            }

            //printf("dim = %d, parameters.dim = %d\n", dim, parameters.dim);
            if (foundMismatch && dim != foreachParamCount)
            {
                const(char)* plural = foreachParamCount > 1 ? "s" : "";
                fs.error("cannot infer argument types, expected %d argument%s, not %d",
                    foreachParamCount, plural, dim);
            }
            else
                fs.error("cannot uniquely infer `foreach` argument types");

            return setError();
        }

        Type tab = fs.aggr.type.toBasetype();

        if (tab.ty == Ttuple) // don't generate new scope for tuple loops
        {
            makeTupleForeach!(false,false)(fs);
            if (vinit)
                result = new CompoundStatement(loc, new ExpStatement(loc, vinit), result);
            result = result.statementSemantic(sc);
            return;
        }

        auto sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        sym.endlinnum = fs.endloc.linnum;
        auto sc2 = sc.push(sym);
        sc2.inLoop = true;

        foreach (Parameter p; *fs.parameters)
        {
            if (p.storageClass & STC.manifest)
            {
                fs.error("cannot declare `enum` loop variables for non-unrolled foreach");
            }
            if (p.storageClass & STC.alias_)
            {
                fs.error("cannot declare `alias` loop variables for non-unrolled foreach");
            }
        }

        Statement s = fs;
        switch (tab.ty)
        {
        case Tarray:
        case Tsarray:
            {
                if (checkForArgTypes(fs))
                    goto case Terror;

                if (dim < 1 || dim > 2)
                {
                    fs.error("only one or two arguments for array `foreach`");
                    goto case Terror;
                }

                /* Look for special case of parsing char types out of char type
                 * array.
                 */
                tn = tab.nextOf().toBasetype();
                if (tn.ty == Tchar || tn.ty == Twchar || tn.ty == Tdchar)
                {
                    int i = (dim == 1) ? 0 : 1; // index of value
                    Parameter p = (*fs.parameters)[i];
                    p.type = p.type.typeSemantic(loc, sc2);
                    p.type = p.type.addStorageClass(p.storageClass);
                    tnv = p.type.toBasetype();
                    if (tnv.ty != tn.ty &&
                        (tnv.ty == Tchar || tnv.ty == Twchar || tnv.ty == Tdchar))
                    {
                        if (p.storageClass & STC.ref_)
                        {
                            fs.error("`foreach`: value of UTF conversion cannot be `ref`");
                            goto case Terror;
                        }
                        if (dim == 2)
                        {
                            p = (*fs.parameters)[0];
                            if (p.storageClass & STC.ref_)
                            {
                                fs.error("`foreach`: key cannot be `ref`");
                                goto case Terror;
                            }
                        }
                        goto Lapply;
                    }
                }

                foreach (i; 0 .. dim)
                {
                    // Declare parameters
                    Parameter p = (*fs.parameters)[i];
                    p.type = p.type.typeSemantic(loc, sc2);
                    p.type = p.type.addStorageClass(p.storageClass);
                    VarDeclaration var;

                    if (dim == 2 && i == 0)
                    {
                        var = new VarDeclaration(loc, p.type.mutableOf(), Identifier.generateId("__key"), null);
                        var.storage_class |= STC.temp | STC.foreach_;
                        if (var.storage_class & (STC.ref_ | STC.out_))
                            var.storage_class |= STC.nodtor;

                        fs.key = var;
                        if (p.storageClass & STC.ref_)
                        {
                            if (var.type.constConv(p.type) <= MATCH.nomatch)
                            {
                                fs.error("key type mismatch, `%s` to `ref %s`",
                                    var.type.toChars(), p.type.toChars());
                                goto case Terror;
                            }
                        }
                        if (tab.ty == Tsarray)
                        {
                            TypeSArray ta = cast(TypeSArray)tab;
                            IntRange dimrange = getIntRange(ta.dim);
                            if (!IntRange.fromType(var.type).contains(dimrange))
                            {
                                fs.error("index type `%s` cannot cover index range 0..%llu",
                                    p.type.toChars(), ta.dim.toInteger());
                                goto case Terror;
                            }
                            fs.key.range = new IntRange(SignExtendedNumber(0), dimrange.imax);
                        }
                    }
                    else
                    {
                        var = new VarDeclaration(loc, p.type, p.ident, null);
                        var.storage_class |= STC.foreach_;
                        var.storage_class |= p.storageClass & (STC.in_ | STC.out_ | STC.ref_ | STC.TYPECTOR);
                        if (var.storage_class & (STC.ref_ | STC.out_))
                            var.storage_class |= STC.nodtor;

                        fs.value = var;
                        if (var.storage_class & STC.ref_)
                        {
                            if (fs.aggr.checkModifiable(sc2, 1) == 2)
                                var.storage_class |= STC.ctorinit;

                            Type t = tab.nextOf();
                            if (t.constConv(p.type) <= MATCH.nomatch)
                            {
                                fs.error("argument type mismatch, `%s` to `ref %s`",
                                    t.toChars(), p.type.toChars());
                                goto case Terror;
                            }
                        }
                    }
                }

                /* Convert to a ForStatement
                 *   foreach (key, value; a) body =>
                 *   for (T[] tmp = a[], size_t key; key < tmp.length; ++key)
                 *   { T value = tmp[k]; body }
                 *
                 *   foreach_reverse (key, value; a) body =>
                 *   for (T[] tmp = a[], size_t key = tmp.length; key--; )
                 *   { T value = tmp[k]; body }
                 */
                auto id = Identifier.generateId("__r");
                auto ie = new ExpInitializer(loc, new SliceExp(loc, fs.aggr, null, null));
                VarDeclaration tmp;
                if (fs.aggr.op == TOK.arrayLiteral &&
                    !((*fs.parameters)[dim - 1].storageClass & STC.ref_))
                {
                    auto ale = cast(ArrayLiteralExp)fs.aggr;
                    size_t edim = ale.elements ? ale.elements.dim : 0;
                    auto telem = (*fs.parameters)[dim - 1].type;

                    // https://issues.dlang.org/show_bug.cgi?id=12936
                    // if telem has been specified explicitly,
                    // converting array literal elements to telem might make it @nogc.
                    fs.aggr = fs.aggr.implicitCastTo(sc, telem.sarrayOf(edim));
                    if (fs.aggr.op == TOK.error)
                        goto case Terror;

                    // for (T[edim] tmp = a, ...)
                    tmp = new VarDeclaration(loc, fs.aggr.type, id, ie);
                }
                else
                    tmp = new VarDeclaration(loc, tab.nextOf().arrayOf(), id, ie);
                tmp.storage_class |= STC.temp;

                Expression tmp_length = new DotIdExp(loc, new VarExp(loc, tmp), Id.length);

                if (!fs.key)
                {
                    Identifier idkey = Identifier.generateId("__key");
                    fs.key = new VarDeclaration(loc, Type.tsize_t, idkey, null);
                    fs.key.storage_class |= STC.temp;
                }
                if (fs.op == TOK.foreach_reverse_)
                    fs.key._init = new ExpInitializer(loc, tmp_length);
                else
                    fs.key._init = new ExpInitializer(loc, new IntegerExp(loc, 0, fs.key.type));

                auto cs = new Statements();
                if (vinit)
                    cs.push(new ExpStatement(loc, vinit));
                cs.push(new ExpStatement(loc, tmp));
                cs.push(new ExpStatement(loc, fs.key));
                Statement forinit = new CompoundDeclarationStatement(loc, cs);

                Expression cond;
                if (fs.op == TOK.foreach_reverse_)
                {
                    // key--
                    cond = new PostExp(TOK.minusMinus, loc, new VarExp(loc, fs.key));
                }
                else
                {
                    // key < tmp.length
                    cond = new CmpExp(TOK.lessThan, loc, new VarExp(loc, fs.key), tmp_length);
                }

                Expression increment = null;
                if (fs.op == TOK.foreach_)
                {
                    // key += 1
                    increment = new AddAssignExp(loc, new VarExp(loc, fs.key), new IntegerExp(loc, 1, fs.key.type));
                }

                // T value = tmp[key];
                IndexExp indexExp = new IndexExp(loc, new VarExp(loc, tmp), new VarExp(loc, fs.key));
                indexExp.indexIsInBounds = true; // disabling bounds checking in foreach statements.
                fs.value._init = new ExpInitializer(loc, indexExp);
                Statement ds = new ExpStatement(loc, fs.value);

                if (dim == 2)
                {
                    Parameter p = (*fs.parameters)[0];
                    if ((p.storageClass & STC.ref_) && p.type.equals(fs.key.type))
                    {
                        fs.key.range = null;
                        auto v = new AliasDeclaration(loc, p.ident, fs.key);
                        fs._body = new CompoundStatement(loc, new ExpStatement(loc, v), fs._body);
                    }
                    else
                    {
                        auto ei = new ExpInitializer(loc, new IdentifierExp(loc, fs.key.ident));
                        auto v = new VarDeclaration(loc, p.type, p.ident, ei);
                        v.storage_class |= STC.foreach_ | (p.storageClass & STC.ref_);
                        fs._body = new CompoundStatement(loc, new ExpStatement(loc, v), fs._body);
                        if (fs.key.range && !p.type.isMutable())
                        {
                            /* Limit the range of the key to the specified range
                             */
                            v.range = new IntRange(fs.key.range.imin, fs.key.range.imax - SignExtendedNumber(1));
                        }
                    }
                }
                fs._body = new CompoundStatement(loc, ds, fs._body);

                s = new ForStatement(loc, forinit, cond, increment, fs._body, fs.endloc);
                if (auto ls = checkLabeledLoop(sc, fs))   // https://issues.dlang.org/show_bug.cgi?id=15450
                                                          // don't use sc2
                    ls.gotoTarget = s;
                s = s.statementSemantic(sc2);
                break;
            }
        case Taarray:
            if (fs.op == TOK.foreach_reverse_)
                fs.warning("cannot use `foreach_reverse` with an associative array");
            if (checkForArgTypes(fs))
                goto case Terror;

            taa = cast(TypeAArray)tab;
            if (dim < 1 || dim > 2)
            {
                fs.error("only one or two arguments for associative array `foreach`");
                goto case Terror;
            }
            goto Lapply;

        case Tclass:
        case Tstruct:
            /* Prefer using opApply, if it exists
             */
            if (sapply)
                goto Lapply;
            {
                /* Look for range iteration, i.e. the properties
                 * .empty, .popFront, .popBack, .front and .back
                 *    foreach (e; aggr) { ... }
                 * translates to:
                 *    for (auto __r = aggr[]; !__r.empty; __r.popFront()) {
                 *        auto e = __r.front;
                 *        ...
                 *    }
                 */
                auto ad = (tab.ty == Tclass) ?
                    cast(AggregateDeclaration)(cast(TypeClass)tab).sym :
                    cast(AggregateDeclaration)(cast(TypeStruct)tab).sym;
                Identifier idfront;
                Identifier idpopFront;
                if (fs.op == TOK.foreach_)
                {
                    idfront = Id.Ffront;
                    idpopFront = Id.FpopFront;
                }
                else
                {
                    idfront = Id.Fback;
                    idpopFront = Id.FpopBack;
                }
                auto sfront = ad.search(Loc.initial, idfront);
                if (!sfront)
                    goto Lapply;

                /* Generate a temporary __r and initialize it with the aggregate.
                 */
                VarDeclaration r;
                Statement _init;
                if (vinit && fs.aggr.op == TOK.variable && (cast(VarExp)fs.aggr).var == vinit)
                {
                    r = vinit;
                    _init = new ExpStatement(loc, vinit);
                }
                else
                {
                    r = copyToTemp(0, "__r", fs.aggr);
                    r.dsymbolSemantic(sc);
                    _init = new ExpStatement(loc, r);
                    if (vinit)
                        _init = new CompoundStatement(loc, new ExpStatement(loc, vinit), _init);
                }

                // !__r.empty
                Expression e = new VarExp(loc, r);
                e = new DotIdExp(loc, e, Id.Fempty);
                Expression condition = new NotExp(loc, e);

                // __r.idpopFront()
                e = new VarExp(loc, r);
                Expression increment = new CallExp(loc, new DotIdExp(loc, e, idpopFront));

                /* Declaration statement for e:
                 *    auto e = __r.idfront;
                 */
                e = new VarExp(loc, r);
                Expression einit = new DotIdExp(loc, e, idfront);
                Statement makeargs, forbody;
                if (dim == 1)
                {
                    auto p = (*fs.parameters)[0];
                    auto ve = new VarDeclaration(loc, p.type, p.ident, new ExpInitializer(loc, einit));
                    ve.storage_class |= STC.foreach_;
                    ve.storage_class |= p.storageClass & (STC.in_ | STC.out_ | STC.ref_ | STC.TYPECTOR);

                    makeargs = new ExpStatement(loc, ve);
                }
                else
                {
                    auto vd = copyToTemp(STC.ref_, "__front", einit);
                    vd.dsymbolSemantic(sc);
                    makeargs = new ExpStatement(loc, vd);

                    Type tfront;
                    if (auto fd = sfront.isFuncDeclaration())
                    {
                        if (!fd.functionSemantic())
                            goto Lrangeerr;
                        tfront = fd.type;
                    }
                    else if (auto td = sfront.isTemplateDeclaration())
                    {
                        Expressions a;
                        if (auto f = resolveFuncCall(loc, sc, td, null, tab, &a, 1))
                            tfront = f.type;
                    }
                    else if (auto d = sfront.isDeclaration())
                    {
                        tfront = d.type;
                    }
                    if (!tfront || tfront.ty == Terror)
                        goto Lrangeerr;
                    if (tfront.toBasetype().ty == Tfunction)
                        tfront = tfront.toBasetype().nextOf();
                    if (tfront.ty == Tvoid)
                    {
                        fs.error("`%s.front` is `void` and has no value", oaggr.toChars());
                        goto case Terror;
                    }

                    // Resolve inout qualifier of front type
                    tfront = tfront.substWildTo(tab.mod);

                    Expression ve = new VarExp(loc, vd);
                    ve.type = tfront;

                    auto exps = new Expressions();
                    exps.push(ve);
                    int pos = 0;
                    while (exps.dim < dim)
                    {
                        pos = expandAliasThisTuples(exps, pos);
                        if (pos == -1)
                            break;
                    }
                    if (exps.dim != dim)
                    {
                        const(char)* plural = exps.dim > 1 ? "s" : "";
                        fs.error("cannot infer argument types, expected %d argument%s, not %d",
                            exps.dim, plural, dim);
                        goto case Terror;
                    }

                    foreach (i; 0 .. dim)
                    {
                        auto p = (*fs.parameters)[i];
                        auto exp = (*exps)[i];
                        version (none)
                        {
                            printf("[%d] p = %s %s, exp = %s %s\n", i,
                                p.type ? p.type.toChars() : "?", p.ident.toChars(),
                                exp.type.toChars(), exp.toChars());
                        }
                        if (!p.type)
                            p.type = exp.type;
                        p.type = p.type.addStorageClass(p.storageClass).typeSemantic(loc, sc2);
                        if (!exp.implicitConvTo(p.type))
                            goto Lrangeerr;

                        auto var = new VarDeclaration(loc, p.type, p.ident, new ExpInitializer(loc, exp));
                        var.storage_class |= STC.ctfe | STC.ref_ | STC.foreach_;
                        makeargs = new CompoundStatement(loc, makeargs, new ExpStatement(loc, var));
                    }
                }

                forbody = new CompoundStatement(loc, makeargs, fs._body);

                s = new ForStatement(loc, _init, condition, increment, forbody, fs.endloc);
                if (auto ls = checkLabeledLoop(sc, fs))
                    ls.gotoTarget = s;

                version (none)
                {
                    printf("init: %s\n", _init.toChars());
                    printf("condition: %s\n", condition.toChars());
                    printf("increment: %s\n", increment.toChars());
                    printf("body: %s\n", forbody.toChars());
                }
                s = s.statementSemantic(sc2);
                break;

            Lrangeerr:
                fs.error("cannot infer argument types");
                goto case Terror;
            }
        case Tdelegate:
            if (fs.op == TOK.foreach_reverse_)
                fs.deprecation("cannot use `foreach_reverse` with a delegate");
        Lapply:
            {
                if (checkForArgTypes(fs))
                    goto case Terror;

                TypeFunction tfld = null;
                if (sapply)
                {
                    FuncDeclaration fdapply = sapply.isFuncDeclaration();
                    if (fdapply)
                    {
                        assert(fdapply.type && fdapply.type.ty == Tfunction);
                        tfld = cast(TypeFunction)fdapply.type.typeSemantic(loc, sc2);
                        goto Lget;
                    }
                    else if (tab.ty == Tdelegate)
                    {
                        tfld = cast(TypeFunction)tab.nextOf();
                    Lget:
                        //printf("tfld = %s\n", tfld.toChars());
                        if (tfld.parameters.dim == 1)
                        {
                            Parameter p = Parameter.getNth(tfld.parameters, 0);
                            if (p.type && p.type.ty == Tdelegate)
                            {
                                auto t = p.type.typeSemantic(loc, sc2);
                                assert(t.ty == Tdelegate);
                                tfld = cast(TypeFunction)t.nextOf();
                            }
                            //printf("tfld = %s\n", tfld.toChars());
                        }
                    }
                }

                FuncExp flde = foreachBodyToFunction(sc2, fs, tfld);
                if (!flde)
                    goto case Terror;

                // Resolve any forward referenced goto's
                foreach (i; 0 .. fs.gotos.dim)
                {
                    GotoStatement gs = cast(GotoStatement)(*fs.gotos)[i].statement;
                    if (!gs.label.statement)
                    {
                        // 'Promote' it to this scope, and replace with a return
                        fs.cases.push(gs);
                        s = new ReturnStatement(Loc.initial, new IntegerExp(fs.cases.dim + 1));
                        (*fs.gotos)[i].statement = s;
                    }
                }

                Expression e = null;
                Expression ec;
                if (vinit)
                {
                    e = new DeclarationExp(loc, vinit);
                    e = e.expressionSemantic(sc2);
                    if (e.op == TOK.error)
                        goto case Terror;
                }

                if (taa)
                {
                    // Check types
                    Parameter p = (*fs.parameters)[0];
                    bool isRef = (p.storageClass & STC.ref_) != 0;
                    Type ta = p.type;
                    if (dim == 2)
                    {
                        Type ti = (isRef ? taa.index.addMod(MODFlags.const_) : taa.index);
                        if (isRef ? !ti.constConv(ta) : !ti.implicitConvTo(ta))
                        {
                            fs.error("`foreach`: index must be type `%s`, not `%s`",
                                ti.toChars(), ta.toChars());
                            goto case Terror;
                        }
                        p = (*fs.parameters)[1];
                        isRef = (p.storageClass & STC.ref_) != 0;
                        ta = p.type;
                    }
                    Type taav = taa.nextOf();
                    if (isRef ? !taav.constConv(ta) : !taav.implicitConvTo(ta))
                    {
                        fs.error("`foreach`: value must be type `%s`, not `%s`",
                            taav.toChars(), ta.toChars());
                        goto case Terror;
                    }

                    /* Call:
                     *  extern(C) int _aaApply(void*, in size_t, int delegate(void*))
                     *      _aaApply(aggr, keysize, flde)
                     *
                     *  extern(C) int _aaApply2(void*, in size_t, int delegate(void*, void*))
                     *      _aaApply2(aggr, keysize, flde)
                     */
                    __gshared const(char)** name = ["_aaApply", "_aaApply2"];
                    __gshared FuncDeclaration* fdapply = [null, null];
                    __gshared TypeDelegate* fldeTy = [null, null];

                    ubyte i = (dim == 2 ? 1 : 0);
                    if (!fdapply[i])
                    {
                        auto params = new Parameters();
                        params.push(new Parameter(0, Type.tvoid.pointerTo(), null, null, null));
                        params.push(new Parameter(STC.in_, Type.tsize_t, null, null, null));
                        auto dgparams = new Parameters();
                        dgparams.push(new Parameter(0, Type.tvoidptr, null, null, null));
                        if (dim == 2)
                            dgparams.push(new Parameter(0, Type.tvoidptr, null, null, null));
                        fldeTy[i] = new TypeDelegate(new TypeFunction(dgparams, Type.tint32, 0, LINK.d));
                        params.push(new Parameter(0, fldeTy[i], null, null, null));
                        fdapply[i] = FuncDeclaration.genCfunc(params, Type.tint32, name[i]);
                    }

                    auto exps = new Expressions();
                    exps.push(fs.aggr);
                    auto keysize = taa.index.size();
                    if (keysize == SIZE_INVALID)
                        goto case Terror;
                    assert(keysize < keysize.max - Target.ptrsize);
                    keysize = (keysize + (Target.ptrsize - 1)) & ~(Target.ptrsize - 1);
                    // paint delegate argument to the type runtime expects
                    Expression fexp = flde;
                    if (!fldeTy[i].equals(flde.type))
                    {
                        fexp = new CastExp(loc, flde, flde.type);
                        fexp.type = fldeTy[i];
                    }
                    exps.push(new IntegerExp(Loc.initial, keysize, Type.tsize_t));
                    exps.push(fexp);
                    ec = new VarExp(Loc.initial, fdapply[i], false);
                    ec = new CallExp(loc, ec, exps);
                    ec.type = Type.tint32; // don't run semantic() on ec
                }
                else if (tab.ty == Tarray || tab.ty == Tsarray)
                {
                    /* Call:
                     *      _aApply(aggr, flde)
                     */
                    __gshared const(char)** fntab =
                    [
                        "cc", "cw", "cd",
                        "wc", "cc", "wd",
                        "dc", "dw", "dd"
                    ];

                    const(size_t) BUFFER_LEN = 7 + 1 + 2 + dim.sizeof * 3 + 1;
                    char[BUFFER_LEN] fdname;
                    int flag;

                    switch (tn.ty)
                    {
                    case Tchar:     flag = 0;   break;
                    case Twchar:    flag = 3;   break;
                    case Tdchar:    flag = 6;   break;
                    default:
                        assert(0);
                    }
                    switch (tnv.ty)
                    {
                    case Tchar:     flag += 0;  break;
                    case Twchar:    flag += 1;  break;
                    case Tdchar:    flag += 2;  break;
                    default:
                        assert(0);
                    }
                    const(char)* r = (fs.op == TOK.foreach_reverse_) ? "R" : "";
                    int j = sprintf(fdname.ptr, "_aApply%s%.*s%llu", r, 2, fntab[flag], cast(ulong)dim);
                    assert(j < BUFFER_LEN);

                    FuncDeclaration fdapply;
                    TypeDelegate dgty;
                    auto params = new Parameters();
                    params.push(new Parameter(STC.in_, tn.arrayOf(), null, null, null));
                    auto dgparams = new Parameters();
                    dgparams.push(new Parameter(0, Type.tvoidptr, null, null, null));
                    if (dim == 2)
                        dgparams.push(new Parameter(0, Type.tvoidptr, null, null, null));
                    dgty = new TypeDelegate(new TypeFunction(dgparams, Type.tint32, 0, LINK.d));
                    params.push(new Parameter(0, dgty, null, null, null));
                    fdapply = FuncDeclaration.genCfunc(params, Type.tint32, fdname.ptr);

                    if (tab.ty == Tsarray)
                        fs.aggr = fs.aggr.castTo(sc2, tn.arrayOf());
                    // paint delegate argument to the type runtime expects
                    Expression fexp = flde;
                    if (!dgty.equals(flde.type))
                    {
                        fexp = new CastExp(loc, flde, flde.type);
                        fexp.type = dgty;
                    }
                    ec = new VarExp(Loc.initial, fdapply, false);
                    ec = new CallExp(loc, ec, fs.aggr, fexp);
                    ec.type = Type.tint32; // don't run semantic() on ec
                }
                else if (tab.ty == Tdelegate)
                {
                    /* Call:
                     *      aggr(flde)
                     */
                    if (fs.aggr.op == TOK.delegate_ && (cast(DelegateExp)fs.aggr).func.isNested())
                    {
                        // https://issues.dlang.org/show_bug.cgi?id=3560
                        fs.aggr = (cast(DelegateExp)fs.aggr).e1;
                    }
                    ec = new CallExp(loc, fs.aggr, flde);
                    ec = ec.expressionSemantic(sc2);
                    if (ec.op == TOK.error)
                        goto case Terror;
                    if (ec.type != Type.tint32)
                    {
                        fs.error("`opApply()` function for `%s` must return an `int`", tab.toChars());
                        goto case Terror;
                    }
                }
                else
                {
version (none)
{
                    if (global.params.vsafe)
                    {
                        message(loc, "To enforce `@safe`, the compiler allocates a closure unless `opApply()` uses `scope`");
                    }
                    flde.fd.tookAddressOf = 1;
}
else
{
                    if (global.params.vsafe)
                        ++flde.fd.tookAddressOf;  // allocate a closure unless the opApply() uses 'scope'
}
                    assert(tab.ty == Tstruct || tab.ty == Tclass);
                    assert(sapply);
                    /* Call:
                     *  aggr.apply(flde)
                     */
                    ec = new DotIdExp(loc, fs.aggr, sapply.ident);
                    ec = new CallExp(loc, ec, flde);
                    ec = ec.expressionSemantic(sc2);
                    if (ec.op == TOK.error)
                        goto case Terror;
                    if (ec.type != Type.tint32)
                    {
                        fs.error("`opApply()` function for `%s` must return an `int`", tab.toChars());
                        goto case Terror;
                    }
                }
                e = Expression.combine(e, ec);

                if (!fs.cases.dim)
                {
                    // Easy case, a clean exit from the loop
                    e = new CastExp(loc, e, Type.tvoid); // https://issues.dlang.org/show_bug.cgi?id=13899
                    s = new ExpStatement(loc, e);
                }
                else
                {
                    // Construct a switch statement around the return value
                    // of the apply function.
                    auto a = new Statements();

                    // default: break; takes care of cases 0 and 1
                    s = new BreakStatement(Loc.initial, null);
                    s = new DefaultStatement(Loc.initial, s);
                    a.push(s);

                    // cases 2...
                    foreach (i, c; *fs.cases)
                    {
                        s = new CaseStatement(Loc.initial, new IntegerExp(i + 2), c);
                        a.push(s);
                    }

                    s = new CompoundStatement(loc, a);
                    s = new SwitchStatement(loc, e, s, false);
                }
                s = s.statementSemantic(sc2);
                break;
            }
            assert(0);

        case Terror:
            s = new ErrorStatement();
            break;

        default:
            fs.error("`foreach`: `%s` is not an aggregate type", fs.aggr.type.toChars());
            goto case Terror;
        }
        sc2.pop();
        result = s;
    }

    /*************************************
     * Turn foreach body into the function literal:
     *  int delegate(ref T param) { body }
     * Params:
     *  sc = context
     *  fs = ForeachStatement
     *  tfld = type of function literal to be created, can be null
     * Returns:
     *  Function literal created, as an expression
     *  null if error.
     */
    static FuncExp foreachBodyToFunction(Scope* sc, ForeachStatement fs, TypeFunction tfld)
    {
        auto params = new Parameters();
        foreach (i; 0 .. fs.parameters.dim)
        {
            Parameter p = (*fs.parameters)[i];
            StorageClass stc = STC.ref_;
            Identifier id;

            p.type = p.type.typeSemantic(fs.loc, sc);
            p.type = p.type.addStorageClass(p.storageClass);
            if (tfld)
            {
                Parameter prm = Parameter.getNth(tfld.parameters, i);
                //printf("\tprm = %s%s\n", (prm.storageClass&STC.ref_?"ref ":"").ptr, prm.ident.toChars());
                stc = prm.storageClass & STC.ref_;
                id = p.ident; // argument copy is not need.
                if ((p.storageClass & STC.ref_) != stc)
                {
                    if (!stc)
                    {
                        fs.error("`foreach`: cannot make `%s` `ref`", p.ident.toChars());
                        return null;
                    }
                    goto LcopyArg;
                }
            }
            else if (p.storageClass & STC.ref_)
            {
                // default delegate parameters are marked as ref, then
                // argument copy is not need.
                id = p.ident;
            }
            else
            {
                // Make a copy of the ref argument so it isn't
                // a reference.
            LcopyArg:
                id = Identifier.generateId("__applyArg", cast(int)i);

                Initializer ie = new ExpInitializer(fs.loc, new IdentifierExp(fs.loc, id));
                auto v = new VarDeclaration(fs.loc, p.type, p.ident, ie);
                v.storage_class |= STC.temp;
                Statement s = new ExpStatement(fs.loc, v);
                fs._body = new CompoundStatement(fs.loc, s, fs._body);
            }
            params.push(new Parameter(stc, p.type, id, null, null));
        }
        // https://issues.dlang.org/show_bug.cgi?id=13840
        // Throwable nested function inside nothrow function is acceptable.
        StorageClass stc = mergeFuncAttrs(STC.safe | STC.pure_ | STC.nogc, fs.func);
        auto tf = new TypeFunction(params, Type.tint32, 0, LINK.d, stc);
        fs.cases = new Statements();
        fs.gotos = new ScopeStatements();
        auto fld = new FuncLiteralDeclaration(fs.loc, fs.endloc, tf, TOK.delegate_, fs);
        fld.fbody = fs._body;
        Expression flde = new FuncExp(fs.loc, fld);
        flde = flde.expressionSemantic(sc);
        fld.tookAddressOf = 0;
        if (flde.op == TOK.error)
            return null;
        return cast(FuncExp)flde;
    }

    override void visit(ForeachRangeStatement fs)
    {
        /* https://dlang.org/spec/statement.html#foreach-range-statement
         */

        //printf("ForeachRangeStatement::semantic() %p\n", fs);
        auto loc = fs.loc;
        fs.lwr = fs.lwr.expressionSemantic(sc);
        fs.lwr = resolveProperties(sc, fs.lwr);
        fs.lwr = fs.lwr.optimize(WANTvalue);
        if (!fs.lwr.type)
        {
            fs.error("invalid range lower bound `%s`", fs.lwr.toChars());
            return setError();
        }

        fs.upr = fs.upr.expressionSemantic(sc);
        fs.upr = resolveProperties(sc, fs.upr);
        fs.upr = fs.upr.optimize(WANTvalue);
        if (!fs.upr.type)
        {
            fs.error("invalid range upper bound `%s`", fs.upr.toChars());
            return setError();
        }

        if (fs.prm.type)
        {
            fs.prm.type = fs.prm.type.typeSemantic(loc, sc);
            fs.prm.type = fs.prm.type.addStorageClass(fs.prm.storageClass);
            fs.lwr = fs.lwr.implicitCastTo(sc, fs.prm.type);

            if (fs.upr.implicitConvTo(fs.prm.type) || (fs.prm.storageClass & STC.ref_))
            {
                fs.upr = fs.upr.implicitCastTo(sc, fs.prm.type);
            }
            else
            {
                // See if upr-1 fits in prm.type
                Expression limit = new MinExp(loc, fs.upr, new IntegerExp(1));
                limit = limit.expressionSemantic(sc);
                limit = limit.optimize(WANTvalue);
                if (!limit.implicitConvTo(fs.prm.type))
                {
                    fs.upr = fs.upr.implicitCastTo(sc, fs.prm.type);
                }
            }
        }
        else
        {
            /* Must infer types from lwr and upr
             */
            Type tlwr = fs.lwr.type.toBasetype();
            if (tlwr.ty == Tstruct || tlwr.ty == Tclass)
            {
                /* Just picking the first really isn't good enough.
                 */
                fs.prm.type = fs.lwr.type;
            }
            else if (fs.lwr.type == fs.upr.type)
            {
                /* Same logic as CondExp ?lwr:upr
                 */
                fs.prm.type = fs.lwr.type;
            }
            else
            {
                scope AddExp ea = new AddExp(loc, fs.lwr, fs.upr);
                if (typeCombine(ea, sc))
                    return setError();
                fs.prm.type = ea.type;
                fs.lwr = ea.e1;
                fs.upr = ea.e2;
            }
            fs.prm.type = fs.prm.type.addStorageClass(fs.prm.storageClass);
        }
        if (fs.prm.type.ty == Terror || fs.lwr.op == TOK.error || fs.upr.op == TOK.error)
        {
            return setError();
        }

        /* Convert to a for loop:
         *  foreach (key; lwr .. upr) =>
         *  for (auto key = lwr, auto tmp = upr; key < tmp; ++key)
         *
         *  foreach_reverse (key; lwr .. upr) =>
         *  for (auto tmp = lwr, auto key = upr; key-- > tmp;)
         */
        auto ie = new ExpInitializer(loc, (fs.op == TOK.foreach_) ? fs.lwr : fs.upr);
        fs.key = new VarDeclaration(loc, fs.upr.type.mutableOf(), Identifier.generateId("__key"), ie);
        fs.key.storage_class |= STC.temp;
        SignExtendedNumber lower = getIntRange(fs.lwr).imin;
        SignExtendedNumber upper = getIntRange(fs.upr).imax;
        if (lower <= upper)
        {
            fs.key.range = new IntRange(lower, upper);
        }

        Identifier id = Identifier.generateId("__limit");
        ie = new ExpInitializer(loc, (fs.op == TOK.foreach_) ? fs.upr : fs.lwr);
        auto tmp = new VarDeclaration(loc, fs.upr.type, id, ie);
        tmp.storage_class |= STC.temp;

        auto cs = new Statements();
        // Keep order of evaluation as lwr, then upr
        if (fs.op == TOK.foreach_)
        {
            cs.push(new ExpStatement(loc, fs.key));
            cs.push(new ExpStatement(loc, tmp));
        }
        else
        {
            cs.push(new ExpStatement(loc, tmp));
            cs.push(new ExpStatement(loc, fs.key));
        }
        Statement forinit = new CompoundDeclarationStatement(loc, cs);

        Expression cond;
        if (fs.op == TOK.foreach_reverse_)
        {
            cond = new PostExp(TOK.minusMinus, loc, new VarExp(loc, fs.key));
            if (fs.prm.type.isscalar())
            {
                // key-- > tmp
                cond = new CmpExp(TOK.greaterThan, loc, cond, new VarExp(loc, tmp));
            }
            else
            {
                // key-- != tmp
                cond = new EqualExp(TOK.notEqual, loc, cond, new VarExp(loc, tmp));
            }
        }
        else
        {
            if (fs.prm.type.isscalar())
            {
                // key < tmp
                cond = new CmpExp(TOK.lessThan, loc, new VarExp(loc, fs.key), new VarExp(loc, tmp));
            }
            else
            {
                // key != tmp
                cond = new EqualExp(TOK.notEqual, loc, new VarExp(loc, fs.key), new VarExp(loc, tmp));
            }
        }

        Expression increment = null;
        if (fs.op == TOK.foreach_)
        {
            // key += 1
            //increment = new AddAssignExp(loc, new VarExp(loc, fs.key), new IntegerExp(1));
            increment = new PreExp(TOK.prePlusPlus, loc, new VarExp(loc, fs.key));
        }
        if ((fs.prm.storageClass & STC.ref_) && fs.prm.type.equals(fs.key.type))
        {
            fs.key.range = null;
            auto v = new AliasDeclaration(loc, fs.prm.ident, fs.key);
            fs._body = new CompoundStatement(loc, new ExpStatement(loc, v), fs._body);
        }
        else
        {
            ie = new ExpInitializer(loc, new CastExp(loc, new VarExp(loc, fs.key), fs.prm.type));
            auto v = new VarDeclaration(loc, fs.prm.type, fs.prm.ident, ie);
            v.storage_class |= STC.temp | STC.foreach_ | (fs.prm.storageClass & STC.ref_);
            fs._body = new CompoundStatement(loc, new ExpStatement(loc, v), fs._body);
            if (fs.key.range && !fs.prm.type.isMutable())
            {
                /* Limit the range of the key to the specified range
                 */
                v.range = new IntRange(fs.key.range.imin, fs.key.range.imax - SignExtendedNumber(1));
            }
        }
        if (fs.prm.storageClass & STC.ref_)
        {
            if (fs.key.type.constConv(fs.prm.type) <= MATCH.nomatch)
            {
                fs.error("argument type mismatch, `%s` to `ref %s`", fs.key.type.toChars(), fs.prm.type.toChars());
                return setError();
            }
        }

        auto s = new ForStatement(loc, forinit, cond, increment, fs._body, fs.endloc);
        if (LabelStatement ls = checkLabeledLoop(sc, fs))
            ls.gotoTarget = s;
        result = s.statementSemantic(sc);
    }

    override void visit(IfStatement ifs)
    {
        /* https://dlang.org/spec/statement.html#IfStatement
         */

        // check in syntax level
        ifs.condition = checkAssignmentAsCondition(ifs.condition);

        auto sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        sym.endlinnum = ifs.endloc.linnum;
        Scope* scd = sc.push(sym);
        if (ifs.prm)
        {
            /* Declare prm, which we will set to be the
             * result of condition.
             */
            auto ei = new ExpInitializer(ifs.loc, ifs.condition);
            ifs.match = new VarDeclaration(ifs.loc, ifs.prm.type, ifs.prm.ident, ei);
            ifs.match.parent = scd.func;
            ifs.match.storage_class |= ifs.prm.storageClass;
            ifs.match.dsymbolSemantic(scd);

            auto de = new DeclarationExp(ifs.loc, ifs.match);
            auto ve = new VarExp(ifs.loc, ifs.match);
            ifs.condition = new CommaExp(ifs.loc, de, ve);
            ifs.condition = ifs.condition.expressionSemantic(scd);

            if (ifs.match.edtor)
            {
                Statement sdtor = new DtorExpStatement(ifs.loc, ifs.match.edtor, ifs.match);
                sdtor = new OnScopeStatement(ifs.loc, TOK.onScopeExit, sdtor);
                ifs.ifbody = new CompoundStatement(ifs.loc, sdtor, ifs.ifbody);
                ifs.match.storage_class |= STC.nodtor;
            }
        }
        else
        {
            if (ifs.condition.op == TOK.dotIdentifier)
                (cast(DotIdExp)ifs.condition).noderef = true;

            ifs.condition = ifs.condition.expressionSemantic(scd);
            ifs.condition = resolveProperties(scd, ifs.condition);
            ifs.condition = ifs.condition.addDtorHook(scd);
        }
        if (checkNonAssignmentArrayOp(ifs.condition))
            ifs.condition = new ErrorExp();
        ifs.condition = checkGC(scd, ifs.condition);

        // Convert to boolean after declaring prm so this works:
        //  if (S prm = S()) {}
        // where S is a struct that defines opCast!bool.
        ifs.condition = ifs.condition.toBoolean(scd);

        // If we can short-circuit evaluate the if statement, don't do the
        // semantic analysis of the skipped code.
        // This feature allows a limited form of conditional compilation.
        ifs.condition = ifs.condition.optimize(WANTvalue);

        // Save 'root' of two branches (then and else) at the point where it forks
        CtorFlow ctorflow_root = scd.ctorflow.clone();

        ifs.ifbody = ifs.ifbody.semanticNoScope(scd);
        scd.pop();

        CtorFlow ctorflow_then = sc.ctorflow;   // move flow results
        sc.ctorflow = ctorflow_root;            // reset flow analysis back to root
        if (ifs.elsebody)
            ifs.elsebody = ifs.elsebody.semanticScope(sc, null, null);

        // Merge 'then' results into 'else' results
        sc.merge(ifs.loc, ctorflow_then);

        ctorflow_then.freeFieldinit();          // free extra copy of the data

        if (ifs.condition.op == TOK.error ||
            (ifs.ifbody && ifs.ifbody.isErrorStatement()) ||
            (ifs.elsebody && ifs.elsebody.isErrorStatement()))
        {
            return setError();
        }
        result = ifs;
    }

    override void visit(ConditionalStatement cs)
    {
        //printf("ConditionalStatement::semantic()\n");

        // If we can short-circuit evaluate the if statement, don't do the
        // semantic analysis of the skipped code.
        // This feature allows a limited form of conditional compilation.
        if (cs.condition.include(sc))
        {
            DebugCondition dc = cs.condition.isDebugCondition();
            if (dc)
            {
                sc = sc.push();
                sc.flags |= SCOPE.debug_;
                cs.ifbody = cs.ifbody.statementSemantic(sc);
                sc.pop();
            }
            else
                cs.ifbody = cs.ifbody.statementSemantic(sc);
            result = cs.ifbody;
        }
        else
        {
            if (cs.elsebody)
                cs.elsebody = cs.elsebody.statementSemantic(sc);
            result = cs.elsebody;
        }
    }

    override void visit(PragmaStatement ps)
    {
        /* https://dlang.org/spec/statement.html#pragma-statement
         */
        // Should be merged with PragmaDeclaration

        //printf("PragmaStatement::semantic() %s\n", ps.toChars());
        //printf("body = %p\n", ps._body);
        if (ps.ident == Id.msg)
        {
            if (ps.args)
            {
                foreach (arg; *ps.args)
                {
                    sc = sc.startCTFE();
                    auto e = arg.expressionSemantic(sc);
                    e = resolveProperties(sc, e);
                    sc = sc.endCTFE();

                    // pragma(msg) is allowed to contain types as well as expressions
                    e = ctfeInterpretForPragmaMsg(e);
                    if (e.op == TOK.error)
                    {
                        errorSupplemental(ps.loc, "while evaluating `pragma(msg, %s)`", arg.toChars());
                        return setError();
                    }
                    StringExp se = e.toStringExp();
                    if (se)
                    {
                        se = se.toUTF8(sc);
                        fprintf(stderr, "%.*s", cast(int)se.len, se.string);
                    }
                    else
                        fprintf(stderr, "%s", e.toChars());
                }
                fprintf(stderr, "\n");
            }
        }
        else if (ps.ident == Id.lib)
        {
            version (all)
            {
                /* Should this be allowed?
                 */
                ps.error("`pragma(lib)` not allowed as statement");
                return setError();
            }
            else
            {
                if (!ps.args || ps.args.dim != 1)
                {
                    ps.error("`string` expected for library name");
                    return setError();
                }
                else
                {
                    auto se = semanticString(sc, (*ps.args)[0], "library name");
                    if (!se)
                        return setError();

                    if (global.params.verbose)
                    {
                        message("library   %.*s", cast(int)se.len, se.string);
                    }
                }
            }
        }
        else if (ps.ident == Id.linkerDirective)
        {
            /* Should this be allowed?
             */
            ps.error("`pragma(linkerDirective)` not allowed as statement");
            return setError();
        }
        else if (ps.ident == Id.startaddress)
        {
            if (!ps.args || ps.args.dim != 1)
                ps.error("function name expected for start address");
            else
            {
                Expression e = (*ps.args)[0];
                sc = sc.startCTFE();
                e = e.expressionSemantic(sc);
                e = resolveProperties(sc, e);
                sc = sc.endCTFE();

                e = e.ctfeInterpret();
                (*ps.args)[0] = e;
                Dsymbol sa = getDsymbol(e);
                if (!sa || !sa.isFuncDeclaration())
                {
                    ps.error("function name expected for start address, not `%s`", e.toChars());
                    return setError();
                }
                if (ps._body)
                {
                    ps._body = ps._body.statementSemantic(sc);
                    if (ps._body.isErrorStatement())
                    {
                        result = ps._body;
                        return;
                    }
                }
                result = ps;
                return;
            }
        }
        else if (ps.ident == Id.Pinline)
        {
            PINLINE inlining = PINLINE.default_;
            if (!ps.args || ps.args.dim == 0)
                inlining = PINLINE.default_;
            else if (!ps.args || ps.args.dim != 1)
            {
                ps.error("boolean expression expected for `pragma(inline)`");
                return setError();
            }
            else
            {
                Expression e = (*ps.args)[0];
                if (e.op != TOK.int64 || !e.type.equals(Type.tbool))
                {
                    ps.error("pragma(inline, true or false) expected, not `%s`", e.toChars());
                    return setError();
                }

                if (e.isBool(true))
                    inlining = PINLINE.always;
                else if (e.isBool(false))
                    inlining = PINLINE.never;

                    FuncDeclaration fd = sc.func;
                if (!fd)
                {
                    ps.error("`pragma(inline)` is not inside a function");
                    return setError();
                }
                fd.inlining = inlining;
            }
        }
        else if (!global.params.ignoreUnsupportedPragmas)
        {
            ps.error("unrecognized `pragma(%s)`", ps.ident.toChars());
            return setError();
        }

        if (ps._body)
        {
            if (ps.ident == Id.msg || ps.ident == Id.startaddress)
            {
                ps.error("`pragma(%s)` is missing a terminating `;`", ps.ident.toChars());
                return setError();
            }
            ps._body = ps._body.statementSemantic(sc);
        }
        result = ps._body;
    }

    override void visit(StaticAssertStatement s)
    {
        s.sa.semantic2(sc);
    }

    override void visit(SwitchStatement ss)
    {
        /* https://dlang.org/spec/statement.html#switch-statement
         */

        //printf("SwitchStatement::semantic(%p)\n", ss);
        ss.tf = sc.tf;
        if (ss.cases)
        {
            result = ss; // already run
            return;
        }

        bool conditionError = false;
        ss.condition = ss.condition.expressionSemantic(sc);
        ss.condition = resolveProperties(sc, ss.condition);

        Type att = null;
        TypeEnum te = null;
        while (ss.condition.op != TOK.error)
        {
            // preserve enum type for final switches
            if (ss.condition.type.ty == Tenum)
                te = cast(TypeEnum)ss.condition.type;
            if (ss.condition.type.isString())
            {
                // If it's not an array, cast it to one
                if (ss.condition.type.ty != Tarray)
                {
                    ss.condition = ss.condition.implicitCastTo(sc, ss.condition.type.nextOf().arrayOf());
                }
                ss.condition.type = ss.condition.type.constOf();
                break;
            }
            ss.condition = integralPromotions(ss.condition, sc);
            if (ss.condition.op != TOK.error && ss.condition.type.isintegral())
                break;

            auto ad = isAggregate(ss.condition.type);
            if (ad && ad.aliasthis && ss.condition.type != att)
            {
                if (!att && ss.condition.type.checkAliasThisRec())
                    att = ss.condition.type;
                if (auto e = resolveAliasThis(sc, ss.condition, true))
                {
                    ss.condition = e;
                    continue;
                }
            }

            if (ss.condition.op != TOK.error)
            {
                ss.error("`%s` must be of integral or string type, it is a `%s`",
                    ss.condition.toChars(), ss.condition.type.toChars());
                conditionError = true;
                break;
            }
        }
        if (checkNonAssignmentArrayOp(ss.condition))
            ss.condition = new ErrorExp();
        ss.condition = ss.condition.optimize(WANTvalue);
        ss.condition = checkGC(sc, ss.condition);
        if (ss.condition.op == TOK.error)
            conditionError = true;

        bool needswitcherror = false;

        ss.lastVar = sc.lastVar;

        sc = sc.push();
        sc.sbreak = ss;
        sc.sw = ss;

        ss.cases = new CaseStatements();
        const inLoopSave = sc.inLoop;
        sc.inLoop = true;        // BUG: should use Scope::mergeCallSuper() for each case instead
        ss._body = ss._body.statementSemantic(sc);
        sc.inLoop = inLoopSave;

        if (conditionError || ss._body.isErrorStatement())
        {
            sc.pop();
            return setError();
        }

        // Resolve any goto case's with exp
      Lgotocase:
        foreach (gcs; ss.gotoCases)
        {
            if (!gcs.exp)
            {
                gcs.error("no `case` statement following `goto case;`");
                sc.pop();
                return setError();
            }

            for (Scope* scx = sc; scx; scx = scx.enclosing)
            {
                if (!scx.sw)
                    continue;
                foreach (cs; *scx.sw.cases)
                {
                    if (cs.exp.equals(gcs.exp))
                    {
                        gcs.cs = cs;
                        continue Lgotocase;
                    }
                }
            }
            gcs.error("`case %s` not found", gcs.exp.toChars());
            sc.pop();
            return setError();
        }

        if (ss.isFinal)
        {
            Type t = ss.condition.type;
            Dsymbol ds;
            EnumDeclaration ed = null;
            if (t && ((ds = t.toDsymbol(sc)) !is null))
                ed = ds.isEnumDeclaration(); // typedef'ed enum
            if (!ed && te && ((ds = te.toDsymbol(sc)) !is null))
                ed = ds.isEnumDeclaration();
            if (ed)
            {
              Lmembers:
                foreach (es; *ed.members)
                {
                    EnumMember em = es.isEnumMember();
                    if (em)
                    {
                        foreach (cs; *ss.cases)
                        {
                            if (cs.exp.equals(em.value) || (!cs.exp.type.isString() && !em.value.type.isString() && cs.exp.toInteger() == em.value.toInteger()))
                                continue Lmembers;
                        }
                        ss.error("`enum` member `%s` not represented in `final switch`", em.toChars());
                        sc.pop();
                        return setError();
                    }
                }
            }
            else
                needswitcherror = true;
        }

        if (!sc.sw.sdefault && (!ss.isFinal || needswitcherror || global.params.useAssert == CHECKENABLE.on))
        {
            ss.hasNoDefault = 1;

            if (!ss.isFinal && !ss._body.isErrorStatement())
                ss.error("`switch` statement without a `default`; use `final switch` or add `default: assert(0);` or add `default: break;`");

            // Generate runtime error if the default is hit
            auto a = new Statements();
            CompoundStatement cs;
            Statement s;

            if (global.params.useSwitchError == CHECKENABLE.on)
            {
                Expression sl = new IdentifierExp(ss.loc, Id.empty);
                sl = new DotIdExp(ss.loc, sl, Id.object);
                sl = new DotIdExp(ss.loc, sl, Id.__switch_error);

                Expressions* args = new Expressions();
                args.push(new StringExp(ss.loc, cast(char*) ss.loc.filename));
                args.push(new IntegerExp(ss.loc.linnum));

                sl = new CallExp(ss.loc, sl, args);
                sl.expressionSemantic(sc);

                s = new SwitchErrorStatement(ss.loc, sl);
            }
            else
                s = new ExpStatement(ss.loc, new HaltExp(ss.loc));

            a.reserve(2);
            sc.sw.sdefault = new DefaultStatement(ss.loc, s);
            a.push(ss._body);
            if (ss._body.blockExit(sc.func, false) & BE.fallthru)
                a.push(new BreakStatement(Loc.initial, null));
            a.push(sc.sw.sdefault);
            cs = new CompoundStatement(ss.loc, a);
            ss._body = cs;
        }

        if (ss.checkLabel())
        {
            sc.pop();
            return setError();
        }


        if (ss.condition.type.isString())
        {
            // Transform a switch with string labels into a switch with integer labels.

            // The integer value of each case corresponds to the index of each label
            // string in the sorted array of label strings.

            // The value of the integer condition is obtained by calling the druntime template
            // switch(object.__switch(cond, options...)) {0: {...}, 1: {...}, ...}

            // We sort a copy of the array of labels because we want to do a binary search in object.__switch,
            // without modifying the order of the case blocks here in the compiler.

            size_t numcases = 0;
            if (ss.cases)
                numcases = ss.cases.dim;

            for (size_t i = 0; i < numcases; i++)
            {
                CaseStatement cs = (*ss.cases)[i];
                cs.index = cast(int)i;
            }

            // Make a copy of all the cases so that qsort doesn't scramble the actual
            // data we pass to codegen (the order of the cases in the switch).
            CaseStatements *csCopy = (*ss.cases).copy();

            extern (C) static int sort_compare(const(void*) x, const(void*) y) @trusted
            {
                CaseStatement ox = *cast(CaseStatement *)x;
                CaseStatement oy = *cast(CaseStatement*)y;

                return ox.compare(oy);
            }

            if (numcases)
            {
                import core.stdc.stdlib;
                qsort(csCopy.data, numcases, CaseStatement.sizeof, cast(_compare_fp_t)&sort_compare);
            }

            // The actual lowering
            auto arguments = new Expressions();
            arguments.push(ss.condition);

            auto compileTimeArgs = new Objects();

            // The type & label no.
            compileTimeArgs.push(new TypeExp(ss.loc, ss.condition.type.nextOf()));

            // The switch labels
            foreach (caseString; *csCopy)
            {
                compileTimeArgs.push(caseString.exp);
            }

            Expression sl = new IdentifierExp(ss.loc, Id.empty);
            sl = new DotIdExp(ss.loc, sl, Id.object);
            sl = new DotTemplateInstanceExp(ss.loc, sl, Id.__switch, compileTimeArgs);

            sl = new CallExp(ss.loc, sl, arguments);
            sl.expressionSemantic(sc);
            ss.condition = sl;

            auto i = 0;
            foreach (c; *csCopy)
            {
                (*ss.cases)[c.index].exp = new IntegerExp(i++);
            }

            //printf("%s\n", ss._body.toChars());
            ss.statementSemantic(sc);
        }

        sc.pop();
        result = ss;
    }

    override void visit(CaseStatement cs)
    {
        SwitchStatement sw = sc.sw;
        bool errors = false;

        //printf("CaseStatement::semantic() %s\n", toChars());
        sc = sc.startCTFE();
        cs.exp = cs.exp.expressionSemantic(sc);
        cs.exp = resolveProperties(sc, cs.exp);
        sc = sc.endCTFE();

        if (sw)
        {
            cs.exp = cs.exp.implicitCastTo(sc, sw.condition.type);
            cs.exp = cs.exp.optimize(WANTvalue | WANTexpand);

            Expression e = cs.exp;
            // Remove all the casts the user and/or implicitCastTo may introduce
            // otherwise we'd sometimes fail the check below.
            while (e.op == TOK.cast_)
                e = (cast(CastExp)e).e1;

            /* This is where variables are allowed as case expressions.
             */
            if (e.op == TOK.variable)
            {
                VarExp ve = cast(VarExp)e;
                VarDeclaration v = ve.var.isVarDeclaration();
                Type t = cs.exp.type.toBasetype();
                if (v && (t.isintegral() || t.ty == Tclass))
                {
                    /* Flag that we need to do special code generation
                     * for this, i.e. generate a sequence of if-then-else
                     */
                    sw.hasVars = 1;

                    /* TODO check if v can be uninitialized at that point.
                     */
                    if (!v.isConst() && !v.isImmutable())
                    {
                        cs.deprecation("`case` variables have to be `const` or `immutable`");
                    }

                    if (sw.isFinal)
                    {
                        cs.error("`case` variables not allowed in `final switch` statements");
                        errors = true;
                    }

                    /* Find the outermost scope `scx` that set `sw`.
                     * Then search scope `scx` for a declaration of `v`.
                     */
                    for (Scope* scx = sc; scx; scx = scx.enclosing)
                    {
                        if (scx.enclosing && scx.enclosing.sw == sw)
                            continue;
                        assert(scx.sw == sw);

                        if (!scx.search(cs.exp.loc, v.ident, null))
                        {
                            cs.error("`case` variable `%s` declared at %s cannot be declared in `switch` body",
                                v.toChars(), v.loc.toChars());
                            errors = true;
                        }
                        break;
                    }
                    goto L1;
                }
            }
            else
                cs.exp = cs.exp.ctfeInterpret();

            if (StringExp se = cs.exp.toStringExp())
                cs.exp = se;
            else if (cs.exp.op != TOK.int64 && cs.exp.op != TOK.error)
            {
                cs.error("`case` must be a `string` or an integral constant, not `%s`", cs.exp.toChars());
                errors = true;
            }

        L1:
            foreach (cs2; *sw.cases)
            {
                //printf("comparing '%s' with '%s'\n", exp.toChars(), cs.exp.toChars());
                if (cs2.exp.equals(cs.exp))
                {
                    cs.error("duplicate `case %s` in `switch` statement", cs.exp.toChars());
                    errors = true;
                    break;
                }
            }

            sw.cases.push(cs);

            // Resolve any goto case's with no exp to this case statement
            for (size_t i = 0; i < sw.gotoCases.dim;)
            {
                GotoCaseStatement gcs = sw.gotoCases[i];
                if (!gcs.exp)
                {
                    gcs.cs = cs;
                    sw.gotoCases.remove(i); // remove from array
                    continue;
                }
                i++;
            }

            if (sc.sw.tf != sc.tf)
            {
                cs.error("`switch` and `case` are in different `finally` blocks");
                errors = true;
            }
        }
        else
        {
            cs.error("`case` not in `switch` statement");
            errors = true;
        }

        sc.ctorflow.orCSX(CSX.label);
        cs.statement = cs.statement.statementSemantic(sc);
        if (cs.statement.isErrorStatement())
        {
            result = cs.statement;
            return;
        }
        if (errors || cs.exp.op == TOK.error)
            return setError();

        cs.lastVar = sc.lastVar;
        result = cs;
    }

    override void visit(CaseRangeStatement crs)
    {
        SwitchStatement sw = sc.sw;
        if (sw is null)
        {
            crs.error("case range not in `switch` statement");
            return setError();
        }

        //printf("CaseRangeStatement::semantic() %s\n", toChars());
        bool errors = false;
        if (sw.isFinal)
        {
            crs.error("case ranges not allowed in `final switch`");
            errors = true;
        }

        sc = sc.startCTFE();
        crs.first = crs.first.expressionSemantic(sc);
        crs.first = resolveProperties(sc, crs.first);
        sc = sc.endCTFE();
        crs.first = crs.first.implicitCastTo(sc, sw.condition.type);
        crs.first = crs.first.ctfeInterpret();

        sc = sc.startCTFE();
        crs.last = crs.last.expressionSemantic(sc);
        crs.last = resolveProperties(sc, crs.last);
        sc = sc.endCTFE();
        crs.last = crs.last.implicitCastTo(sc, sw.condition.type);
        crs.last = crs.last.ctfeInterpret();

        if (crs.first.op == TOK.error || crs.last.op == TOK.error || errors)
        {
            if (crs.statement)
                crs.statement.statementSemantic(sc);
            return setError();
        }

        uinteger_t fval = crs.first.toInteger();
        uinteger_t lval = crs.last.toInteger();
        if ((crs.first.type.isunsigned() && fval > lval) || (!crs.first.type.isunsigned() && cast(sinteger_t)fval > cast(sinteger_t)lval))
        {
            crs.error("first `case %s` is greater than last `case %s`", crs.first.toChars(), crs.last.toChars());
            errors = true;
            lval = fval;
        }

        if (lval - fval > 256)
        {
            crs.error("had %llu cases which is more than 256 cases in case range", lval - fval);
            errors = true;
            lval = fval + 256;
        }

        if (errors)
            return setError();

        /* This works by replacing the CaseRange with an array of Case's.
         *
         * case a: .. case b: s;
         *    =>
         * case a:
         *   [...]
         * case b:
         *   s;
         */

        auto statements = new Statements();
        for (uinteger_t i = fval; i != lval + 1; i++)
        {
            Statement s = crs.statement;
            if (i != lval) // if not last case
                s = new ExpStatement(crs.loc, cast(Expression)null);
            Expression e = new IntegerExp(crs.loc, i, crs.first.type);
            Statement cs = new CaseStatement(crs.loc, e, s);
            statements.push(cs);
        }
        Statement s = new CompoundStatement(crs.loc, statements);
        sc.ctorflow.orCSX(CSX.label);
        s = s.statementSemantic(sc);
        result = s;
    }

    override void visit(DefaultStatement ds)
    {
        //printf("DefaultStatement::semantic()\n");
        bool errors = false;
        if (sc.sw)
        {
            if (sc.sw.sdefault)
            {
                ds.error("`switch` statement already has a default");
                errors = true;
            }
            sc.sw.sdefault = ds;

            if (sc.sw.tf != sc.tf)
            {
                ds.error("`switch` and `default` are in different `finally` blocks");
                errors = true;
            }
            if (sc.sw.isFinal)
            {
                ds.error("`default` statement not allowed in `final switch` statement");
                errors = true;
            }
        }
        else
        {
            ds.error("`default` not in `switch` statement");
            errors = true;
        }

        sc.ctorflow.orCSX(CSX.label);
        ds.statement = ds.statement.statementSemantic(sc);
        if (errors || ds.statement.isErrorStatement())
            return setError();

        ds.lastVar = sc.lastVar;
        result = ds;
    }

    override void visit(GotoDefaultStatement gds)
    {
        /* https://dlang.org/spec/statement.html#goto-statement
         */

        gds.sw = sc.sw;
        if (!gds.sw)
        {
            gds.error("`goto default` not in `switch` statement");
            return setError();
        }
        if (gds.sw.isFinal)
        {
            gds.error("`goto default` not allowed in `final switch` statement");
            return setError();
        }
        result = gds;
    }

    override void visit(GotoCaseStatement gcs)
    {
        /* https://dlang.org/spec/statement.html#goto-statement
         */

        if (!sc.sw)
        {
            gcs.error("`goto case` not in `switch` statement");
            return setError();
        }

        if (gcs.exp)
        {
            gcs.exp = gcs.exp.expressionSemantic(sc);
            gcs.exp = gcs.exp.implicitCastTo(sc, sc.sw.condition.type);
            gcs.exp = gcs.exp.optimize(WANTvalue);
            if (gcs.exp.op == TOK.error)
                return setError();
        }

        sc.sw.gotoCases.push(gcs);
        result = gcs;
    }

    override void visit(ReturnStatement rs)
    {
        /* https://dlang.org/spec/statement.html#return-statement
         */

        //printf("ReturnStatement.dsymbolSemantic() %p, %s\n", rs, rs.toChars());

        FuncDeclaration fd = sc.parent.isFuncDeclaration();
        if (fd.fes)
            fd = fd.fes.func; // fd is now function enclosing foreach

            TypeFunction tf = cast(TypeFunction)fd.type;
        assert(tf.ty == Tfunction);

        if (rs.exp && rs.exp.op == TOK.variable && (cast(VarExp)rs.exp).var == fd.vresult)
        {
            // return vresult;
            if (sc.fes)
            {
                assert(rs.caseDim == 0);
                sc.fes.cases.push(rs);
                result = new ReturnStatement(Loc.initial, new IntegerExp(sc.fes.cases.dim + 1));
                return;
            }
            if (fd.returnLabel)
            {
                auto gs = new GotoStatement(rs.loc, Id.returnLabel);
                gs.label = fd.returnLabel;
                result = gs;
                return;
            }

            if (!fd.returns)
                fd.returns = new ReturnStatements();
            fd.returns.push(rs);
            result = rs;
            return;
        }

        Type tret = tf.next;
        Type tbret = tret ? tret.toBasetype() : null;

        bool inferRef = (tf.isref && (fd.storage_class & STC.auto_));
        Expression e0 = null;

        bool errors = false;
        if (sc.flags & SCOPE.contract)
        {
            rs.error("`return` statements cannot be in contracts");
            errors = true;
        }
        if (sc.os && sc.os.tok != TOK.onScopeFailure)
        {
            rs.error("`return` statements cannot be in `%s` bodies", Token.toChars(sc.os.tok));
            errors = true;
        }
        if (sc.tf)
        {
            rs.error("`return` statements cannot be in `finally` bodies");
            errors = true;
        }

        if (fd.isCtorDeclaration())
        {
            if (rs.exp)
            {
                rs.error("cannot return expression from constructor");
                errors = true;
            }

            // Constructors implicitly do:
            //      return this;
            rs.exp = new ThisExp(Loc.initial);
            rs.exp.type = tret;
        }
        else if (rs.exp)
        {
            fd.hasReturnExp |= (fd.hasReturnExp & 1 ? 16 : 1);

            FuncLiteralDeclaration fld = fd.isFuncLiteralDeclaration();
            if (tret)
                rs.exp = inferType(rs.exp, tret);
            else if (fld && fld.treq)
                rs.exp = inferType(rs.exp, fld.treq.nextOf().nextOf());

            rs.exp = rs.exp.expressionSemantic(sc);

            // for static alias this: https://issues.dlang.org/show_bug.cgi?id=17684
            if (rs.exp.op == TOK.type)
                rs.exp = resolveAliasThis(sc, rs.exp);

            rs.exp = resolveProperties(sc, rs.exp);
            if (rs.exp.checkType())
                rs.exp = new ErrorExp();
            if (auto f = isFuncAddress(rs.exp))
            {
                if (fd.inferRetType && f.checkForwardRef(rs.exp.loc))
                    rs.exp = new ErrorExp();
            }
            if (checkNonAssignmentArrayOp(rs.exp))
                rs.exp = new ErrorExp();

            // Extract side-effect part
            rs.exp = Expression.extractLast(rs.exp, &e0);
            if (rs.exp.op == TOK.call)
                rs.exp = valueNoDtor(rs.exp);

            if (e0)
                e0 = e0.optimize(WANTvalue);

            /* Void-return function can have void typed expression
             * on return statement.
             */
            if (tbret && tbret.ty == Tvoid || rs.exp.type.ty == Tvoid)
            {
                if (rs.exp.type.ty != Tvoid)
                {
                    rs.error("cannot return non-void from `void` function");
                    errors = true;
                    rs.exp = new CastExp(rs.loc, rs.exp, Type.tvoid);
                    rs.exp = rs.exp.expressionSemantic(sc);
                }

                /* Replace:
                 *      return exp;
                 * with:
                 *      exp; return;
                 */
                e0 = Expression.combine(e0, rs.exp);
                rs.exp = null;
            }
            if (e0)
                e0 = checkGC(sc, e0);
        }

        if (rs.exp)
        {
            if (fd.inferRetType) // infer return type
            {
                if (!tret)
                {
                    tf.next = rs.exp.type;
                }
                else if (tret.ty != Terror && !rs.exp.type.equals(tret))
                {
                    int m1 = rs.exp.type.implicitConvTo(tret);
                    int m2 = tret.implicitConvTo(rs.exp.type);
                    //printf("exp.type = %s m2<-->m1 tret %s\n", exp.type.toChars(), tret.toChars());
                    //printf("m1 = %d, m2 = %d\n", m1, m2);

                    if (m1 && m2)
                    {
                    }
                    else if (!m1 && m2)
                        tf.next = rs.exp.type;
                    else if (m1 && !m2)
                    {
                    }
                    else if (rs.exp.op != TOK.error)
                    {
                        rs.error("mismatched function return type inference of `%s` and `%s`", rs.exp.type.toChars(), tret.toChars());
                        errors = true;
                        tf.next = Type.terror;
                    }
                }

                tret = tf.next;
                tbret = tret.toBasetype();
            }

            if (inferRef) // deduce 'auto ref'
            {
                /* Determine "refness" of function return:
                 * if it's an lvalue, return by ref, else return by value
                 * https://dlang.org/spec/function.html#auto-ref-functions
                 */

                void turnOffRef()
                {
                    tf.isref = false;    // return by value
                    tf.isreturn = false; // ignore 'return' attribute, whether explicit or inferred
                    fd.storage_class &= ~STC.return_;
                }

                if (rs.exp.isLvalue())
                {
                    /* May return by ref
                     */
                    if (checkReturnEscapeRef(sc, rs.exp, true))
                        turnOffRef();
                    else if (!rs.exp.type.constConv(tf.next))
                        turnOffRef();
                }
                else
                    turnOffRef();

                /* The "refness" is determined by all of return statements.
                 * This means:
                 *    return 3; return x;  // ok, x can be a value
                 *    return x; return 3;  // ok, x can be a value
                 */
            }

            // handle NRVO
            if (fd.nrvo_can && rs.exp.op == TOK.variable)
            {
                VarExp ve = cast(VarExp)rs.exp;
                VarDeclaration v = ve.var.isVarDeclaration();
                if (tf.isref)
                {
                    // Function returns a reference
                    if (!inferRef)
                        fd.nrvo_can = 0;
                }
                else if (!v || v.isOut() || v.isRef())
                    fd.nrvo_can = 0;
                else if (fd.nrvo_var is null)
                {
                    if (!v.isDataseg() && !v.isParameter() && v.toParent2() == fd)
                    {
                        //printf("Setting nrvo to %s\n", v.toChars());
                        fd.nrvo_var = v;
                    }
                    else
                        fd.nrvo_can = 0;
                }
                else if (fd.nrvo_var != v)
                    fd.nrvo_can = 0;
            }
            else //if (!exp.isLvalue())    // keep NRVO-ability
                fd.nrvo_can = 0;
        }
        else
        {
            // handle NRVO
            fd.nrvo_can = 0;

            // infer return type
            if (fd.inferRetType)
            {
                if (tf.next && tf.next.ty != Tvoid)
                {
                    if (tf.next.ty != Terror)
                    {
                        rs.error("mismatched function return type inference of `void` and `%s`", tf.next.toChars());
                    }
                    errors = true;
                    tf.next = Type.terror;
                }
                else
                    tf.next = Type.tvoid;

                    tret = tf.next;
                tbret = tret.toBasetype();
            }

            if (inferRef) // deduce 'auto ref'
                tf.isref = false;

            if (tbret.ty != Tvoid) // if non-void return
            {
                if (tbret.ty != Terror)
                    rs.error("`return` expression expected");
                errors = true;
            }
            else if (fd.isMain())
            {
                // main() returns 0, even if it returns void
                rs.exp = new IntegerExp(0);
            }
        }

        // If any branches have called a ctor, but this branch hasn't, it's an error
        if (sc.ctorflow.callSuper & CSX.any_ctor && !(sc.ctorflow.callSuper & (CSX.this_ctor | CSX.super_ctor)))
        {
            rs.error("`return` without calling constructor");
            errors = true;
        }

        if (sc.ctorflow.fieldinit.length)       // if aggregate fields are being constructed
        {
            auto ad = fd.isMember2();
            assert(ad);
            foreach (i, v; ad.fields)
            {
                bool mustInit = (v.storage_class & STC.nodefaultctor || v.type.needsNested());
                if (mustInit && !(sc.ctorflow.fieldinit[i].csx & CSX.this_ctor))
                {
                    rs.error("an earlier `return` statement skips field `%s` initialization", v.toChars());
                    errors = true;
                }
            }
        }
        sc.ctorflow.orCSX(CSX.return_);

        if (errors)
            return setError();

        if (sc.fes)
        {
            if (!rs.exp)
            {
                // Send out "case receiver" statement to the foreach.
                //  return exp;
                Statement s = new ReturnStatement(Loc.initial, rs.exp);
                sc.fes.cases.push(s);

                // Immediately rewrite "this" return statement as:
                //  return cases.dim+1;
                rs.exp = new IntegerExp(sc.fes.cases.dim + 1);
                if (e0)
                {
                    result = new CompoundStatement(rs.loc, new ExpStatement(rs.loc, e0), rs);
                    return;
                }
                result = rs;
                return;
            }
            else
            {
                fd.buildResultVar(null, rs.exp.type);
                bool r = fd.vresult.checkNestedReference(sc, Loc.initial);
                assert(!r); // vresult should be always accessible

                // Send out "case receiver" statement to the foreach.
                //  return vresult;
                Statement s = new ReturnStatement(Loc.initial, new VarExp(Loc.initial, fd.vresult));
                sc.fes.cases.push(s);

                // Save receiver index for the later rewriting from:
                //  return exp;
                // to:
                //  vresult = exp; retrun caseDim;
                rs.caseDim = sc.fes.cases.dim + 1;
            }
        }
        if (rs.exp)
        {
            if (!fd.returns)
                fd.returns = new ReturnStatements();
            fd.returns.push(rs);
        }
        if (e0)
        {
            result = new CompoundStatement(rs.loc, new ExpStatement(rs.loc, e0), rs);
            return;
        }
        result = rs;
    }

    override void visit(BreakStatement bs)
    {
        /* https://dlang.org/spec/statement.html#break-statement
         */

        //printf("BreakStatement::semantic()\n");

        // If:
        //  break Identifier;
        if (bs.ident)
        {
            bs.ident = fixupLabelName(sc, bs.ident);

            FuncDeclaration thisfunc = sc.func;

            for (Scope* scx = sc; scx; scx = scx.enclosing)
            {
                if (scx.func != thisfunc) // if in enclosing function
                {
                    if (sc.fes) // if this is the body of a foreach
                    {
                        /* Post this statement to the fes, and replace
                         * it with a return value that caller will put into
                         * a switch. Caller will figure out where the break
                         * label actually is.
                         * Case numbers start with 2, not 0, as 0 is continue
                         * and 1 is break.
                         */
                        sc.fes.cases.push(bs);
                        result = new ReturnStatement(Loc.initial, new IntegerExp(sc.fes.cases.dim + 1));
                        return;
                    }
                    break; // can't break to it
                }

                LabelStatement ls = scx.slabel;
                if (ls && ls.ident == bs.ident)
                {
                    Statement s = ls.statement;
                    if (!s || !s.hasBreak())
                        bs.error("label `%s` has no `break`", bs.ident.toChars());
                    else if (ls.tf != sc.tf)
                        bs.error("cannot break out of `finally` block");
                    else
                    {
                        ls.breaks = true;
                        result = bs;
                        return;
                    }
                    return setError();
                }
            }
            bs.error("enclosing label `%s` for `break` not found", bs.ident.toChars());
            return setError();
        }
        else if (!sc.sbreak)
        {
            if (sc.os && sc.os.tok != TOK.onScopeFailure)
            {
                bs.error("`break` is not inside `%s` bodies", Token.toChars(sc.os.tok));
            }
            else if (sc.fes)
            {
                // Replace break; with return 1;
                result = new ReturnStatement(Loc.initial, new IntegerExp(1));
                return;
            }
            else
                bs.error("`break` is not inside a loop or `switch`");
            return setError();
        }
        else if (sc.sbreak.isForwardingStatement())
        {
            bs.error("must use labeled `break` within `static foreach`");
        }
        result = bs;
    }

    override void visit(ContinueStatement cs)
    {
        /* https://dlang.org/spec/statement.html#continue-statement
         */

        //printf("ContinueStatement::semantic() %p\n", cs);
        if (cs.ident)
        {
            cs.ident = fixupLabelName(sc, cs.ident);

            Scope* scx;
            FuncDeclaration thisfunc = sc.func;

            for (scx = sc; scx; scx = scx.enclosing)
            {
                LabelStatement ls;
                if (scx.func != thisfunc) // if in enclosing function
                {
                    if (sc.fes) // if this is the body of a foreach
                    {
                        for (; scx; scx = scx.enclosing)
                        {
                            ls = scx.slabel;
                            if (ls && ls.ident == cs.ident && ls.statement == sc.fes)
                            {
                                // Replace continue ident; with return 0;
                                result = new ReturnStatement(Loc.initial, new IntegerExp(0));
                                return;
                            }
                        }

                        /* Post this statement to the fes, and replace
                         * it with a return value that caller will put into
                         * a switch. Caller will figure out where the break
                         * label actually is.
                         * Case numbers start with 2, not 0, as 0 is continue
                         * and 1 is break.
                         */
                        sc.fes.cases.push(cs);
                        result = new ReturnStatement(Loc.initial, new IntegerExp(sc.fes.cases.dim + 1));
                        return;
                    }
                    break; // can't continue to it
                }

                ls = scx.slabel;
                if (ls && ls.ident == cs.ident)
                {
                    Statement s = ls.statement;
                    if (!s || !s.hasContinue())
                        cs.error("label `%s` has no `continue`", cs.ident.toChars());
                    else if (ls.tf != sc.tf)
                        cs.error("cannot continue out of `finally` block");
                    else
                    {
                        result = cs;
                        return;
                    }
                    return setError();
                }
            }
            cs.error("enclosing label `%s` for `continue` not found", cs.ident.toChars());
            return setError();
        }
        else if (!sc.scontinue)
        {
            if (sc.os && sc.os.tok != TOK.onScopeFailure)
            {
                cs.error("`continue` is not inside `%s` bodies", Token.toChars(sc.os.tok));
            }
            else if (sc.fes)
            {
                // Replace continue; with return 0;
                result = new ReturnStatement(Loc.initial, new IntegerExp(0));
                return;
            }
            else
                cs.error("`continue` is not inside a loop");
            return setError();
        }
        else if (sc.scontinue.isForwardingStatement())
        {
            cs.error("must use labeled `continue` within `static foreach`");
        }
        result = cs;
    }

    override void visit(SynchronizedStatement ss)
    {
        /* https://dlang.org/spec/statement.html#synchronized-statement
         */

        if (ss.exp)
        {
            ss.exp = ss.exp.expressionSemantic(sc);
            ss.exp = resolveProperties(sc, ss.exp);
            ss.exp = ss.exp.optimize(WANTvalue);
            ss.exp = checkGC(sc, ss.exp);
            if (ss.exp.op == TOK.error)
            {
                if (ss._body)
                    ss._body = ss._body.statementSemantic(sc);
                return setError();
            }

            ClassDeclaration cd = ss.exp.type.isClassHandle();
            if (!cd)
            {
                ss.error("can only `synchronize` on class objects, not `%s`", ss.exp.type.toChars());
                return setError();
            }
            else if (cd.isInterfaceDeclaration())
            {
                /* Cast the interface to an object, as the object has the monitor,
                 * not the interface.
                 */
                if (!ClassDeclaration.object)
                {
                    ss.error("missing or corrupt object.d");
                    fatal();
                }

                Type t = ClassDeclaration.object.type;
                t = t.typeSemantic(Loc.initial, sc).toBasetype();
                assert(t.ty == Tclass);

                ss.exp = new CastExp(ss.loc, ss.exp, t);
                ss.exp = ss.exp.expressionSemantic(sc);
            }
            version (all)
            {
                /* Rewrite as:
                 *  auto tmp = exp;
                 *  _d_monitorenter(tmp);
                 *  try { body } finally { _d_monitorexit(tmp); }
                 */
                auto tmp = copyToTemp(0, "__sync", ss.exp);
                tmp.dsymbolSemantic(sc);

                auto cs = new Statements();
                cs.push(new ExpStatement(ss.loc, tmp));

                auto args = new Parameters();
                args.push(new Parameter(0, ClassDeclaration.object.type, null, null, null));

                FuncDeclaration fdenter = FuncDeclaration.genCfunc(args, Type.tvoid, Id.monitorenter);
                Expression e = new CallExp(ss.loc, fdenter, new VarExp(ss.loc, tmp));
                e.type = Type.tvoid; // do not run semantic on e

                cs.push(new ExpStatement(ss.loc, e));
                FuncDeclaration fdexit = FuncDeclaration.genCfunc(args, Type.tvoid, Id.monitorexit);
                e = new CallExp(ss.loc, fdexit, new VarExp(ss.loc, tmp));
                e.type = Type.tvoid; // do not run semantic on e
                Statement s = new ExpStatement(ss.loc, e);
                s = new TryFinallyStatement(ss.loc, ss._body, s);
                cs.push(s);

                s = new CompoundStatement(ss.loc, cs);
                result = s.statementSemantic(sc);
            }
        }
        else
        {
            /* Generate our own critical section, then rewrite as:
             *  static shared align(D_CRITICAL_SECTION.alignof) byte[D_CRITICAL_SECTION.sizeof] __critsec;
             *  _d_criticalenter(&__critsec[0]);
             *  try { body } finally { _d_criticalexit(&__critsec[0]); }
             */
            auto id = Identifier.generateId("__critsec");
            auto t = Type.tint8.sarrayOf(Target.ptrsize + Target.critsecsize());
            auto tmp = new VarDeclaration(ss.loc, t, id, null);
            tmp.storage_class |= STC.temp | STC.shared_ | STC.static_;
            Expression tmpExp = new VarExp(ss.loc, tmp);

            auto cs = new Statements();
            cs.push(new ExpStatement(ss.loc, tmp));

            /* This is just a dummy variable for "goto skips declaration" error.
             * Backend optimizer could remove this unused variable.
             */
            auto v = new VarDeclaration(ss.loc, Type.tvoidptr, Identifier.generateId("__sync"), null);
            v.dsymbolSemantic(sc);
            cs.push(new ExpStatement(ss.loc, v));

            auto args = new Parameters();
            args.push(new Parameter(0, t.pointerTo(), null, null, null));

            FuncDeclaration fdenter = FuncDeclaration.genCfunc(args, Type.tvoid, Id.criticalenter, STC.nothrow_);
            Expression int0 = new IntegerExp(ss.loc, dinteger_t(0), Type.tint8);
            Expression e = new AddrExp(ss.loc, new IndexExp(ss.loc, tmpExp, int0));
            e = e.expressionSemantic(sc);
            e = new CallExp(ss.loc, fdenter, e);
            e.type = Type.tvoid; // do not run semantic on e
            cs.push(new ExpStatement(ss.loc, e));

            FuncDeclaration fdexit = FuncDeclaration.genCfunc(args, Type.tvoid, Id.criticalexit, STC.nothrow_);
            e = new AddrExp(ss.loc, new IndexExp(ss.loc, tmpExp, int0));
            e = e.expressionSemantic(sc);
            e = new CallExp(ss.loc, fdexit, e);
            e.type = Type.tvoid; // do not run semantic on e
            Statement s = new ExpStatement(ss.loc, e);
            s = new TryFinallyStatement(ss.loc, ss._body, s);
            cs.push(s);

            s = new CompoundStatement(ss.loc, cs);
            result = s.statementSemantic(sc);

            // set the explicit __critsec alignment after semantic()
            tmp.alignment = Target.ptrsize;
        }
    }

    override void visit(WithStatement ws)
    {
        /* https://dlang.org/spec/statement.html#with-statement
         */

        ScopeDsymbol sym;
        Initializer _init;

        //printf("WithStatement::semantic()\n");
        ws.exp = ws.exp.expressionSemantic(sc);
        ws.exp = resolveProperties(sc, ws.exp);
        ws.exp = ws.exp.optimize(WANTvalue);
        ws.exp = checkGC(sc, ws.exp);
        if (ws.exp.op == TOK.error)
            return setError();
        if (ws.exp.op == TOK.scope_)
        {
            sym = new WithScopeSymbol(ws);
            sym.parent = sc.scopesym;
            sym.endlinnum = ws.endloc.linnum;
        }
        else if (ws.exp.op == TOK.type)
        {
            Dsymbol s = (cast(TypeExp)ws.exp).type.toDsymbol(sc);
            if (!s || !s.isScopeDsymbol())
            {
                ws.error("`with` type `%s` has no members", ws.exp.toChars());
                return setError();
            }
            sym = new WithScopeSymbol(ws);
            sym.parent = sc.scopesym;
            sym.endlinnum = ws.endloc.linnum;
        }
        else
        {
            Type t = ws.exp.type.toBasetype();

            Expression olde = ws.exp;
            if (t.ty == Tpointer)
            {
                ws.exp = new PtrExp(ws.loc, ws.exp);
                ws.exp = ws.exp.expressionSemantic(sc);
                t = ws.exp.type.toBasetype();
            }

            assert(t);
            t = t.toBasetype();
            if (t.isClassHandle())
            {
                _init = new ExpInitializer(ws.loc, ws.exp);
                ws.wthis = new VarDeclaration(ws.loc, ws.exp.type, Id.withSym, _init);
                ws.wthis.dsymbolSemantic(sc);

                sym = new WithScopeSymbol(ws);
                sym.parent = sc.scopesym;
                sym.endlinnum = ws.endloc.linnum;
            }
            else if (t.ty == Tstruct)
            {
                if (!ws.exp.isLvalue())
                {
                    /* Re-write to
                     * {
                     *   auto __withtmp = exp
                     *   with(__withtmp)
                     *   {
                     *     ...
                     *   }
                     * }
                     */
                    auto tmp = copyToTemp(0, "__withtmp", ws.exp);
                    tmp.dsymbolSemantic(sc);
                    auto es = new ExpStatement(ws.loc, tmp);
                    ws.exp = new VarExp(ws.loc, tmp);
                    Statement ss = new ScopeStatement(ws.loc, new CompoundStatement(ws.loc, es, ws), ws.endloc);
                    result = ss.statementSemantic(sc);
                    return;
                }
                Expression e = ws.exp.addressOf();
                _init = new ExpInitializer(ws.loc, e);
                ws.wthis = new VarDeclaration(ws.loc, e.type, Id.withSym, _init);
                ws.wthis.dsymbolSemantic(sc);
                sym = new WithScopeSymbol(ws);
                // Need to set the scope to make use of resolveAliasThis
                sym.setScope(sc);
                sym.parent = sc.scopesym;
                sym.endlinnum = ws.endloc.linnum;
            }
            else
            {
                ws.error("`with` expressions must be aggregate types or pointers to them, not `%s`", olde.type.toChars());
                return setError();
            }
        }

        if (ws._body)
        {
            sym._scope = sc;
            sc = sc.push(sym);
            sc.insert(sym);
            ws._body = ws._body.statementSemantic(sc);
            sc.pop();
            if (ws._body && ws._body.isErrorStatement())
            {
                result = ws._body;
                return;
            }
        }

        result = ws;
    }

    // https://dlang.org/spec/statement.html#TryStatement
    override void visit(TryCatchStatement tcs)
    {
        //printf("TryCatchStatement.semantic()\n");

        if (!global.params.useExceptions)
        {
            tcs.error("Cannot use try-catch statements with -betterC");
            return setError();
        }

        if (!ClassDeclaration.throwable)
        {
            tcs.error("Cannot use try-catch statements because `object.Throwable` was not declared");
            return setError();
        }

        uint flags;
        enum FLAGcpp = 1;
        enum FLAGd = 2;

        tcs._body = tcs._body.semanticScope(sc, null, null);
        assert(tcs._body);

        /* Even if body is empty, still do semantic analysis on catches
         */
        bool catchErrors = false;
        foreach (i, c; *tcs.catches)
        {
            c.catchSemantic(sc);
            if (c.errors)
            {
                catchErrors = true;
                continue;
            }
            auto cd = c.type.toBasetype().isClassHandle();
            flags |= cd.isCPPclass() ? FLAGcpp : FLAGd;

            // Determine if current catch 'hides' any previous catches
            foreach (j; 0 .. i)
            {
                Catch cj = (*tcs.catches)[j];
                const si = c.loc.toChars();
                const sj = cj.loc.toChars();
                if (c.type.toBasetype().implicitConvTo(cj.type.toBasetype()))
                {
                    tcs.error("`catch` at %s hides `catch` at %s", sj, si);
                    catchErrors = true;
                }
            }
        }

        if (sc.func)
        {
            sc.func.flags |= FUNCFLAG.hasCatches;
            if (flags == (FLAGcpp | FLAGd))
            {
                tcs.error("cannot mix catching D and C++ exceptions in the same try-catch");
                catchErrors = true;
            }
        }

        if (catchErrors)
            return setError();

        if (tcs._body.isErrorStatement())
        {
            result = tcs._body;
            return;
        }

        /* If the try body never throws, we can eliminate any catches
         * of recoverable exceptions.
         */
        if (!(tcs._body.blockExit(sc.func, false) & BE.throw_) && ClassDeclaration.exception)
        {
            foreach_reverse (i; 0 .. tcs.catches.dim)
            {
                Catch c = (*tcs.catches)[i];

                /* If catch exception type is derived from Exception
                 */
                if (c.type.toBasetype().implicitConvTo(ClassDeclaration.exception.type) &&
                    (!c.handler || !c.handler.comeFrom()))
                {
                    // Remove c from the array of catches
                    tcs.catches.remove(i);
                }
            }
        }

        if (tcs.catches.dim == 0)
        {
            result = tcs._body.hasCode() ? tcs._body : null;
            return;
        }

        result = tcs;
    }

    override void visit(TryFinallyStatement tfs)
    {
        //printf("TryFinallyStatement::semantic()\n");
        tfs._body = tfs._body.statementSemantic(sc);

        sc = sc.push();
        sc.tf = tfs;
        sc.sbreak = null;
        sc.scontinue = null; // no break or continue out of finally block
        tfs.finalbody = tfs.finalbody.semanticNoScope(sc);
        sc.pop();

        if (!tfs._body)
        {
            result = tfs.finalbody;
            return;
        }
        if (!tfs.finalbody)
        {
            result = tfs._body;
            return;
        }

        auto blockexit = tfs._body.blockExit(sc.func, false);

        // if not worrying about exceptions
        if (!(global.params.useExceptions && ClassDeclaration.throwable))
            blockexit &= ~BE.throw_;            // don't worry about paths that otherwise may throw

        // Don't care about paths that halt, either
        if ((blockexit & ~BE.halt) == BE.fallthru)
        {
            result = new CompoundStatement(tfs.loc, tfs._body, tfs.finalbody);
            return;
        }
        tfs.bodyFallsThru = (blockexit & BE.fallthru) != 0;
        result = tfs;
    }

    override void visit(OnScopeStatement oss)
    {
        /* https://dlang.org/spec/statement.html#scope-guard-statement
         */

        if (oss.tok != TOK.onScopeExit)
        {
            // scope(success) and scope(failure) are rewritten to try-catch(-finally) statement,
            // so the generated catch block cannot be placed in finally block.
            // See also Catch::semantic.
            if (sc.os && sc.os.tok != TOK.onScopeFailure)
            {
                // If enclosing is scope(success) or scope(exit), this will be placed in finally block.
                oss.error("cannot put `%s` statement inside `%s`", Token.toChars(oss.tok), Token.toChars(sc.os.tok));
                return setError();
            }
            if (sc.tf)
            {
                oss.error("cannot put `%s` statement inside `finally` block", Token.toChars(oss.tok));
                return setError();
            }
        }

        sc = sc.push();
        sc.tf = null;
        sc.os = oss;
        if (oss.tok != TOK.onScopeFailure)
        {
            // Jump out from scope(failure) block is allowed.
            sc.sbreak = null;
            sc.scontinue = null;
        }
        oss.statement = oss.statement.semanticNoScope(sc);
        sc.pop();

        if (!oss.statement || oss.statement.isErrorStatement())
        {
            result = oss.statement;
            return;
        }
        result = oss;
    }

    override void visit(ThrowStatement ts)
    {
        /* https://dlang.org/spec/statement.html#throw-statement
         */

        //printf("ThrowStatement::semantic()\n");

        if (!global.params.useExceptions)
        {
            ts.error("Cannot use `throw` statements with -betterC");
            return setError();
        }

        if (!ClassDeclaration.throwable)
        {
            ts.error("Cannot use `throw` statements because `object.Throwable` was not declared");
            return setError();
        }

        FuncDeclaration fd = sc.parent.isFuncDeclaration();
        fd.hasReturnExp |= 2;

        if (ts.exp.op == TOK.new_)
        {
            NewExp ne = cast(NewExp)ts.exp;
            ne.thrownew = true;
        }

        ts.exp = ts.exp.expressionSemantic(sc);
        ts.exp = resolveProperties(sc, ts.exp);
        ts.exp = checkGC(sc, ts.exp);
        if (ts.exp.op == TOK.error)
            return setError();

        checkThrowEscape(sc, ts.exp, false);

        ClassDeclaration cd = ts.exp.type.toBasetype().isClassHandle();
        if (!cd || ((cd != ClassDeclaration.throwable) && !ClassDeclaration.throwable.isBaseOf(cd, null)))
        {
            ts.error("can only throw class objects derived from `Throwable`, not type `%s`", ts.exp.type.toChars());
            return setError();
        }

        result = ts;
    }

    override void visit(DebugStatement ds)
    {
        if (ds.statement)
        {
            sc = sc.push();
            sc.flags |= SCOPE.debug_;
            ds.statement = ds.statement.statementSemantic(sc);
            sc.pop();
        }
        result = ds.statement;
    }

    override void visit(GotoStatement gs)
    {
        /* https://dlang.org/spec/statement.html#goto-statement
         */

        //printf("GotoStatement::semantic()\n");
        FuncDeclaration fd = sc.func;

        gs.ident = fixupLabelName(sc, gs.ident);
        gs.label = fd.searchLabel(gs.ident);
        gs.tf = sc.tf;
        gs.os = sc.os;
        gs.lastVar = sc.lastVar;

        if (!gs.label.statement && sc.fes)
        {
            /* Either the goto label is forward referenced or it
             * is in the function that the enclosing foreach is in.
             * Can't know yet, so wrap the goto in a scope statement
             * so we can patch it later, and add it to a 'look at this later'
             * list.
             */
            auto ss = new ScopeStatement(gs.loc, gs, gs.loc);
            sc.fes.gotos.push(ss); // 'look at this later' list
            result = ss;
            return;
        }

        // Add to fwdref list to check later
        if (!gs.label.statement)
        {
            if (!fd.gotos)
                fd.gotos = new GotoStatements();
            fd.gotos.push(gs);
        }
        else if (gs.checkLabel())
            return setError();

        result = gs;
    }

    override void visit(LabelStatement ls)
    {
        //printf("LabelStatement::semantic()\n");
        FuncDeclaration fd = sc.parent.isFuncDeclaration();

        ls.ident = fixupLabelName(sc, ls.ident);
        ls.tf = sc.tf;
        ls.os = sc.os;
        ls.lastVar = sc.lastVar;

        LabelDsymbol ls2 = fd.searchLabel(ls.ident);
        if (ls2.statement)
        {
            ls.error("label `%s` already defined", ls2.toChars());
            return setError();
        }
        else
            ls2.statement = ls;

        sc = sc.push();
        sc.scopesym = sc.enclosing.scopesym;

        sc.ctorflow.orCSX(CSX.label);

        sc.slabel = ls;
        if (ls.statement)
            ls.statement = ls.statement.statementSemantic(sc);
        sc.pop();

        result = ls;
    }

    override void visit(AsmStatement s)
    {
        /* https://dlang.org/spec/statement.html#asm
         */

        result = asmSemantic(s, sc);
    }

    override void visit(CompoundAsmStatement cas)
    {
        // Apply postfix attributes of the asm block to each statement.
        sc = sc.push();
        sc.stc |= cas.stc;
        foreach (ref s; *cas.statements)
        {
            s = s ? s.statementSemantic(sc) : null;
        }

        assert(sc.func);
        // use setImpure/setGC when the deprecation cycle is over
        PURE purity;
        if (!(cas.stc & STC.pure_) && (purity = sc.func.isPureBypassingInference()) != PURE.impure && purity != PURE.fwdref)
            cas.deprecation("`asm` statement is assumed to be impure - mark it with `pure` if it is not");
        if (!(cas.stc & STC.nogc) && sc.func.isNogcBypassingInference())
            cas.deprecation("`asm` statement is assumed to use the GC - mark it with `@nogc` if it does not");
        if (!(cas.stc & (STC.trusted | STC.safe)) && sc.func.setUnsafe())
            cas.error("`asm` statement is assumed to be `@system` - mark it with `@trusted` if it is not");

        sc.pop();
        result = cas;
    }

    override void visit(ImportStatement imps)
    {
        /* https://dlang.org/spec/module.html#ImportDeclaration
         */

        foreach (i; 0 .. imps.imports.dim)
        {
            Import s = (*imps.imports)[i].isImport();
            assert(!s.aliasdecls.dim);
            foreach (j, name; s.names)
            {
                Identifier _alias = s.aliases[j];
                if (!_alias)
                    _alias = name;

                auto tname = new TypeIdentifier(s.loc, name);
                auto ad = new AliasDeclaration(s.loc, _alias, tname);
                ad._import = s;
                s.aliasdecls.push(ad);
            }

            s.dsymbolSemantic(sc);
            Module.addDeferredSemantic2(s);     // https://issues.dlang.org/show_bug.cgi?id=14666
            sc.insert(s);

            foreach (aliasdecl; s.aliasdecls)
            {
                sc.insert(aliasdecl);
            }
        }
        result = imps;
    }
}

void catchSemantic(Catch c, Scope* sc)
{
    //printf("Catch::semantic(%s)\n", ident.toChars());

    if (sc.os && sc.os.tok != TOK.onScopeFailure)
    {
        // If enclosing is scope(success) or scope(exit), this will be placed in finally block.
        error(c.loc, "cannot put `catch` statement inside `%s`", Token.toChars(sc.os.tok));
        c.errors = true;
    }
    if (sc.tf)
    {
        /* This is because the _d_local_unwind() gets the stack munged
         * up on this. The workaround is to place any try-catches into
         * a separate function, and call that.
         * To fix, have the compiler automatically convert the finally
         * body into a nested function.
         */
        error(c.loc, "cannot put `catch` statement inside `finally` block");
        c.errors = true;
    }

    auto sym = new ScopeDsymbol();
    sym.parent = sc.scopesym;
    sc = sc.push(sym);

    if (!c.type)
    {
        error(c.loc, "`catch` statement without an exception specification is deprecated");
        errorSupplemental(c.loc, "use `catch(Throwable)` for old behavior");
        c.errors = true;

        // reference .object.Throwable
        c.type = getThrowable();
    }
    c.type = c.type.typeSemantic(c.loc, sc);
    if (c.type == Type.terror)
        c.errors = true;
    else
    {
        StorageClass stc;
        auto cd = c.type.toBasetype().isClassHandle();
        if (!cd)
        {
            error(c.loc, "can only catch class objects, not `%s`", c.type.toChars());
            c.errors = true;
        }
        else if (cd.isCPPclass())
        {
            if (!Target.cppExceptions)
            {
                error(c.loc, "catching C++ class objects not supported for this target");
                c.errors = true;
            }
            if (sc.func && !sc.intypeof && !c.internalCatch && sc.func.setUnsafe())
            {
                error(c.loc, "cannot catch C++ class objects in `@safe` code");
                c.errors = true;
            }
        }
        else if (cd != ClassDeclaration.throwable && !ClassDeclaration.throwable.isBaseOf(cd, null))
        {
            error(c.loc, "can only catch class objects derived from `Throwable`, not `%s`", c.type.toChars());
            c.errors = true;
        }
        else if (sc.func && !sc.intypeof && !c.internalCatch && ClassDeclaration.exception &&
                 cd != ClassDeclaration.exception && !ClassDeclaration.exception.isBaseOf(cd, null) &&
                 sc.func.setUnsafe())
        {
            error(c.loc, "can only catch class objects derived from `Exception` in `@safe` code, not `%s`", c.type.toChars());
            c.errors = true;
        }
        else if (global.params.ehnogc)
        {
            stc |= STC.scope_;
        }

        if (c.ident)
        {
            c.var = new VarDeclaration(c.loc, c.type, c.ident, null, stc);
            c.var.iscatchvar = true;
            c.var.dsymbolSemantic(sc);
            sc.insert(c.var);

            if (global.params.ehnogc && stc & STC.scope_)
            {
                /* Add a destructor for c.var
                 * try { handler } finally { if (!__ctfe) _d_delThrowable(var); }
                 */
                assert(!c.var.edtor);           // ensure we didn't create one in callScopeDtor()

                Loc loc = c.loc;
                Expression e = new VarExp(loc, c.var);
                e = new CallExp(loc, new IdentifierExp(loc, Id._d_delThrowable), e);

                Expression ec = new IdentifierExp(loc, Id.ctfe);
                ec = new NotExp(loc, ec);
                Statement s = new IfStatement(loc, null, ec, new ExpStatement(loc, e), null, loc);
                c.handler = new TryFinallyStatement(loc, c.handler, s);
            }

        }
        c.handler = c.handler.statementSemantic(sc);
        if (c.handler && c.handler.isErrorStatement())
            c.errors = true;
    }

    sc.pop();
}

Statement semanticNoScope(Statement s, Scope* sc)
{
    //printf("Statement::semanticNoScope() %s\n", toChars());
    if (!s.isCompoundStatement() && !s.isScopeStatement())
    {
        s = new CompoundStatement(s.loc, s); // so scopeCode() gets called
    }
    s = s.statementSemantic(sc);
    return s;
}

// Same as semanticNoScope(), but do create a new scope
Statement semanticScope(Statement s, Scope* sc, Statement sbreak, Statement scontinue)
{
    auto sym = new ScopeDsymbol();
    sym.parent = sc.scopesym;
    Scope* scd = sc.push(sym);
    if (sbreak)
        scd.sbreak = sbreak;
    if (scontinue)
        scd.scontinue = scontinue;
    s = s.semanticNoScope(scd);
    scd.pop();
    return s;
}


/*******************
 * Determines additional argument types for makeTupleForeach.
 */
static template TupleForeachArgs(bool isStatic, bool isDecl)
{
    alias Seq(T...)=T;
    static if(isStatic) alias T = Seq!(bool);
    else alias T = Seq!();
    static if(!isDecl) alias TupleForeachArgs = T;
    else alias TupleForeachArgs = Seq!(Dsymbols*,T);
}

/*******************
 * Determines the return type of makeTupleForeach.
 */
static template TupleForeachRet(bool isStatic, bool isDecl)
{
    alias Seq(T...)=T;
    static if(!isDecl) alias TupleForeachRet = Statement;
    else alias TupleForeachRet = Dsymbols*;
}


/*******************
 * See StatementSemanticVisitor.makeTupleForeach.  This is a simple
 * wrapper that returns the generated statements/declarations.
 */
TupleForeachRet!(isStatic, isDecl) makeTupleForeach(bool isStatic, bool isDecl)(Scope* sc, ForeachStatement fs, TupleForeachArgs!(isStatic, isDecl) args)
{
    scope v = new StatementSemanticVisitor(sc);
    static if(!isDecl)
    {
        v.makeTupleForeach!(isStatic, isDecl)(fs, args);
        return v.result;
    }
    else
    {
        return v.makeTupleForeach!(isStatic, isDecl)(fs, args);
    }
}
