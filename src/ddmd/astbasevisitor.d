module ddmd.astbasevisitor;

import ddmd.astbase;
import ddmd.tokens;
import ddmd.root.outbuffer;

import core.stdc.stdio;

alias Dsymbol                       = ASTBase.Dsymbol;
alias AliasThis                     = ASTBase.AliasThis;
alias Declaration                   = ASTBase.Declaration;
alias ScopeDsymbol                  = ASTBase.ScopeDsymbol;
alias Import                        = ASTBase.Import;
alias AttribDeclaration             = ASTBase.AttribDeclaration;
alias StaticAssert                  = ASTBase.StaticAssert;
alias DebugSymbol                   = ASTBase.DebugSymbol;
alias VersionSymbol                 = ASTBase.VersionSymbol;
alias VarDeclaration                = ASTBase.VarDeclaration;
alias FuncDeclaration               = ASTBase.FuncDeclaration;
alias AliasDeclaration              = ASTBase.AliasDeclaration;
alias TupleDeclaration              = ASTBase.TupleDeclaration;
alias FuncLiteralDeclaration        = ASTBase.FuncLiteralDeclaration;
alias PostBlitDeclaration           = ASTBase.PostBlitDeclaration;
alias CtorDeclaration               = ASTBase.CtorDeclaration;
alias DtorDeclaration               = ASTBase.DtorDeclaration;
alias InvariantDeclaration          = ASTBase.InvariantDeclaration;
alias UnitTestDeclaration           = ASTBase.UnitTestDeclaration;
alias NewDeclaration                = ASTBase.NewDeclaration;
alias DeleteDeclaration             = ASTBase.DeleteDeclaration;
alias StaticCtorDeclaration         = ASTBase.StaticCtorDeclaration;
alias StaticDtorDeclaration         = ASTBase.StaticDtorDeclaration;
alias SharedStaticCtorDeclaration   = ASTBase.SharedStaticCtorDeclaration;
alias SharedStaticDtorDeclaration   = ASTBase.SharedStaticDtorDeclaration;
alias Package                       = ASTBase.Package;
alias EnumDeclaration               = ASTBase.EnumDeclaration;
alias AggregateDeclaration          = ASTBase.AggregateDeclaration;
alias TemplateDeclaration           = ASTBase.TemplateDeclaration;
alias TemplateInstance              = ASTBase.TemplateInstance;
alias Nspace                        = ASTBase.Nspace;
alias CompileDeclaration            = ASTBase.CompileDeclaration;
alias UserAttributeDeclaration      = ASTBase.UserAttributeDeclaration;
alias LinkDeclaration               = ASTBase.LinkDeclaration;
alias AnonDeclaration               = ASTBase.AnonDeclaration;
alias AlignDeclaration              = ASTBase.AlignDeclaration;
alias CPPMangleDeclaration          = ASTBase.CPPMangleDeclaration;
alias ProtDeclaration               = ASTBase.ProtDeclaration;
alias PragmaDeclaration             = ASTBase.PragmaDeclaration;
alias StorageClassDeclaration       = ASTBase.StorageClassDeclaration;
alias ConditionalDeclaration        = ASTBase.ConditionalDeclaration;
alias DeprecatedDeclaration         = ASTBase.DeprecatedDeclaration;
alias StaticIfDeclaration           = ASTBase.StaticIfDeclaration;
alias EnumMember                    = ASTBase.EnumMember;
alias Module                        = ASTBase.Module;
alias StructDeclaration             = ASTBase.StructDeclaration;
alias UnionDeclaration              = ASTBase.UnionDeclaration;
alias ClassDeclaration              = ASTBase.ClassDeclaration;
alias InterfaceDeclaration          = ASTBase.InterfaceDeclaration;
alias TemplateMixin                 = ASTBase.TemplateMixin;
alias Parameter                     = ASTBase.Parameter;
alias Statement                     = ASTBase.Statement;
alias ImportStatement               = ASTBase.ImportStatement;
alias ScopeStatement                = ASTBase.ScopeStatement;
alias ReturnStatement               = ASTBase.ReturnStatement;
alias LabelStatement                = ASTBase.LabelStatement;
alias StaticAssertStatement         = ASTBase.StaticAssertStatement;
alias CompileStatement              = ASTBase.CompileStatement;
alias WhileStatement                = ASTBase.WhileStatement;
alias ForStatement                  = ASTBase.ForStatement;
alias DoStatement                   = ASTBase.DoStatement;
alias ForeachRangeStatement         = ASTBase.ForeachRangeStatement;
alias ForeachStatement              = ASTBase.ForeachStatement;
alias IfStatement                   = ASTBase.IfStatement;
alias OnScopeStatement              = ASTBase.OnScopeStatement;
alias ConditionalStatement          = ASTBase.ConditionalStatement;
alias PragmaStatement               = ASTBase.PragmaStatement;
alias SwitchStatement               = ASTBase.SwitchStatement;
alias CaseRangeStatement            = ASTBase.CaseRangeStatement;
alias CaseStatement                 = ASTBase.CaseStatement;
alias DefaultStatement              = ASTBase.DefaultStatement;
alias BreakStatement                = ASTBase.BreakStatement;
alias ContinueStatement             = ASTBase.ContinueStatement;
alias GotoDefaultStatement          = ASTBase.GotoDefaultStatement;
alias GotoCaseStatement             = ASTBase.GotoCaseStatement;
alias GotoStatement                 = ASTBase.GotoStatement;
alias SynchronizedStatement         = ASTBase.SynchronizedStatement;
alias WithStatement                 = ASTBase.WithStatement;
alias TryCatchStatement             = ASTBase.TryCatchStatement;
alias TryFinallyStatement           = ASTBase.TryFinallyStatement;
alias ThrowStatement                = ASTBase.ThrowStatement;
alias AsmStatement                  = ASTBase.AsmStatement;
alias ExpStatement                  = ASTBase.ExpStatement;
alias CompoundStatement             = ASTBase.CompoundStatement;
alias CompoundDeclarationStatement  = ASTBase.CompoundDeclarationStatement;
alias CompoundAsmStatement          = ASTBase.CompoundAsmStatement;
alias Type                          = ASTBase.Type;
alias TypeBasic                     = ASTBase.TypeBasic;
alias TypeError                     = ASTBase.TypeError;
alias TypeNull                      = ASTBase.TypeNull;
alias TypeVector                    = ASTBase.TypeVector;
alias TypeEnum                      = ASTBase.TypeEnum;
alias TypeTuple                     = ASTBase.TypeTuple;
alias TypeClass                     = ASTBase.TypeClass;
alias TypeStruct                    = ASTBase.TypeStruct;
alias TypeNext                      = ASTBase.TypeNext;
alias TypeReference                 = ASTBase.TypeReference;
alias TypeSlice                     = ASTBase.TypeSlice;
alias TypeDelegate                  = ASTBase.TypeDelegate;
alias TypePointer                   = ASTBase.TypePointer;
alias TypeFunction                  = ASTBase.TypeFunction;
alias TypeArray                     = ASTBase.TypeArray;
alias TypeDArray                    = ASTBase.TypeDArray;
alias TypeAArray                    = ASTBase.TypeAArray;
alias TypeSArray                    = ASTBase.TypeSArray;
alias TypeQualified                 = ASTBase.TypeQualified;
alias TypeIdentifier                = ASTBase.TypeIdentifier;
alias TypeTypeof                    = ASTBase.TypeTypeof;
alias TypeInstance                  = ASTBase.TypeInstance;
alias TypeReturn                    = ASTBase.TypeReturn;
alias Expression                    = ASTBase.Expression;
alias DeclarationExp                = ASTBase.DeclarationExp;
alias IntegerExp                    = ASTBase.IntegerExp;
alias NewAnonClassExp               = ASTBase.NewAnonClassExp;
alias IsExp                         = ASTBase.IsExp;
alias RealExp                       = ASTBase.RealExp;
alias NullExp                       = ASTBase.NullExp;
alias TypeidExp                     = ASTBase.TypeidExp;
alias TraitsExp                     = ASTBase.TraitsExp;
alias StringExp                     = ASTBase.StringExp;
alias NewExp                        = ASTBase.NewExp;
alias AssocArrayLiteralExp          = ASTBase.AssocArrayLiteralExp;
alias ArrayLiteralExp               = ASTBase.ArrayLiteralExp;
alias FuncExp                       = ASTBase.FuncExp;
alias IntervalExp                   = ASTBase.IntervalExp;
alias TypeExp                       = ASTBase.TypeExp;
alias ScopeExp                      = ASTBase.ScopeExp;
alias IdentifierExp                 = ASTBase.IdentifierExp;
alias UnaExp                        = ASTBase.UnaExp;
alias DefaultInitExp                = ASTBase.DefaultInitExp;
alias BinExp                        = ASTBase.BinExp;
alias DsymbolExp                    = ASTBase.DsymbolExp;
alias TemplateExp                   = ASTBase.TemplateExp;
alias SymbolExp                     = ASTBase.SymbolExp;
alias VarExp                        = ASTBase.VarExp;
alias TupleExp                      = ASTBase.TupleExp;
alias DollarExp                     = ASTBase.DollarExp;
alias ThisExp                       = ASTBase.ThisExp;
alias SuperExp                      = ASTBase.SuperExp;
alias AddrExp                       = ASTBase.AddrExp;
alias PreExp                        = ASTBase.PreExp;
alias PtrExp                        = ASTBase.PtrExp;
alias NegExp                        = ASTBase.NegExp;
alias UAddExp                       = ASTBase.UAddExp;
alias NotExp                        = ASTBase.NotExp;
alias ComExp                        = ASTBase.ComExp;
alias DeleteExp                     = ASTBase.DeleteExp;
alias CastExp                       = ASTBase.CastExp;
alias CallExp                       = ASTBase.CallExp;
alias DotIdExp                      = ASTBase.DotIdExp;
alias AssertExp                     = ASTBase.AssertExp;
alias CompileExp                    = ASTBase.CompileExp;
alias ImportExp                     = ASTBase.ImportExp;
alias DotTemplateInstanceExp        = ASTBase.DotTemplateInstanceExp;
alias ArrayExp                      = ASTBase.ArrayExp;
alias FuncInitExp                   = ASTBase.FuncInitExp;
alias PrettyFuncInitExp             = ASTBase.PrettyFuncInitExp;
alias FileInitExp                   = ASTBase.FileInitExp;
alias LineInitExp                   = ASTBase.LineInitExp;
alias ModuleInitExp                 = ASTBase.ModuleInitExp;
alias CommaExp                      = ASTBase.CommaExp;
alias PostExp                       = ASTBase.PostExp;
alias PowExp                        = ASTBase.PowExp;
alias MulExp                        = ASTBase.MulExp;
alias DivExp                        = ASTBase.DivExp;
alias ModExp                        = ASTBase.ModExp;
alias AddExp                        = ASTBase.AddExp;
alias MinExp                        = ASTBase.MinExp;
alias CatExp                        = ASTBase.CatExp;
alias ShlExp                        = ASTBase.ShlExp;
alias ShrExp                        = ASTBase.ShrExp;
alias UshrExp                       = ASTBase.UshrExp;
alias EqualExp                      = ASTBase.EqualExp;
alias InExp                         = ASTBase.InExp;
alias IdentityExp                   = ASTBase.IdentityExp;
alias CmpExp                        = ASTBase.CmpExp;
alias XorExp                        = ASTBase.XorExp;
alias OrExp                         = ASTBase.OrExp;
alias AndExp                        = ASTBase.AndExp;
alias OrOrExp                       = ASTBase.OrOrExp;
alias AndAndExp                     = ASTBase.AndAndExp;
alias CondExp                       = ASTBase.CondExp;
alias AssignExp                     = ASTBase.AssignExp;
alias BinAssignExp                  = ASTBase.BinAssignExp;
alias AddAssignExp                  = ASTBase.AddAssignExp;
alias MinAssignExp                  = ASTBase.MinAssignExp;
alias MulAssignExp                  = ASTBase.MulAssignExp;
alias DivAssignExp                  = ASTBase.DivAssignExp;
alias ModAssignExp                  = ASTBase.ModAssignExp;
alias PowAssignExp                  = ASTBase.PowAssignExp;
alias AndAssignExp                  = ASTBase.AndAssignExp;
alias OrAssignExp                   = ASTBase.OrAssignExp;
alias XorAssignExp                  = ASTBase.XorAssignExp;
alias ShlAssignExp                  = ASTBase.ShlAssignExp;
alias ShrAssignExp                  = ASTBase.ShrAssignExp;
alias UshrAssignExp                 = ASTBase.UshrAssignExp;
alias CatAssignExp                  = ASTBase.CatAssignExp;
alias TemplateParameter             = ASTBase.TemplateParameter;
alias TemplateAliasParameter        = ASTBase.TemplateAliasParameter;
alias TemplateTypeParameter         = ASTBase.TemplateTypeParameter;
alias TemplateTupleParameter        = ASTBase.TemplateTupleParameter;
alias TemplateValueParameter        = ASTBase.TemplateValueParameter;
alias TemplateThisParameter         = ASTBase.TemplateThisParameter;
alias Condition                     = ASTBase.Condition;
alias StaticIfCondition             = ASTBase.StaticIfCondition;
alias DVCondition                   = ASTBase.DVCondition;
alias DebugCondition                = ASTBase.DebugCondition;
alias VersionCondition              = ASTBase.VersionCondition;
alias Initializer                   = ASTBase.Initializer;
alias ExpInitializer                = ASTBase.ExpInitializer;
alias StructInitializer             = ASTBase.StructInitializer;
alias ArrayInitializer              = ASTBase.ArrayInitializer;
alias VoidInitializer               = ASTBase.VoidInitializer;
alias Dsymbols                      = ASTBase.Dsymbols;
alias Catch                         = ASTBase.Catch;

class Visitor
{
    void visit(Dsymbol)
    {
        assert(0);
    }

    void visit(AliasThis s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(Declaration s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(ScopeDsymbol s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(Import s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(AttribDeclaration s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(StaticAssert s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(DebugSymbol s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(VersionSymbol s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(VarDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(FuncDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(AliasDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(TupleDeclaration s)
    {
        visit(cast(Declaration) s);
    }

    void visit(FuncLiteralDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(PostBlitDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(CtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(DtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(InvariantDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(UnitTestDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(NewDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(DeleteDeclaration s)
    {
        visit(cast(FuncDeclaration) s);
    }

    void visit(StaticCtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(StaticDtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(SharedStaticCtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(SharedStaticDtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(Package s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(EnumDeclaration s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(AggregateDeclaration s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(TemplateDeclaration s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(TemplateInstance s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(Nspace s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(CompileDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(UserAttributeDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(LinkDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(AnonDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(AlignDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(CPPMangleDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(ProtDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(PragmaDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(StorageClassDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(ConditionalDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(DeprecatedDeclaration s)
    {
        visit(cast(StorageClassDeclaration)s);
    }

    void visit(StaticIfDeclaration s)
    {
        visit(cast(ConditionalDeclaration)s);
    }

    void visit(EnumMember s)
    {
        visit(cast(VarDeclaration)s);
    }

    void visit(Module s)
    {
        visit(cast(Package)s);
    }

    void visit(StructDeclaration s)
    {
        visit(cast(AggregateDeclaration)s);
    }

    void visit(UnionDeclaration s)
    {
        visit(cast(StructDeclaration)s);
    }

    void visit(ClassDeclaration s)
    {
        visit(cast(AggregateDeclaration)s);
    }

    void visit(InterfaceDeclaration s)
    {
        visit(cast(ClassDeclaration)s);
    }

    void visit(TemplateMixin s)
    {
        visit(cast(TemplateInstance)s);
    }

    void visit(Parameter)
    {
        assert(0);
    }

    void visit(Statement)
    {
        assert(0);
    }

    void visit(ImportStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ScopeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ReturnStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(LabelStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(StaticAssertStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CompileStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(WhileStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ForStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(DoStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ForeachRangeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ForeachStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(IfStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(OnScopeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ConditionalStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(PragmaStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(SwitchStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CaseRangeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CaseStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(DefaultStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(BreakStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ContinueStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(GotoDefaultStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(GotoCaseStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(GotoStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(SynchronizedStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(WithStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(TryCatchStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(TryFinallyStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ThrowStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(AsmStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ExpStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CompoundStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CompoundDeclarationStatement s)
    {
        visit(cast(CompoundStatement)s);
    }

    void visit(CompoundAsmStatement s)
    {
        visit(cast(CompoundStatement)s);
    }

    void visit(Type)
    {
        assert(0);
    }

    void visit(TypeBasic t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeError t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeNull t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeVector t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeEnum t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeTuple t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeClass t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeStruct t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeNext t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeReference t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeSlice t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeDelegate t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypePointer t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeFunction t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeArray t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeDArray t)
    {
        visit(cast(TypeArray)t);
    }

    void visit(TypeAArray t)
    {
        visit(cast(TypeArray)t);
    }

    void visit(TypeSArray t)
    {
        visit(cast(TypeArray)t);
    }

    void visit(TypeQualified t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeIdentifier t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeReturn t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeTypeof t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeInstance t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(Expression e)
    {
        assert(0);
    }

    void visit(DeclarationExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(IntegerExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(NewAnonClassExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(IsExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(RealExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(NullExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(TypeidExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(TraitsExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(StringExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(NewExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(AssocArrayLiteralExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ArrayLiteralExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(FuncExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(IntervalExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(TypeExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ScopeExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(IdentifierExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(UnaExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(DefaultInitExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(BinExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(DsymbolExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(TemplateExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(SymbolExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(VarExp e)
    {
        visit(cast(SymbolExp)e);
    }

    void visit(TupleExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(DollarExp e)
    {
        visit(cast(IdentifierExp)e);
    }

    void visit(ThisExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(SuperExp e)
    {
        visit(cast(ThisExp)e);
    }

    void visit(AddrExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(PreExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(PtrExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(NegExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(UAddExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(NotExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(ComExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DeleteExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(CastExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(CallExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotIdExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(AssertExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(CompileExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(ImportExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotTemplateInstanceExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(ArrayExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(FuncInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(PrettyFuncInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(FileInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(LineInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(ModuleInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(CommaExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(PostExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(PowExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(MulExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(DivExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(ModExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(AddExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(MinExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CatExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(ShlExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(ShrExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(UshrExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(EqualExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(InExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(IdentityExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CmpExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(AndExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(XorExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(OrExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(AndAndExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(OrOrExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CondExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(AssignExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(BinAssignExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(AddAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(MinAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(MulAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(DivAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(ModAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(PowAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(AndAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(OrAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(XorAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(ShlAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(ShrAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(UshrAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(CatAssignExp e)
    {
        visit(cast(BinAssignExp)e);
    }

    void visit(TemplateParameter)
    {
        assert(0);
    }

    void visit(TemplateAliasParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateTypeParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateTupleParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateValueParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateThisParameter tp)
    {
        visit(cast(TemplateTypeParameter)tp);
    }

    void visit(Condition c)
    {
        assert(0);
    }

    void visit(StaticIfCondition c)
    {
        visit(cast(Condition)c);
    }

    void visit(DVCondition c)
    {
        visit(cast(Condition)c);
    }

    void visit(DebugCondition c)
    {
        visit(cast(DVCondition)c);
    }

    void visit(VersionCondition c)
    {
        visit(cast(DVCondition)c);
    }

    void visit(Initializer)
    {
        assert(0);
    }

    void visit(ExpInitializer i)
    {
        visit(cast(Initializer)i);
    }

    void visit(StructInitializer i)
    {
        visit(cast(Initializer)i);
    }

    void visit(ArrayInitializer i)
    {
        visit(cast(Initializer)i);
    }

    void visit(VoidInitializer i)
    {
        visit(cast(Initializer)i);
    }
}

class ImportVisitor : Visitor
{
    alias visit = super.visit;
    OutBuffer* buf;

    this(OutBuffer* buf)
    {
        this.buf = buf;
    }

    void visitModuleMembers(Dsymbols* members)
    {
        foreach (s; *members)
        {
            s.accept(this);
        }
    }

    override void visit(Import i)
    {
        buf.printf("%s", i.toChars());
    }

    override void visit(ImportStatement s)
    {
            foreach (imp; *s.imports)
            {
                imp.accept(this);
            }
    }

    override void visit(FuncDeclaration fd)
    {
        fd.fbody.accept(this);
    }

    override void visit(ClassDeclaration cd)
    {
        foreach (mem; *cd.members)
        {
            mem.accept(this);
        }
    }

    override void visit(StructDeclaration sd)
    {
        foreach (mem; *sd.members)
        {
            mem.accept(this);
        }
    }

    override void visit(CompoundStatement s)
    {
        foreach (sx; *s.statements)
        {
            sx.accept(this);
        }
    }

    override void visit(ExpStatement s)
    {
        if (s.exp && s.exp.op == TOKdeclaration)
            (cast(DeclarationExp)s.exp).declaration.accept(this);
    }

    override void visit(IfStatement s)
    {
        if (s.ifbody)
            s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    override void visit(ScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(WhileStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(DoStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ForStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ForeachStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(SwitchStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(CaseStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(DefaultStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(SynchronizedStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(WithStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(TryCatchStatement s)
    {
        if (s._body)
            s._body.accept(this);

        foreach (c; *s.catches)
        {
            visit(c);
        }
    }

    void visit(Catch c)
    {
        if (c.handler)
            c.handler.accept(this);
    }

    override void visit(TryFinallyStatement s)
    {
        s._body.accept(this);
        s.finalbody.accept(this);
    }

    override void visit(OnScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(LabelStatement s)
    {
         if (s.statement)
            s.statement.accept(this);
    }
}
