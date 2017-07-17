module ddmd.astbasevisitor;

import ddmd.astbase;

/** Basic and dumm visitor which implements a visit method for each AST node
  * implemented in ASTBase. This visitor is the parent of strict, transitive
  * and permissive visitors.
  */
class Visitor
{
    void visit(ASTBase.Dsymbol) { assert(0); }
    void visit(ASTBase.Parameter) { assert(0); }
    void visit(ASTBase.Statement) { assert(0); }
    void visit(ASTBase.Type) { assert(0); }
    void visit(ASTBase.Expression) { assert(0); }
    void visit(ASTBase.TemplateParameter) { assert(0); }
    void visit(ASTBase.Condition) { assert(0); }
    void visit(ASTBase.StaticForeach) { assert(0); }
    void visit(ASTBase.Initializer) { assert(0); }

    //=======================================================================================
    // Dsymbols
    void visit(ASTBase.AliasThis s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.Declaration s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.ScopeDsymbol s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.Import s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.AttribDeclaration s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.StaticAssert s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.DebugSymbol s) { visit(cast(ASTBase.Dsymbol)s); }
    void visit(ASTBase.VersionSymbol s) { visit(cast(ASTBase.Dsymbol)s); }

    // ScopeDsymbols
    void visit(ASTBase.Package s) { visit(cast(ASTBase.ScopeDsymbol)s); }
    void visit(ASTBase.EnumDeclaration s) { visit(cast(ASTBase.ScopeDsymbol)s); }
    void visit(ASTBase.AggregateDeclaration s) { visit(cast(ASTBase.ScopeDsymbol)s); }
    void visit(ASTBase.TemplateDeclaration s) { visit(cast(ASTBase.ScopeDsymbol)s); }
    void visit(ASTBase.TemplateInstance s) { visit(cast(ASTBase.ScopeDsymbol)s); }
    void visit(ASTBase.Nspace s) { visit(cast(ASTBase.ScopeDsymbol)s); }

    //=========================================================================================
    // Declarations
    void visit(ASTBase.VarDeclaration s) { visit(cast(ASTBase.Declaration)s); }
    void visit(ASTBase.FuncDeclaration s) { visit(cast(ASTBase.Declaration)s); }
    void visit(ASTBase.AliasDeclaration s) { visit(cast(ASTBase.Declaration)s); }
    void visit(ASTBase.TupleDeclaration s) { visit(cast(ASTBase.Declaration)s); }

    // FuncDeclarations
    void visit(ASTBase.FuncLiteralDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.PostBlitDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.CtorDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.DtorDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.InvariantDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.UnitTestDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.NewDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.DeleteDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.StaticCtorDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.StaticDtorDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.SharedStaticCtorDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }
    void visit(ASTBase.SharedStaticDtorDeclaration s) { visit(cast(ASTBase.FuncDeclaration)s); }

    // AttribDeclarations
    void visit(ASTBase.CompileDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.UserAttributeDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.LinkDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.AnonDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.AlignDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.CPPMangleDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.ProtDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.PragmaDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.StorageClassDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }
    void visit(ASTBase.ConditionalDeclaration s) { visit(cast(ASTBase.AttribDeclaration)s); }

    //==============================================================================================
    // Miscellaneous
    void visit(ASTBase.DeprecatedDeclaration s) { visit(cast(ASTBase.StorageClassDeclaration)s); }
    void visit(ASTBase.StaticIfDeclaration s) { visit(cast(ASTBase.ConditionalDeclaration)s); }
    void visit(ASTBase.StaticForeachDeclaration s) { visit(cast(ASTBase.ConditionalDeclaration)s); }
    void visit(ASTBase.EnumMember s) { visit(cast(ASTBase.VarDeclaration)s); }
    void visit(ASTBase.Module s) { visit(cast(ASTBase.Package)s); }
    void visit(ASTBase.StructDeclaration s) { visit(cast(ASTBase.AggregateDeclaration)s); }
    void visit(ASTBase.UnionDeclaration s) { visit(cast(ASTBase.StructDeclaration)s); }
    void visit(ASTBase.ClassDeclaration s) { visit(cast(ASTBase.AggregateDeclaration)s); }
    void visit(ASTBase.InterfaceDeclaration s) { visit(cast(ASTBase.ClassDeclaration)s); }
    void visit(ASTBase.TemplateMixin s) { visit(cast(ASTBase.TemplateInstance)s); }

    //============================================================================================
    // Statements
    void visit(ASTBase.ImportStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ScopeStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ReturnStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.LabelStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.StaticAssertStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.CompileStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.WhileStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ForStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.DoStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ForeachRangeStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ForeachStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.IfStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.OnScopeStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ConditionalStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.StaticForeachStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.PragmaStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.SwitchStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.CaseRangeStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.CaseStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.DefaultStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.BreakStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ContinueStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.GotoDefaultStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.GotoCaseStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.GotoStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.SynchronizedStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.WithStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.TryCatchStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.TryFinallyStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ThrowStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.AsmStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.ExpStatement s) { visit(cast(ASTBase.Statement)s); }
    void visit(ASTBase.CompoundStatement s) { visit(cast(ASTBase.Statement)s); }

    // CompoundStatements
    void visit(ASTBase.CompoundDeclarationStatement s) { visit(cast(ASTBase.CompoundStatement)s); }
    void visit(ASTBase.CompoundAsmStatement s) { visit(cast(ASTBase.CompoundStatement)s); }

    //=========================================================================================
    // Types
    void visit(ASTBase.TypeBasic t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeError t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeNull t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeVector t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeEnum t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeTuple t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeClass t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeStruct t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeNext t) { visit(cast(ASTBase.Type)t); }
    void visit(ASTBase.TypeQualified t) { visit(cast(ASTBase.Type)t); }

    // TypeNext
    void visit(ASTBase.TypeReference t) { visit(cast(ASTBase.TypeNext)t); }
    void visit(ASTBase.TypeSlice t) { visit(cast(ASTBase.TypeNext)t); }
    void visit(ASTBase.TypeDelegate t) { visit(cast(ASTBase.TypeNext)t); }
    void visit(ASTBase.TypePointer t) { visit(cast(ASTBase.TypeNext)t); }
    void visit(ASTBase.TypeFunction t) { visit(cast(ASTBase.TypeNext)t); }
    void visit(ASTBase.TypeArray t) { visit(cast(ASTBase.TypeNext)t); }

    // TypeArray
    void visit(ASTBase.TypeDArray t) { visit(cast(ASTBase.TypeArray)t); }
    void visit(ASTBase.TypeAArray t) { visit(cast(ASTBase.TypeArray)t); }
    void visit(ASTBase.TypeSArray t) { visit(cast(ASTBase.TypeArray)t); }

    // TypeQualified
    void visit(ASTBase.TypeIdentifier t) { visit(cast(ASTBase.TypeQualified)t); }
    void visit(ASTBase.TypeReturn t) { visit(cast(ASTBase.TypeQualified)t); }
    void visit(ASTBase.TypeTypeof t) { visit(cast(ASTBase.TypeQualified)t); }
    void visit(ASTBase.TypeInstance t) { visit(cast(ASTBase.TypeQualified)t); }

    //=================================================================================
    // Expressions
    void visit(ASTBase.DeclarationExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.IntegerExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.NewAnonClassExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.IsExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.RealExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.NullExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.TypeidExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.TraitsExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.StringExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.NewExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.AssocArrayLiteralExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.ArrayLiteralExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.FuncExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.IntervalExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.TypeExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.ScopeExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.IdentifierExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.UnaExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.DefaultInitExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.BinExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.DsymbolExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.TemplateExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.SymbolExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.TupleExp e) { visit(cast(ASTBase.Expression)e); }
    void visit(ASTBase.ThisExp e) { visit(cast(ASTBase.Expression)e); }

    // Miscellaneous
    void visit(ASTBase.VarExp e) { visit(cast(ASTBase.SymbolExp)e); }
    void visit(ASTBase.DollarExp e) { visit(cast(ASTBase.IdentifierExp)e); }
    void visit(ASTBase.SuperExp e) { visit(cast(ASTBase.ThisExp)e); }

    // UnaExp
    void visit(ASTBase.AddrExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.PreExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.PtrExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.NegExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.UAddExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.NotExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.ComExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.DeleteExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.CastExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.CallExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.DotIdExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.AssertExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.CompileExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.ImportExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.DotTemplateInstanceExp e) { visit(cast(ASTBase.UnaExp)e); }
    void visit(ASTBase.ArrayExp e) { visit(cast(ASTBase.UnaExp)e); }

    // DefaultInitExp
    void visit(ASTBase.FuncInitExp e) { visit(cast(ASTBase.DefaultInitExp)e); }
    void visit(ASTBase.PrettyFuncInitExp e) { visit(cast(ASTBase.DefaultInitExp)e); }
    void visit(ASTBase.FileInitExp e) { visit(cast(ASTBase.DefaultInitExp)e); }
    void visit(ASTBase.LineInitExp e) { visit(cast(ASTBase.DefaultInitExp)e); }
    void visit(ASTBase.ModuleInitExp e) { visit(cast(ASTBase.DefaultInitExp)e); }

    // BinExp
    void visit(ASTBase.CommaExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.PostExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.PowExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.MulExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.DivExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.ModExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.AddExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.MinExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.CatExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.ShlExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.ShrExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.UshrExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.EqualExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.InExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.IdentityExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.CmpExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.AndExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.XorExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.OrExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.AndAndExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.OrOrExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.CondExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.AssignExp e) { visit(cast(ASTBase.BinExp)e); }
    void visit(ASTBase.BinAssignExp e) { visit(cast(ASTBase.BinExp)e); }

    // BinAssignExp
    void visit(ASTBase.AddAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.MinAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.MulAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.DivAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.ModAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.PowAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.AndAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.OrAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.XorAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.ShlAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.ShrAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.UshrAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }
    void visit(ASTBase.CatAssignExp e) { visit(cast(ASTBase.BinAssignExp)e); }

    //===============================================================================
    // TemplateParameter
    void visit(ASTBase.TemplateAliasParameter tp) { visit(cast(ASTBase.TemplateParameter)tp); }
    void visit(ASTBase.TemplateTypeParameter tp) { visit(cast(ASTBase.TemplateParameter)tp); }
    void visit(ASTBase.TemplateTupleParameter tp) { visit(cast(ASTBase.TemplateParameter)tp); }
    void visit(ASTBase.TemplateValueParameter tp) { visit(cast(ASTBase.TemplateParameter)tp); }

    void visit(ASTBase.TemplateThisParameter tp) { visit(cast(ASTBase.TemplateTypeParameter)tp); }

    //===============================================================================
    // Condition
    void visit(ASTBase.StaticIfCondition c) { visit(cast(ASTBase.Condition)c); }
    void visit(ASTBase.DVCondition c) { visit(cast(ASTBase.Condition)c); }
    void visit(ASTBase.DebugCondition c) { visit(cast(ASTBase.DVCondition)c); }
    void visit(ASTBase.VersionCondition c) { visit(cast(ASTBase.DVCondition)c); }

    //===============================================================================
    // Initializer
    void visit(ASTBase.ExpInitializer i) { visit(cast(ASTBase.Initializer)i); }
    void visit(ASTBase.StructInitializer i) { visit(cast(ASTBase.Initializer)i); }
    void visit(ASTBase.ArrayInitializer i) { visit(cast(ASTBase.Initializer)i); }
    void visit(ASTBase.VoidInitializer i) { visit(cast(ASTBase.Initializer)i); }
}
