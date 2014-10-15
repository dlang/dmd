
// Support functions for Objective-C integration with DMD
// Copyright (c) 2010 Michel Fortin
// All Rights Reserved
// http://michelf.com/
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef OBJC_H
#define OBJC_H

#include "root.h"
#include "mtype.h"
#include "stringtable.h"

struct elem;
struct dt_t;

Symbol *toSymbol(Dsymbol *s);

class Identifier;
struct Symbol;
class FuncDeclaration;
class ClassDeclaration;
class InterfaceDeclaration;
class ObjcSelector;
class ObjcClassDeclaration;

enum ObjcSegment
{
    SEGcat_inst_meth,
    SEGcat_cls_meth,
    SEGstring_object,
    SEGcstring_object,
    SEGmessage_refs,
    SEGsel_fixup,
    SEGcls_refs,
    SEGclass,
    SEGmeta_class,
    SEGcls_meth,
    SEGinst_meth,
    SEGprotocol,
    SEGcstring,
    SEGustring,
    SEGcfstring,
    SEGcategory,
    SEGclass_vars,
    SEGinstance_vars,
    SEGmodule_info,
    SEGsymbols,
    SEGprotocol_ext,
    SEGclass_ext,
    SEGproperty,
    SEGimage_info,
    SEGmethname,
    SEGmethtype,
    SEGclassname,
    SEGselrefs,
    SEGobjc_const,
    SEGobjc_ivar,
    SEGobjc_protolist,
    SEG_MAX
};

class ObjcSymbols
{
public:
    static void init();

    static int hassymbols;
    static ObjcSymbols *instance;

    static Symbol *msgSend;
    static Symbol *msgSend_stret;
    static Symbol *msgSend_fpret;
    static Symbol *msgSendSuper;
    static Symbol *msgSendSuper_stret;
    static Symbol *msgSend_fixup;
    static Symbol *msgSend_stret_fixup;
    static Symbol *msgSend_fpret_fixup;
    static Symbol *stringLiteralClassRef;
    static Symbol *siminfo;
    static Symbol *smodinfo;
    static Symbol *ssymmap;
    static Symbol *classListReferences;

    static StringTable *sclassnametable;
    static StringTable *sclassreftable;
    static StringTable *smethvarnametable;
    static StringTable *smethvarreftable;
    static StringTable *smethvartypetable;
    static StringTable *sprototable;
    static StringTable *sivarOffsetTable;
    static StringTable *spropertyNameTable;
    static StringTable *spropertyTypeStringTable;

    static Symbol *getGlobal(const char* name);
    static Symbol *getGlobal(const char* name, type* t);
    static Symbol *getFunction(const char* name);

    static Symbol *getMsgSend(Type *ret, int hasHiddenArg);
    static Symbol *getMsgSendSuper(int hasHiddenArg);
    static Symbol *getMsgSendFixup(Type *returnType, bool hasHiddenArg);
    static Symbol *getStringLiteralClassRef();

    static Symbol *getCString(const char *str, size_t len, const char *symbolName, ObjcSegment segment = SEGcstring);
    static Symbol *getUString(const void *str, size_t len, const char *symbolName);
    static Symbol *getImageInfo();
    static Symbol *getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat);
    static Symbol *getSymbolMap(ClassDeclarations *cls, ClassDeclarations *cat);

    static Symbol *getClassName(ObjcClassDeclaration* cdecl);
    static Symbol *getClassName(ClassDeclaration* cdecl, bool meta = false);
    static Symbol *getClassReference(ClassDeclaration* cdecl);
    static Symbol *getClassListReference(const char *s, size_t len);
    static Symbol *getClassListReference(Identifier *ident);

    static Symbol *getMethVarName(const char *str, size_t len);
    static Symbol *getMethVarName(Identifier *ident);
    static Symbol *getMethVarRef(const char *str, size_t len);
    static Symbol *getMethVarRef(Identifier *ident);
    static Symbol *getMethVarType(const char *str, size_t len);
    static Symbol *getMethVarType(Dsymbol **types, size_t dim);
    static Symbol *getMethVarType(Dsymbol *type);
    static Symbol *getMethVarType(FuncDeclaration *func);

    static Symbol *getMessageReference(ObjcSelector* selector, Type* returnType, bool hasHiddenArg);

    static Symbol *getProtocolSymbol(ClassDeclaration *interface);
    static Symbol *getProtocolName(ClassDeclaration* interface);
    static Symbol *getStringLiteral(const void *str, size_t len, size_t sz);

    static Symbol* getPropertyName(const char* str, size_t len);
    static Symbol* getPropertyName(Identifier* ident);
    static Symbol* getPropertyTypeString(FuncDeclaration* property);

//protected:
    virtual Symbol *_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat) = 0;
    virtual Symbol *_getClassName(ObjcClassDeclaration* cdecl) = 0;
};

class FragileAbiObjcSymbols : public ObjcSymbols
{
//protected:
    Symbol *_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat);
    Symbol *_getClassName(ObjcClassDeclaration* cdecl);
};

class NonFragileAbiObjcSymbols : public ObjcSymbols
{
public:
    static NonFragileAbiObjcSymbols* instance;

    Symbol *emptyCache;
    Symbol *emptyVTable;

    NonFragileAbiObjcSymbols();

    Symbol *getClassNameRo(const char *str, size_t len);
    Symbol *getClassNameRo(Identifier* ident);

    Symbol *getIVarOffset(ClassDeclaration *cdecl, VarDeclaration *ivar, bool outputSymbol);

    Symbol *getEmptyCache();
    Symbol *getEmptyVTable();

//protected:
    Symbol *_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat);
    Symbol *_getClassName(ObjcClassDeclaration* cdecl);
};

// Helper class to efficiently build a selector from identifiers and colon tokens
class ObjcSelectorBuilder
{
public:
    size_t slen;
    Identifier *parts[10];
    size_t partCount;
    int colonCount;

    /**
     * Returns a new string with the selector used for the message reference table.
     *
     * This will bascilly take a selector like "alloc" and an fixup function name
     * like "objc_msgSend_fixup" and concatenate them to "l_objc_msgSend_fixup_alloc".
     *
     * Input:
     *      selector        the selector to take the name from
     *      fixupName       the name of the fixup function
     *      fixupLength     the length of fixupName
     *
     * Output:
     *      outputLength    the length of the returned string
     */
    static const char* fixupSelector (ObjcSelector* selector, const char* fixupName, size_t fixupLength, size_t* outputLength);

    ObjcSelectorBuilder() { partCount = 0; colonCount = 0; slen = 0; }
    void addIdentifier(Identifier *id);
    void addColon();
    int isValid();
    const char *toString() { return buildString(':'); }
    const char *toMangledString() { return buildString('_'); }

private:
    const char* buildString (char separator);
};

class ObjcSelector
{
public:
    static StringTable stringtable;
    static StringTable vTableDispatchSelectors;
    static int incnum;

    const char *stringvalue;
    const char *mangledStringValue;
    size_t stringlen;
    size_t paramCount;

    static void init ();

    ObjcSelector(const char *sv, size_t len, size_t pcount, const char* mangled);
    Symbol *toNameSymbol();
    Symbol *toRefSymbol();
    elem *toElem();
    bool usesVTableDispatch () { return false; }//mangledStringValue != NULL; }

    static ObjcSelector *lookup(ObjcSelectorBuilder *builder);
    static ObjcSelector *lookup(const char *s);
    static ObjcSelector *lookup(const char *s, size_t len, size_t pcount, const char* mangled = NULL);

    static ObjcSelector *create(FuncDeclaration *fdecl);
    static bool isVTableDispatchSelector(const char* selector, size_t length);
};

class ObjcClassRefExp : public Expression
{
public:
    ClassDeclaration *cdecl;

    ObjcClassRefExp(Loc loc, ClassDeclaration *cdecl);

    void accept(Visitor *v) { v->visit(this); }
};

class ObjcDotClassExp : public UnaExp
{
public:
    int noop; // !=0 if nothing needs to be done

    ObjcDotClassExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);

    static FuncDeclaration *classFunc();

    void accept(Visitor *v) { v->visit(this); }
};

class ObjcProtocolOfExp : public UnaExp
{
public:
	InterfaceDeclaration *idecl;
	static ClassDeclaration *protocolClassDecl;

    ObjcProtocolOfExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);

    void accept(Visitor *v) { v->visit(this); }
};


class ObjcClassDeclaration
{
public:
    ClassDeclaration *cdecl;
    int ismeta;
    Symbol *symbol;
    Symbol *sprotocols;
    Symbol *sproperties;

    static ObjcClassDeclaration *create(ClassDeclaration *cdecl, int ismeta = 0);
    static ClassDeclaration *getObjcMetaClass(ClassDeclaration *cdecl);

    ObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta);

    virtual void toObjFile(int multiobj) = 0;
    virtual void toDt(dt_t **pdt) = 0;

    Symbol *getMetaclass();
    virtual Symbol *getIVarList() = 0;
    Symbol *getMethodList();
    Symbol *getProtocolList();
    Symbol *getPropertyList();
    Dsymbols *getProperties();
};

class FragileAbiObjcClassDeclaration : public ObjcClassDeclaration
{
public:
    FragileAbiObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta = 0) :
        ObjcClassDeclaration(cdecl, ismeta) { }

    void toObjFile(int multiobj);
    void toDt(dt_t **pdt);

    Symbol *getIVarList();
    Symbol *getClassExtension();
};

class NonFragileAbiObjcClassDeclaration : public ObjcClassDeclaration
{
public:
    enum NonFragileFlags
    {
        nonFragileFlags_meta = 0x00001,
        nonFragileFlags_root = 0x00002
    };

    NonFragileAbiObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta = 0) :
        ObjcClassDeclaration(cdecl, ismeta) { }

    void toObjFile(int multiobj);
    void toDt(dt_t **pdt);

    Symbol *getIVarList();
    Symbol *getIVarOffset(VarDeclaration* ivar);
    Symbol *getClassRo();
    uint32_t generateFlags();
    unsigned getInstanceStart();
};

class ObjcProtocolDeclaration
{
public:
    ClassDeclaration *idecl;
    Symbol *symbol;

    static ObjcProtocolDeclaration* create(ClassDeclaration *idecl);

    ObjcProtocolDeclaration(ClassDeclaration *idecl);
    virtual void toObjFile(int multiobj) = 0;
    virtual void toDt(dt_t **pdt);

    Symbol *getMethodList(int wantsClassMethods);
    Symbol *getProtocolList();

//protected:
    virtual Symbol *getClassName() = 0;
};

class FragileAbiObjcProtocolDeclaration : public ObjcProtocolDeclaration
{
public:
    FragileAbiObjcProtocolDeclaration(ClassDeclaration *idecl) :
        ObjcProtocolDeclaration(idecl) { }

    void toObjFile(int multiobj);

//protected:
    Symbol *getClassName();
};

class NonFragileAbiObjcProtocolDeclaration : public ObjcProtocolDeclaration
{
public:
    NonFragileAbiObjcProtocolDeclaration(ClassDeclaration *idecl) :
        ObjcProtocolDeclaration(idecl) { }

    void toObjFile(int multiobj);
    void toDt(dt_t **pdt);

    Symbol *getMethodTypes();

//protected:
    Symbol *getClassName();
};

class TypeObjcSelector : public TypeNext
{
public:
    // .next is a TypeFunction

    TypeObjcSelector(Type *t);
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    d_uns64 size(Loc loc);
    unsigned alignsize();
    MATCH implicitConvTo(Type *to);
    Expression *defaultInit(Loc loc);
    bool isZeroInit(Loc loc);
    bool checkBoolean();
    TypeInfoDeclaration *getTypeInfoDeclaration();
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident, int flag);
    int hasPointers();

    void accept(Visitor *v) { v->visit(this); }
};

/***************************************/

class ObjcSelectorExp;
struct IRState;
typedef struct Symbol symbol;

elem *callfunc(Loc loc,
               IRState *irs,
               int directcall,         // 1: don't do virtual call
               Type *tret,             // return type
               elem *ec,               // evaluates to function address
               Type *ectype,           // original type of ec
               FuncDeclaration *fd,    // if !=NULL, this is the function being called
               Type *t,                // TypeDelegate or TypeFunction for this function
               elem *ehidden,          // if !=NULL, this is the 'hidden' argument
               Expressions *arguments,
               elem *esel);      // selector for Objective-C methods (when not provided by fd)

type *Type_toCtype(Type *t);
elem *toElem(Expression *e, IRState *irs);

enum ControlFlow
{
    CFnone,
    CFreturn,
    CFcontinue,
    CFbreak,
    CFvisit,
    CFgoto
};

struct Objc_StructDeclaration
{
    // true if valid target for a selector
    bool selectorTarget;

    // true if represents a selector
    bool isSelector;

    Objc_StructDeclaration();
};

struct Objc_ClassDeclaration
{
    ClassDeclaration* cdecl;

    // true if this is an Objective-C class/interface
    bool objc;

    // true if this is an Objective-C metaclass
    bool meta;

    // true if this is a delcaration for a class defined externally
    bool extern_;

    // true if this class has _dobjc_preinit
    bool hasPreinit;

    // true if this class can represent NSString literals
    bool takesStringLiteral;

    // name of this class
    Identifier *ident;

    // generated symbol for this class (if not objc.extern_)
    Symbol *classSymbol;

    // table of selectors for methods
    StringTable *methods;

    // list of non-inherited methods
    Dsymbols methodList;

    // class declaration for metaclass
    ClassDeclaration *metaclass;

    Objc_ClassDeclaration(ClassDeclaration* cdecl, const char* msg);

    bool isInterface();
    bool isRootClass();

    void addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories);
};

struct Ojbc_FuncDeclaration
{
    FuncDeclaration* fdecl;

    // Objective-C method selector (member function only)
    ObjcSelector *selector;

    // Objective-C implicit selector parameter
    VarDeclaration *vcmd;

    Ojbc_FuncDeclaration(FuncDeclaration* fdecl);

    /*********************************************
     * Create the Objective-C selector for this function if this is a
     * virtual member with Objective-C linkage.
     */
    void createSelector();

    // Returns true if the receiver->fdecl is an Objective-C property.
    bool isProperty();
};

void objc_AttribDeclaration_addObjcSymbols(AttribDeclaration* self, ClassDeclarations *classes, ClassDeclarations *categories);

TypeTuple * objc_toArgTypesVisit (TypeObjcSelector*);

void objc_PragmaDeclaration_semantic_objcTakesStringLiteral(PragmaDeclaration* self, Scope *sc);
void objc_PragmaDeclaration_semantic_objcSelectorTarget(PragmaDeclaration* self, Scope *sc);
void objc_PragmaDeclaration_semantic_objcSelector(PragmaDeclaration* self, Scope *sc);
void objc_PragmaDeclaration_semantic_objcNameOverride(PragmaDeclaration* self, Scope *sc);

void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration *self);
void objc_ClassDeclaration_semantic_SIZEOKnone(ClassDeclaration *self, Scope *sc);
void objc_ClassDeclaration_semantic_staticInitializers(ClassDeclaration *self, Scope *sc2, size_t members_dim);
void objc_ClassDeclaration_semantic_invariant(ClassDeclaration *self, Scope *sc2);

void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration *self, Scope *sc);
ControlFlow objc_InterfaceDeclaration_semantic_mixingObjc(InterfaceDeclaration *self, Scope *sc, size_t i, TypeClass *tc);
void objc_InterfaceDeclaration_semantic_createMetaclass(InterfaceDeclaration *self, Scope *sc);

ControlFlow objc_StringExp_semantic(StringExp *self, Expression *&error);

ControlFlow objc_NewExp_semantic_alloc(NewExp *self, Scope *sc, ClassDeclaration *cd);

ControlFlow objc_IsExp_semantic_TOKobjcselector(IsExp *self, Type *&tded);
void objc_IsExp_semantic_TOKreturn_selector(IsExp *self, Type *&tded);

void objc_CallExp_semantic_opOverload_selector(CallExp *self, Scope *sc, Type *t1);
void objc_CallExp_semantic_noFunction_selector(Type *t1, TypeFunction *&tf, const char *&p);

ObjcSelectorExp * objc_AddrExp_semantic_TOKdotvar_selector(AddrExp *self, DotVarExp *dve, FuncDeclaration *f);
Expression * objc_AddrExp_semantic_TOKvar_selector(AddrExp *self, Scope *sc, VarExp *ve, FuncDeclaration *f);

void objc_FuncDeclaration_semantic_checkAbstractStatic(FuncDeclaration *self);
void objc_FuncDeclaration_semantic_parentForStaticMethod(FuncDeclaration *self, Dsymbol *&parent, ClassDeclaration *&cd);
void objc_FuncDeclaration_semantic_checkInheritedSelector(FuncDeclaration *self, ClassDeclaration *cd);
void objc_FuncDeclaration_semantic_addClassMethodList(FuncDeclaration *self, ClassDeclaration *cd);
void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration *self);

void objc_FuncDeclaration_declareThis(FuncDeclaration *self, Scope *sc, VarDeclaration** vobjccmd, VarDeclaration *v);

ControlFlow objc_implicitConvTo_visit_StringExp_Tclass(Type *t, MATCH *result);
MATCH objc_implicitConvTo_visit_ObjcSelectorExp(Type *&t, ObjcSelectorExp *e);

ControlFlow objc_castTo_visit_StringExp_Tclass(Scope *sc, Type *t, Expression *&result, StringExp *e, Type *tb);
ControlFlow objc_castTo_visit_StringExp_isSelector(Type *t, Expression *&result, StringExp *e, Type *tb);
ControlFlow objc_castTo_visit_SymOffExp_Tobjcselector(Scope *sc, Expression *&result, SymOffExp *e, FuncDeclaration *f);
ControlFlow objc_castTo_visit_DelegateExp_Tobjcselector(Type *t, Expression *&result, DelegateExp *e, Type *tb);
ControlFlow objc_castTo_visit_ObjcSelectorExp(Type *t, Expression *&result, ObjcSelectorExp *e);

void objc_CppMangleVisitor_visit_TypeObjcSelector(OutBuffer &buf, TypeObjcSelector *t);

ControlFlow objc_ScopeDsymbol_multiplyDefined(Dsymbol *s1, Dsymbol *s2);

void objc_callfunc_setupSelector(elem *ec, FuncDeclaration *fd, elem *esel, Type *t, TypeFunction *&tf, elem *&ethis);
void objc_callfunc_setupMethodSelector(Type *tret, FuncDeclaration *fd, Type *t, elem *ehidden, elem *&esel);
void objc_callfunc_setupEp(elem *esel, elem *&ep, int reverse);
void objc_callfunc_checkThisForSelector(elem *esel, elem *ethis);
void objc_callfunc_setupMethodCall(int directcall, elem *&ec, FuncDeclaration *fd, Type *t, elem *&ehidden, elem *&ethis, TypeFunction *tf, Symbol *sfunc);
void objc_callfunc_setupSelectorCall(elem *&ec, elem *ehidden, elem *ethis, TypeFunction *tf);

void objc_toElem_visit_StringExp_Tclass(StringExp *se, elem *&e);
void objc_toElem_visit_NewExp_Tclass(IRState *irs, NewExp *ne, Type *&ectype, TypeClass *tclass, ClassDeclaration *cd, elem *&ex, elem *&ey, elem *&ez);
bool objc_toElem_visit_NewExp_Tclass_isDirectCall(bool isObjc);
void objc_toElem_visit_AssertExp_callInvariant(symbol *&ts, elem *&einv, Type *t1);
void objc_toElem_visit_DotVarExp_nonFragileAbiOffset(VarDeclaration *v, Type *tb1, elem *&offset);
elem * objc_toElem_visit_ObjcSelectorExp(ObjcSelectorExp *ose);
void objc_toElem_visit_CallExp_selector(IRState *irs, CallExp *ce, elem *&ec, elem *&esel);
ControlFlow objc_toElem_visit_CastExp_Tclass_fromObjc(int &rtl, ClassDeclaration *cdfrom, ClassDeclaration *cdto);
ControlFlow objc_toElem_visit_CastExp_Tclass_toObjc();
void objc_toElem_visit_CastExp_Tclass_fromObjcToObjcInterface(int &rtl);
void objc_toElem_visit_CastExp_Tclass_assertNoOffset(int offset, ClassDeclaration *cdfrom);
ControlFlow objc_toElem_visit_CastExp_Tclass_toObjcCall(elem *&e, int rtl, ClassDeclaration *cdto);
elem *objc_toElem_visit_ObjcDotClassExp(IRState *irs, ObjcDotClassExp *odce);
elem *objc_toElem_visit_ObjcClassRefExp(ObjcClassRefExp *ocre);
elem *objc_toElem_visit_ObjcProtocolOfExp(ObjcProtocolOfExp *e);

ControlFlow objc_getRightThis(AggregateDeclaration *ad, Expression *&e1, Declaration *var);

#endif