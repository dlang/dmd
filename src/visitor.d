// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.visitor;

import ddmd.aggregate;
import ddmd.aliasthis;
import ddmd.attrib;
import ddmd.cond;
import ddmd.ctfeexpr;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dmodule;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.dversion;
import ddmd.expression;
import ddmd.func;
import ddmd.init;
import ddmd.mtype;
import ddmd.nspace;
import ddmd.statement;
import ddmd.staticassert;

extern (C++) class Visitor
{
public:
    void visit(Statement)
    {
        assert(0);
    }

    void visit(ErrorStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(PeelStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ExpStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(DtorExpStatement s)
    {
        visit(cast(ExpStatement)s);
    }

    void visit(CompileStatement s)
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

    void visit(UnrolledLoopStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ScopeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(WhileStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(DoStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ForStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ForeachStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ForeachRangeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(IfStatement s)
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

    void visit(StaticAssertStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(SwitchStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CaseStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CaseRangeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(DefaultStatement s)
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

    void visit(SwitchErrorStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ReturnStatement s)
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

    void visit(OnScopeStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(ThrowStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(DebugStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(GotoStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(LabelStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(AsmStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(CompoundAsmStatement s)
    {
        visit(cast(CompoundStatement)s);
    }

    void visit(ImportStatement s)
    {
        visit(cast(Statement)s);
    }

    void visit(Type)
    {
        assert(0);
    }

    void visit(TypeError t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeNext t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeBasic t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeVector t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeArray t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeSArray t)
    {
        visit(cast(TypeArray)t);
    }

    void visit(TypeDArray t)
    {
        visit(cast(TypeArray)t);
    }

    void visit(TypeAArray t)
    {
        visit(cast(TypeArray)t);
    }

    void visit(TypePointer t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeReference t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeFunction t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeDelegate t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeQualified t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeIdentifier t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeInstance t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeTypeof t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeReturn t)
    {
        visit(cast(TypeQualified)t);
    }

    void visit(TypeStruct t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeEnum t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeClass t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeTuple t)
    {
        visit(cast(Type)t);
    }

    void visit(TypeSlice t)
    {
        visit(cast(TypeNext)t);
    }

    void visit(TypeNull t)
    {
        visit(cast(Type)t);
    }

    void visit(Dsymbol)
    {
        assert(0);
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

    void visit(EnumMember s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(Import s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(OverloadSet s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(LabelDsymbol s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(AliasThis s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(AttribDeclaration s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(StorageClassDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(DeprecatedDeclaration s)
    {
        visit(cast(StorageClassDeclaration)s);
    }

    void visit(LinkDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(ProtDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(AlignDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(AnonDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(PragmaDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(ConditionalDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(StaticIfDeclaration s)
    {
        visit(cast(ConditionalDeclaration)s);
    }

    void visit(CompileDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(UserAttributeDeclaration s)
    {
        visit(cast(AttribDeclaration)s);
    }

    void visit(ScopeDsymbol s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(TemplateDeclaration s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(TemplateInstance s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(TemplateMixin s)
    {
        visit(cast(TemplateInstance)s);
    }

    void visit(EnumDeclaration s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(Package s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(Module s)
    {
        visit(cast(Package)s);
    }

    void visit(WithScopeSymbol s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(ArrayScopeSymbol s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(Nspace s)
    {
        visit(cast(ScopeDsymbol)s);
    }

    void visit(AggregateDeclaration s)
    {
        visit(cast(ScopeDsymbol)s);
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

    void visit(Declaration s)
    {
        visit(cast(Dsymbol)s);
    }

    void visit(TupleDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(AliasDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(OverDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(VarDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(SymbolDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(ThisDeclaration s)
    {
        visit(cast(VarDeclaration)s);
    }

    void visit(TypeInfoDeclaration s)
    {
        visit(cast(VarDeclaration)s);
    }

    void visit(TypeInfoStructDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoClassDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoInterfaceDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoPointerDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoArrayDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoStaticArrayDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoAssociativeArrayDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoEnumDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoFunctionDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoDelegateDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoTupleDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoConstDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoInvariantDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoSharedDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoWildDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(TypeInfoVectorDeclaration s)
    {
        visit(cast(TypeInfoDeclaration)s);
    }

    void visit(FuncDeclaration s)
    {
        visit(cast(Declaration)s);
    }

    void visit(FuncAliasDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(FuncLiteralDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(CtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(PostBlitDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(DtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(StaticCtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(SharedStaticCtorDeclaration s)
    {
        visit(cast(StaticCtorDeclaration)s);
    }

    void visit(StaticDtorDeclaration s)
    {
        visit(cast(FuncDeclaration)s);
    }

    void visit(SharedStaticDtorDeclaration s)
    {
        visit(cast(StaticDtorDeclaration)s);
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
        visit(cast(FuncDeclaration)s);
    }

    void visit(Initializer)
    {
        assert(0);
    }

    void visit(VoidInitializer i)
    {
        visit(cast(Initializer)i);
    }

    void visit(ErrorInitializer i)
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

    void visit(ExpInitializer i)
    {
        visit(cast(Initializer)i);
    }

    void visit(Expression)
    {
        assert(0);
    }

    void visit(IntegerExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ErrorExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(RealExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ComplexExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(IdentifierExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(DollarExp e)
    {
        visit(cast(IdentifierExp)e);
    }

    void visit(DsymbolExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ThisExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(SuperExp e)
    {
        visit(cast(ThisExp)e);
    }

    void visit(NullExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(StringExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(TupleExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ArrayLiteralExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(AssocArrayLiteralExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(StructLiteralExp e)
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

    void visit(TemplateExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(NewExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(NewAnonClassExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(SymbolExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(SymOffExp e)
    {
        visit(cast(SymbolExp)e);
    }

    void visit(VarExp e)
    {
        visit(cast(SymbolExp)e);
    }

    void visit(OverExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(FuncExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(DeclarationExp e)
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

    void visit(HaltExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(IsExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(UnaExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(BinExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(BinAssignExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CompileExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(FileExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(AssertExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotIdExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotTemplateExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotVarExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotTemplateInstanceExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DelegateExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotTypeExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(CallExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(AddrExp e)
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

    void visit(ComExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(NotExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(BoolExp e)
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

    void visit(VectorExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(SliceExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(ArrayLengthExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(IntervalExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(DelegatePtrExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DelegateFuncptrExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(ArrayExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(DotExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CommaExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(IndexExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(PostExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(PreExp e)
    {
        visit(cast(UnaExp)e);
    }

    void visit(AssignExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(ConstructExp e)
    {
        visit(cast(AssignExp)e);
    }

    void visit(BlitExp e)
    {
        visit(cast(AssignExp)e);
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

    void visit(PowAssignExp e)
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

    void visit(PowExp e)
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

    void visit(AndExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(OrExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(XorExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(OrOrExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(AndAndExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CmpExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(InExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(RemoveExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(EqualExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(IdentityExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(CondExp e)
    {
        visit(cast(BinExp)e);
    }

    void visit(DefaultInitExp e)
    {
        visit(cast(Expression)e);
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

    void visit(FuncInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(PrettyFuncInitExp e)
    {
        visit(cast(DefaultInitExp)e);
    }

    void visit(ClassReferenceExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(VoidInitExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(ThrownExceptionExp e)
    {
        visit(cast(Expression)e);
    }

    void visit(TemplateParameter)
    {
        assert(0);
    }

    void visit(TemplateTypeParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateThisParameter tp)
    {
        visit(cast(TemplateTypeParameter)tp);
    }

    void visit(TemplateValueParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateAliasParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(TemplateTupleParameter tp)
    {
        visit(cast(TemplateParameter)tp);
    }

    void visit(Condition)
    {
        assert(0);
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

    void visit(StaticIfCondition c)
    {
        visit(cast(Condition)c);
    }

    void visit(Parameter)
    {
        assert(0);
    }
}

extern (C++) class StoppableVisitor : Visitor
{
    alias visit = super.visit;
public:
    bool stop;

    final extern (D) this()
    {
        this.stop = false;
    }
}
