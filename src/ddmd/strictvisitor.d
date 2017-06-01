module ddmd.strictvisitor;

import ddmd.astbase;
import ddmd.astbasevisitor;

class StrictVisitor : Visitor
{
    alias visit = super.visit;

    override void visit(ASTBase.Dsymbol)
    {
        assert(0);
    }

    override void visit(ASTBase.AliasThis s)
    {
        assert(0);
    }

    override void visit(ASTBase.Declaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.ScopeDsymbol s)
    {
        assert(0);
    }

    override void visit(ASTBase.Import s)
    {
        assert(0);
    }

    override void visit(ASTBase.AttribDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.StaticAssert s)
    {
        assert(0);
    }

    override void visit(ASTBase.DebugSymbol s)
    {
        assert(0);
    }

    override void visit(ASTBase.VersionSymbol s)
    {
        assert(0);
    }

    override void visit(ASTBase.VarDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.FuncDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.AliasDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.TupleDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.FuncLiteralDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.PostBlitDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.CtorDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.DtorDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.InvariantDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.UnitTestDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.NewDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.DeleteDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.StaticCtorDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.StaticDtorDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.SharedStaticCtorDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.SharedStaticDtorDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.Package s)
    {
        assert(0);
    }

    override void visit(ASTBase.EnumDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.AggregateDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateInstance s)
    {
        assert(0);
    }

    override void visit(ASTBase.Nspace s)
    {
        assert(0);
    }

    override void visit(ASTBase.CompileDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.UserAttributeDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.LinkDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.AnonDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.AlignDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.CPPMangleDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.ProtDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.PragmaDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.StorageClassDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.ConditionalDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.DeprecatedDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.StaticIfDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.EnumMember s)
    {
        assert(0);
    }

    override void visit(ASTBase.Module s)
    {
        assert(0);
    }

    override void visit(ASTBase.StructDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.UnionDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.ClassDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.InterfaceDeclaration s)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateMixin s)
    {
        assert(0);
    }

    override void visit(ASTBase.Parameter)
    {
        assert(0);
    }

    override void visit(ASTBase.Statement)
    {
        assert(0);
    }

    override void visit(ASTBase.ImportStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ScopeStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ReturnStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.LabelStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.StaticAssertStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.CompileStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.WhileStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ForStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.DoStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ForeachRangeStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ForeachStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.IfStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.OnScopeStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ConditionalStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.PragmaStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.SwitchStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.CaseRangeStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.CaseStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.DefaultStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.BreakStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ContinueStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.GotoDefaultStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.GotoCaseStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.GotoStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.SynchronizedStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.WithStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.TryCatchStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.TryFinallyStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ThrowStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.AsmStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.ExpStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.CompoundStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.CompoundDeclarationStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.CompoundAsmStatement s)
    {
        assert(0);
    }

    override void visit(ASTBase.Type)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeBasic t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeError t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeNull t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeVector t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeEnum t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeTuple t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeClass t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeStruct t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeNext t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeReference t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeSlice t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeDelegate t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypePointer t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeFunction t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeArray t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeDArray t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeAArray t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeSArray t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeQualified t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeIdentifier t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeReturn t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeTypeof t)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeInstance t)
    {
        assert(0);
    }

    override void visit(ASTBase.Expression e)
    {
        assert(0);
    }

    override void visit(ASTBase.DeclarationExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.IntegerExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.NewAnonClassExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.IsExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.RealExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.NullExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeidExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.TraitsExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.StringExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.NewExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AssocArrayLiteralExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ArrayLiteralExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.FuncExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.IntervalExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.TypeExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ScopeExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.IdentifierExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.UnaExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DefaultInitExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.BinExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DsymbolExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.SymbolExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.VarExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.TupleExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DollarExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ThisExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.SuperExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AddrExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.PreExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.PtrExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.NegExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.UAddExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.NotExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ComExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DeleteExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CastExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CallExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DotIdExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AssertExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CompileExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ImportExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DotTemplateInstanceExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ArrayExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.FuncInitExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.PrettyFuncInitExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.FileInitExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.LineInitExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ModuleInitExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CommaExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.PostExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.PowExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.MulExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DivExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ModExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AddExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.MinExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CatExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ShlExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ShrExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.UshrExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.EqualExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.InExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.IdentityExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CmpExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AndExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.XorExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.OrExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AndAndExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.OrOrExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CondExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.BinAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AddAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.MinAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.MulAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.DivAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ModAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.PowAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.AndAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.OrAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.XorAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ShlAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.ShrAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.UshrAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.CatAssignExp e)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateParameter)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateAliasParameter tp)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateTypeParameter tp)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateTupleParameter tp)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateValueParameter tp)
    {
        assert(0);
    }

    override void visit(ASTBase.TemplateThisParameter tp)
    {
        assert(0);
    }

    override void visit(ASTBase.Condition c)
    {
        assert(0);
    }

    override void visit(ASTBase.StaticIfCondition c)
    {
        assert(0);
    }

    override void visit(ASTBase.DVCondition c)
    {
        assert(0);
    }

    override void visit(ASTBase.DebugCondition c)
    {
        assert(0);
    }

    override void visit(ASTBase.VersionCondition c)
    {
        assert(0);
    }

    override void visit(ASTBase.Initializer)
    {
        assert(0);
    }

    override void visit(ASTBase.ExpInitializer i)
    {
        assert(0);
    }

    override void visit(ASTBase.StructInitializer i)
    {
        assert(0);
    }

    override void visit(ASTBase.ArrayInitializer i)
    {
        assert(0);
    }

    override void visit(ASTBase.VoidInitializer i)
    {
        assert(0);
    }
}
