module ddmd.astbasevisitor;

import ddmd.astbase;

class Visitor(AST)
{
    void visit(AST.Dsymbol)
    {
        assert(0);
    }

    void visit(AST.AliasThis s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.Declaration s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.ScopeDsymbol s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.Import s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.AttribDeclaration s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.StaticAssert s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.DebugSymbol s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.VersionSymbol s)
    {
        visit(cast(AST.Dsymbol)s);
    }

    void visit(AST.VarDeclaration s)
    {
        visit(cast(AST.Declaration)s);
    }

    void visit(AST.FuncDeclaration s)
    {
        visit(cast(AST.Declaration)s);
    }

    void visit(AST.AliasDeclaration s)
    {
        visit(cast(AST.Declaration)s);
    }

    void visit(AST.TupleDeclaration s)
    {
        visit(cast(AST.Declaration)s);
    }

    void visit(AST.FuncLiteralDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.PostBlitDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.CtorDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.DtorDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.InvariantDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.UnitTestDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.NewDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.DeleteDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.StaticCtorDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.StaticDtorDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.SharedStaticCtorDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.SharedStaticDtorDeclaration s)
    {
        visit(cast(AST.FuncDeclaration)s);
    }

    void visit(AST.Package s)
    {
        visit(cast(AST.ScopeDsymbol)s);
    }

    void visit(AST.EnumDeclaration s)
    {
        visit(cast(AST.ScopeDsymbol)s);
    }

    void visit(AST.AggregateDeclaration s)
    {
        visit(cast(AST.ScopeDsymbol)s);
    }

    void visit(AST.TemplateDeclaration s)
    {
        visit(cast(AST.ScopeDsymbol)s);
    }

    void visit(AST.TemplateInstance s)
    {
        visit(cast(AST.ScopeDsymbol)s);
    }

    void visit(AST.Nspace s)
    {
        visit(cast(AST.ScopeDsymbol)s);
    }

    void visit(AST.CompileDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.UserAttributeDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.LinkDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.AnonDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.AlignDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.CPPMangleDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.ProtDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.PragmaDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.StorageClassDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.ConditionalDeclaration s)
    {
        visit(cast(AST.AttribDeclaration)s);
    }

    void visit(AST.DeprecatedDeclaration s)
    {
        visit(cast(AST.StorageClassDeclaration)s);
    }

    void visit(AST.StaticIfDeclaration s)
    {
        visit(cast(AST.ConditionalDeclaration)s);
    }

    void visit(AST.EnumMember s)
    {
        visit(cast(AST.VarDeclaration)s);
    }

    void visit(AST.Module s)
    {
        visit(cast(AST.Package)s);
    }

    void visit(AST.StructDeclaration s)
    {
        visit(cast(AST.AggregateDeclaration)s);
    }

    void visit(AST.UnionDeclaration s)
    {
        visit(cast(AST.StructDeclaration)s);
    }

    void visit(AST.ClassDeclaration s)
    {
        visit(cast(AST.AggregateDeclaration)s);
    }

    void visit(AST.InterfaceDeclaration s)
    {
        visit(cast(AST.ClassDeclaration)s);
    }

    void visit(AST.TemplateMixin s)
    {
        visit(cast(AST.TemplateInstance)s);
    }

    void visit(AST.Parameter)
    {
        assert(0);
    }

    void visit(AST.Statement)
    {
        assert(0);
    }

    void visit(AST.ImportStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ScopeStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ReturnStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.LabelStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.StaticAssertStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.CompileStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.WhileStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ForStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.DoStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ForeachRangeStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ForeachStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.IfStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.OnScopeStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ConditionalStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.PragmaStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.SwitchStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.CaseRangeStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.CaseStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.DefaultStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.BreakStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ContinueStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.GotoDefaultStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.GotoCaseStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.GotoStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.SynchronizedStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.WithStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.TryCatchStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.TryFinallyStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ThrowStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.AsmStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.ExpStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.CompoundStatement s)
    {
        visit(cast(AST.Statement)s);
    }

    void visit(AST.CompoundDeclarationStatement s)
    {
        visit(cast(AST.CompoundStatement)s);
    }

    void visit(AST.CompoundAsmStatement s)
    {
        visit(cast(AST.CompoundStatement)s);
    }

    void visit(AST.Type)
    {
        assert(0);
    }

    void visit(AST.TypeBasic t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeError t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeNull t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeVector t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeEnum t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeTuple t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeClass t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeStruct t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeNext t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeReference t)
    {
        visit(cast(AST.TypeNext)t);
    }

    void visit(AST.TypeSlice t)
    {
        visit(cast(AST.TypeNext)t);
    }

    void visit(AST.TypeDelegate t)
    {
        visit(cast(AST.TypeNext)t);
    }

    void visit(AST.TypePointer t)
    {
        visit(cast(AST.TypeNext)t);
    }

    void visit(AST.TypeFunction t)
    {
        visit(cast(AST.TypeNext)t);
    }

    void visit(AST.TypeArray t)
    {
        visit(cast(AST.TypeNext)t);
    }

    void visit(AST.TypeDArray t)
    {
        visit(cast(AST.TypeArray)t);
    }

    void visit(AST.TypeAArray t)
    {
        visit(cast(AST.TypeArray)t);
    }

    void visit(AST.TypeSArray t)
    {
        visit(cast(AST.TypeArray)t);
    }

    void visit(AST.TypeQualified t)
    {
        visit(cast(AST.Type)t);
    }

    void visit(AST.TypeIdentifier t)
    {
        visit(cast(AST.TypeQualified)t);
    }

    void visit(AST.TypeReturn t)
    {
        visit(cast(AST.TypeQualified)t);
    }

    void visit(AST.TypeTypeof t)
    {
        visit(cast(AST.TypeQualified)t);
    }

    void visit(AST.TypeInstance t)
    {
        visit(cast(AST.TypeQualified)t);
    }

    void visit(AST.Expression e)
    {
        assert(0);
    }

    void visit(AST.DeclarationExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.IntegerExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.NewAnonClassExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.IsExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.RealExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.NullExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.TypeidExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.TraitsExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.StringExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.NewExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.AssocArrayLiteralExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.ArrayLiteralExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.FuncExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.IntervalExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.TypeExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.ScopeExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.IdentifierExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.UnaExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.DefaultInitExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.BinExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.DsymbolExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.TemplateExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.SymbolExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.VarExp e)
    {
        visit(cast(AST.SymbolExp)e);
    }

    void visit(AST.TupleExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.DollarExp e)
    {
        visit(cast(AST.IdentifierExp)e);
    }

    void visit(AST.ThisExp e)
    {
        visit(cast(AST.Expression)e);
    }

    void visit(AST.SuperExp e)
    {
        visit(cast(AST.ThisExp)e);
    }

    void visit(AST.AddrExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.PreExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.PtrExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.NegExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.UAddExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.NotExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.ComExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.DeleteExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.CastExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.CallExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.DotIdExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.AssertExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.CompileExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.ImportExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.DotTemplateInstanceExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.ArrayExp e)
    {
        visit(cast(AST.UnaExp)e);
    }

    void visit(AST.FuncInitExp e)
    {
        visit(cast(AST.DefaultInitExp)e);
    }

    void visit(AST.PrettyFuncInitExp e)
    {
        visit(cast(AST.DefaultInitExp)e);
    }

    void visit(AST.FileInitExp e)
    {
        visit(cast(AST.DefaultInitExp)e);
    }

    void visit(AST.LineInitExp e)
    {
        visit(cast(AST.DefaultInitExp)e);
    }

    void visit(AST.ModuleInitExp e)
    {
        visit(cast(AST.DefaultInitExp)e);
    }

    void visit(AST.CommaExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.PostExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.PowExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.MulExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.DivExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.ModExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.AddExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.MinExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.CatExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.ShlExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.ShrExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.UshrExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.EqualExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.InExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.IdentityExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.CmpExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.AndExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.XorExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.OrExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.AndAndExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.OrOrExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.CondExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.AssignExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.BinAssignExp e)
    {
        visit(cast(AST.BinExp)e);
    }

    void visit(AST.AddAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.MinAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.MulAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.DivAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.ModAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.PowAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.AndAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.OrAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.XorAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.ShlAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.ShrAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.UshrAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.CatAssignExp e)
    {
        visit(cast(AST.BinAssignExp)e);
    }

    void visit(AST.TemplateParameter)
    {
        assert(0);
    }

    void visit(AST.TemplateAliasParameter tp)
    {
        visit(cast(AST.TemplateParameter)tp);
    }

    void visit(AST.TemplateTypeParameter tp)
    {
        visit(cast(AST.TemplateParameter)tp);
    }

    void visit(AST.TemplateTupleParameter tp)
    {
        visit(cast(AST.TemplateParameter)tp);
    }

    void visit(AST.TemplateValueParameter tp)
    {
        visit(cast(AST.TemplateParameter)tp);
    }

    void visit(AST.TemplateThisParameter tp)
    {
        visit(cast(AST.TemplateTypeParameter)tp);
    }

    void visit(AST.Condition c)
    {
        assert(0);
    }

    void visit(AST.StaticIfCondition c)
    {
        visit(cast(AST.Condition)c);
    }

    void visit(AST.DVCondition c)
    {
        visit(cast(AST.Condition)c);
    }

    void visit(AST.DebugCondition c)
    {
        visit(cast(AST.DVCondition)c);
    }

    void visit(AST.VersionCondition c)
    {
        visit(cast(AST.DVCondition)c);
    }

    void visit(AST.Initializer)
    {
        assert(0);
    }

    void visit(AST.ExpInitializer i)
    {
        visit(cast(AST.Initializer)i);
    }

    void visit(AST.StructInitializer i)
    {
        visit(cast(AST.Initializer)i);
    }

    void visit(AST.ArrayInitializer i)
    {
        visit(cast(AST.Initializer)i);
    }

    void visit(AST.VoidInitializer i)
    {
        visit(cast(AST.Initializer)i);
    }
}

class StrictVisitor(AST) : Visitor!AST
{
    alias visit = Visitor!AST.visit;

    override void visit(AST.Dsymbol)
    {
        assert(0);
    }

    override void visit(AST.AliasThis s)
    {
        assert(0);
    }

    override void visit(AST.Declaration s)
    {
        assert(0);
    }

    override void visit(AST.ScopeDsymbol s)
    {
        assert(0);
    }

    override void visit(AST.Import s)
    {
        assert(0);
    }

    override void visit(AST.AttribDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.StaticAssert s)
    {
        assert(0);
    }

    override void visit(AST.DebugSymbol s)
    {
        assert(0);
    }

    override void visit(AST.VersionSymbol s)
    {
        assert(0);
    }

    override void visit(AST.VarDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.FuncDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.AliasDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.TupleDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.FuncLiteralDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.PostBlitDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.CtorDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.DtorDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.InvariantDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.UnitTestDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.NewDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.DeleteDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.StaticCtorDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.StaticDtorDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.SharedStaticCtorDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.SharedStaticDtorDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.Package s)
    {
        assert(0);
    }

    override void visit(AST.EnumDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.AggregateDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.TemplateDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.TemplateInstance s)
    {
        assert(0);
    }

    override void visit(AST.Nspace s)
    {
        assert(0);
    }

    override void visit(AST.CompileDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.UserAttributeDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.LinkDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.AnonDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.AlignDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.CPPMangleDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.ProtDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.PragmaDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.StorageClassDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.ConditionalDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.DeprecatedDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.StaticIfDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.EnumMember s)
    {
        assert(0);
    }

    override void visit(AST.Module s)
    {
        assert(0);
    }

    override void visit(AST.StructDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.UnionDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.ClassDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.InterfaceDeclaration s)
    {
        assert(0);
    }

    override void visit(AST.TemplateMixin s)
    {
        assert(0);
    }

    override void visit(AST.Parameter)
    {
        assert(0);
    }

    override void visit(AST.Statement)
    {
        assert(0);
    }

    override void visit(AST.ImportStatement s)
    {
        assert(0);
    }

    override void visit(AST.ScopeStatement s)
    {
        assert(0);
    }

    override void visit(AST.ReturnStatement s)
    {
        assert(0);
    }

    override void visit(AST.LabelStatement s)
    {
        assert(0);
    }

    override void visit(AST.StaticAssertStatement s)
    {
        assert(0);
    }

    override void visit(AST.CompileStatement s)
    {
        assert(0);
    }

    override void visit(AST.WhileStatement s)
    {
        assert(0);
    }

    override void visit(AST.ForStatement s)
    {
        assert(0);
    }

    override void visit(AST.DoStatement s)
    {
        assert(0);
    }

    override void visit(AST.ForeachRangeStatement s)
    {
        assert(0);
    }

    override void visit(AST.ForeachStatement s)
    {
        assert(0);
    }

    override void visit(AST.IfStatement s)
    {
        assert(0);
    }

    override void visit(AST.OnScopeStatement s)
    {
        assert(0);
    }

    override void visit(AST.ConditionalStatement s)
    {
        assert(0);
    }

    override void visit(AST.PragmaStatement s)
    {
        assert(0);
    }

    override void visit(AST.SwitchStatement s)
    {
        assert(0);
    }

    override void visit(AST.CaseRangeStatement s)
    {
        assert(0);
    }

    override void visit(AST.CaseStatement s)
    {
        assert(0);
    }

    override void visit(AST.DefaultStatement s)
    {
        assert(0);
    }

    override void visit(AST.BreakStatement s)
    {
        assert(0);
    }

    override void visit(AST.ContinueStatement s)
    {
        assert(0);
    }

    override void visit(AST.GotoDefaultStatement s)
    {
        assert(0);
    }

    override void visit(AST.GotoCaseStatement s)
    {
        assert(0);
    }

    override void visit(AST.GotoStatement s)
    {
        assert(0);
    }

    override void visit(AST.SynchronizedStatement s)
    {
        assert(0);
    }

    override void visit(AST.WithStatement s)
    {
        assert(0);
    }

    override void visit(AST.TryCatchStatement s)
    {
        assert(0);
    }

    override void visit(AST.TryFinallyStatement s)
    {
        assert(0);
    }

    override void visit(AST.ThrowStatement s)
    {
        assert(0);
    }

    override void visit(AST.AsmStatement s)
    {
        assert(0);
    }

    override void visit(AST.ExpStatement s)
    {
        assert(0);
    }

    override void visit(AST.CompoundStatement s)
    {
        assert(0);
    }

    override void visit(AST.CompoundDeclarationStatement s)
    {
        assert(0);
    }

    override void visit(AST.CompoundAsmStatement s)
    {
        assert(0);
    }

    override void visit(AST.Type)
    {
        assert(0);
    }

    override void visit(AST.TypeBasic t)
    {
        assert(0);
    }

    override void visit(AST.TypeError t)
    {
        assert(0);
    }

    override void visit(AST.TypeNull t)
    {
        assert(0);
    }

    override void visit(AST.TypeVector t)
    {
        assert(0);
    }

    override void visit(AST.TypeEnum t)
    {
        assert(0);
    }

    override void visit(AST.TypeTuple t)
    {
        assert(0);
    }

    override void visit(AST.TypeClass t)
    {
        assert(0);
    }

    override void visit(AST.TypeStruct t)
    {
        assert(0);
    }

    override void visit(AST.TypeNext t)
    {
        assert(0);
    }

    override void visit(AST.TypeReference t)
    {
        assert(0);
    }

    override void visit(AST.TypeSlice t)
    {
        assert(0);
    }

    override void visit(AST.TypeDelegate t)
    {
        assert(0);
    }

    override void visit(AST.TypePointer t)
    {
        assert(0);
    }

    override void visit(AST.TypeFunction t)
    {
        assert(0);
    }

    override void visit(AST.TypeArray t)
    {
        assert(0);
    }

    override void visit(AST.TypeDArray t)
    {
        assert(0);
    }

    override void visit(AST.TypeAArray t)
    {
        assert(0);
    }

    override void visit(AST.TypeSArray t)
    {
        assert(0);
    }

    override void visit(AST.TypeQualified t)
    {
        assert(0);
    }

    override void visit(AST.TypeIdentifier t)
    {
        assert(0);
    }

    override void visit(AST.TypeReturn t)
    {
        assert(0);
    }

    override void visit(AST.TypeTypeof t)
    {
        assert(0);
    }

    override void visit(AST.TypeInstance t)
    {
        assert(0);
    }

    override void visit(AST.Expression e)
    {
        assert(0);
    }

    override void visit(AST.DeclarationExp e)
    {
        assert(0);
    }

    override void visit(AST.IntegerExp e)
    {
        assert(0);
    }

    override void visit(AST.NewAnonClassExp e)
    {
        assert(0);
    }

    override void visit(AST.IsExp e)
    {
        assert(0);
    }

    override void visit(AST.RealExp e)
    {
        assert(0);
    }

    override void visit(AST.NullExp e)
    {
        assert(0);
    }

    override void visit(AST.TypeidExp e)
    {
        assert(0);
    }

    override void visit(AST.TraitsExp e)
    {
        assert(0);
    }

    override void visit(AST.StringExp e)
    {
        assert(0);
    }

    override void visit(AST.NewExp e)
    {
        assert(0);
    }

    override void visit(AST.AssocArrayLiteralExp e)
    {
        assert(0);
    }

    override void visit(AST.ArrayLiteralExp e)
    {
        assert(0);
    }

    override void visit(AST.FuncExp e)
    {
        assert(0);
    }

    override void visit(AST.IntervalExp e)
    {
        assert(0);
    }

    override void visit(AST.TypeExp e)
    {
        assert(0);
    }

    override void visit(AST.ScopeExp e)
    {
        assert(0);
    }

    override void visit(AST.IdentifierExp e)
    {
        assert(0);
    }

    override void visit(AST.UnaExp e)
    {
        assert(0);
    }

    override void visit(AST.DefaultInitExp e)
    {
        assert(0);
    }

    override void visit(AST.BinExp e)
    {
        assert(0);
    }

    override void visit(AST.DsymbolExp e)
    {
        assert(0);
    }

    override void visit(AST.TemplateExp e)
    {
        assert(0);
    }

    override void visit(AST.SymbolExp e)
    {
        assert(0);
    }

    override void visit(AST.VarExp e)
    {
        assert(0);
    }

    override void visit(AST.TupleExp e)
    {
        assert(0);
    }

    override void visit(AST.DollarExp e)
    {
        assert(0);
    }

    override void visit(AST.ThisExp e)
    {
        assert(0);
    }

    override void visit(AST.SuperExp e)
    {
        assert(0);
    }

    override void visit(AST.AddrExp e)
    {
        assert(0);
    }

    override void visit(AST.PreExp e)
    {
        assert(0);
    }

    override void visit(AST.PtrExp e)
    {
        assert(0);
    }

    override void visit(AST.NegExp e)
    {
        assert(0);
    }

    override void visit(AST.UAddExp e)
    {
        assert(0);
    }

    override void visit(AST.NotExp e)
    {
        assert(0);
    }

    override void visit(AST.ComExp e)
    {
        assert(0);
    }

    override void visit(AST.DeleteExp e)
    {
        assert(0);
    }

    override void visit(AST.CastExp e)
    {
        assert(0);
    }

    override void visit(AST.CallExp e)
    {
        assert(0);
    }

    override void visit(AST.DotIdExp e)
    {
        assert(0);
    }

    override void visit(AST.AssertExp e)
    {
        assert(0);
    }

    override void visit(AST.CompileExp e)
    {
        assert(0);
    }

    override void visit(AST.ImportExp e)
    {
        assert(0);
    }

    override void visit(AST.DotTemplateInstanceExp e)
    {
        assert(0);
    }

    override void visit(AST.ArrayExp e)
    {
        assert(0);
    }

    override void visit(AST.FuncInitExp e)
    {
        assert(0);
    }

    override void visit(AST.PrettyFuncInitExp e)
    {
        assert(0);
    }

    override void visit(AST.FileInitExp e)
    {
        assert(0);
    }

    override void visit(AST.LineInitExp e)
    {
        assert(0);
    }

    override void visit(AST.ModuleInitExp e)
    {
        assert(0);
    }

    override void visit(AST.CommaExp e)
    {
        assert(0);
    }

    override void visit(AST.PostExp e)
    {
        assert(0);
    }

    override void visit(AST.PowExp e)
    {
        assert(0);
    }

    override void visit(AST.MulExp e)
    {
        assert(0);
    }

    override void visit(AST.DivExp e)
    {
        assert(0);
    }

    override void visit(AST.ModExp e)
    {
        assert(0);
    }

    override void visit(AST.AddExp e)
    {
        assert(0);
    }

    override void visit(AST.MinExp e)
    {
        assert(0);
    }

    override void visit(AST.CatExp e)
    {
        assert(0);
    }

    override void visit(AST.ShlExp e)
    {
        assert(0);
    }

    override void visit(AST.ShrExp e)
    {
        assert(0);
    }

    override void visit(AST.UshrExp e)
    {
        assert(0);
    }

    override void visit(AST.EqualExp e)
    {
        assert(0);
    }

    override void visit(AST.InExp e)
    {
        assert(0);
    }

    override void visit(AST.IdentityExp e)
    {
        assert(0);
    }

    override void visit(AST.CmpExp e)
    {
        assert(0);
    }

    override void visit(AST.AndExp e)
    {
        assert(0);
    }

    override void visit(AST.XorExp e)
    {
        assert(0);
    }

    override void visit(AST.OrExp e)
    {
        assert(0);
    }

    override void visit(AST.AndAndExp e)
    {
        assert(0);
    }

    override void visit(AST.OrOrExp e)
    {
        assert(0);
    }

    override void visit(AST.CondExp e)
    {
        assert(0);
    }

    override void visit(AST.AssignExp e)
    {
        assert(0);
    }

    override void visit(AST.BinAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.AddAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.MinAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.MulAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.DivAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.ModAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.PowAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.AndAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.OrAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.XorAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.ShlAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.ShrAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.UshrAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.CatAssignExp e)
    {
        assert(0);
    }

    override void visit(AST.TemplateParameter)
    {
        assert(0);
    }

    override void visit(AST.TemplateAliasParameter tp)
    {
        assert(0);
    }

    override void visit(AST.TemplateTypeParameter tp)
    {
        assert(0);
    }

    override void visit(AST.TemplateTupleParameter tp)
    {
        assert(0);
    }

    override void visit(AST.TemplateValueParameter tp)
    {
        assert(0);
    }

    override void visit(AST.TemplateThisParameter tp)
    {
        assert(0);
    }

    override void visit(AST.Condition c)
    {
        assert(0);
    }

    override void visit(AST.StaticIfCondition c)
    {
        assert(0);
    }

    override void visit(AST.DVCondition c)
    {
        assert(0);
    }

    override void visit(AST.DebugCondition c)
    {
        assert(0);
    }

    override void visit(AST.VersionCondition c)
    {
        assert(0);
    }

    override void visit(AST.Initializer)
    {
        assert(0);
    }

    override void visit(AST.ExpInitializer i)
    {
        assert(0);
    }

    override void visit(AST.StructInitializer i)
    {
        assert(0);
    }

    override void visit(AST.ArrayInitializer i)
    {
        assert(0);
    }

    override void visit(AST.VoidInitializer i)
    {
        assert(0);
    }
}

class PermissiveVisitor(AST) : Visitor!AST
{
    alias visit = Visitor!AST.visit;

    override void visit(AST.Dsymbol){}
    override void visit(AST.Parameter){}
    override void visit(AST.Statement){}
    override void visit(AST.Type){}
    override void visit(AST.Expression){}
    override void visit(AST.TemplateParameter){}
    override void visit(AST.Condition){}
    override void visit(AST.Initializer){}
}
