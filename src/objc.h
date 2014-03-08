
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

struct Identifier;
struct Symbol;
struct FuncDeclaration;
struct ClassDeclaration;
struct InterfaceDeclaration;
struct ObjcSelector;
struct ObjcClassDeclaration;

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

struct ObjcSymbols
{
    static void init();

    static int hassymbols;

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
    static Symbol *emptyCache;
    static Symbol *emptyVTable;

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
    static Symbol *getClassNameRo(const char *str, size_t len);
    static Symbol *getClassNameRo(Identifier* ident);
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
    static Symbol *getIVarOffset(ClassDeclaration *cdecl, VarDeclaration *ivar);

    static Symbol *getMessageReference(ObjcSelector* selector, Type* returnType, bool hasHiddenArg);

    static Symbol *getProtocolSymbol(ClassDeclaration *interface);
    static Symbol *getProtocolName(ClassDeclaration* interface);
    static Symbol *getStringLiteral(const void *str, size_t len, size_t sz);

    static Symbol *getEmptyCache();
    static Symbol *getEmptyVTable();

    static Symbol* getPropertyName(const char* str, size_t len);
    static Symbol* getPropertyName(Identifier* ident);
    static Symbol* getPropertyTypeString(FuncDeclaration* property);
};

// Helper class to efficiently build a selector from identifiers and colon tokens
struct ObjcSelectorBuilder
{
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

struct ObjcSelector
{
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

struct ObjcClassRefExp : Expression
{
    ClassDeclaration *cdecl;

    ObjcClassRefExp(Loc loc, ClassDeclaration *cdecl);

    void accept(Visitor *v) { v->visit(this); }
};

struct ObjcDotClassExp : UnaExp
{
    int noop; // !=0 if nothing needs to be done

    ObjcDotClassExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);

    static FuncDeclaration *classFunc();

    void accept(Visitor *v) { v->visit(this); }
};

struct ObjcProtocolOfExp : UnaExp
{
	InterfaceDeclaration *idecl;
	static ClassDeclaration *protocolClassDecl;

    ObjcProtocolOfExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);

    void accept(Visitor *v) { v->visit(this); }
};


struct ObjcClassDeclaration
{
    enum NonFragileFlags
    {
        nonFragileFlags_meta = 0x00001,
        nonFragileFlags_root = 0x00002
    };

    ClassDeclaration *cdecl;
    int ismeta;
    Symbol *symbol;
    Symbol *sprotocols;
    Symbol *sproperties;

    static ClassDeclaration *getObjcMetaClass(ClassDeclaration *cdecl);

    ObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta = 0);
    void toObjFile(int multiobj);
    void toDt(dt_t **pdt);

    Symbol *getMetaclass();
    Symbol *getIVarList();
    Symbol *getMethodList();
    Symbol *getProtocolList();
    Symbol *getPropertyList();
    Dsymbols *getProperties();
    Symbol *getClassRo();
    Symbol *getClassExtension();
    uint32_t generateFlags ();
};

struct ObjcProtocolDeclaration
{
    ClassDeclaration *idecl;
    Symbol *symbol;

    ObjcProtocolDeclaration(ClassDeclaration *idecl);
    void toObjFile(int multiobj);
    void toDt(dt_t **pdt);

    Symbol *getMethodList(int wantsClassMethods);
    Symbol *getProtocolList();
    Symbol *getMethodTypes();
};

struct TypeObjcSelector : TypeNext
{
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

#endif