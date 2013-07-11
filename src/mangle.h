
#ifndef DMD_MANGLE_H
#define DMD_MANGLE_H 1

#include <stdint.h>
#include "mtype.h"
#include "declaration.h"
#include "visitor.h"


class Mangler: public Visitor
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

    void visit(Dsymbol *d);
    void visit(FuncDeclaration *d);
    void visit(VarDeclaration *d);

    void visit(Type *type);
    void visit(TypeBasic *type);
    void visit(TypeVector *type);
    void visit(TypeSArray *type);
    void visit(TypePointer *type);
    void visit(TypeReference *type);
    void visit(TypeFunction *type);
    void visit(TypeStruct *type);
    void visit(TypeEnum *type);
    void visit(TypeClass *type);

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

    VisualCPPMangler(bool isdmc);
    ~VisualCPPMangler();

    void visit(Dsymbol *d);
    void visit(FuncDeclaration *d);
    void visit(VarDeclaration *d);

    void visit(Type *type);
    void visit(TypeBasic *type);
    void visit(TypeVector *type);
    void visit(TypeSArray *type);
    void visit(TypePointer *type);
    void visit(TypeReference *type);
    void visit(TypeFunction *type);
    void visit(TypeStruct *type);
    void visit(TypeEnum *type);
    void visit(TypeClass *type);

    const char *result();
private:
    void mangleName(Dsymbol *s, bool dont_use_back_reference = false);
    void mangleIdent(Dsymbol *sym, bool dont_use_back_reference = false);
    void mangleNumber(uint64_t);
    bool checkTypeSaved(Type *type);
    void mangleModifier(Type *type);
    void mangleArray(TypeSArray*);
    const char *mangleFunction(TypeFunction*, bool needthis = false);
    void mangleParamenter(Parameter *type);

    const char *saved_idents[10];
    Type *saved_types[10];
    //when we mangling one argument, we can call visit several times (for base types of arg type)
    //but we must save only arg type:
    //For example: if we have an int** argument, we should save "int**" but visit will be called for "int**", "int*", "int"
    //This flag is set up by the visit(NextType, ) function  and should be reset when the arg type output is finished.
    bool is_not_top_type;

    //in some cases we should ignore CV-modifiers, like array:
    bool ignore_const;

    OutBuffer *buf;
	
	bool is_dmc;
};

#endif
