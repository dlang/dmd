
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_stubs.c
 */

#include "arraytypes.h"
#include "class.c"
#include "mars.h"
#include "objc.h"
#include "outbuffer.h"
#include "parse.h"

class AddrExp;
class AggregateDeclaration;
class AttribDeclaration;
class CallExp;
class ClassDeclaration;
class DelegateExp;
class DotVarExp;
class Dsymbol;
class Expression;
class FuncDeclaration;
class Identifier;
class InterfaceDeclaration;
class IsExp;
class ObjcDotClassExp;
class ObjcProtocolOfExp;
class ObjcSelectorExp;
class PragmaDeclaration;
class Scope;
class StringExp;
class SymOffExp;
class Type;
class TypeClass;
class TypeFunction;
class TypeInfoObjcSelectorDeclaration;
class TypeObjcSelector;
class TypeTuple;
class VarDeclaration;

struct elem;
struct HdrGenState;
struct IRState;
struct Symbol;

//#include <stdlib.h>
//#include <string.h>
//
//#include "aggregate.h"
//#include "attrib.h"
//#include "cc.h"
//#include "declaration.h"
//#include "dsymbol.h"
//#include "dt.h"
//#include "el.h"
//#include "expression.h"
//#include "global.h"
//#include "id.h"
//#include "init.h"
//#include "mach.h"
//#include "module.h"
//#include "mtype.h"
//#include "obj.h"
//#include "objc.h"
//#include "objc_glue.h"
//#include "oper.h"
//#include "outbuf.h"

//#include "parse.h"
//#include "scope.h"
//#include "statement.h"
//#include "target.h"
//#include "type.h"
//#include "utf.h"

TypeTuple * objc_toArgTypesVisit (TypeObjcSelector*)
{
    assert(false && "Should never be called on this platform");
    return NULL;
}

// MARK: addObjcSymbols

void Objc_ClassDeclaration::addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_AttribDeclaration_addObjcSymbols(AttribDeclaration* self, ClassDeclarations *classes, ClassDeclarations *categories)
{
    assert(false && "Should never be called on this platform");
}

// MARK: semantic

void objc_PragmaDeclaration_semantic_objcTakesStringLiteral(PragmaDeclaration* self, Scope *sc)
{
    self->error("not supported");
}

void objc_PragmaDeclaration_semantic_objcSelectorTarget(PragmaDeclaration* self, Scope *sc)
{
    self->error("not supported");
}

void objc_PragmaDeclaration_semantic_objcSelector(PragmaDeclaration* self, Scope *sc)
{
    assert(false && "Should never be called on this platform");
}

ControlFlow objc_setMangleOverride_ClassDeclaration(Dsymbol *s, char *name)
{
    assert(false && "Should never be called on this platform");
}

// MARK: implicitConvTo

ControlFlow objc_implicitConvTo_visit_StringExp_Tclass(Type *t, MATCH *result)
{
    return CFnone;
}

MATCH objc_implicitConvTo_visit_ObjcSelectorExp(Type *&t, ObjcSelectorExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
    return MATCHnomatch;
}

// MARK: castTo

ControlFlow objc_castTo_visit_StringExp_Tclass(Scope *sc, Type *t, Expression *&result, StringExp *e, Type *tb)
{
    return CFnone;
}

ControlFlow objc_castTo_visit_StringExp_isSelector(Type *t, Expression *&result, StringExp *e, Type *tb)
{
    return CFnone;
}

ControlFlow objc_castTo_visit_SymOffExp_Tobjcselector(Scope *sc, Expression *&result, SymOffExp *e, FuncDeclaration *f)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFreturn;
}

ControlFlow objc_castTo_visit_DelegateExp_Tobjcselector(Type *t, Expression *&result, DelegateExp *e, Type *tb)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

ControlFlow objc_castTo_visit_ObjcSelectorExp(Type *t, Expression *&result, ObjcSelectorExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

// MARK: ObjcClassDeclaration

ObjcClassDeclaration *ObjcClassDeclaration::create(ClassDeclaration *cdecl, int ismeta)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

/* ClassDeclaration::metaclass contains the metaclass from the semantic point
 of view. This function returns the metaclass from the Objective-C runtime's
 point of view. Here, the metaclass of a metaclass is the root metaclass, not
 nil, and the root metaclass's metaclass is itself. */
ClassDeclaration *ObjcClassDeclaration::getObjcMetaClass(ClassDeclaration *cdecl)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

ObjcClassDeclaration::ObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: ObjcProtocolDeclaration

ObjcProtocolDeclaration* ObjcProtocolDeclaration::create(ClassDeclaration *idecl)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

ObjcProtocolDeclaration::ObjcProtocolDeclaration(ClassDeclaration *idecl)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: Objc_ClassDeclaration

Objc_ClassDeclaration::Objc_ClassDeclaration(ClassDeclaration* cdecl, const char* msg)
{
    this->cdecl = cdecl;
    objc = false;
    meta = false;
    extern_ = false;
    hasPreinit = false;
    takesStringLiteral = false;
    ident = NULL;
    classSymbol = NULL;
    methods = NULL;
    metaclass = NULL;
}

bool Objc_ClassDeclaration::isInterface()
{
    return false;
}

bool Objc_ClassDeclaration::isRootClass()
{
    return false;
}

// MARK: semantic

void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration *self)
{
    self->error("Objective-C classes not supported");
}

void objc_ClassDeclaration_semantic_SIZEOKnone(ClassDeclaration *self, Scope *sc)
{
    // noop
}

void objc_ClassDeclaration_semantic_staticInitializers(ClassDeclaration *self, Scope *sc2, size_t members_dim)
{
    // noop
}

void objc_ClassDeclaration_semantic_invariant(ClassDeclaration *self, Scope *sc2)
{
    // noop
}

void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration *self, Scope *sc)
{
    if (sc->linkage == LINKobjc)
        self->error("Objective-C interfaces not supported");
}

ControlFlow objc_InterfaceDeclaration_semantic_mixingObjc(InterfaceDeclaration *self, Scope *sc, size_t i, TypeClass *tc)
{
    return CFnone;
}

void objc_InterfaceDeclaration_semantic_createMetaclass(InterfaceDeclaration *self, Scope *sc)
{
    // noop
}

void objc_CppMangleVisitor_visit_TypeObjcSelector(OutBuffer &buf, TypeObjcSelector *t)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: TypeInfoObjcSelectorDeclaration

TypeInfoObjcSelectorDeclaration::TypeInfoObjcSelectorDeclaration(Type *tinfo)
: TypeInfoDeclaration(tinfo, 0)
{
    assert(false && "Should never be called when D_OBJC is false");
}

TypeInfoObjcSelectorDeclaration *TypeInfoObjcSelectorDeclaration::create(Type *tinfo)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

ControlFlow objc_ScopeDsymbol_multiplyDefined(Dsymbol *s1, Dsymbol *s2)
{
    return CFnone;
}

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);

// MARK: ObjcSymbols

Symbol *ObjcSymbols::getFunction(const char* name)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMsgSend(Type *ret, int hasHiddenArg)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMsgSendSuper(int hasHiddenArg)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMsgSendFixup(Type* returnType, bool hasHiddenArg)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getStringLiteralClassRef()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getUString(const void *str, size_t len, const char *symbolName)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getClassReference(ClassDeclaration* cdecl)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarRef(const char *s, size_t len)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarRef(Identifier *ident)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMessageReference(ObjcSelector* selector, Type* returnType, bool hasHiddenArg)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getStringLiteral(const void *str, size_t len, size_t sz)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: ObjcSelector

Symbol *ObjcSelector::toRefSymbol()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

elem *ObjcSelector::toElem()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: callfunc

void objc_callfunc_setupSelector(elem *ec, FuncDeclaration *fd, elem *esel, Type *t, TypeFunction *&tf, elem *&ethis)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_callfunc_setupMethodSelector(Type *tret, FuncDeclaration *fd, Type *t, elem *ehidden, elem *&esel)
{
    // noop
}

void objc_callfunc_setupEp(elem *esel, elem *&ep, int reverse)
{
    // noop
}

void objc_callfunc_checkThisForSelector(elem *esel, elem *ethis)
{
    // noop
}

void objc_callfunc_setupMethodCall(int directcall, elem *&ec, FuncDeclaration *fd, Type *t, elem *&ehidden, elem *&ethis, TypeFunction *tf, Symbol *sfunc)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_callfunc_setupSelectorCall(elem *&ec, elem *ehidden, elem *ethis, TypeFunction *tf)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: toElem

void objc_toElem_visit_StringExp_Tclass(StringExp *se, elem *&e)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_toElem_visit_NewExp_Tclass(IRState *irs, NewExp *ne, Type *&ectype, TypeClass *tclass, ClassDeclaration *cd, elem *&ex, elem *&ey, elem *&ez)
{
    assert(false && "Should never be called when D_OBJC is false");
}

bool objc_toElem_visit_NewExp_Tclass_isDirectCall(bool isObjc)
{
    return true;
}

void objc_toElem_visit_AssertExp_callInvariant(symbol *&ts, elem *&einv, Type *t1)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_toElem_visit_DotVarExp_nonFragileAbiOffset(VarDeclaration *v, Type *tb1, elem *&offset)
{
    // noop
}

elem * objc_toElem_visit_ObjcSelectorExp(ObjcSelectorExp *ose)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

void objc_toElem_visit_CallExp_selector(IRState *irs, CallExp *ce, elem *&ec, elem *&esel)
{
    assert(false && "Should never be called when D_OBJC is false");
}

ControlFlow objc_toElem_visit_CastExp_Tclass_fromObjc(int &rtl, ClassDeclaration *cdfrom, ClassDeclaration *cdto)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

ControlFlow objc_toElem_visit_CastExp_Tclass_toObjc()
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

void objc_toElem_visit_CastExp_Tclass_fromObjcToObjcInterface(int &rtl)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_toElem_visit_CastExp_Tclass_assertNoOffset(int offset, ClassDeclaration *cdfrom)
{
    // noop
}

ControlFlow objc_toElem_visit_CastExp_Tclass_toObjcCall(elem *&e, int rtl, ClassDeclaration *cdto)
{
    return CFnone;
}

elem *objc_toElem_visit_ObjcDotClassExp(IRState *irs, ObjcDotClassExp *odce)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

elem *objc_toElem_visit_ObjcClassRefExp(ObjcClassRefExp *ocre)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

elem *objc_toElem_visit_ObjcProtocolOfExp(ObjcProtocolOfExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: Class References

ObjcClassRefExp::ObjcClassRefExp(Loc loc, ClassDeclaration *cdecl)
: Expression(loc, TOKobjcclsref, sizeof(ObjcClassRefExp))
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: .class Expression

ObjcDotClassExp::ObjcDotClassExp(Loc loc, Expression *e)
: UnaExp(loc, TOKobjc_dotclass, sizeof(ObjcDotClassExp), e)
{
    noop = 0;
}

Expression *ObjcDotClassExp::semantic(Scope *sc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: ObjcSelectorExp

ObjcSelectorExp::ObjcSelectorExp(Loc loc, FuncDeclaration *f, int hasOverloads)
: Expression(loc, TOKobjcselector, sizeof(ObjcSelectorExp))
{
    assert(false && "Should never be called when D_OBJC is false");
}

ObjcSelectorExp::ObjcSelectorExp(Loc loc, char *selname, int hasOverloads)
: Expression(loc, TOKobjcselector, sizeof(ObjcSelectorExp))
{
    assert(false && "Should never be called when D_OBJC is false");
}

Expression *ObjcSelectorExp::semantic(Scope *sc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: .interface Expression

ClassDeclaration *ObjcProtocolOfExp::protocolClassDecl = NULL;

ObjcProtocolOfExp::ObjcProtocolOfExp(Loc loc, Expression *e)
: UnaExp(loc, TOKobjc_dotprotocolof, sizeof(ObjcProtocolOfExp), e)
{
    assert(false && "Should never be called when D_OBJC is false");
}

Expression *ObjcProtocolOfExp::semantic(Scope *sc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: semantic

ControlFlow objc_StringExp_semantic(StringExp *self, Expression *&error)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

ControlFlow objc_NewExp_semantic_alloc(NewExp *self, Scope *sc, ClassDeclaration *cd)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

ControlFlow objc_IsExp_semantic_TOKobjcselector(IsExp *self, Type *&tded)
{
    assert(false && "Should never be called when D_OBJC is false");
    return CFnone;
}

void objc_IsExp_semantic_TOKreturn_selector(IsExp *self, Type *&tded)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_CallExp_semantic_opOverload_selector(CallExp *self, Scope *sc, Type *t1)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_CallExp_semantic_noFunction_selector(Type *t1, TypeFunction *&tf, const char *&p)
{
    assert(false && "Should never be called when D_OBJC is false");
}

ObjcSelectorExp * objc_AddrExp_semantic_TOKdotvar_selector(AddrExp *self, DotVarExp *dve, FuncDeclaration *f)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Expression * objc_AddrExp_semantic_TOKvar_selector(AddrExp *self, Scope *sc, VarExp *ve, FuncDeclaration *f)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: getRightThis

ControlFlow objc_getRightThis(AggregateDeclaration *ad, Expression *&e1, Declaration *var)
{
    return CFnone;
}

// MARK: Ojbc_FuncDeclaration

Ojbc_FuncDeclaration::Ojbc_FuncDeclaration(FuncDeclaration* fdecl)
{
    this->fdecl = fdecl;
    selector = NULL;
    vcmd = NULL;
}

void Ojbc_FuncDeclaration::createSelector()
{
    assert(false && "Should never be called when D_OBJC is false");
}

bool Ojbc_FuncDeclaration::isProperty()
{
    assert(false && "Should never be called when D_OBJC is false");
    return false;
}

// MARK: semantic

void objc_FuncDeclaration_semantic_validateSelector (FuncDeclaration *self)
{
    if (self->objc.selector)
        self->error("Objective-C selectors not supported");
}

void objc_FuncDeclaration_semantic_checkAbstractStatic(FuncDeclaration *self)
{
    // noop
}

void objc_FuncDeclaration_semantic_parentForStaticMethod(FuncDeclaration *self, ClassDeclaration *&cd)
{
    // noop
}

void objc_FuncDeclaration_semantic_checkInheritedSelector(FuncDeclaration *self, ClassDeclaration *cd)
{
    // noop
}

void objc_FuncDeclaration_semantic_addClassMethodList(FuncDeclaration *self, ClassDeclaration *cd)
{
    // noop
}

void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration *self)
{
    // noop
}

void objc_SynchronizedStatement_semantic_sync_enter(ClassDeclaration *cd, Parameters* args, FuncDeclaration *&fdenter)
{
    // noop
}

void objc_SynchronizedStatement_semantic_sync_exit(ClassDeclaration *cd, Parameters* args, FuncDeclaration *&fdexit)
{
    // noop
}

// MARK: FuncDeclaration

void objc_FuncDeclaration_declareThis(FuncDeclaration *self, Scope *sc, VarDeclaration** vobjccmd, VarDeclaration *v)
{
    // noop
}

void objc_FuncDeclaration_isThis(FuncDeclaration *self, AggregateDeclaration *&ad)
{
    assert(false && "Should never be called when D_OBJC is false");
}

ControlFlow objc_FuncDeclaration_isVirtual(FuncDeclaration *self, Dsymbol *p, bool &result)
{
    return CFnone;
}

bool objc_FuncDeclaration_objcPreinitInvariant(FuncDeclaration *self)
{
    return true;
}

// MARK: Utility

void error (const char* format, ...)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// Utility for concatenating names with a prefix
char *prefixSymbolName(const char *name, size_t name_len, const char *prefix, size_t prefix_len)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

int seg_list[SEG_MAX] = {0};

int objc_getsegment(ObjcSegment segid)
{
    assert(false && "Should never be called when D_OBJC is false");
    return 0;
}

// MARK: toObjFile

void objc_FuncDeclaration_toObjFile_extraArgument(FuncDeclaration *self, size_t &pi)
{
    // noop
}

void objc_FuncDeclaration_toObjFile_selfCmd(FuncDeclaration *self, Symbol **params, size_t &pi)
{
    // noop
}

// MARK: Module::genobjfile

void objc_Module_genobjfile_initSymbols()
{
    // noop
}

// MARK: toCBuffer

void objc_toCBuffer_visit_ObjcSelectorExp(OutBuffer *buf, ObjcSelectorExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_toCBuffer_visit_ObjcDotClassExp(OutBuffer *buf, HdrGenState *hgs, ObjcDotClassExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_toCBuffer_visit_ObjcClassRefExp(OutBuffer *buf, ObjcClassRefExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_toCBuffer_visit_ObjcProtocolOfExp(OutBuffer *buf, HdrGenState *hgs, ObjcProtocolOfExp *e)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_inline_visit_ObjcSelectorExp(int &cost)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_interpret_visit_ObjcSelectorExp(ObjcSelectorExp *e, Expression *&result)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_tryMain_dObjc()
{
    // noop
}

void objc_tryMain_init()
{
    // noop
}

// MARK: TypeObjcSelector

TypeObjcSelector::TypeObjcSelector(Type *t)
: TypeNext(Tobjcselector, t)
{
    assert(((TypeFunction *)t)->linkage == LINKobjc);
}

Type *TypeObjcSelector::syntaxCopy()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Type *TypeObjcSelector::semantic(Loc loc, Scope *sc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

d_uns64 TypeObjcSelector::size(Loc loc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return 0;
}

unsigned TypeObjcSelector::alignsize()
{
    assert(false && "Should never be called when D_OBJC is false");
    return 0;
}

MATCH TypeObjcSelector::implicitConvTo(Type *to)
{
    assert(false && "Should never be called when D_OBJC is false");
    return MATCHnomatch;
}

Expression *TypeObjcSelector::defaultInit(Loc loc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

bool TypeObjcSelector::isZeroInit(Loc loc)
{
    assert(false && "Should never be called when D_OBJC is false");
    return false;
}

bool TypeObjcSelector::checkBoolean()
{
    assert(false && "Should never be called when D_OBJC is false");
    return false;
}

Expression *TypeObjcSelector::dotExp(Scope *sc, Expression *e, Identifier *ident, int flag)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

int TypeObjcSelector::hasPointers()
{
    assert(false && "Should never be called when D_OBJC is false");
    return false; // not in GC memory
}

TypeInfoDeclaration *TypeObjcSelector::getTypeInfoDeclaration()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: Type::init

void objc_Type_init(unsigned char sizeTy[TMAX])
{
    // noop
}

// MARK: dotExp

void objc_Type_dotExp_TOKdotvar_setReceiver(ClassDeclaration *&receiver, DotVarExp *dv)
{
    // noop
}

void objc_Type_dotExp_TOKvar_setReceiver(VarDeclaration *v, ClassDeclaration *&receiver)
{
    // noop
}

void objc_Type_dotExp_offsetof(Type *self, Expression *e, ClassDeclaration *receiver)
{
    // noop
}

void objc_TypeClass_dotExp_tupleof(TypeClass *self, Expression *e)
{
    // noop
}

ControlFlow objc_TypeClass_dotExp_protocolof(Scope *sc, Expression *&e, Identifier *ident)
{
    return CFnone;
}

void objc_TypeClass_dotExp_TOKtype(TypeClass *self, Scope *sc, Expression *&e, Declaration *d)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void objc_Expression_optimize_visit_CallExp_Tobjcselector(Type *&t1)
{
    // noop
}

void objc_Parser_parseBasicType2_selector(Type *&t, TypeFunction *tf)
{
    tf->linkage = LINKobjc; // force Objective-C linkage
    t = new TypeObjcSelector(tf);
}

void objc_Parser_parseDeclarations_Tobjcselector(Type *&t, LINK &link)
{
    if (t->ty == Tobjcselector)
        link = LINKobjc; // force Objective-C linkage
}

ControlFlow objc_Parser_parsePostExp_TOKclass(Parser *self, Expression *&e, Loc loc)
{
    e = new ObjcDotClassExp(loc, e);
    self->nextToken();
    return CFcontinue;
}

void mangleToBuffer(Type *t, OutBuffer *buf);

// MARK: Selector

StringTable ObjcSelector::stringtable;
StringTable ObjcSelector::vTableDispatchSelectors;
int ObjcSelector::incnum = 0;

void ObjcSelector::init ()
{
    assert(false && "Should never be called when D_OBJC is false");
}

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount, const char* mangled)
{
    assert(false && "Should never be called when D_OBJC is false");
}

ObjcSelector *ObjcSelector::lookup(ObjcSelectorBuilder *builder)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

ObjcSelector *ObjcSelector::lookup(const char *s)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount, const char* mangled)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

ObjcSelector *ObjcSelector::create(FuncDeclaration *fdecl)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

bool ObjcSelector::isVTableDispatchSelector(const char* selector, size_t length)
{
    assert(false && "Should never be called when D_OBJC is false");
    return false;
}

// MARK: ObjcSelectorBuilder

const char* ObjcSelectorBuilder::fixupSelector (ObjcSelector* selector, const char* fixupName, size_t fixupLength, size_t* fixupSelectorLength)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

void ObjcSelectorBuilder::addIdentifier(Identifier *id)
{
    assert(false && "Should never be called when D_OBJC is false");
}

void ObjcSelectorBuilder::addColon()
{
    assert(false && "Should never be called when D_OBJC is false");
}

int ObjcSelectorBuilder::isValid()
{
    assert(false && "Should never be called when D_OBJC is false");
    return 0;
}

const char *ObjcSelectorBuilder::buildString(char separator)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: callSideEffectLevel

void objc_callSideEffectLevel_Tobjcselector(Type *t, TypeFunction *&tf)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: lambdaHasSideEffect

void objc_lambdaHasSideEffect_TOKcall_Tobjcselector(Type *&t)
{
    assert(false && "Should never be called when D_OBJC is false");
}

Objc_StructDeclaration::Objc_StructDeclaration()
{
    selectorTarget = false;
    isSelector = false;
}

#define DMD_OBJC_ALIGN 2

// MARK: ObjcSymbols

int ObjcSymbols::hassymbols = 0;

Symbol *ObjcSymbols::msgSend = NULL;
Symbol *ObjcSymbols::msgSend_stret = NULL;
Symbol *ObjcSymbols::msgSend_fpret = NULL;
Symbol *ObjcSymbols::msgSendSuper = NULL;
Symbol *ObjcSymbols::msgSendSuper_stret = NULL;
Symbol *ObjcSymbols::msgSend_fixup = NULL;
Symbol *ObjcSymbols::msgSend_stret_fixup = NULL;
Symbol *ObjcSymbols::msgSend_fpret_fixup = NULL;
Symbol *ObjcSymbols::stringLiteralClassRef = NULL;
Symbol *ObjcSymbols::siminfo = NULL;
Symbol *ObjcSymbols::smodinfo = NULL;
Symbol *ObjcSymbols::ssymmap = NULL;
ObjcSymbols *ObjcSymbols::instance = NULL;

StringTable *ObjcSymbols::sclassnametable = NULL;
StringTable *ObjcSymbols::sclassreftable = NULL;
StringTable *ObjcSymbols::smethvarnametable = NULL;
StringTable *ObjcSymbols::smethvarreftable = NULL;
StringTable *ObjcSymbols::smethvartypetable = NULL;
StringTable *ObjcSymbols::sprototable = NULL;
StringTable *ObjcSymbols::sivarOffsetTable = NULL;
StringTable *ObjcSymbols::spropertyNameTable = NULL;
StringTable *ObjcSymbols::spropertyTypeStringTable = NULL;

static StringTable *initStringTable(StringTable *stringtable)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

extern int seg_list[SEG_MAX];

void ObjcSymbols::init()
{
    assert(false && "Should never be called when D_OBJC is false");
}

Symbol *ObjcSymbols::getGlobal(const char* name)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getGlobal(const char* name, type* t)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getCString(const char *str, size_t len, const char *symbolName, ObjcSegment segment)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getSymbolMap(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getClassName(ObjcClassDeclaration* objcClass)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getClassName(ClassDeclaration* cdecl, bool meta)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarName(const char *s, size_t len)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarName(Identifier *ident)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getProtocolSymbol(ClassDeclaration *interface)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: FragileAbiObjcSymbols

Symbol* FragileAbiObjcSymbols::_getClassName(ObjcClassDeclaration *objcClass)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: FragileAbiObjcSymbols

Symbol* NonFragileAbiObjcSymbols::_getClassName(ObjcClassDeclaration *objcClass)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

unsigned totym(Type *tx);

void objc_Type_toCtype_visit_TypeObjcSelector(TypeObjcSelector *t)
{
    assert(false && "Should never be called when D_OBJC is false");
}

static char* buildIVarName (ClassDeclaration* cdecl, VarDeclaration* ivar, size_t* resultLength)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

static const char* getTypeEncoding(Type* type)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: ObjcSymbols

Symbol *ObjcSymbols::getMethVarType(const char *s, size_t len)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarType(Dsymbol **types, size_t dim)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarType(FuncDeclaration *func)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getMethVarType(Dsymbol *s)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getPropertyName(const char* str, size_t len)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getPropertyName(Identifier* ident)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getPropertyTypeString(FuncDeclaration* property)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: NonFragileAbiObjcSymbols

NonFragileAbiObjcSymbols *NonFragileAbiObjcSymbols::instance = NULL;

NonFragileAbiObjcSymbols::NonFragileAbiObjcSymbols()
{
    assert(false && "Should never be called when D_OBJC is false");
}

Symbol *NonFragileAbiObjcSymbols::getClassNameRo(Identifier* ident)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *NonFragileAbiObjcSymbols::getClassNameRo(const char *s, size_t len)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *NonFragileAbiObjcSymbols::getIVarOffset(ClassDeclaration* cdecl, VarDeclaration* ivar, bool outputSymbol)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *NonFragileAbiObjcSymbols::getEmptyCache()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *NonFragileAbiObjcSymbols::getEmptyVTable()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: ObjcClassDeclaration

Symbol *ObjcClassDeclaration::getMetaclass()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcClassDeclaration::getMethodList()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcClassDeclaration::getProtocolList()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcClassDeclaration::getPropertyList()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Dsymbols* ObjcClassDeclaration::getProperties()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: FragileAbiObjcClassDeclaration

void FragileAbiObjcClassDeclaration::toDt(dt_t **pdt)
{
    assert(false && "Should never be called when D_OBJC is false");
}

Symbol *FragileAbiObjcClassDeclaration::getIVarList()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *FragileAbiObjcClassDeclaration::getClassExtension()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: NonFragileAbiObjcClassDeclaration

void NonFragileAbiObjcClassDeclaration::toDt(dt_t **pdt)
{
    assert(false && "Should never be called when D_OBJC is false");
}

Symbol *NonFragileAbiObjcClassDeclaration::getIVarList()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *NonFragileAbiObjcClassDeclaration::getIVarOffset(VarDeclaration* ivar)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *NonFragileAbiObjcClassDeclaration::getClassRo()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

uint32_t NonFragileAbiObjcClassDeclaration::generateFlags ()
{
    assert(false && "Should never be called when D_OBJC is false");
    return 0;
}

unsigned NonFragileAbiObjcClassDeclaration::getInstanceStart ()
{
    assert(false && "Should never be called when D_OBJC is false");
    return 0;
}

// MARK: ObjcProtocolDeclaration

void ObjcProtocolDeclaration::toDt(dt_t **pdt)
{
    assert(false && "Should never be called when D_OBJC is false");
}

Symbol *ObjcProtocolDeclaration::getMethodList(int wantsClassMethods)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcProtocolDeclaration::getProtocolList()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol* FragileAbiObjcProtocolDeclaration::getClassName()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: NonFragileAbiObjcProtocolDeclaration

void NonFragileAbiObjcProtocolDeclaration::toDt(dt_t **pdt)
{
    assert(false && "Should never be called when D_OBJC is false");
}

Symbol* NonFragileAbiObjcProtocolDeclaration::getMethodTypes ()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol* NonFragileAbiObjcProtocolDeclaration::getClassName()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: ObjcSelector

Symbol *ObjcSelector::toNameSymbol()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: ObjcSymbols

Symbol *ObjcSymbols::getImageInfo()
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

Symbol *ObjcSymbols::getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: FragileAbiObjcSymbols

Symbol *FragileAbiObjcSymbols::_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: NonFragileAbiObjcSymbols

Symbol *NonFragileAbiObjcSymbols::_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(false && "Should never be called when D_OBJC is false");
    return NULL;
}

// MARK: FragileAbiObjcClassDeclaration

void FragileAbiObjcClassDeclaration::toObjFile(int multiobj)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: NonFragileAbiObjcClassDeclaration

void NonFragileAbiObjcClassDeclaration::toObjFile(int multiobj)
{
    assert(false && "Should never be called when D_OBJC is false");
}


// MARK: FragileAbiObjcProtocolDeclaration

void FragileAbiObjcProtocolDeclaration::toObjFile(int multiobj)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: NonFragileAbiObjcProtocolDeclaration

void NonFragileAbiObjcProtocolDeclaration::toObjFile(int multiobj)
{
    assert(false && "Should never be called when D_OBJC is false");
}

// MARK: ClassDeclaration

ControlFlow objc_ClassDeclaration_toObjFile(ClassDeclaration *self, bool multiobj)
{
    return CFnone;
}

// MARK: Module::genmoduleinfo

void objc_Module_genmoduleinfo_classes(Module *self)
{
    // noop
}

void objc_TypeInfo_toDt_visit_TypeInfoObjcSelectorDeclaration(dt_t **pdt, TypeInfoObjcSelectorDeclaration *d)
{
    assert(false && "Should never be called when D_OBJC is false");
}
