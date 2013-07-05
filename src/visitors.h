#ifndef DMD_VISITORS_H
#define DMD_VISITORS_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */



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


class TypeVisitor
{
public:
    virtual ~TypeVisitor();
    virtual void visitType(Type*)=0;
    virtual void visitType(TypeError*);
    virtual void visitType(TypeNext*);
    virtual void visitType(TypeBasic*);
    virtual void visitType(TypeVector*);
    virtual void visitType(TypeArray*);
    virtual void visitType(TypeSArray*);
    virtual void visitType(TypeDArray*);
    virtual void visitType(TypeAArray*);
    virtual void visitType(TypePointer*);
    virtual void visitType(TypeReference*);
    virtual void visitType(TypeFunction*);
    virtual void visitType(TypeDelegate*);
    virtual void visitType(TypeQualified*);
    virtual void visitType(TypeIdentifier*);
    virtual void visitType(TypeInstance*);
    virtual void visitType(TypeTypeof*);
    virtual void visitType(TypeReturn*);
    virtual void visitType(TypeStruct*);
    virtual void visitType(TypeEnum*);
    virtual void visitType(TypeTypedef*);
    virtual void visitType(TypeClass*);
    virtual void visitType(TypeTuple*);
    virtual void visitType(TypeSlice*);
    virtual void visitType(TypeNull*);
};

class Dsymbol;
class Declaration;
class VarDeclaration;
class FuncDeclaration;

class DsymbolVisitor
{
public:
    virtual ~DsymbolVisitor();
    virtual void visitDsymbol(Dsymbol*)=0;
    virtual void visitDsymbol(Declaration*);
    virtual void visitDsymbol(VarDeclaration*);
    virtual void visitDsymbol(FuncDeclaration*);
};
#endif 
