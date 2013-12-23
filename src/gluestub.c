
#include "module.h"
#include "declaration.h"
#include "aggregate.h"
#include "enum.h"
#include "attrib.h"
#include "template.h"
#include "statement.h"
#include "init.h"
#include "ctfe.h"
#include "lib.h"

// tocsym

Symbol *SymbolDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, TYPE *t, const char *suffix)
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toImport()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toImport(Symbol *sym)
{
    assert(0);
    return NULL;
}

Symbol *VarDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *ClassInfoDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeInfoDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeInfoClassDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncAliasDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toThunkSymbol(int offset)
{
    assert(0);
    return NULL;
}

Symbol *ClassDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *InterfaceDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Module::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *ClassDeclaration::toVtblSymbol()
{
    assert(0);
    return NULL;
}

Symbol *AggregateDeclaration::toInitializer()
{
    return NULL;
}

Symbol *TypedefDeclaration::toInitializer()
{
    return NULL;
}

Symbol *EnumDeclaration::toInitializer()
{
    return NULL;
}

Symbol *Module::toModuleAssert()
{
    return NULL;
}

Symbol *Module::toModuleUnittest()
{
    return NULL;
}

Symbol *Module::toModuleArray()
{
    return NULL;
}

Symbol *TypeAArray::aaGetSymbol(const char *func, int flags)
{
    assert(0);
    return NULL;
}

Symbol* StructLiteralExp::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol* ClassReferenceExp::toSymbol()
{
    assert(0);
    return NULL;
}

// todt

dt_t *Initializer::toDt()
{
    assert(0);
    return NULL;
}

dt_t *VoidInitializer::toDt()
{
    assert(0);
    return NULL;
}

dt_t *StructInitializer::toDt()
{
    assert(0);
    return NULL;
}

dt_t *ArrayInitializer::toDt()
{
    assert(0);
    return NULL;
}

dt_t *ExpInitializer::toDt()
{
    assert(0);
    return NULL;
}

dt_t **Expression::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **CastExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **AddrExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **IntegerExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **RealExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **ComplexExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **NullExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **StringExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **ArrayLiteralExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **StructLiteralExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **SymOffExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **VarExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **FuncExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **VectorExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

void ClassDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void ClassDeclaration::toDt2(dt_t **pdt, ClassDeclaration *cd)
{
    assert(0);
}

void StructDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

dt_t **Type::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **TypeVector::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **TypeSArray::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **TypeSArray::toDtElem(dt_t **pdt, Expression *e)
{
    assert(0);
    return NULL;
}

dt_t **TypeStruct::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **TypeTypedef::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **ClassReferenceExp::toDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **ClassReferenceExp::toDtI(dt_t **pdt, int off)
{
    assert(0);
    return NULL;
}

dt_t **ClassReferenceExp::toInstanceDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **ClassReferenceExp::toDt2(dt_t **pdt, ClassDeclaration *cd, Dts *dts)
{
    assert(0);
    return NULL;
}

// e2ir

elem *Expression::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *Expression::toElemDtor(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *SymbolExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *FuncExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *Dsymbol_toElem(Dsymbol *s, IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DeclarationExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ThisExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *IntegerExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *RealExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ComplexExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *NullExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *StringExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *NewExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *NegExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ComExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *NotExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *HaltExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AssertExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *PostExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *BinExp::toElemBin(IRState *irs,int op)
{
    assert(0);
    return NULL;
}

elem *AddExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *MinExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CatExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *MulExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DivExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ModExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CmpExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *EqualExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *IdentityExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *InExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *RemoveExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AddAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *MinAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CatAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DivAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ModAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *MulAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ShlAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ShrAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *UshrAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AndAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *OrAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *XorAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *PowAssignExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AndAndExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *OrOrExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *XorExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *PowExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AndExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *OrExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ShlExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ShrExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *UshrExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CommaExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CondExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *TypeExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ScopeExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DotVarExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DelegateExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DotTypeExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CallExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AddrExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *PtrExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *BoolExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *DeleteExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *VectorExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *CastExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ArrayLengthExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *SliceExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *IndexExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *TupleExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ArrayLiteralExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *AssocArrayLiteralExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *StructLiteralExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

elem *ClassReferenceExp::toElem(IRState *irs)
{
    assert(0);
    return NULL;
}

// toobj

void Module::genmoduleinfo()
{
    assert(0);
}

void Dsymbol::toObjFile(int multiobj)
{
    assert(0);
}

void ClassDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

unsigned ClassDeclaration::baseVtblOffset(BaseClass *bc)
{
    assert(0);
    return 0;
}

void InterfaceDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void StructDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void VarDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TypedefDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void EnumDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TypeInfoDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void AttribDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void PragmaDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TemplateInstance::toObjFile(int multiobj)
{
    assert(0);
}

void TemplateMixin::toObjFile(int multiobj)
{
    assert(0);
}

// glue

void obj_append(Dsymbol *s)
{
    assert(0);
}

void obj_write_deferred(Library *library)
{
}

void obj_start(char *srcfile)
{
}

void obj_end(Library *library, File *objfile)
{
}

bool obj_includelib(const char *name)
{
    assert(0);
    return false;
}

void obj_startaddress(Symbol *s)
{
    assert(0);
}

void Module::genobjfile(int multiobj)
{
}

void FuncDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

unsigned Type::totym()
{
    assert(0);
    return 0;
}

unsigned TypeFunction::totym()
{
    assert(0);
    return 0;
}

Symbol *Type::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeClass::toSymbol()
{
    assert(0);
    return NULL;
}

elem *Module::toEfilename()
{
    assert(0);
    return NULL;
}

// toctype

type *Type::toCtype()
{
    assert(0);
    return NULL;
}

type *Type::toCParamtype()
{
    assert(0);
    return NULL;
}

type *TypeSArray::toCParamtype()
{
    assert(0);
    return NULL;
}

type *TypeVector::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeSArray::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeDArray::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeAArray::toCtype()
{
    assert(0);
    return NULL;
}

type *TypePointer::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeFunction::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeDelegate::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeStruct::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeEnum::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeTypedef::toCtype()
{
    assert(0);
    return NULL;
}

type *TypeTypedef::toCParamtype()
{
    assert(0);
    return NULL;
}

type *TypeClass::toCtype()
{
    assert(0);
    return NULL;
}


// msc

void backend_init()
{
}

void backend_term()
{
}

// typinf

Expression *Type::getInternalTypeInfo(Scope *sc)
{
    assert(0);
    return NULL;
}

Expression *Type::getTypeInfo(Scope *sc)
{
    Declaration *ti = new TypeInfoDeclaration(this, 1);
    Expression *e = new VarExp(Loc(), ti);
    e = e->addressOf(sc);
    e->type = ti->type;
    return e;
}

TypeInfoDeclaration *Type::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeTypedef::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypePointer::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeDArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeSArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeAArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeStruct::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeClass::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeVector::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeEnum::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeFunction::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeDelegate::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeTuple::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

void TypeInfoDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoConstDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoInvariantDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoSharedDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoWildDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoTypedefDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoEnumDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoPointerDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoArrayDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoStaticArrayDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoVectorDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoAssociativeArrayDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoFunctionDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoDelegateDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoStructDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoClassDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoInterfaceDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void TypeInfoTupleDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

int Type::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeBasic::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeDArray::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeClass::builtinTypeInfo()
{
    assert(0);
    return 0;
}

Expression *createTypeInfoArray(Scope *sc, Expression *exps[], size_t dim)
{
    /*
     * Pass a reference to the TypeInfo_Tuple corresponding to the types of the
     * arguments. Source compatibility is maintained by computing _arguments[]
     * at the start of the called function by offseting into the TypeInfo_Tuple
     * reference.
     */
    Parameters *args = new Parameters;
    args->setDim(dim);
    for (size_t i = 0; i < dim; i++)
    {   Parameter *arg = new Parameter(STCin, exps[i]->type, NULL, NULL);
        (*args)[i] = arg;
    }
    TypeTuple *tup = new TypeTuple(args);
    Expression *e = tup->getTypeInfo(sc);
    e = e->optimize(WANTvalue);
    assert(e->op == TOKsymoff);         // should be SymOffExp

    return e;
}

// tocvdebug

void TypedefDeclaration::toDebug()
{
    assert(0);
}

void EnumDeclaration::toDebug()
{
    assert(0);
}

void StructDeclaration::toDebug()
{
    assert(0);
}

void ClassDeclaration::toDebug()
{
    assert(0);
}

int Dsymbol::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int TypedefDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int EnumDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int FuncDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int VarDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

// toir

void FuncDeclaration::buildClosure(IRState *irs)
{
    assert(0);
}

RET TypeFunction::retStyle()
{
    return RETregs;
}

// lib

Library *Library::factory()
{
    assert(0);
    return NULL;
}

Statement *AsmStatement::semantic(Scope *)
{
    assert(0);
    return NULL;
}

int binary(const char *p, const char **tab, int n)
{
    for (int i = 0; i < n; ++i)
        if (!strcmp(p, tab[i]))
            return i;
    return -1;
}
