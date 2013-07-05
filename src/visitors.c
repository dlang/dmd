#include "visitors.h"
#include "mtype.h"

TypeVisitor::~TypeVisitor()
{
}

void TypeVisitor::visitType(TypeError* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeNext* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeBasic* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeVector* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeArray* arg)
{
    visitType((TypeNext*)arg);
}

void TypeVisitor::visitType(TypeSArray* arg)
{
    visitType((TypeArray*)arg);
}

void TypeVisitor::visitType(TypeDArray* arg)
{
    visitType((TypeArray*)arg);
}

void TypeVisitor::visitType(TypeAArray* arg)
{
    visitType((TypeArray*)arg);
}

void TypeVisitor::visitType(TypePointer* arg)
{
    visitType((TypeNext*)arg);
}

void TypeVisitor::visitType(TypeReference* arg)
{
    visitType((TypeNext*)arg);
}

void TypeVisitor::visitType(TypeFunction* arg)
{
    visitType((TypeNext*)arg);
}

void TypeVisitor::visitType(TypeDelegate* arg)
{
    visitType((TypeNext*)arg);
}

void TypeVisitor::visitType(TypeQualified* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeIdentifier* arg)
{
    visitType((TypeQualified*)arg);
}

void TypeVisitor::visitType(TypeInstance* arg)
{
    visitType((TypeQualified*)arg);
}

void TypeVisitor::visitType(TypeTypeof* arg)
{
    visitType((TypeQualified*)arg);
}

void TypeVisitor::visitType(TypeReturn* arg)
{
    visitType((TypeQualified*)arg);
}

void TypeVisitor::visitType(TypeStruct* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeEnum* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeTypedef* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeClass* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeTuple* arg)
{
    visitType((Type*)arg);
}

void TypeVisitor::visitType(TypeSlice* arg)
{
    visitType((TypeNext*)arg);
}

void TypeVisitor::visitType(TypeNull* arg)
{
    visitType((Type*)arg);
}


DsymbolVisitor::~DsymbolVisitor()
{
}

void DsymbolVisitor::visitDsymbol(Declaration* arg)
{
    visitDsymbol((Dsymbol*)arg);
}

void DsymbolVisitor::visitDsymbol(VarDeclaration* arg)
{
    visitDsymbol((Declaration*)arg);
}

void DsymbolVisitor::visitDsymbol(FuncDeclaration* arg)
{
    visitDsymbol((Declaration*)arg);
}
