
#ifndef DMD_MANGLE_H
#define DMD_MANGLE_H 1

#include <stdint.h>
#include "mtype.h"
#include "declaration.h"
#include "visitors.h"


class Mangler: public TypeVisitor, public DsymbolVisitor
{
public:
    virtual ~Mangler(){}
    virtual const char *result() = 0;
};

//GCC C++ mangling
class ItaniumCPPMangler: public Mangler
{
public:
    
    ItaniumCPPMangler();
    ~ItaniumCPPMangler();

    void visitDsymbol(Dsymbol *d);
    void visitDsymbol(FuncDeclaration *d);
    void visitDsymbol(VarDeclaration *d);

    void visitType(Type *type);
    void visitType(TypeBasic *type);
    void visitType(TypeVector *type);
    void visitType(TypeSArray *type);
    void visitType(TypePointer *type);
    void visitType(TypeReference *type);
    void visitType(TypeFunction *type);
    void visitType(TypeStruct *type);
    void visitType(TypeEnum *type);
    void visitType(TypeClass *type);
    
    const char *result();
    
private:
    int substitute(void *p);
    int exist(void *p);
    void store(void *p);
    void sourceName(Dsymbol *s);
    void prefixName(Dsymbol *s);
    void argsCppMangle(Parameters *arguments, int varargs);
    void mangleName(Dsymbol *s);

    Voids components;
    OutBuffer *buf;
};

//Windows DMC an Microsoft Visual C++ mangling
class VisualCPPMangler: public Mangler
{
public:

    VisualCPPMangler();
    ~VisualCPPMangler();

    void visitDsymbol(Dsymbol *d);
    void visitDsymbol(FuncDeclaration *d);
    void visitDsymbol(VarDeclaration *d);

    void visitType(Type *type);
    void visitType(TypeBasic *type);
    void visitType(TypeVector *type);
    void visitType(TypeSArray *type);
    void visitType(TypePointer *type);
    void visitType(TypeReference *type);
    void visitType(TypeFunction *type);
    void visitType(TypeStruct *type);
    void visitType(TypeEnum *type);
    void visitType(TypeClass *type);
    
    const char *result();
private:
    void mangleName(const char *name);
    void mangleIdent(Dsymbol *sym);
    void mangleNumber(uint64_t);
    bool checkTypeSaved(Type *type);
    void mangleModifier(Type *type);
    void mangleArray(TypeSArray*);
    const char *mangleFunction(TypeFunction*, bool needthis = false);
    void mangleParamenter(Parameter *type);
    
    const char *saved_idents[10];
    Type *saved_types[10];
    //when we mangling one argument, we can call visitType several times (for base types of arg type) 
    //but we must save only arg type:
    //For example: if we have an int** argument, we should save "int**" but visitType will be called for "int**", "int*", "int"
    //This flag is set up by the visitType(NextType, ) function  and should be reset when the arg type output is finished.
    bool is_not_top_type; 
    
    //in some cases we should ignore CV-modifiers, like array:
    bool ignore_const;
    
    OutBuffer *buf;
};

#endif
