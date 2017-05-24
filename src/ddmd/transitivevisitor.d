module ddmd.transitivevisitor;

import ddmd.astbase;
import ddmd.permissivevisitor;
import ddmd.tokens;

import ddmd.root.rootobject;

class TransitiveVisitor : PermissiveVisitor
{
    alias visit = super.visit;

//   Statement Nodes
//===========================================================
    override void visit(ASTBase.ExpStatement s)
    {
        if (s.exp && s.exp.op == TOKdeclaration)
        {
            (cast(ASTBase.DeclarationExp)s.exp).declaration.accept(this);
            return;
        }
        if (s.exp)
            s.exp.accept(this);
    }

    override void visit(ASTBase.CompileStatement s)
    {
        s.exp.accept(this);
    }

    override void visit(ASTBase.CompoundStatement s)
    {
        foreach (sx; *s.statements)
        {
            if (sx)
                sx.accept(this);
        }
    }

    void visitVarDecl(ASTBase.VarDeclaration v)
    {
        if (v.type)
            visitType(v.type);
        if (v._init)
        {
            auto ie = v._init.isExpInitializer();
            if (ie && (ie.exp.op == TOKconstruct || ie.exp.op == TOKblit))
                (cast(ASTBase.AssignExp)ie.exp).e2.accept(this);
            else
                v._init.accept(this);
        }
    }

    override void visit(ASTBase.CompoundDeclarationStatement s)
    {
        foreach (sx; *s.statements)
        {
            auto ds = sx ? sx.isExpStatement() : null;
            if (ds && ds.exp.op == TOKdeclaration)
            {
                auto d = (cast(ASTBase.DeclarationExp)ds.exp).declaration;
                assert(d.isDeclaration());
                if (auto v = d.isVarDeclaration())
                    visitVarDecl(v);
                else
                    d.accept(this);
            }
        }
    }

    override void visit(ASTBase.ScopeStatement s)
    {
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(ASTBase.WhileStatement s)
    {
        s.condition.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.DoStatement s)
    {
        if (s._body)
            s._body.accept(this);
        s.condition.accept(this);
    }

    override void visit(ASTBase.ForStatement s)
    {
        if (s._init)
            s._init.accept(this);
        if (s.condition)
            s.condition.accept(this);
        if (s.increment)
            s.increment.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.ForeachStatement s)
    {
        foreach (p; *s.parameters)
            if (p.type)
                visitType(p.type);
        s.aggr.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.ForeachRangeStatement s)
    {
        if (s.prm.type)
            visitType(s.prm.type);
        s.lwr.accept(this);
        s.upr.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.IfStatement s)
    {
        if (s.prm.type)
            visitType(s.prm.type);
        s.condition.accept(this);
        s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    override void visit(ASTBase.ConditionalStatement s)
    {
        s.condition.accept(this);
        if (s.ifbody)
            s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    void visitArgs(ASTBase.Expressions* expressions, ASTBase.Expression basis = null)
    {
        if (!expressions || !expressions.dim)
            return;
        foreach (el; *expressions)
        {
            if (!el)
                el = basis;
            if (el)
                el.accept(this);
        }
    }

    override void visit(ASTBase.PragmaStatement s)
    {
        if (s.args && s.args.dim)
            visitArgs(s.args);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.StaticAssertStatement s)
    {
        s.sa.accept(this);
    }

    override void visit(ASTBase.SwitchStatement s)
    {
        s.condition.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.CaseStatement s)
    {
        s.exp.accept(this);
        s.statement.accept(this);
    }

    override void visit(ASTBase.CaseRangeStatement s)
    {
        s.first.accept(this);
        s.last.accept(this);
        s.statement.accept(this);
    }

    override void visit(ASTBase.DefaultStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(ASTBase.GotoCaseStatement s)
    {
        if (s.exp)
            s.exp.accept(this);
    }

    override void visit(ASTBase.ReturnStatement s)
    {
        if (s.exp)
            s.exp.accept(this);
    }

    override void visit(ASTBase.SynchronizedStatement s)
    {
        if (s.exp)
            s.exp.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.WithStatement s)
    {
        s.exp.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.TryCatchStatement s)
    {
        if (s._body)
            s._body.accept(this);
        foreach (c; *s.catches)
            visit(c);
    }

    override void visit(ASTBase.TryFinallyStatement s)
    {
        s._body.accept(this);
        s.finalbody.accept(this);
    }

    override void visit(ASTBase.OnScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(ASTBase.ThrowStatement s)
    {
        s.exp.accept(this);
    }

    override void visit(ASTBase.LabelStatement s)
    {
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(ASTBase.ImportStatement s)
    {
        foreach (imp; *s.imports)
            imp.accept(this);
    }

    void visit(ASTBase.Catch c)
    {
        if (c.type)
            visitType(c.type);
        if (c.handler)
            c.handler.accept(this);
    }

//   Type Nodes
//============================================================

    void visitType(ASTBase.Type t)
    {
        if (t.ty == ASTBase.Tfunction)
        {
            visitFunctionType(cast(ASTBase.TypeFunction)t, null);
            return;
        }
        else
            t.accept(this);
    }

    void visitFunctionType(ASTBase.TypeFunction t, ASTBase.TemplateDeclaration td)
    {
        if (t.next)
            visitType(t.next);
        if (td)
        {
            foreach (p; *td.origParameters)
                p.accept(this);
        }
        visitParameters(t.parameters);
    }

    void visitParameters(ASTBase.Parameters* parameters)
    {
        if (parameters)
        {
            size_t dim = ASTBase.Parameter.dim(parameters);
            foreach(i; 0..dim)
            {
                ASTBase.Parameter fparam = ASTBase.Parameter.getNth(parameters, i);
                fparam.accept(this);
            }
        }
    }

    override void visit(ASTBase.TypeVector t)
    {
        t.basetype.accept(this);
    }

    override void visit(ASTBase.TypeSArray t)
    {
        t.next.accept(this);
    }

    override void visit(ASTBase.TypeDArray t)
    {
        t.next.accept(this);
    }

    override void visit(ASTBase.TypeAArray t)
    {
        t.next.accept(this);
        t.index.accept(this);
    }

    override void visit(ASTBase.TypePointer t)
    {
        if (t.next.ty == ASTBase.Tfunction)
        {
            visitFunctionType(cast(ASTBase.TypeFunction)t.next, null);
        }
        else
            t.next.accept(this);
    }

    override void visit(ASTBase.TypeReference t)
    {
        t.next.accept(this);
    }

    override void visit(ASTBase.TypeFunction t)
    {
        visitFunctionType(t, null);
    }

    override void visit(ASTBase.TypeDelegate t)
    {
        visitFunctionType(cast(ASTBase.TypeFunction)t.next, null);
    }

    void visitTypeQualified(ASTBase.TypeQualified t)
    {
        foreach (id; t.idents)
        {
            if (id.dyncast() == DYNCAST.dsymbol)
                (cast(ASTBase.TemplateInstance)id).accept(this);
            else if (id.dyncast() == DYNCAST.expression)
                (cast(ASTBase.Expression)id).accept(this);
            else if (id.dyncast() == DYNCAST.type)
                (cast(ASTBase.Type)id).accept(this);
        }
    }

    override void visit(ASTBase.TypeIdentifier t)
    {
        visitTypeQualified(t);
    }

    override void visit(ASTBase.TypeInstance t)
    {
        t.tempinst.accept(this);
        visitTypeQualified(t);
    }

    override void visit(ASTBase.TypeTypeof t)
    {
        t.exp.accept(this);
        visitTypeQualified(t);
    }

    override void visit(ASTBase.TypeReturn t)
    {
        visitTypeQualified(t);
    }

    override void visit(ASTBase.TypeTuple t)
    {
        visitParameters(t.arguments);
    }

    override void visit(ASTBase.TypeSlice t)
    {
        t.next.accept(this);
        t.lwr.accept(this);
        t.upr.accept(this);
    }

//      Miscellaneous
//========================================================

    override void visit(ASTBase.StaticAssert s)
    {
        s.exp.accept(this);
        if (s.msg)
            s.msg.accept(this);
    }

    override void visit(ASTBase.EnumMember em)
    {
        if (em.type)
            visitType(em.type);
        if (em.value)
            em.value.accept(this);
    }

//      Declarations
//=========================================================
    void visitAttribDeclaration(ASTBase.AttribDeclaration d)
    {
        if (d.decl)
            foreach (de; *d.decl)
                de.accept(this);
    }

    override void visit(ASTBase.AttribDeclaration d)
    {
        visitAttribDeclaration(d);
    }

    override void visit(ASTBase.StorageClassDeclaration d)
    {
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.DeprecatedDeclaration d)
    {
        d.msg.accept(this);
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.LinkDeclaration d)
    {
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.CPPMangleDeclaration d)
    {
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.ProtDeclaration d)
    {
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.AlignDeclaration d)
    {
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.AnonDeclaration d)
    {
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.PragmaDeclaration d)
    {
        if (d.args && d.args.dim)
            visitArgs(d.args);
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    override void visit(ASTBase.ConditionalDeclaration d)
    {
        d.condition.accept(this);
        if (d.decl)
            foreach (de; *d.decl)
                de.accept(this);
        if (d.elsedecl)
            foreach (de; *d.elsedecl)
                de.accept(this);
    }

    override void visit(ASTBase.CompileDeclaration d)
    {
        d.exp.accept(this);
    }

    override void visit(ASTBase.UserAttributeDeclaration d)
    {
        visitArgs(d.atts);
        visitAttribDeclaration(cast(ASTBase.AttribDeclaration)d);
    }

    void visitFuncBody(ASTBase.FuncDeclaration f)
    {
        if (f.frequire)
            f.frequire.accept(this);
        if (f.fensure)
            f.fensure.accept(this);
        f.fbody.accept(this);
    }

    void visitBaseClasses(ASTBase.ClassDeclaration d)
    {
        if (!d || !d.baseclasses.dim)
            return;
        foreach (b; *d.baseclasses)
            visitType(b.type);
    }

    bool visitEponymousMember(ASTBase.TemplateDeclaration d)
    {
        if (!d.members || d.members.dim != 1)
            return false;
        ASTBase.Dsymbol onemember = (*d.members)[0];
        if (onemember.ident != d.ident)
            return false;

        if (ASTBase.FuncDeclaration fd = onemember.isFuncDeclaration())
        {
            assert(fd.type);
            visitFunctionType(cast(ASTBase.TypeFunction)fd.type, d);
            if (d.constraint)
                d.constraint.accept(this);
            visitFuncBody(fd);

            return true;
        }

        if (ASTBase.AggregateDeclaration ad = onemember.isAggregateDeclaration())
        {
            visitTemplateParameters(d.parameters);
            if (d.constraint)
                d.constraint.accept(this);
            visitBaseClasses(ad.isClassDeclaration());

            if (ad.members)
                foreach (s; *ad.members)
                    s.accept(this);

            return true;
        }

        if (ASTBase.VarDeclaration vd = onemember.isVarDeclaration())
        {
            if (d.constraint)
                return false;
            if (vd.type)
                visitType(vd.type);
            visitTemplateParameters(d.parameters);
            if (vd._init)
            {
                ASTBase.ExpInitializer ie = vd._init.isExpInitializer();
                if (ie && (ie.exp.op == TOKconstruct || ie.exp.op == TOKblit))
                    (cast(ASTBase.AssignExp)ie.exp).e2.accept(this);
                else
                    vd._init.accept(this);

                return true;
            }
        }

        return false;
    }

    void visitTemplateParameters(ASTBase.TemplateParameters* parameters)
    {
        if (!parameters || !parameters.dim)
            return;
        foreach (p; *parameters)
            p.accept(this);
    }

    override void visit(ASTBase.TemplateDeclaration d)
    {
        if (visitEponymousMember(d))
            return;

        visitTemplateParameters(d.parameters);
        if (d.constraint)
            d.constraint.accept(this);

        foreach (s; *d.members)
            s.accept(this);
    }

    void visitObject(RootObject oarg)
    {
        if (auto t = ASTBase.isType(oarg))
        {
            visitType(t);
        }
        else if (auto e = ASTBase.isExpression(oarg))
        {
            e.accept(this);
        }
        else if (auto v = ASTBase.isTuple(oarg))
        {
            auto args = &v.objects;
            foreach (arg; *args)
                visitObject(arg);
        }
    }

    void visitTiargs(ASTBase.TemplateInstance ti)
    {
        foreach (arg; *ti.tiargs)
        {
            visitObject(arg);
        }
    }

    override void visit(ASTBase.TemplateInstance ti)
    {
        visitTiargs(ti);
    }

    override void visit(ASTBase.TemplateMixin tm)
    {
        visitType(tm.tqual);
        visitTiargs(tm);
    }

    override void visit(ASTBase.EnumDeclaration d)
    {
        if (d.memtype)
            visitType(d.memtype);
        foreach (em; *d.members)
        {
            if (!em)
                continue;
            em.accept(this);
        }
    }

    override void visit(ASTBase.Nspace d)
    {
        foreach(s; *d.members)
            s.accept(this);
    }

    override void visit(ASTBase.StructDeclaration d)
    {
        foreach (s; *d.members)
            s.accept(this);
    }

    override void visit(ASTBase.ClassDeclaration d)
    {
        visitBaseClasses(d);
        if (d.members)
            foreach (s; *d.members)
                s.accept(this);
    }

    override void visit(ASTBase.AliasDeclaration d)
    {
        if (d.aliassym)
            d.aliassym.accept(this);
        else
            visitType(d.type);
    }

    override void visit(ASTBase.VarDeclaration d)
    {
        visitVarDecl(d);
    }

    override void visit(ASTBase.FuncDeclaration f)
    {
        auto tf = cast(ASTBase.TypeFunction)f.type;
        visitType(tf);
        visitFuncBody(f);
    }

    override void visit(ASTBase.FuncLiteralDeclaration f)
    {
        if (f.type.ty == ASTBase.Terror)
            return;
        ASTBase.TypeFunction tf = cast(ASTBase.TypeFunction)f.type;
        if (!f.inferRetType && tf.next)
            visitType(tf.next);
        visitParameters(tf.parameters);
        ASTBase.CompoundStatement cs = f.fbody.isCompoundStatement();
        ASTBase.Statement s = !cs ? f.fbody : null;
        ASTBase.ReturnStatement rs = s ? s.isReturnStatement() : null;
        if (rs && rs.exp)
            rs.exp.accept(this);
        else
            visitFuncBody(f);
    }

    override void visit(ASTBase.PostBlitDeclaration d)
    {
        visitFuncBody(d);
    }

    override void visit(ASTBase.DtorDeclaration d)
    {
        visitFuncBody(d);
    }

    override void visit(ASTBase.StaticCtorDeclaration d)
    {
        visitFuncBody(d);
    }

    override void visit(ASTBase.StaticDtorDeclaration d)
    {
        visitFuncBody(d);
    }

    override void visit(ASTBase.InvariantDeclaration d)
    {
        visitFuncBody(d);
    }

    override void visit(ASTBase.UnitTestDeclaration d)
    {
        visitFuncBody(d);
    }

    override void visit(ASTBase.NewDeclaration d)
    {
        visitParameters(d.parameters);
        visitFuncBody(d);
    }

    override void visit(ASTBase.DeleteDeclaration d)
    {
        visitParameters(d.parameters);
        visitFuncBody(d);
    }

//   Initializers
//============================================================

    override void visit(ASTBase.StructInitializer si)
    {
        foreach (i, const id; si.field)
            if (auto iz = si.value[i])
                iz.accept(this);
    }

    override void visit(ASTBase.ArrayInitializer ai)
    {
        foreach (i, ex; ai.index)
        {
            if (ex)
                ex.accept(this);
            if (auto iz = ai.value[i])
                iz.accept(this);
        }
    }

    override void visit(ASTBase.ExpInitializer ei)
    {
        ei.exp.accept(this);
    }

//      Expressions
//===================================================

    override void visit(ASTBase.ArrayLiteralExp e)
    {
        visitArgs(e.elements, e.basis);
    }

    override void visit(ASTBase.AssocArrayLiteralExp e)
    {
        foreach (i, key; *e.keys)
        {
            key.accept(this);
            ((*e.values)[i]).accept(this);
        }
    }

    override void visit(ASTBase.TypeExp e)
    {
        visitType(e.type);
    }

    override void visit(ASTBase.ScopeExp e)
    {
        if (e.sds.isTemplateInstance())
            e.sds.accept(this);
    }

    override void visit(ASTBase.NewExp e)
    {
        if (e.thisexp)
            e.thisexp.accept(this);
        if (e.newargs && e.newargs.dim)
            visitArgs(e.newargs);
        visitType(e.newtype);
        if (e.arguments && e.arguments.dim)
            visitArgs(e.arguments);
    }

    override void visit(ASTBase.NewAnonClassExp e)
    {
        if (e.thisexp)
            e.thisexp.accept(this);
        if (e.newargs && e.newargs.dim)
            visitArgs(e.newargs);
        if (e.arguments && e.arguments.dim)
            visitArgs(e.arguments);
        if (e.cd)
            e.cd.accept(this);
    }

    override void visit(ASTBase.TupleExp e)
    {
        if (e.e0)
            e.e0.accept(this);
        visitArgs(e.exps);
    }

    override void visit(ASTBase.FuncExp e)
    {
        e.fd.accept(this);
    }

    override void visit(ASTBase.DeclarationExp e)
    {
        if (auto v = e.declaration.isVarDeclaration())
            visitVarDecl(v);
        else
            e.declaration.accept(this);
    }

    override void visit(ASTBase.TypeidExp e)
    {
        visitObject(e.obj);
    }

    override void visit(ASTBase.TraitsExp e)
    {
        if (e.args)
            foreach (arg; *e.args)
                visitObject(arg);
    }

    override void visit(ASTBase.IsExp e)
    {
        visitType(e.targ);
        if (e.tspec)
            visitType(e.tspec);
        if (e.parameters && e.parameters.dim)
            visitTemplateParameters(e.parameters);
    }

    override void visit(ASTBase.UnaExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.BinExp e)
    {
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(ASTBase.CompileExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.ImportExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.AssertExp e)
    {
        e.e1.accept(this);
        if (e.msg)
            e.msg.accept(this);
    }

    override void visit(ASTBase.DotIdExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.DotTemplateInstanceExp e)
    {
        e.e1.accept(this);
        e.ti.accept(this);
    }

    override void visit(ASTBase.CallExp e)
    {
        e.e1.accept(this);
        visitArgs(e.arguments);
    }

    override void visit(ASTBase.PtrExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.DeleteExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.CastExp e)
    {
        if (e.to)
            visitType(e.to);
        e.e1.accept(this);
    }

    override void visit(ASTBase.IntervalExp e)
    {
        e.lwr.accept(this);
        e.upr.accept(this);
    }

    override void visit(ASTBase.ArrayExp e)
    {
        e.e1.accept(this);
        visitArgs(e.arguments);
    }

    override void visit(ASTBase.PostExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.PreExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTBase.CondExp e)
    {
        e.econd.accept(this);
        e.e1.accept(this);
        e.e2.accept(this);
    }

// Template Parameter
//===========================================================

    override void visit(ASTBase.TemplateTypeParameter tp)
    {
        if (tp.specType)
            visitType(tp.specType);
        if (tp.defaultType)
            visitType(tp.defaultType);
    }

    override void visit(ASTBase.TemplateThisParameter tp)
    {
        visit(cast(ASTBase.TemplateTypeParameter)tp);
    }

    override void visit(ASTBase.TemplateAliasParameter tp)
    {
        if (tp.specType)
            visitType(tp.specType);
        if (tp.specAlias)
            visitObject(tp.specAlias);
        if (tp.defaultAlias)
            visitObject(tp.defaultAlias);
    }

    override void visit(ASTBase.TemplateValueParameter tp)
    {
        visitType(tp.valType);
        if (tp.specValue)
            tp.specValue.accept(this);
        if (tp.defaultValue)
            tp.defaultValue.accept(this);
    }

//===========================================================

    override void visit(ASTBase.StaticIfCondition c)
    {
        c.exp.accept(this);
    }

    override void visit(ASTBase.Parameter p)
    {
        visitType(p.type);
        if (p.defaultArg)
            p.defaultArg.accept(this);
    }

    override void visit(ASTBase.Module m)
    {
        foreach (s; *m.members)
            s.accept(this);
    }
}

