#include "visitor.h"
#include "mtype.h"

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
