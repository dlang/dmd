
#ifndef DMD_VISITOR_H
#define DMD_VISITOR_H

#include <assert.h>

class Statement;
class ErrorStatement;
class PeelStatement;
class ExpStatement;
class DtorExpStatement;
class CompileStatement;
class CompoundStatement;
class CompoundDeclarationStatement;
class UnrolledLoopStatement;
class ScopeStatement;
class WhileStatement;
class DoStatement;
class ForStatement;
class ForeachStatement;
class ForeachRangeStatement;
class IfStatement;
class ConditionalStatement;
class PragmaStatement;
class StaticAssertStatement;
class SwitchStatement;
class CaseStatement;
class CaseRangeStatement;
class DefaultStatement;
class GotoDefaultStatement;
class GotoCaseStatement;
class SwitchErrorStatement;
class ReturnStatement;
class BreakStatement;
class ContinueStatement;
class SynchronizedStatement;
class WithStatement;
class TryCatchStatement;
class TryFinallyStatement;
class OnScopeStatement;
class ThrowStatement;
class DebugStatement;
class GotoStatement;
class LabelStatement;
class AsmStatement;
class ImportStatement;
#if DMD_OBJC
struct ObjcExceptionBridge;
#endif

class Type;
class TypeError;
class TypeNext;
class TypeBasic;
class TypeVector;
class TypeArray;
class TypeSArray;
class TypeDArray;
class TypeAArray;
class TypePointer;
class TypeReference;
class TypeFunction;
class TypeDelegate;
class TypeQualified;
class TypeIdentifier;
class TypeInstance;
class TypeTypeof;
class TypeReturn;
class TypeStruct;
class TypeEnum;
class TypeTypedef;
class TypeClass;
class TypeTuple;
class TypeSlice;
class TypeNull;

class Dsymbol;

class StaticAssert;
class DebugSymbol;
class VersionSymbol;
class EnumMember;
class Import;
class OverloadSet;
class LabelDsymbol;
class AliasThis;

class AttribDeclaration;
class StorageClassDeclaration;
class DeprecatedDeclaration;
class LinkDeclaration;
class ProtDeclaration;
class AlignDeclaration;
class AnonDeclaration;
class PragmaDeclaration;
class ConditionalDeclaration;
class StaticIfDeclaration;
class CompileDeclaration;
class UserAttributeDeclaration;

class ScopeDsymbol;
class TemplateDeclaration;
class TemplateInstance;
class TemplateMixin;
class EnumDeclaration;
class Package;
class Module;
class WithScopeSymbol;
class ArrayScopeSymbol;

class AggregateDeclaration;
class StructDeclaration;
class UnionDeclaration;
class ClassDeclaration;
class InterfaceDeclaration;

class Declaration;
class TupleDeclaration;
class TypedefDeclaration;
class AliasDeclaration;
class VarDeclaration;
class SymbolDeclaration;
class ClassInfoDeclaration;
class ThisDeclaration;

class TypeInfoDeclaration;
class TypeInfoStructDeclaration;
class TypeInfoClassDeclaration;
class TypeInfoInterfaceDeclaration;
class TypeInfoTypedefDeclaration;
class TypeInfoPointerDeclaration;
class TypeInfoArrayDeclaration;
class TypeInfoStaticArrayDeclaration;
class TypeInfoAssociativeArrayDeclaration;
class TypeInfoEnumDeclaration;
class TypeInfoFunctionDeclaration;
class TypeInfoDelegateDeclaration;
class TypeInfoTupleDeclaration;
class TypeInfoConstDeclaration;
class TypeInfoInvariantDeclaration;
class TypeInfoSharedDeclaration;
class TypeInfoWildDeclaration;
class TypeInfoVectorDeclaration;

class FuncDeclaration;
class FuncAliasDeclaration;
class FuncLiteralDeclaration;
class CtorDeclaration;
class PostBlitDeclaration;
class DtorDeclaration;
class StaticCtorDeclaration;
class SharedStaticCtorDeclaration;
class StaticDtorDeclaration;
class SharedStaticDtorDeclaration;
class InvariantDeclaration;
class UnitTestDeclaration;
class NewDeclaration;
class DeleteDeclaration;

class Visitor
{
public:
    virtual void visit(Statement *s) { assert(0); }
    virtual void visit(ErrorStatement *s) { visit((Statement *)s); }
    virtual void visit(PeelStatement *s) { visit((Statement *)s); }
    virtual void visit(ExpStatement *s) { visit((Statement *)s); }
    virtual void visit(DtorExpStatement *s) { visit((ExpStatement *)s); }
    virtual void visit(CompileStatement *s) { visit((Statement *)s); }
    virtual void visit(CompoundStatement *s) { visit((Statement *)s); }
    virtual void visit(CompoundDeclarationStatement *s) { visit((CompoundStatement *)s); }
    virtual void visit(UnrolledLoopStatement *s) { visit((Statement *)s); }
    virtual void visit(ScopeStatement *s) { visit((Statement *)s); }
    virtual void visit(WhileStatement *s) { visit((Statement *)s); }
    virtual void visit(DoStatement *s) { visit((Statement *)s); }
    virtual void visit(ForStatement *s) { visit((Statement *)s); }
    virtual void visit(ForeachStatement *s) { visit((Statement *)s); }
    virtual void visit(ForeachRangeStatement *s) { visit((Statement *)s); }
    virtual void visit(IfStatement *s) { visit((Statement *)s); }
    virtual void visit(ConditionalStatement *s) { visit((Statement *)s); }
    virtual void visit(PragmaStatement *s) { visit((Statement *)s); }
    virtual void visit(StaticAssertStatement *s) { visit((Statement *)s); }
    virtual void visit(SwitchStatement *s) { visit((Statement *)s); }
    virtual void visit(CaseStatement *s) { visit((Statement *)s); }
    virtual void visit(CaseRangeStatement *s) { visit((Statement *)s); }
    virtual void visit(DefaultStatement *s) { visit((Statement *)s); }
    virtual void visit(GotoDefaultStatement *s) { visit((Statement *)s); }
    virtual void visit(GotoCaseStatement *s) { visit((Statement *)s); }
    virtual void visit(SwitchErrorStatement *s) { visit((Statement *)s); }
    virtual void visit(ReturnStatement *s) { visit((Statement *)s); }
    virtual void visit(BreakStatement *s) { visit((Statement *)s); }
    virtual void visit(ContinueStatement *s) { visit((Statement *)s); }
    virtual void visit(SynchronizedStatement *s) { visit((Statement *)s); }
    virtual void visit(WithStatement *s) { visit((Statement *)s); }
    virtual void visit(TryCatchStatement *s) { visit((Statement *)s); }
    virtual void visit(TryFinallyStatement *s) { visit((Statement *)s); }
    virtual void visit(OnScopeStatement *s) { visit((Statement *)s); }
    virtual void visit(ThrowStatement *s) { visit((Statement *)s); }
    virtual void visit(DebugStatement *s) { visit((Statement *)s); }
    virtual void visit(GotoStatement *s) { visit((Statement *)s); }
    virtual void visit(LabelStatement *s) { visit((Statement *)s); }
    virtual void visit(AsmStatement *s) { visit((Statement *)s); }
    virtual void visit(ImportStatement *s) { visit((Statement *)s); }
#if DMD_OBJC
    virtual void visit(ObjcExceptionBridge *s) { visit((Statement *)s); }
#endif

    virtual void visit(Type *t) { assert(0); }
    virtual void visit(TypeError *t) { visit((Type *)t); }
    virtual void visit(TypeNext *t) { visit((Type *)t); }
    virtual void visit(TypeBasic *t) { visit((Type *)t); }
    virtual void visit(TypeVector *t) { visit((Type *)t); }
    virtual void visit(TypeArray *t) { visit((TypeNext *)t); }
    virtual void visit(TypeSArray *t) { visit((TypeArray *)t); }
    virtual void visit(TypeDArray *t) { visit((TypeArray *)t); }
    virtual void visit(TypeAArray *t) { visit((TypeArray *)t); }
    virtual void visit(TypePointer *t) { visit((TypeNext *)t); }
    virtual void visit(TypeReference *t) { visit((TypeNext *)t); }
    virtual void visit(TypeFunction *t) { visit((TypeFunction *)t); }
    virtual void visit(TypeDelegate *t) { visit((TypeNext *)t); }
    virtual void visit(TypeQualified *t) { visit((Type *)t); }
    virtual void visit(TypeIdentifier *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeInstance *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeTypeof *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeReturn *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeStruct *t) { visit((Type *)t); }
    virtual void visit(TypeEnum *t) { visit((Type *)t); }
    virtual void visit(TypeTypedef *t) { visit((Type *)t); }
    virtual void visit(TypeClass *t) { visit((Type *)t); }
    virtual void visit(TypeTuple *t) { visit((Type *)t); }
    virtual void visit(TypeSlice *t) { visit((TypeNext *)t); }
    virtual void visit(TypeNull *t) { visit((Type *)t); }

    virtual void visit(Dsymbol *s) { assert(0); }

    virtual void visit(StaticAssert *s) { visit((Dsymbol *)s); }
    virtual void visit(DebugSymbol *s) { visit((Dsymbol *)s); }
    virtual void visit(VersionSymbol *s) { visit((Dsymbol *)s); }
    virtual void visit(EnumMember *s) { visit((Dsymbol *)s); }
    virtual void visit(Import *s) { visit((Dsymbol *)s); }
    virtual void visit(OverloadSet *s) { visit((Dsymbol *)s); }
    virtual void visit(LabelDsymbol *s) { visit((Dsymbol *)s); }
    virtual void visit(AliasThis *s) { visit((Dsymbol *)s); }

    virtual void visit(AttribDeclaration *s) { visit((Dsymbol *)s); }
    virtual void visit(StorageClassDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(DeprecatedDeclaration *s) { visit((StorageClassDeclaration *)s); }
    virtual void visit(LinkDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(ProtDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(AlignDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(AnonDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(PragmaDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(ConditionalDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(StaticIfDeclaration *s) { visit((ConditionalDeclaration *)s); }
    virtual void visit(CompileDeclaration *s) { visit((AttribDeclaration *)s); }
    virtual void visit(UserAttributeDeclaration *s) { visit((AttribDeclaration *)s); }

    virtual void visit(ScopeDsymbol *s) { visit((Dsymbol *)s); }
    virtual void visit(TemplateDeclaration *s) { visit((ScopeDsymbol *)s); }
    virtual void visit(TemplateInstance *s) { visit((ScopeDsymbol *)s); }
    virtual void visit(TemplateMixin *s) { visit((TemplateInstance *)s); }
    virtual void visit(EnumDeclaration *s) { visit((ScopeDsymbol *)s); }
    virtual void visit(Package *s) { visit((ScopeDsymbol *)s); }
    virtual void visit(Module *s) { visit((Package *)s); }
    virtual void visit(WithScopeSymbol *s) { visit((ScopeDsymbol *)s); }
    virtual void visit(ArrayScopeSymbol *s) { visit((ScopeDsymbol *)s); }

    virtual void visit(AggregateDeclaration *s) { visit((ScopeDsymbol *)s); }
    virtual void visit(StructDeclaration *s) { visit((AggregateDeclaration *)s); }
    virtual void visit(UnionDeclaration *s) { visit((StructDeclaration *)s); }
    virtual void visit(ClassDeclaration *s) { visit((AggregateDeclaration *)s); }
    virtual void visit(InterfaceDeclaration *s) { visit((ClassDeclaration *)s); }

    virtual void visit(Declaration *s) { visit((Dsymbol *)s); }
    virtual void visit(TupleDeclaration *s) { visit((Declaration *)s); }
    virtual void visit(TypedefDeclaration *s) { visit((Declaration *)s); }
    virtual void visit(AliasDeclaration *s) { visit((Declaration *)s); }
    virtual void visit(VarDeclaration *s) { visit((Declaration *)s); }
    virtual void visit(SymbolDeclaration *s) { visit((Declaration *)s); }
    virtual void visit(ClassInfoDeclaration *s) { visit((VarDeclaration *)s); }
    virtual void visit(ThisDeclaration *s) { visit((VarDeclaration *)s); }

    virtual void visit(TypeInfoDeclaration *s) { visit((VarDeclaration *)s); }
    virtual void visit(TypeInfoStructDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoClassDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoInterfaceDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoTypedefDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoPointerDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoArrayDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoStaticArrayDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoAssociativeArrayDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoEnumDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoFunctionDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoDelegateDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoTupleDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoConstDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoInvariantDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoSharedDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoWildDeclaration *s) { visit((TypeInfoDeclaration *)s); }
    virtual void visit(TypeInfoVectorDeclaration *s) { visit((TypeInfoDeclaration *)s); }

    virtual void visit(FuncDeclaration *s) { visit((Declaration *)s); }
    virtual void visit(FuncAliasDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(FuncLiteralDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(CtorDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(PostBlitDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(DtorDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(StaticCtorDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(SharedStaticCtorDeclaration *s) { visit((StaticCtorDeclaration *)s); }
    virtual void visit(StaticDtorDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(SharedStaticDtorDeclaration *s) { visit((StaticDtorDeclaration *)s); }
    virtual void visit(InvariantDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(UnitTestDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(NewDeclaration *s) { visit((FuncDeclaration *)s); }
    virtual void visit(DeleteDeclaration *s) { visit((FuncDeclaration *)s); }
};

#endif /* DMD_VISITOR_H */
