/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC _inline.d)
 */

module ddmd.inline;

import core.stdc.stdio;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.apply;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.initsem;
import ddmd.mtype;
import ddmd.opover;
import ddmd.statement;
import ddmd.tokens;
import ddmd.visitor;
import ddmd.inlinecost;

private:

enum LOG = false;
enum CANINLINE_LOG = false;
enum EXPANDINLINE_LOG = false;


/***********************************************************
 * Represent a context to inline statements and expressions.
 *
 * Todo:
 *  It would be better to make foundReturn an instance field of DoInlineAs visitor class,
 *  like as DoInlineAs!Result.result field, because it's one another result of inlining.
 *  The best would be to return a pair of result Expression and a bool value as foundReturn
 *  from doInlineAs function.
 */
final class InlineDoState
{
    // inline context
    VarDeclaration vthis;
    Dsymbols from;      // old Dsymbols
    Dsymbols to;        // parallel array of new Dsymbols
    Dsymbol parent;     // new parent
    FuncDeclaration fd; // function being inlined (old parent)
    // inline result
    bool foundReturn;

    this(Dsymbol parent, FuncDeclaration fd)
    {
        this.parent = parent;
        this.fd = fd;
    }
}

/***********************************************************
 * Perform the inlining from (Statement or Expression) to (Statement or Expression).
 *
 * Inlining is done by:
 *  - Converting to an Expression
 *  - Copying the trees of the function to be inlined
 *  - Renaming the variables
 */
extern (C++) final class DoInlineAs(Result) : Visitor
if (is(Result == Statement) || is(Result == Expression))
{
    alias visit = super.visit;
public:
    InlineDoState ids;
    Result result;

    enum asStatements = is(Result == Statement);

    extern (D) this(InlineDoState ids)
    {
        this.ids = ids;
    }

    // Statement -> (Statement | Expression)

    override void visit(Statement s)
    {
        printf("Statement.doInlineAs!%s()\n%s\n", Result.stringof.ptr, s.toChars());
        fflush(stdout);
        assert(0); // default is we can't inline it
    }

    override void visit(ExpStatement s)
    {
        static if (LOG)
        {
            if (s.exp)
                printf("ExpStatement.doInlineAs!%s() '%s'\n", Result.stringof.ptr, s.exp.toChars());
        }

        auto exp = doInlineAs!Expression(s.exp, ids);
        static if (asStatements)
            result = new ExpStatement(s.loc, exp);
        else
            result = exp;
    }

    override void visit(CompoundStatement s)
    {
        //printf("CompoundStatement.doInlineAs!%s() %d\n", Result.stringof.ptr, s.statements.dim);
        static if (asStatements)
        {
            auto as = new Statements();
            as.reserve(s.statements.dim);
        }

        foreach (i, sx; *s.statements)
        {
            if (!sx)
                continue;
            static if (asStatements)
            {
                as.push(doInlineAs!Statement(sx, ids));
            }
            else
            {
                /* Specifically allow:
                 *  if (condition)
                 *      return exp1;
                 *  return exp2;
                 */
                IfStatement ifs;
                Statement s3;
                if ((ifs = sx.isIfStatement()) !is null &&
                    ifs.ifbody &&
                    ifs.ifbody.isReturnStatement() &&
                    !ifs.elsebody &&
                    i + 1 < s.statements.dim &&
                    (s3 = (*s.statements)[i + 1]) !is null &&
                    s3.isReturnStatement()
                   )
                {
                    /* Rewrite as ?:
                     */
                    auto econd = doInlineAs!Expression(ifs.condition, ids);
                    assert(econd);
                    auto e1 = doInlineAs!Expression(ifs.ifbody, ids);
                    assert(ids.foundReturn);
                    auto e2 = doInlineAs!Expression(s3, ids);

                    Expression e = new CondExp(econd.loc, econd, e1, e2);
                    e.type = e1.type;
                    if (e.type.ty == Ttuple)
                    {
                        e1.type = Type.tvoid;
                        e2.type = Type.tvoid;
                        e.type = Type.tvoid;
                    }
                    result = Expression.combine(result, e);
                }
                else
                {
                    auto e = doInlineAs!Expression(sx, ids);
                    result = Expression.combine(result, e);
                }
            }

            if (ids.foundReturn)
                break;
        }

        static if (asStatements)
            result = new CompoundStatement(s.loc, as);
    }

    override void visit(UnrolledLoopStatement s)
    {
        //printf("UnrolledLoopStatement.doInlineAs!%s() %d\n", Result.stringof.ptr, s.statements.dim);
        static if (asStatements)
        {
            auto as = new Statements();
            as.reserve(s.statements.dim);
        }

        foreach (sx; *s.statements)
        {
            if (!sx)
                continue;
            auto r = doInlineAs!Result(sx, ids);
            static if (asStatements)
                as.push(r);
            else
                result = Expression.combine(result, r);

            if (ids.foundReturn)
                break;
        }

        static if (asStatements)
            result = new UnrolledLoopStatement(s.loc, as);
    }

    override void visit(ScopeStatement s)
    {
        //printf("ScopeStatement.doInlineAs!%s() %d\n", Result.stringof.ptr, s.statement.dim);
        auto r = doInlineAs!Result(s.statement, ids);
        static if (asStatements)
            result = new ScopeStatement(s.loc, r, s.endloc);
        else
            result = r;
    }

    override void visit(IfStatement s)
    {
        assert(!s.prm);
        auto econd = doInlineAs!Expression(s.condition, ids);
        assert(econd);

        auto ifbody = doInlineAs!Result(s.ifbody, ids);
        bool bodyReturn = ids.foundReturn;

        ids.foundReturn = false;
        auto elsebody = doInlineAs!Result(s.elsebody, ids);

        static if (asStatements)
        {
            result = new IfStatement(s.loc, s.prm, econd, ifbody, elsebody, s.endloc);
        }
        else
        {
            alias e1 = ifbody;
            alias e2 = elsebody;
            if (e1 && e2)
            {
                result = new CondExp(econd.loc, econd, e1, e2);
                result.type = e1.type;
                if (result.type.ty == Ttuple)
                {
                    e1.type = Type.tvoid;
                    e2.type = Type.tvoid;
                    result.type = Type.tvoid;
                }
            }
            else if (e1)
            {
                result = new AndAndExp(econd.loc, econd, e1);
                result.type = Type.tvoid;
            }
            else if (e2)
            {
                result = new OrOrExp(econd.loc, econd, e2);
                result.type = Type.tvoid;
            }
            else
            {
                result = econd;
            }
        }
        ids.foundReturn = ids.foundReturn && bodyReturn;
    }

    override void visit(ReturnStatement s)
    {
        //printf("ReturnStatement.doInlineAs!%s() '%s'\n", Result.stringof.ptr, s.exp ? s.exp.toChars() : "");
        ids.foundReturn = true;

        auto exp = doInlineAs!Expression(s.exp, ids);
        if (!exp) // https://issues.dlang.org/show_bug.cgi?id=14560
                  // 'return' must not leave in the expand result
            return;
        static if (asStatements)
        {
            /* Any return statement should be the last statement in the function being
             * inlined, otherwise things shouldn't have gotten this far. Since the
             * return value is being ignored (otherwise it wouldn't be inlined as a statement)
             * we only need to evaluate `exp` for side effects.
             * Already disallowed this if `exp` produces an object that needs destruction -
             * an enhancement would be to do the destruction here.
             */

            // is seems the above assumtion is not quite true ... see Issue 17676
            // Therefore we check
            if (ids.fd.fbody.last is s)
                result = new ExpStatement(s.loc, exp);
            else
                result = new ReturnStatement(s.loc, exp); // cannot be inlined
        }
        else
            result = exp;
    }

    override void visit(ImportStatement s)
    {
    }

    override void visit(ForStatement s)
    {
        //printf("ForStatement.doInlineAs!%s()\n", Result.stringof.ptr);
        static if (asStatements)
        {
            auto sinit = doInlineAs!Statement(s._init, ids);
            auto scond = doInlineAs!Expression(s.condition, ids);
            auto sincr = doInlineAs!Expression(s.increment, ids);
            auto sbody = doInlineAs!Statement(s._body, ids);
            result = new ForStatement(s.loc, sinit, scond, sincr, sbody, s.endloc);
        }
        else
            result = null;  // cannot be inlined as an Expression
    }

    override void visit(ThrowStatement s)
    {
        //printf("ThrowStatement.doInlineAs!%s() '%s'\n", Result.stringof.ptr, s.exp.toChars());
        static if (asStatements)
            result = new ThrowStatement(s.loc, doInlineAs!Expression(s.exp, ids));
        else
            result = null;  // cannot be inlined as an Expression
    }

    // Expression -> (Statement | Expression)

    static if (asStatements)
    {
        override void visit(Expression e)
        {
            result = new ExpStatement(e.loc, doInlineAs!Expression(e, ids));
        }
    }
    else
    {
        /******************************
         * Perform doInlineAs() on an array of Expressions.
         */
        Expressions* arrayExpressionDoInline(Expressions* a)
        {
            if (!a)
                return null;

            auto newa = new Expressions();
            newa.setDim(a.dim);

            foreach (i; 0 .. a.dim)
            {
                (*newa)[i] = doInlineAs!Expression((*a)[i], ids);
            }
            return newa;
        }

        override void visit(Expression e)
        {
            //printf("Expression.doInlineAs!%s(%s): %s\n", Result.stringof.ptr, Token.toChars(e.op), e.toChars());
            result = e.copy();
        }

        override void visit(SymOffExp e)
        {
            //printf("SymOffExp.doInlineAs!%s(%s)\n", Result.stringof.ptr, e.toChars());
            foreach (i; 0 .. ids.from.dim)
            {
                if (e.var != ids.from[i])
                    continue;
                auto se = cast(SymOffExp)e.copy();
                se.var = cast(Declaration)ids.to[i];
                result = se;
                return;
            }
            result = e;
        }

        override void visit(VarExp e)
        {
            //printf("VarExp.doInlineAs!%s(%s)\n", Result.stringof.ptr, e.toChars());
            foreach (i; 0 .. ids.from.dim)
            {
                if (e.var != ids.from[i])
                    continue;
                auto ve = cast(VarExp)e.copy();
                ve.var = cast(Declaration)ids.to[i];
                result = ve;
                return;
            }
            if (ids.fd && e.var == ids.fd.vthis)
            {
                result = new VarExp(e.loc, ids.vthis);
                result.type = e.type;
                return;
            }

            /* Inlining context pointer access for nested referenced variables.
             * For example:
             *      auto fun() {
             *        int i = 40;
             *        auto foo() {
             *          int g = 2;
             *          struct Result {
             *            auto bar() { return i + g; }
             *          }
             *          return Result();
             *        }
             *        return foo();
             *      }
             *      auto t = fun();
             * 'i' and 'g' are nested referenced variables in Result.bar(), so:
             *      auto x = t.bar();
             * should be inlined to:
             *      auto x = *(t.vthis.vthis + i.voffset) + *(t.vthis + g.voffset)
             */
            auto v = e.var.isVarDeclaration();
            if (v && v.nestedrefs.dim && ids.vthis)
            {
                Dsymbol s = ids.fd;
                auto fdv = v.toParent().isFuncDeclaration();
                assert(fdv);
                result = new VarExp(e.loc, ids.vthis);
                result.type = ids.vthis.type;
                while (s != fdv)
                {
                    auto f = s.isFuncDeclaration();
                    if (auto ad = s.isThis())
                    {
                        assert(ad.vthis);
                        result = new DotVarExp(e.loc, result, ad.vthis);
                        result.type = ad.vthis.type;
                        s = ad.toParent2();
                    }
                    else if (f && f.isNested())
                    {
                        assert(f.vthis);
                        if (f.hasNestedFrameRefs())
                        {
                            result = new DotVarExp(e.loc, result, f.vthis);
                            result.type = f.vthis.type;
                        }
                        s = f.toParent2();
                    }
                    else
                        assert(0);
                    assert(s);
                }
                result = new DotVarExp(e.loc, result, v);
                result.type = v.type;
                //printf("\t==> result = %s, type = %s\n", result.toChars(), result.type.toChars());
                return;
            }

            result = e;
        }

        override void visit(ThisExp e)
        {
            //if (!ids.vthis)
            //    e.error("no `this` when inlining `%s`", ids.parent.toChars());
            if (!ids.vthis)
            {
                result = e;
                return;
            }
            result = new VarExp(e.loc, ids.vthis);
            result.type = e.type;
        }

        override void visit(SuperExp e)
        {
            assert(ids.vthis);
            result = new VarExp(e.loc, ids.vthis);
            result.type = e.type;
        }

        override void visit(DeclarationExp e)
        {
            //printf("DeclarationExp.doInlineAs!%s(%s)\n", Result.stringof.ptr, e.toChars());
            if (auto vd = e.declaration.isVarDeclaration())
            {
                version (none)
                {
                    // Need to figure this out before inlining can work for tuples
                    if (auto tup = vd.toAlias().isTupleDeclaration())
                    {
                        foreach (i; 0 .. tup.objects.dim)
                        {
                            DsymbolExp se = (*tup.objects)[i];
                            assert(se.op == TOKdsymbol);
                            se.s;
                        }
                        result = st.objects.dim;
                        return;
                    }
                }
                if (vd.isStatic())
                    return;

                if (ids.fd && vd == ids.fd.nrvo_var)
                {
                    foreach (i; 0 .. ids.from.dim)
                    {
                        if (vd != ids.from[i])
                            continue;
                        if (vd._init && !vd._init.isVoidInitializer())
                        {
                            result = vd._init.initializerToExpression();
                            assert(result);
                            result = doInlineAs!Expression(result, ids);
                        }
                        else
                            result = new IntegerExp(vd._init.loc, 0, Type.tint32);
                        return;
                    }
                }

                auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
                memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
                vto.parent = ids.parent;
                vto.csym = null;
                vto.isym = null;

                ids.from.push(vd);
                ids.to.push(vto);

                if (vd._init)
                {
                    if (vd._init.isVoidInitializer())
                    {
                        vto._init = new VoidInitializer(vd._init.loc);
                    }
                    else
                    {
                        auto ei = vd._init.initializerToExpression();
                        assert(ei);
                        vto._init = new ExpInitializer(ei.loc, doInlineAs!Expression(ei, ids));
                    }
                }
                auto de = cast(DeclarationExp)e.copy();
                de.declaration = vto;
                result = de;
                return;
            }

            /* This needs work, like DeclarationExp.toElem(), if we are
             * to handle TemplateMixin's. For now, we just don't inline them.
             */
            visit(cast(Expression)e);
        }

        override void visit(TypeidExp e)
        {
            //printf("TypeidExp.doInlineAs!%s(): %s\n", Result.stringof.ptr, e.toChars());
            auto te = cast(TypeidExp)e.copy();
            if (auto ex = isExpression(te.obj))
            {
                te.obj = doInlineAs!Expression(ex, ids);
            }
            else
                assert(isType(te.obj));
            result = te;
        }

        override void visit(NewExp e)
        {
            //printf("NewExp.doInlineAs!%s(): %s\n", Result.stringof.ptr, e.toChars());
            auto ne = cast(NewExp)e.copy();
            ne.thisexp = doInlineAs!Expression(e.thisexp, ids);
            ne.newargs = arrayExpressionDoInline(e.newargs);
            ne.arguments = arrayExpressionDoInline(e.arguments);
            result = ne;

            semanticTypeInfo(null, e.type);
        }

        override void visit(DeleteExp e)
        {
            visit(cast(UnaExp)e);

            Type tb = e.e1.type.toBasetype();
            if (tb.ty == Tarray)
            {
                Type tv = tb.nextOf().baseElemOf();
                if (tv.ty == Tstruct)
                {
                    auto ts = cast(TypeStruct)tv;
                    auto sd = ts.sym;
                    if (sd.dtor)
                        semanticTypeInfo(null, ts);
                }
            }
        }

        override void visit(UnaExp e)
        {
            auto ue = cast(UnaExp)e.copy();
            ue.e1 = doInlineAs!Expression(e.e1, ids);
            result = ue;
        }

        override void visit(AssertExp e)
        {
            auto ae = cast(AssertExp)e.copy();
            ae.e1 = doInlineAs!Expression(e.e1, ids);
            ae.msg = doInlineAs!Expression(e.msg, ids);
            result = ae;
        }

        override void visit(BinExp e)
        {
            auto be = cast(BinExp)e.copy();
            be.e1 = doInlineAs!Expression(e.e1, ids);
            be.e2 = doInlineAs!Expression(e.e2, ids);
            result = be;
        }

        override void visit(CallExp e)
        {
            auto ce = cast(CallExp)e.copy();
            ce.e1 = doInlineAs!Expression(e.e1, ids);
            ce.arguments = arrayExpressionDoInline(e.arguments);
            result = ce;
        }

        override void visit(AssignExp e)
        {
            visit(cast(BinExp)e);

            if (e.e1.op == TOKarraylength)
            {
                auto ale = cast(ArrayLengthExp)e.e1;
                Type tn = ale.e1.type.toBasetype().nextOf();
                semanticTypeInfo(null, tn);
            }
        }

        override void visit(EqualExp e)
        {
            visit(cast(BinExp)e);

            Type t1 = e.e1.type.toBasetype();
            if (t1.ty == Tarray || t1.ty == Tsarray)
            {
                Type t = t1.nextOf().toBasetype();
                while (t.toBasetype().nextOf())
                    t = t.nextOf().toBasetype();
                if (t.ty == Tstruct)
                    semanticTypeInfo(null, t);
            }
            else if (t1.ty == Taarray)
            {
                semanticTypeInfo(null, t1);
            }
        }

        override void visit(IndexExp e)
        {
            auto are = cast(IndexExp)e.copy();
            are.e1 = doInlineAs!Expression(e.e1, ids);
            if (e.lengthVar)
            {
                //printf("lengthVar\n");
                auto vd = e.lengthVar;
                auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
                memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
                vto.parent = ids.parent;
                vto.csym = null;
                vto.isym = null;

                ids.from.push(vd);
                ids.to.push(vto);

                if (vd._init && !vd._init.isVoidInitializer())
                {
                    auto ie = vd._init.isExpInitializer();
                    assert(ie);
                    vto._init = new ExpInitializer(ie.loc, doInlineAs!Expression(ie.exp, ids));
                }
                are.lengthVar = vto;
            }
            are.e2 = doInlineAs!Expression(e.e2, ids);
            result = are;
        }

        override void visit(SliceExp e)
        {
            auto are = cast(SliceExp)e.copy();
            are.e1 = doInlineAs!Expression(e.e1, ids);
            if (e.lengthVar)
            {
                //printf("lengthVar\n");
                auto vd = e.lengthVar;
                auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
                memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
                vto.parent = ids.parent;
                vto.csym = null;
                vto.isym = null;

                ids.from.push(vd);
                ids.to.push(vto);

                if (vd._init && !vd._init.isVoidInitializer())
                {
                    auto ie = vd._init.isExpInitializer();
                    assert(ie);
                    vto._init = new ExpInitializer(ie.loc, doInlineAs!Expression(ie.exp, ids));
                }

                are.lengthVar = vto;
            }
            are.lwr = doInlineAs!Expression(e.lwr, ids);
            are.upr = doInlineAs!Expression(e.upr, ids);
            result = are;
        }

        override void visit(TupleExp e)
        {
            auto ce = cast(TupleExp)e.copy();
            ce.e0 = doInlineAs!Expression(e.e0, ids);
            ce.exps = arrayExpressionDoInline(e.exps);
            result = ce;
        }

        override void visit(ArrayLiteralExp e)
        {
            auto ce = cast(ArrayLiteralExp)e.copy();
            ce.basis = doInlineAs!Expression(e.basis, ids);
            ce.elements = arrayExpressionDoInline(e.elements);
            result = ce;

            semanticTypeInfo(null, e.type);
        }

        override void visit(AssocArrayLiteralExp e)
        {
            auto ce = cast(AssocArrayLiteralExp)e.copy();
            ce.keys = arrayExpressionDoInline(e.keys);
            ce.values = arrayExpressionDoInline(e.values);
            result = ce;

            semanticTypeInfo(null, e.type);
        }

        override void visit(StructLiteralExp e)
        {
            if (e.inlinecopy)
            {
                result = e.inlinecopy;
                return;
            }
            auto ce = cast(StructLiteralExp)e.copy();
            e.inlinecopy = ce;
            ce.elements = arrayExpressionDoInline(e.elements);
            e.inlinecopy = null;
            result = ce;
        }

        override void visit(ArrayExp e)
        {
            auto ce = cast(ArrayExp)e.copy();
            ce.e1 = doInlineAs!Expression(e.e1, ids);
            ce.arguments = arrayExpressionDoInline(e.arguments);
            result = ce;
        }

        override void visit(CondExp e)
        {
            auto ce = cast(CondExp)e.copy();
            ce.econd = doInlineAs!Expression(e.econd, ids);
            ce.e1 = doInlineAs!Expression(e.e1, ids);
            ce.e2 = doInlineAs!Expression(e.e2, ids);
            result = ce;
        }
    }
}

/// ditto
Result doInlineAs(Result)(Statement s, InlineDoState ids)
{
    if (!s)
        return null;

    scope DoInlineAs!Result v = new DoInlineAs!Result(ids);
    s.accept(v);
    return v.result;
}

/// ditto
Result doInlineAs(Result)(Expression e, InlineDoState ids)
{
    if (!e)
        return null;

    scope DoInlineAs!Result v = new DoInlineAs!Result(ids);
    e.accept(v);
    return v.result;
}

/***********************************************************
 * Walk the trees, looking for functions to inline.
 * Inline any that can be.
 */
extern (C++) final class InlineScanVisitor : Visitor
{
    alias visit = super.visit;
public:
    FuncDeclaration parent;     // function being scanned
    // As the visit method cannot return a value, these variables
    // are used to pass the result from 'visit' back to 'inlineScan'
    Statement sresult;
    Expression eresult;
    bool again;

    extern (D) this()
    {
    }

    override void visit(Statement s)
    {
    }

    override void visit(ExpStatement s)
    {
        static if (LOG)
        {
            printf("ExpStatement.inlineScan(%s)\n", s.toChars());
        }
        if (!s.exp)
            return;

        Statement inlineScanExpAsStatement(ref Expression exp)
        {
            /* If there's a TOKcall at the top, then it may fail to inline
             * as an Expression. Try to inline as a Statement instead.
             */
            if (exp.op == TOKcall)
            {
                visitCallExp(cast(CallExp)exp, null, true);
                if (eresult)
                    exp = eresult;
                auto s = sresult;
                sresult = null;
                eresult = null;
                return s;
            }

            /* If there's a CondExp or CommaExp at the top, then its
             * sub-expressions may be inlined as statements.
             */
            if (exp.op == TOKquestion)
            {
                auto e = cast(CondExp)exp;
                inlineScan(e.econd);
                auto s1 = inlineScanExpAsStatement(e.e1);
                auto s2 = inlineScanExpAsStatement(e.e2);
                if (!s1 && !s2)
                    return null;
                auto ifbody   = !s1 ? new ExpStatement(e.e1.loc, e.e1) : s1;
                auto elsebody = !s2 ? new ExpStatement(e.e2.loc, e.e2) : s2;
                return new IfStatement(exp.loc, null, e.econd, ifbody, elsebody, exp.loc);
            }
            if (exp.op == TOKcomma)
            {
                auto e = cast(CommaExp)exp;
                auto s1 = inlineScanExpAsStatement(e.e1);
                auto s2 = inlineScanExpAsStatement(e.e2);
                if (!s1 && !s2)
                    return null;
                auto a = new Statements();
                a.push(!s1 ? new ExpStatement(e.e1.loc, e.e1) : s1);
                a.push(!s2 ? new ExpStatement(e.e2.loc, e.e2) : s2);
                return new CompoundStatement(exp.loc, a);
            }

            // inline as an expression
            inlineScan(exp);
            return null;
        }

        sresult = inlineScanExpAsStatement(s.exp);
    }

    override void visit(CompoundStatement s)
    {
        foreach (i; 0 .. s.statements.dim)
        {
            inlineScan((*s.statements)[i]);
        }
    }

    override void visit(UnrolledLoopStatement s)
    {
        foreach (i; 0 .. s.statements.dim)
        {
            inlineScan((*s.statements)[i]);
        }
    }

    override void visit(ScopeStatement s)
    {
        inlineScan(s.statement);
    }

    override void visit(WhileStatement s)
    {
        inlineScan(s.condition);
        inlineScan(s._body);
    }

    override void visit(DoStatement s)
    {
        inlineScan(s._body);
        inlineScan(s.condition);
    }

    override void visit(ForStatement s)
    {
        inlineScan(s._init);
        inlineScan(s.condition);
        inlineScan(s.increment);
        inlineScan(s._body);
    }

    override void visit(ForeachStatement s)
    {
        inlineScan(s.aggr);
        inlineScan(s._body);
    }

    override void visit(ForeachRangeStatement s)
    {
        inlineScan(s.lwr);
        inlineScan(s.upr);
        inlineScan(s._body);
    }

    override void visit(IfStatement s)
    {
        inlineScan(s.condition);
        inlineScan(s.ifbody);
        inlineScan(s.elsebody);
    }

    override void visit(SwitchStatement s)
    {
        //printf("SwitchStatement.inlineScan()\n");
        inlineScan(s.condition);
        inlineScan(s._body);
        Statement sdefault = s.sdefault;
        inlineScan(sdefault);
        s.sdefault = cast(DefaultStatement)sdefault;
        if (s.cases)
        {
            foreach (i; 0 .. s.cases.dim)
            {
                Statement scase = (*s.cases)[i];
                inlineScan(scase);
                (*s.cases)[i] = cast(CaseStatement)scase;
            }
        }
    }

    override void visit(CaseStatement s)
    {
        //printf("CaseStatement.inlineScan()\n");
        inlineScan(s.exp);
        inlineScan(s.statement);
    }

    override void visit(DefaultStatement s)
    {
        inlineScan(s.statement);
    }

    override void visit(ReturnStatement s)
    {
        //printf("ReturnStatement.inlineScan()\n");
        inlineScan(s.exp);
    }

    override void visit(SynchronizedStatement s)
    {
        inlineScan(s.exp);
        inlineScan(s._body);
    }

    override void visit(WithStatement s)
    {
        inlineScan(s.exp);
        inlineScan(s._body);
    }

    override void visit(TryCatchStatement s)
    {
        inlineScan(s._body);
        if (s.catches)
        {
            foreach (c; *s.catches)
            {
                inlineScan(c.handler);
            }
        }
    }

    override void visit(TryFinallyStatement s)
    {
        inlineScan(s._body);
        inlineScan(s.finalbody);
    }

    override void visit(ThrowStatement s)
    {
        inlineScan(s.exp);
    }

    override void visit(LabelStatement s)
    {
        inlineScan(s.statement);
    }

    /********************************
     * Scan Statement s for inlining opportunities,
     * and if found replace s with an inlined one.
     * Params:
     *  s = Statement to be scanned and updated
     */
    void inlineScan(ref Statement s)
    {
        if (!s)
            return;
        assert(sresult is null);
        s.accept(this);
        if (sresult)
        {
            s = sresult;
            sresult = null;
        }
    }

    /* -------------------------- */
    void arrayInlineScan(Expressions* arguments)
    {
        if (arguments)
        {
            foreach (i; 0 .. arguments.dim)
            {
                inlineScan((*arguments)[i]);
            }
        }
    }

    override void visit(Expression e)
    {
    }

    void scanVar(Dsymbol s)
    {
        //printf("scanVar(%s %s)\n", s.kind(), s.toPrettyChars());
        VarDeclaration vd = s.isVarDeclaration();
        if (vd)
        {
            TupleDeclaration td = vd.toAlias().isTupleDeclaration();
            if (td)
            {
                foreach (i; 0 .. td.objects.dim)
                {
                    DsymbolExp se = cast(DsymbolExp)(*td.objects)[i];
                    assert(se.op == TOKdsymbol);
                    scanVar(se.s); // TODO
                }
            }
            else if (vd._init)
            {
                if (ExpInitializer ie = vd._init.isExpInitializer())
                {
                    inlineScan(ie.exp);
                }
            }
        }
        else
        {
            s.accept(this);
        }
    }

    override void visit(DeclarationExp e)
    {
        //printf("DeclarationExp.inlineScan() %s\n", e.toChars());
        scanVar(e.declaration);
    }

    override void visit(UnaExp e)
    {
        inlineScan(e.e1);
    }

    override void visit(AssertExp e)
    {
        inlineScan(e.e1);
        inlineScan(e.msg);
    }

    override void visit(BinExp e)
    {
        inlineScan(e.e1);
        inlineScan(e.e2);
    }

    override void visit(AssignExp e)
    {
        // Look for NRVO, as inlining NRVO function returns require special handling
        if (e.op == TOKconstruct && e.e2.op == TOKcall)
        {
            CallExp ce = cast(CallExp)e.e2;
            if (ce.f && ce.f.nrvo_can && ce.f.nrvo_var) // NRVO
            {
                if (e.e1.op == TOKvar)
                {
                    /* Inlining:
                     *   S s = foo();   // initializing by rvalue
                     *   S s = S(1);    // constructor call
                     */
                    Declaration d = (cast(VarExp)e.e1).var;
                    if (d.storage_class & (STCout | STCref)) // refinit
                        goto L1;
                }
                else
                {
                    /* Inlining:
                     *   this.field = foo();   // inside constructor
                     */
                    inlineScan(e.e1);
                }

                visitCallExp(ce, e.e1, false);
                if (eresult)
                {
                    //printf("call with nrvo: %s ==> %s\n", e.toChars(), eresult.toChars());
                    return;
                }
            }
        }
    L1:
        visit(cast(BinExp)e);
    }

    override void visit(CallExp e)
    {
        //printf("CallExp.inlineScan() %s\n", e.toChars());
        visitCallExp(e, null, false);
    }

    /**************************************
     * Check function call to see if can be inlined,
     * and then inline it if it can.
     * Params:
     *  e = the function call
     *  eret = if !null, then this is the lvalue of the nrvo function result
     *  asStatements = if inline as statements rather than as an Expression
     * Returns:
     *  this.eresult if asStatements == false
     *  this.sresult if asStatements == true
     */
    void visitCallExp(CallExp e, Expression eret, bool asStatements)
    {
        inlineScan(e.e1);
        arrayInlineScan(e.arguments);

        //printf("visitCallExp() %s\n", e.toChars());
        FuncDeclaration fd;

        void inlineFd()
        {
            if (fd && fd != parent && canInline(fd, false, false, asStatements))
            {
                expandInline(e.loc, fd, parent, eret, null, e.arguments, asStatements, eresult, sresult, again);
            }
        }

        /* Pattern match various ASTs looking for indirect function calls, delegate calls,
         * function literal calls, delegate literal calls, and dot member calls.
         * If so, and that is only assigned its _init.
         * If so, do 'copy propagation' of the _init value and try to inline it.
         */
        if (e.e1.op == TOKvar)
        {
            VarExp ve = cast(VarExp)e.e1;
            fd = ve.var.isFuncDeclaration();
            if (fd)
                // delegate call
                inlineFd();
            else
            {
                // delegate literal call
                auto v = ve.var.isVarDeclaration();
                if (v && v._init && v.type.ty == Tdelegate && onlyOneAssign(v, parent))
                {
                    //printf("init: %s\n", v._init.toChars());
                    auto ei = v._init.isExpInitializer();
                    if (ei && ei.exp.op == TOKblit)
                    {
                        Expression e2 = (cast(AssignExp)ei.exp).e2;
                        if (e2.op == TOKfunction)
                        {
                            auto fld = (cast(FuncExp)e2).fd;
                            assert(fld.tok == TOKdelegate);
                            fd = fld;
                            inlineFd();
                        }
                        else if (e2.op == TOKdelegate)
                        {
                            auto de = cast(DelegateExp)e2;
                            if (de.e1.op == TOKvar)
                            {
                                auto ve2 = cast(VarExp)de.e1;
                                fd = ve2.var.isFuncDeclaration();
                                inlineFd();
                            }
                        }
                    }
                }
            }
        }
        else if (e.e1.op == TOKdotvar)
        {
            DotVarExp dve = cast(DotVarExp)e.e1;
            fd = dve.var.isFuncDeclaration();
            if (fd && fd != parent && canInline(fd, true, false, asStatements))
            {
                if (dve.e1.op == TOKcall && dve.e1.type.toBasetype().ty == Tstruct)
                {
                    /* To create ethis, we'll need to take the address
                     * of dve.e1, but this won't work if dve.e1 is
                     * a function call.
                     */
                }
                else
                {
                    expandInline(e.loc, fd, parent, eret, dve.e1, e.arguments, asStatements, eresult, sresult, again);
                }
            }
        }
        else if (e.e1.op == TOKstar &&
                 (cast(PtrExp)e.e1).e1.op == TOKvar)
        {
            VarExp ve = cast(VarExp)(cast(PtrExp)e.e1).e1;
            VarDeclaration v = ve.var.isVarDeclaration();
            if (v && v._init && onlyOneAssign(v, parent))
            {
                //printf("init: %s\n", v._init.toChars());
                auto ei = v._init.isExpInitializer();
                if (ei && ei.exp.op == TOKblit)
                {
                    Expression e2 = (cast(AssignExp)ei.exp).e2;
                    // function pointer call
                    if (e2.op == TOKsymoff)
                    {
                        auto se = cast(SymOffExp)e2;
                        fd = se.var.isFuncDeclaration();
                        inlineFd();
                    }
                    // function literal call
                    else if (e2.op == TOKfunction)
                    {
                        auto fld = (cast(FuncExp)e2).fd;
                        assert(fld.tok == TOKfunction);
                        fd = fld;
                        inlineFd();
                    }
                }
            }
        }
        else
            return;

        if (global.params.verbose && (eresult || sresult))
            fprintf(global.stdmsg, "inlined   %s =>\n          %s\n", fd.toPrettyChars(), parent.toPrettyChars());

        if (eresult && e.type.ty != Tvoid)
        {
            Expression ex = eresult;
            while (ex.op == TOKcomma)
            {
                ex.type = e.type;
                ex = (cast(CommaExp)ex).e2;
            }
            ex.type = e.type;
        }
    }

    override void visit(SliceExp e)
    {
        inlineScan(e.e1);
        inlineScan(e.lwr);
        inlineScan(e.upr);
    }

    override void visit(TupleExp e)
    {
        //printf("TupleExp.inlineScan()\n");
        inlineScan(e.e0);
        arrayInlineScan(e.exps);
    }

    override void visit(ArrayLiteralExp e)
    {
        //printf("ArrayLiteralExp.inlineScan()\n");
        inlineScan(e.basis);
        arrayInlineScan(e.elements);
    }

    override void visit(AssocArrayLiteralExp e)
    {
        //printf("AssocArrayLiteralExp.inlineScan()\n");
        arrayInlineScan(e.keys);
        arrayInlineScan(e.values);
    }

    override void visit(StructLiteralExp e)
    {
        //printf("StructLiteralExp.inlineScan()\n");
        if (e.stageflags & stageInlineScan)
            return;
        int old = e.stageflags;
        e.stageflags |= stageInlineScan;
        arrayInlineScan(e.elements);
        e.stageflags = old;
    }

    override void visit(ArrayExp e)
    {
        //printf("ArrayExp.inlineScan()\n");
        inlineScan(e.e1);
        arrayInlineScan(e.arguments);
    }

    override void visit(CondExp e)
    {
        inlineScan(e.econd);
        inlineScan(e.e1);
        inlineScan(e.e2);
    }

    /********************************
     * Scan Expression e for inlining opportunities,
     * and if found replace e with an inlined one.
     * Params:
     *  e = Expression to be scanned and updated
     */
    void inlineScan(ref Expression e)
    {
        if (!e)
            return;
        assert(eresult is null);
        e.accept(this);
        if (eresult)
        {
            e = eresult;
            eresult = null;
        }
    }

    /*************************************
     * Look for function inlining possibilities.
     */
    override void visit(Dsymbol d)
    {
        // Most Dsymbols aren't functions
    }

    override void visit(FuncDeclaration fd)
    {
        static if (LOG)
        {
            printf("FuncDeclaration.inlineScan('%s')\n", fd.toPrettyChars());
        }
        if (fd.isUnitTestDeclaration() && !global.params.useUnitTests ||
            fd.flags & FUNCFLAGinlineScanned)
            return;
        if (fd.fbody && !fd.naked)
        {
            auto againsave = again;
            auto parentsave = parent;
            parent = fd;
            do
            {
                again = false;
                fd.inlineNest++;
                fd.flags |= FUNCFLAGinlineScanned;
                inlineScan(fd.fbody);
                fd.inlineNest--;
            }
            while (again);
            again = againsave;
            parent = parentsave;
        }
    }

    override void visit(AttribDeclaration d)
    {
        Dsymbols* decls = d.include(null, null);
        if (decls)
        {
            foreach (i; 0 .. decls.dim)
            {
                Dsymbol s = (*decls)[i];
                //printf("AttribDeclaration.inlineScan %s\n", s.toChars());
                s.accept(this);
            }
        }
    }

    override void visit(AggregateDeclaration ad)
    {
        //printf("AggregateDeclaration.inlineScan(%s)\n", toChars());
        if (ad.members)
        {
            foreach (i; 0 .. ad.members.dim)
            {
                Dsymbol s = (*ad.members)[i];
                //printf("inline scan aggregate symbol '%s'\n", s.toChars());
                s.accept(this);
            }
        }
    }

    override void visit(TemplateInstance ti)
    {
        static if (LOG)
        {
            printf("TemplateInstance.inlineScan('%s')\n", ti.toChars());
        }
        if (!ti.errors && ti.members)
        {
            foreach (i; 0 .. ti.members.dim)
            {
                Dsymbol s = (*ti.members)[i];
                s.accept(this);
            }
        }
    }
}

/***********************************************************
 * Test that `fd` can be inlined.
 *
 * Params:
 *  hasthis = `true` if the function call has explicit 'this' expression.
 *  hdrscan = `true` if the inline scan is for 'D header' content.
 *  statementsToo = `true` if the function call is placed on ExpStatement.
 *      It means more code-block dependent statements in fd body - ForStatement,
 *      ThrowStatement, etc. can be inlined.
 *
 * Returns:
 *  true if the function body can be expanded.
 *
 * Todo:
 *  - Would be able to eliminate `hasthis` parameter, because semantic analysis
 *    no longer accepts calls of contextful function without valid 'this'.
 *  - Would be able to eliminate `hdrscan` parameter, because it's always false.
 */
bool canInline(FuncDeclaration fd, bool hasthis, bool hdrscan, bool statementsToo)
{
    int cost;

    static if (CANINLINE_LOG)
    {
        printf("FuncDeclaration.canInline(hasthis = %d, statementsToo = %d, '%s')\n",
            hasthis, statementsToo, fd.toPrettyChars());
    }

    if (fd.needThis() && !hasthis)
        return false;

    if (fd.inlineNest)
    {
        static if (CANINLINE_LOG)
        {
            printf("\t1: no, inlineNest = %d, semanticRun = %d\n", fd.inlineNest, fd.semanticRun);
        }
        return false;
    }

    if (fd.semanticRun < PASSsemantic3 && !hdrscan)
    {
        if (!fd.fbody)
            return false;
        if (!fd.functionSemantic3())
            return false;
        Module.runDeferredSemantic3();
        if (global.errors)
            return false;
        assert(fd.semanticRun >= PASSsemantic3done);
    }

    switch (statementsToo ? fd.inlineStatusStmt : fd.inlineStatusExp)
    {
    case ILSyes:
        static if (CANINLINE_LOG)
        {
            printf("\t1: yes %s\n", fd.toChars());
        }
        return true;
    case ILSno:
        static if (CANINLINE_LOG)
        {
            printf("\t1: no %s\n", fd.toChars());
        }
        return false;
    case ILSuninitialized:
        break;
    default:
        assert(0);
    }

    switch (fd.inlining)
    {
    case PINLINEdefault:
        break;
    case PINLINEalways:
        break;
    case PINLINEnever:
        return false;
    default:
        assert(0);
    }

    if (fd.type)
    {
        assert(fd.type.ty == Tfunction);
        TypeFunction tf = cast(TypeFunction)fd.type;

        // no variadic parameter lists
        if (tf.varargs == 1)
            goto Lno;

        /* No lazy parameters when inlining by statement, as the inliner tries to
         * operate on the created delegate itself rather than the return value.
         * Discussion: https://github.com/dlang/dmd/pull/6815
         */
        if (statementsToo && fd.parameters)
        {
            foreach (param; *fd.parameters)
            {
                if (param.storage_class & STClazy)
                    goto Lno;
            }
        }

        static bool hasDtor(Type t)
        {
            auto tv = t.baseElemOf();
            return tv.ty == Tstruct || tv.ty == Tclass; // for now assume these might have a destructor
        }

        /* Don't inline a function that returns non-void, but has
         * no or multiple return expression.
         * When inlining as a statement:
         * 1. don't inline array operations, because the order the arguments
         *    get evaluated gets reversed. This is the same issue that e2ir.callfunc()
         *    has with them
         * 2. don't inline when the return value has a destructor, as it doesn't
         *    get handled properly
         */
        if (tf.next && tf.next.ty != Tvoid &&
            (!(fd.hasReturnExp & 1) ||
             statementsToo && (fd.isArrayOp || hasDtor(tf.next))) &&
            !hdrscan)
        {
            static if (CANINLINE_LOG)
            {
                printf("\t3: no %s\n", fd.toChars());
            }
            goto Lno;
        }

        /* https://issues.dlang.org/show_bug.cgi?id=14560
         * If fd returns void, all explicit `return;`s
         * must not appear in the expanded result.
         * See also ReturnStatement.doInlineAs!Statement().
         */
    }

    // cannot inline constructor calls because we need to convert:
    //      return;
    // to:
    //      return this;
    // ensure() has magic properties the inliner loses
    // require() has magic properties too
    // see bug 7699
    // no nested references to this frame
    if (!fd.fbody ||
        fd.ident == Id.ensure ||
        (fd.ident == Id.require &&
         fd.toParent().isFuncDeclaration() &&
         fd.toParent().isFuncDeclaration().needThis()) ||
        !hdrscan && (fd.isSynchronized() ||
                     fd.isImportedSymbol() ||
                     fd.hasNestedFrameRefs() ||
                     (fd.isVirtual() && !fd.isFinalFunc())))
    {
        static if (CANINLINE_LOG)
        {
            printf("\t4: no %s\n", fd.toChars());
        }
        goto Lno;
    }

    // cannot inline functions as statement if they have multiple
    //  return statements
    if ((fd.hasReturnExp & 16) && statementsToo)
    {
        static if (CANINLINE_LOG)
        {
            printf("\t5: no %s\n", fd.toChars());
        }
        goto Lno;
    }

    {
        cost = inlineCostFunction(fd, hasthis, hdrscan);
    }
    static if (CANINLINE_LOG)
    {
        printf("\tcost = %d for %s\n", cost, fd.toChars());
    }

    if (tooCostly(cost))
        goto Lno;
    if (!statementsToo && cost > COST_MAX)
        goto Lno;

    if (!hdrscan)
    {
        // Don't modify inlineStatus for header content scan
        if (statementsToo)
            fd.inlineStatusStmt = ILSyes;
        else
            fd.inlineStatusExp = ILSyes;

        scope InlineScanVisitor v = new InlineScanVisitor();
        fd.accept(v); // Don't scan recursively for header content scan

        if (fd.inlineStatusExp == ILSuninitialized)
        {
            // Need to redo cost computation, as some statements or expressions have been inlined
            cost = inlineCostFunction(fd, hasthis, hdrscan);
            static if (CANINLINE_LOG)
            {
                printf("recomputed cost = %d for %s\n", cost, fd.toChars());
            }

            if (tooCostly(cost))
                goto Lno;
            if (!statementsToo && cost > COST_MAX)
                goto Lno;

            if (statementsToo)
                fd.inlineStatusStmt = ILSyes;
            else
                fd.inlineStatusExp = ILSyes;
        }
    }
    static if (CANINLINE_LOG)
    {
        printf("\t2: yes %s\n", fd.toChars());
    }
    return true;

Lno:
    if (fd.inlining == PINLINEalways)
        fd.error("cannot inline function");

    if (!hdrscan) // Don't modify inlineStatus for header content scan
    {
        if (statementsToo)
            fd.inlineStatusStmt = ILSno;
        else
            fd.inlineStatusExp = ILSno;
    }
    static if (CANINLINE_LOG)
    {
        printf("\t2: no %s\n", fd.toChars());
    }
    return false;
}

/***********************************************************
 * Scan function implementations in Module m looking for functions that can be inlined,
 * and inline them in situ.
 *
 * Params:
 *    m = module to scan
 */
public void inlineScanModule(Module m)
{
    if (m.semanticRun != PASSsemantic3done)
        return;
    m.semanticRun = PASSinline;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.

    //printf("Module = %p\n", m.sc.scopesym);

    foreach (i; 0 .. m.members.dim)
    {
        Dsymbol s = (*m.members)[i];
        //if (global.params.verbose)
        //    fprintf(global.stdmsg, "inline scan symbol %s\n", s.toChars());
        scope InlineScanVisitor v = new InlineScanVisitor();
        s.accept(v);
    }
    m.semanticRun = PASSinlinedone;
}

/***********************************************************
 * Expand a function call inline,
 *      ethis.fd(arguments)
 *
 * Params:
 *      callLoc = location of CallExp
 *      fd = function to expand
 *      parent = function that the call to fd is being expanded into
 *      eret = if !null then the lvalue of where the nrvo return value goes
 *      ethis = 'this' reference
 *      arguments = arguments passed to fd
 *      asStatements = expand to Statements rather than Expressions
 *      eresult = if expanding to an expression, this is where the expression is written to
 *      sresult = if expanding to a statement, this is where the statement is written to
 *      again = if true, then fd can be inline scanned again because there may be
 *           more opportunities for inlining
 */
private void expandInline(Loc callLoc, FuncDeclaration fd, FuncDeclaration parent, Expression eret,
        Expression ethis, Expressions* arguments, bool asStatements,
        out Expression eresult, out Statement sresult, out bool again)
{
    TypeFunction tf = cast(TypeFunction)fd.type;
    static if (LOG || CANINLINE_LOG || EXPANDINLINE_LOG)
        printf("FuncDeclaration.expandInline('%s')\n", fd.toChars());
    static if (EXPANDINLINE_LOG)
    {
        if (eret) printf("\teret = %s\n", eret.toChars());
        if (ethis) printf("\tethis = %s\n", ethis.toChars());
    }
    scope ids = new InlineDoState(parent, fd);

    if (fd.isNested())
    {
        if (!parent.inlinedNestedCallees)
            parent.inlinedNestedCallees = new FuncDeclarations();
        parent.inlinedNestedCallees.push(fd);
    }

    VarDeclaration vret;    // will be set the function call result
    if (eret)
    {
        if (eret.op == TOKvar)
        {
            vret = (cast(VarExp)eret).var.isVarDeclaration();
            assert(!(vret.storage_class & (STCout | STCref)));
            eret = null;
        }
        else
        {
            /* Inlining:
             *   this.field = foo();   // inside constructor
             */
            auto ei = new ExpInitializer(callLoc, null);
            auto tmp = Identifier.generateId("__retvar");
            vret = new VarDeclaration(fd.loc, eret.type, tmp, ei);
            vret.storage_class |= STCtemp | STCref;
            vret.linkage = LINKd;
            vret.parent = parent;

            ei.exp = new ConstructExp(fd.loc, vret, eret);
            ei.exp.type = vret.type;

            auto de = new DeclarationExp(fd.loc, vret);
            de.type = Type.tvoid;
            eret = de;
        }

        if (!asStatements && fd.nrvo_var)
        {
            ids.from.push(fd.nrvo_var);
            ids.to.push(vret);
        }
    }
    else
    {
        if (!asStatements && fd.nrvo_var)
        {
            auto tmp = Identifier.generateId("__retvar");
            vret = new VarDeclaration(fd.loc, fd.nrvo_var.type, tmp, new VoidInitializer(fd.loc));
            assert(!tf.isref);
            vret.storage_class = STCtemp | STCrvalue;
            vret.linkage = tf.linkage;
            vret.parent = parent;

            auto de = new DeclarationExp(fd.loc, vret);
            de.type = Type.tvoid;
            eret = de;

            ids.from.push(fd.nrvo_var);
            ids.to.push(vret);
        }
    }

    // Set up vthis
    VarDeclaration vthis;
    if (ethis)
    {
        Expression e0;
        ethis = Expression.extractLast(ethis, &e0);
        if (ethis.op == TOKvar)
        {
            vthis = (cast(VarExp)ethis).var.isVarDeclaration();
        }
        else
        {
            //assert(ethis.type.ty != Tpointer);
            if (ethis.type.ty == Tpointer)
            {
                Type t = ethis.type.nextOf();
                ethis = new PtrExp(ethis.loc, ethis);
                ethis.type = t;
            }

            auto ei = new ExpInitializer(fd.loc, ethis);
            vthis = new VarDeclaration(fd.loc, ethis.type, Id.This, ei);
            if (ethis.type.ty != Tclass)
                vthis.storage_class = STCref;
            else
                vthis.storage_class = STCin;
            vthis.linkage = LINKd;
            vthis.parent = parent;

            ei.exp = new ConstructExp(fd.loc, vthis, ethis);
            ei.exp.type = vthis.type;

            auto de = new DeclarationExp(fd.loc, vthis);
            de.type = Type.tvoid;
            e0 = Expression.combine(e0, de);
        }
        ethis = e0;

        ids.vthis = vthis;
    }

    // Set up parameters
    Expression eparams;
    if (arguments && arguments.dim)
    {
        assert(fd.parameters.dim == arguments.dim);
        foreach (i; 0 .. arguments.dim)
        {
            auto vfrom = (*fd.parameters)[i];
            auto arg = (*arguments)[i];

            auto ei = new ExpInitializer(vfrom.loc, arg);
            auto vto = new VarDeclaration(vfrom.loc, vfrom.type, vfrom.ident, ei);
            vto.storage_class |= vfrom.storage_class & (STCtemp | STCin | STCout | STClazy | STCref);
            vto.linkage = vfrom.linkage;
            vto.parent = parent;
            //printf("vto = '%s', vto.storage_class = x%x\n", vto.toChars(), vto.storage_class);
            //printf("vto.parent = '%s'\n", parent.toChars());

            // Even if vto is STClazy, `vto = arg` is handled correctly in glue layer.
            ei.exp = new BlitExp(vto.loc, vto, arg);
            ei.exp.type = vto.type;
            //arg.type.print();
            //ei.exp.print();

            ids.from.push(vfrom);
            ids.to.push(vto);

            auto de = new DeclarationExp(vto.loc, vto);
            de.type = Type.tvoid;
            eparams = Expression.combine(eparams, de);

            /* If function pointer or delegate parameters are present,
             * inline scan again because if they are initialized to a symbol,
             * any calls to the fp or dg can be inlined.
             */
            if (vfrom.type.ty == Tdelegate ||
                vfrom.type.ty == Tpointer && vfrom.type.nextOf().ty == Tfunction)
            {
                if (arg.op == TOKvar)
                {
                    VarExp ve = cast(VarExp)arg;
                    if (ve.var.isFuncDeclaration())
                        again = true;
                }
                else if (arg.op == TOKsymoff)
                {
                    SymOffExp se = cast(SymOffExp)arg;
                    if (se.var.isFuncDeclaration())
                        again = true;
                }
                else if (arg.op == TOKfunction || arg.op == TOKdelegate)
                    again = true;
            }
        }
    }

    if (asStatements)
    {
        /* Construct:
         *  { eret; ethis; eparams; fd.fbody; }
         * or:
         *  { eret; ethis; try { eparams; fd.fbody; } finally { vthis.edtor; } }
         */

        auto as = new Statements();
        if (eret)
            as.push(new ExpStatement(callLoc, eret));
        if (ethis)
            as.push(new ExpStatement(callLoc, ethis));

        auto as2 = as;
        if (vthis && !vthis.isDataseg())
        {
            if (vthis.needsScopeDtor())
            {
                // same with ExpStatement.scopeCode()
                as2 = new Statements();
                vthis.storage_class |= STCnodtor;
            }
        }

        if (eparams)
            as2.push(new ExpStatement(callLoc, eparams));

        fd.inlineNest++;
        Statement s = doInlineAs!Statement(fd.fbody, ids);
        fd.inlineNest--;
        as2.push(s);

        if (as2 != as)
        {
            as.push(new TryFinallyStatement(callLoc,
                        new CompoundStatement(callLoc, as2),
                        new DtorExpStatement(callLoc, vthis.edtor, vthis)));
        }

        sresult = new ScopeStatement(callLoc, new CompoundStatement(callLoc, as), callLoc);

        static if (EXPANDINLINE_LOG)
            printf("\n[%s] %s expandInline sresult =\n%s\n",
                callLoc.toChars(), fd.toPrettyChars(), sresult.toChars());
    }
    else
    {
        /* Construct:
         *  (eret, ethis, eparams, fd.fbody)
         */

        fd.inlineNest++;
        auto e = doInlineAs!Expression(fd.fbody, ids);
        fd.inlineNest--;
        //e.type.print();
        //e.print();
        //e.print();

        // https://issues.dlang.org/show_bug.cgi?id=11322
        if (tf.isref)
            e = e.toLvalue(null, null);

        /* If the inlined function returns a copy of a struct,
         * and then the return value is used subsequently as an
         * lvalue, as in a struct return that is then used as a 'this'.
         * Taking the address of the return value will be taking the address
         * of the original, not the copy. Fix this by assigning the return value to
         * a temporary, then returning the temporary. If the temporary is used as an
         * lvalue, it will work.
         * This only happens with struct returns.
         * See https://issues.dlang.org/show_bug.cgi?id=2127 for an example.
         *
         * On constructor call making __inlineretval is merely redundant, because
         * the returned reference is exactly same as vthis, and the 'this' variable
         * already exists at the caller side.
         */
        if (tf.next.ty == Tstruct && !fd.nrvo_var && !fd.isCtorDeclaration() &&
            !isConstruction(e))
        {
            /* Generate a new variable to hold the result and initialize it with the
             * inlined body of the function:
             *   tret __inlineretval = e;
             */
            auto ei = new ExpInitializer(callLoc, e);
            auto tmp = Identifier.generateId("__inlineretval");
            auto vd = new VarDeclaration(callLoc, tf.next, tmp, ei);
            vd.storage_class = STCtemp | (tf.isref ? STCref : STCrvalue);
            vd.linkage = tf.linkage;
            vd.parent = parent;

            ei.exp = new ConstructExp(callLoc, vd, e);
            ei.exp.type = vd.type;

            auto de = new DeclarationExp(callLoc, vd);
            de.type = Type.tvoid;

            // Chain the two together:
            //   ( typeof(return) __inlineretval = ( inlined body )) , __inlineretval
            e = Expression.combine(de, new VarExp(callLoc, vd));

            //fprintf(stderr, "CallExp.inlineScan: e = "); e.print();
        }

        // https://issues.dlang.org/show_bug.cgi?id=15210
        if (tf.next.ty == Tvoid && e && e.type.ty != Tvoid)
        {
            e = new CastExp(callLoc, e, Type.tvoid);
            e.type = Type.tvoid;
        }

        eresult = Expression.combine(eresult, eret);
        eresult = Expression.combine(eresult, ethis);
        eresult = Expression.combine(eresult, eparams);
        eresult = Expression.combine(eresult, e);

        static if (EXPANDINLINE_LOG)
            printf("\n[%s] %s expandInline eresult = %s\n",
                callLoc.toChars(), fd.toPrettyChars(), eresult.toChars());
    }

    // Need to reevaluate whether parent can now be inlined
    // in expressions, as we might have inlined statements
    parent.inlineStatusExp = ILSuninitialized;
}

/****************************************************
 * Determine if the value of `e` is the result of construction.
 *
 * Params:
 *      e = expression to check
 * Returns:
 *      true for value generated by a constructor or struct literal
 */
private bool isConstruction(Expression e)
{
    while (e.op == TOKcomma)
        e = (cast(CommaExp)e).e2;

    if (e.op == TOKstructliteral)
    {
        return true;
    }
    /* Detect:
     *    structliteral.ctor(args)
     */
    else if (e.op == TOKcall)
    {
        auto ce = cast(CallExp)e;
        if (ce.e1.op == TOKdotvar)
        {
            auto dve = cast(DotVarExp)ce.e1;
            auto fd = dve.var.isFuncDeclaration();
            if (fd && fd.isCtorDeclaration())
            {
                if (dve.e1.op == TOKstructliteral)
                {
                    return true;
                }
            }
        }
    }
    return false;
}


/***********************************************************
 * Perform the "inline copying" of a default argument for a function parameter.
 *
 * Todo:
 *  The hack for bugzilla 4820 case is still questionable. Perhaps would have to
 *  handle a delegate expression with 'null' context properly in front-end.
 */
public Expression inlineCopy(Expression e, Scope* sc)
{
    /* See https://issues.dlang.org/show_bug.cgi?id=2935
     * for explanation of why just a copy() is broken
     */
    //return e.copy();
    if (e.op == TOKdelegate)
    {
        DelegateExp de = cast(DelegateExp)e;
        if (de.func.isNested())
        {
            /* https://issues.dlang.org/show_bug.cgi?id=4820
             * Defer checking until later if we actually need the 'this' pointer
             */
            return de.copy();
        }
    }
    int cost = inlineCostExpression(e);
    if (cost >= COST_MAX)
    {
        e.error("cannot inline default argument `%s`", e.toChars());
        return new ErrorExp();
    }
    scope ids = new InlineDoState(sc.parent, null);
    return doInlineAs!Expression(e, ids);
}

/***********************************************************
 * Determine if v is 'head const', meaning
 * that once it is initialized it is not changed
 * again.
 *
 * This is done using a primitive flow analysis.
 *
 * v is head const if v is const or immutable.
 * Otherwise, v is assumed to be head const unless one of the
 * following is true:
 *      1. v is a `ref` or `out` variable
 *      2. v is a parameter and fd is a variadic function
 *      3. v is assigned to again
 *      4. the address of v is taken
 *      5. v is referred to by a function nested within fd
 *      6. v is ever assigned to a `ref` or `out` variable
 *      7. v is ever passed to another function as `ref` or `out`
 *
 * Params:
 *      v       variable to check
 *      fd      function that v is local to
 * Returns:
 *      true if v's initializer is the only value assigned to v
 */
bool onlyOneAssign(VarDeclaration v, FuncDeclaration fd)
{
    if (!v.type.isMutable())
        return true;            // currently the only case handled atm
    return false;
}
