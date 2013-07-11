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
class Declaration;
class VarDeclaration;
class FuncDeclaration;


class Visitor
{
public:
    virtual ~Visitor();
    virtual void visit(RootObject*)=0;
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
    virtual void visit(Declaration*);
    virtual void visit(VarDeclaration*);
    virtual void visit(FuncDeclaration*);
};

#endif 
