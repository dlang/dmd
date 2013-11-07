#ifndef DMD_VISITOR_H
#define DMD_VISITOR_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */


class RootObject;
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
class TypeStruct ;
class TypeEnum;
class TypeTypedef;
class TypeClass;
class TypeTuple;
class TypeSlice;
class TypeNull;

class Dsymbol;
class ScopeDsymbol;
class WithScopeSymbol;
class ArrayScopeSymbol;
class OverloadSet;

class Declaration;
class VarDeclaration;
class FuncDeclaration;
class TupleDeclaration;
class TypedefDeclaration;
class AliasDeclaration;
class SymbolDeclaration;
class ClassInfoDeclaration;
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
class ThisDeclaration;
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

class AggregateDeclaration;
class StructDeclaration;
class UnionDeclaration;
class ClassDeclaration;
class InterfaceDeclaration;

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

class EnumDeclaration;
class EnumMember;

class Import;

class Package;
class Module;

class StaticAssert;

class DebugSymbol;
class VersionSymbol;

class TemplateDeclaration;
class TemplateInstance;
class TemplateMixin;

class Visitor
{
public:
    virtual ~Visitor();
    virtual void visit(RootObject*);
    virtual void visit(Type*);
    virtual void visit(TypeError*);
    virtual void visit(TypeNext*);
    virtual void visit(TypeBasic*);
    virtual void visit(TypeVector*);
    virtual void visit(TypeArray*);
    virtual void visit(TypeSArray*);
    virtual void visit(TypeDArray*);
    virtual void visit(TypeAArray*);
    virtual void visit(TypePointer*);
    virtual void visit(TypeReference*);
    virtual void visit(TypeFunction*);
    virtual void visit(TypeDelegate*);
    virtual void visit(TypeQualified*);
    virtual void visit(TypeIdentifier*);
    virtual void visit(TypeInstance*);
    virtual void visit(TypeTypeof*);
    virtual void visit(TypeReturn*);
    virtual void visit(TypeStruct*);
    virtual void visit(TypeEnum*);
    virtual void visit(TypeTypedef*);
    virtual void visit(TypeClass*);
    virtual void visit(TypeTuple*);
    virtual void visit(TypeSlice*);
    virtual void visit(TypeNull*);
    
    virtual void visit(Dsymbol*);
    virtual void visit(ScopeDsymbol*);
    virtual void visit(WithScopeSymbol*);
    virtual void visit(ArrayScopeSymbol*);
    virtual void visit(OverloadSet*);
    
    virtual void visit(Declaration*);
    virtual void visit(VarDeclaration*);
    virtual void visit(FuncDeclaration*);
    virtual void visit(TupleDeclaration*);
    virtual void visit(TypedefDeclaration*);
    virtual void visit(AliasDeclaration*);
    virtual void visit(SymbolDeclaration*);
    virtual void visit(ClassInfoDeclaration*);
    virtual void visit(TypeInfoDeclaration*);
    virtual void visit(TypeInfoStructDeclaration*);
    virtual void visit(TypeInfoClassDeclaration*);
    virtual void visit(TypeInfoInterfaceDeclaration*);
    virtual void visit(TypeInfoTypedefDeclaration*);
    virtual void visit(TypeInfoPointerDeclaration*);
    virtual void visit(TypeInfoArrayDeclaration*);
    virtual void visit(TypeInfoStaticArrayDeclaration*);
    virtual void visit(TypeInfoAssociativeArrayDeclaration*);
    virtual void visit(TypeInfoEnumDeclaration*);
    virtual void visit(TypeInfoFunctionDeclaration*);
    virtual void visit(TypeInfoDelegateDeclaration*);
    virtual void visit(TypeInfoTupleDeclaration*);
    virtual void visit(TypeInfoConstDeclaration*);
    virtual void visit(TypeInfoInvariantDeclaration*);
    virtual void visit(TypeInfoSharedDeclaration*);
    virtual void visit(TypeInfoWildDeclaration*);
    virtual void visit(TypeInfoVectorDeclaration*);
    virtual void visit(ThisDeclaration*);
    virtual void visit(FuncAliasDeclaration*);
    virtual void visit(FuncLiteralDeclaration*);
    virtual void visit(CtorDeclaration*);
    virtual void visit(PostBlitDeclaration*);
    virtual void visit(DtorDeclaration*);
    virtual void visit(StaticCtorDeclaration*);
    virtual void visit(SharedStaticCtorDeclaration*);
    virtual void visit(StaticDtorDeclaration*);
    virtual void visit(SharedStaticDtorDeclaration*);
    virtual void visit(InvariantDeclaration*);
    virtual void visit(UnitTestDeclaration*);
    virtual void visit(NewDeclaration*);
    virtual void visit(DeleteDeclaration*);

    virtual void visit(AggregateDeclaration*);
    virtual void visit(StructDeclaration*);
    virtual void visit(UnionDeclaration*);
    virtual void visit(ClassDeclaration*);
    virtual void visit(InterfaceDeclaration*);
    
    virtual void visit(AliasThis*);

    virtual void visit(AttribDeclaration*);
    virtual void visit(StorageClassDeclaration*);
    virtual void visit(DeprecatedDeclaration*);
    virtual void visit(LinkDeclaration*);
    virtual void visit(ProtDeclaration*);
    virtual void visit(AlignDeclaration*);
    virtual void visit(AnonDeclaration*);
    virtual void visit(PragmaDeclaration*);
    virtual void visit(ConditionalDeclaration*);
    virtual void visit(StaticIfDeclaration*);
    virtual void visit(CompileDeclaration*);
    virtual void visit(UserAttributeDeclaration*);
    
    virtual void visit(EnumDeclaration*);
    virtual void visit(EnumMember*);
    
    virtual void visit(Import*);
    
    virtual void visit(Package*);
    virtual void visit(Module*);

    virtual void visit(StaticAssert*);
    
    virtual void visit(DebugSymbol*);
    virtual void visit(VersionSymbol*);
    
    virtual void visit(TemplateDeclaration*);
    virtual void visit(TemplateInstance*);
    virtual void visit(TemplateMixin*);
};

#endif 
