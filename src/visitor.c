#include "visitor.h"
#include "mtype.h"
#include "dsymbol.h"
#include "declaration.h"
#include "aggregate.h"
#include "aliasthis.h"
#include "attrib.h"
#include "enum.h"
#include "import.h"
#include "module.h"
#include "staticassert.h"
#include "version.h"
#include "template.h"

Visitor::~Visitor()
{
}

void Visitor::visit(RootObject *arg)
{
    assert(0);
}

void Visitor::visit(Type *arg)
{
    visit((RootObject*)arg);
}

void Visitor::visit(TypeError *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeNext *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeBasic *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeVector *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeArray *arg)
{
    visit((TypeNext*)arg);
}

void Visitor::visit(TypeSArray *arg)
{
    visit((TypeArray*)arg);
}

void Visitor::visit(TypeDArray *arg)
{
    visit((TypeArray*)arg);
}

void Visitor::visit(TypeAArray *arg)
{
    visit((TypeArray*)arg);
}

void Visitor::visit(TypePointer *arg)
{
    visit((TypeNext*)arg);
}

void Visitor::visit(TypeReference *arg)
{
    visit((TypeNext*)arg);
}

void Visitor::visit(TypeFunction *arg)
{
    visit((TypeNext*)arg);
}

void Visitor::visit(TypeDelegate *arg)
{
    visit((TypeNext*)arg);
}

void Visitor::visit(TypeQualified *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeIdentifier *arg)
{
    visit((TypeQualified*)arg);
}

void Visitor::visit(TypeInstance *arg)
{
    visit((TypeQualified*)arg);
}

void Visitor::visit(TypeTypeof *arg)
{
    visit((TypeQualified*)arg);
}

void Visitor::visit(TypeReturn *arg)
{
    visit((TypeQualified*)arg);
}

void Visitor::visit(TypeStruct *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeEnum *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeTypedef *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeClass *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeTuple *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(TypeSlice *arg)
{
    visit((TypeNext*)arg);
}

void Visitor::visit(TypeNull *arg)
{
    visit((Type*)arg);
}

void Visitor::visit(Dsymbol *arg)
{
    visit((RootObject*)arg);
}

void Visitor::visit(ScopeDsymbol *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(WithScopeSymbol *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(ArrayScopeSymbol *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(OverloadSet *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(Declaration *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(VarDeclaration *arg)
{
    visit((Declaration*)arg);
}

void Visitor::visit(FuncDeclaration *arg)
{
    visit((Declaration*)arg);
}

void Visitor::visit(TupleDeclaration *arg)
{
    visit((Declaration*)arg);
}

void Visitor::visit(TypedefDeclaration *arg)
{
    visit((Declaration*)arg);
}

void Visitor::visit(AliasDeclaration *arg)
{
    visit((Declaration*)arg);
}

void Visitor::visit(SymbolDeclaration *arg)
{
    visit((Declaration*)arg);
}

void Visitor::visit(ClassInfoDeclaration *arg)
{
    visit((VarDeclaration*)arg);
}

void Visitor::visit(TypeInfoDeclaration *arg)
{
    visit((VarDeclaration*)arg);
}

void Visitor::visit(TypeInfoStructDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoClassDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoInterfaceDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoTypedefDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoPointerDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoArrayDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoStaticArrayDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoAssociativeArrayDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoEnumDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoFunctionDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoDelegateDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoTupleDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoConstDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoInvariantDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoSharedDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoWildDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(TypeInfoVectorDeclaration *arg)
{
    visit((TypeInfoDeclaration*)arg);
}

void Visitor::visit(ThisDeclaration *arg)
{
    visit((VarDeclaration*)arg);
}

void Visitor::visit(FuncAliasDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(FuncLiteralDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(CtorDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(PostBlitDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(DtorDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(StaticCtorDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(SharedStaticCtorDeclaration *arg)
{
    visit((StaticCtorDeclaration*)arg);
}

void Visitor::visit(StaticDtorDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(SharedStaticDtorDeclaration *arg)
{
    visit((StaticDtorDeclaration*)arg);
}

void Visitor::visit(InvariantDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(UnitTestDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(NewDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(DeleteDeclaration *arg)
{
    visit((FuncDeclaration*)arg);
}

void Visitor::visit(AggregateDeclaration *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(StructDeclaration *arg)
{
    visit((AggregateDeclaration*)arg);
}

void Visitor::visit(UnionDeclaration *arg)
{
    visit((StructDeclaration*)arg);
}

void Visitor::visit(ClassDeclaration *arg)
{
    visit((AggregateDeclaration*)arg);
}

void Visitor::visit(InterfaceDeclaration *arg)
{
    visit((ClassDeclaration*)arg);
}

void Visitor::visit(AliasThis *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(AttribDeclaration *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(StorageClassDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(DeprecatedDeclaration *arg)
{
    visit((StorageClassDeclaration*)arg);
}

void Visitor::visit(LinkDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(ProtDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(AlignDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(AnonDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(PragmaDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(ConditionalDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(StaticIfDeclaration *arg)
{
    visit((ConditionalDeclaration*)arg);
}

void Visitor::visit(CompileDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(UserAttributeDeclaration *arg)
{
    visit((AttribDeclaration*)arg);
}

void Visitor::visit(EnumDeclaration *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(EnumMember *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(Import *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(Package *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(Module *arg)
{
    visit((Package*)arg);
}
    
void Visitor::visit(StaticAssert *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(DebugSymbol *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(VersionSymbol *arg)
{
    visit((Dsymbol*)arg);
}

void Visitor::visit(TemplateDeclaration *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(TemplateInstance *arg)
{
    visit((ScopeDsymbol*)arg);
}

void Visitor::visit(TemplateMixin *arg)
{
    visit((TemplateInstance*)arg);
}
