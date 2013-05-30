
#ifndef DMD_MANGLE_H
#define DMD_MANGLE_H 1

#include <stdint.h>
#include "mtype.h"
#include "declaration.h"

class Mangler
{
public:
    //Double dispatching:
    //Mangle strategy depends on king of mangling object and type of mangling.
    virtual const char *mangleDsymbol(Dsymbol *d) = 0;
    virtual const char *mangleDsymbol(FuncDeclaration *d) = 0;
    virtual const char *mangleDsymbol(VarDeclaration *d) = 0;

    virtual void mangleType(Type *type, OutBuffer *buf) {}
    virtual void mangleType(TypeBasic *type, OutBuffer *buf) {}
    virtual void mangleType(TypeVector *type, OutBuffer *buf) {}
    virtual void mangleType(TypeSArray *type, OutBuffer *buf) {}
    virtual void mangleType(TypeDArray *type, OutBuffer *buf) {}
    virtual void mangleType(TypeAArray *type, OutBuffer *buf) {}
    virtual void mangleType(TypePointer *type, OutBuffer *buf) {}
    virtual void mangleType(TypeReference *type, OutBuffer *buf) {}
    virtual void mangleType(TypeFunction *type, OutBuffer *buf) {}
    virtual void mangleType(TypeDelegate *type, OutBuffer *buf) {}
    virtual void mangleType(TypeStruct *type, OutBuffer *buf) {}
    virtual void mangleType(TypeEnum *type, OutBuffer *buf) {}
    virtual void mangleType(TypeTypedef *type, OutBuffer *buf) {}
    virtual void mangleType(TypeClass *type, OutBuffer *buf) {}
};

//GCC C++ mangling
class ItaniumCPPMangler: public Mangler
{
public:

    const char *mangleDsymbol(Dsymbol *d);
    const char *mangleDsymbol(FuncDeclaration *d);
    const char *mangleDsymbol(VarDeclaration *d);

    void mangleType(Type *type, OutBuffer *buf);
    void mangleType(TypeBasic *type, OutBuffer *buf);
    void mangleType(TypeVector *type, OutBuffer *buf);
    void mangleType(TypeSArray *type, OutBuffer *buf);
    void mangleType(TypeDArray *type, OutBuffer *buf);
    void mangleType(TypeAArray *type, OutBuffer *buf);
    void mangleType(TypePointer *type, OutBuffer *buf);
    void mangleType(TypeReference *type, OutBuffer *buf);
    void mangleType(TypeFunction *type, OutBuffer *buf);
    void mangleType(TypeDelegate *type, OutBuffer *buf);
    void mangleType(TypeStruct *type, OutBuffer *buf);
    void mangleType(TypeEnum *type, OutBuffer *buf);
    void mangleType(TypeTypedef *type, OutBuffer *buf);
    void mangleType(TypeClass *type, OutBuffer *buf);
    
private:
    int substitute(OutBuffer *buf, void *p);
    int exist(void *p);
    void store(void *p);
    void sourceName(OutBuffer *buf, Dsymbol *s);
    void prefixName(OutBuffer *buf, Dsymbol *s);
    void argsCppMangle(OutBuffer *buf, Parameters *arguments, int varargs);
    void mangleName(OutBuffer *buf, Dsymbol *s);
    void reset();
    
    Voids components;
};

//Windows DMC an Microsoft Visual C++ mangling
class VisualCPPMangler: public Mangler
{
public:

    const char *mangleDsymbol(Dsymbol *d);
    const char *mangleDsymbol(FuncDeclaration *d);
    const char *mangleDsymbol(VarDeclaration *d);

    void mangleType(Type *type, OutBuffer *buf);
    void mangleType(TypeBasic *type, OutBuffer *buf);
    void mangleType(TypeVector *type, OutBuffer *buf);
    void mangleType(TypeSArray *type, OutBuffer *buf);
    void mangleType(TypeDArray *type, OutBuffer *buf);
    void mangleType(TypeAArray *type, OutBuffer *buf);
    void mangleType(TypePointer *type, OutBuffer *buf);
    void mangleType(TypeReference *type, OutBuffer *buf);
    void mangleType(TypeFunction *type, OutBuffer *buf);
    void mangleType(TypeDelegate *type, OutBuffer *buf);
    void mangleType(TypeStruct *type, OutBuffer *buf);
    void mangleType(TypeEnum *type, OutBuffer *buf);
    void mangleType(TypeTypedef *type, OutBuffer *buf);
    void mangleType(TypeClass *type, OutBuffer *buf);
    
private:
    void mangleName(const char *name, OutBuffer *buf);
    void mangleIdent(Dsymbol *sym, OutBuffer *buf);
    void mangleNumber(uint64_t, OutBuffer *buf);
    bool checkTypeSaved(Type *type, OutBuffer *buf);
    void mangleModifier(Type *type, OutBuffer *buf);
    void mangleArray(TypeSArray*, OutBuffer *buf);
    const char *mangleFunction(TypeFunction*, bool needthis = false);
    void mangleParamenter(Parameter *type, OutBuffer *buf);
	
    //Should be called after symbol writing. This function clear saved_idents and saved_types tables
    void reset();
    
    const char *saved_idents[10];
    Type *saved_types[10];
    //when we mangling one argument, we can call mangleType several times (for base types of arg type) 
    //but we must save only arg type:
    //For example: if we have an int** argument, we should save "int**" but mangleType will be called for "int**", "int*", "int"
    //This flag is set up by the mangleType(NextType, ) function  and should be reset when the arg type output is finished.
    bool is_not_top_type; 
    
    //in some cases we should ignore CV-modifiers, like array:
    bool ignore_const;
};

#endif
