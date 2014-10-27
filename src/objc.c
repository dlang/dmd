
#include "objc.h"
#include "identifier.h"
#include "dsymbol.h"
#include "declaration.h"
#include "aggregate.h"
#include "target.h"
#include "id.h"
#include "attrib.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "objc_glue.h"

// Backend
#include "cc.h"
#include "dt.h"
#include "type.h"
#include "mtype.h"
#include "oper.h"
#include "global.h"
#include "mach.h"
#include "scope.h"

void mangleToBuffer(Type *t, OutBuffer *buf);

#define DMD_OBJC_ALIGN 2

static char* buildIVarName (ClassDeclaration* cdecl, VarDeclaration* ivar, size_t* resultLength)
{
    const char* className = cdecl->objc.ident->string;
    size_t classLength = cdecl->objc.ident->len;
    const char* ivarName = ivar->ident->string;
    size_t ivarLength = ivar->ident->len;

    // Ensure we have a long-enough buffer for the symbol name. Previous buffer is reused.
    static const char* prefix = "_OBJC_IVAR_$_";
    static size_t prefixLength = 13;
    static char* name;
    static size_t length;
    size_t requiredLength = prefixLength + classLength + 1 + ivarLength;

    if (requiredLength + 1 >= length)
    {
        length = requiredLength + 12;
        name = (char*) realloc(name, length);
    }

    // Create symbol name _OBJC_IVAR_$_<ClassName>.<IvarName>
    memmove(name, prefix, prefixLength);
    memmove(name + prefixLength, className, classLength);
    memmove(name + prefixLength + classLength + 1, ivarName, ivarLength);
    name[prefixLength + classLength] = '.';
    name[requiredLength] = 0;

    *resultLength = requiredLength;
    return name;
}

static const char* getTypeEncoding(Type* type)
{
    if (type == Type::tvoid)            return "v";
    else if (type == Type::tint8)       return "c";
    else if (type == Type::tuns8)       return "C";
    else if (type == Type::tchar)       return "C";
    else if (type == Type::tint16)      return "s";
    else if (type == Type::tuns16)      return "S";
    else if (type == Type::twchar)      return "S";
    else if (type == Type::tint32)      return "l";
    else if (type == Type::tuns32)      return "L";
    else if (type == Type::tdchar)      return "L";
    else if (type == Type::tint64)      return "q";
    else if (type == Type::tuns64)      return "Q";
    else if (type == Type::tfloat32)     return "f";
    else if (type == Type::timaginary32) return "f";
    else if (type == Type::tfloat64)     return "d";
    else if (type == Type::timaginary64) return "d";
    else if (type == Type::tfloat80)     return "d"; // "float80" is "long double" in Objective-C, but "long double" has no specific
    else if (type == Type::timaginary80) return "d"; // encoding character documented. Since @encode in Objective-C outputs "d", which is the same as "double", that's what we do here. But it doesn't look right.

    else                                 return "?"; // unknown
    // TODO: add "B" BOOL, "*" char*, "#" Class, "@" id, ":" SEL
    // TODO: add "^"<type> indirection and "^^" double indirection
}

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
    delete stringtable;
    stringtable = new StringTable();
    stringtable->_init();

    return stringtable;
}

extern int seg_list[SEG_MAX];

void ObjcSymbols::init()
{
    if (global.params.isObjcNonFragileAbi)
        instance = new NonFragileAbiObjcSymbols();
    else
        instance = new FragileAbiObjcSymbols();

    hassymbols = 0;

    msgSend = NULL;
    msgSend_stret = NULL;
    msgSend_fpret = NULL;
    msgSendSuper = NULL;
    msgSendSuper_stret = NULL;
    stringLiteralClassRef = NULL;
    siminfo = NULL;
    smodinfo = NULL;
    ssymmap = NULL;

    // clear tables
    sclassnametable = initStringTable(sclassnametable);
    sclassreftable = initStringTable(sclassreftable);
    smethvarnametable = initStringTable(smethvarnametable);
    smethvarreftable = initStringTable(smethvarreftable);
    smethvartypetable = initStringTable(smethvartypetable);
    sprototable = initStringTable(sprototable);
    sivarOffsetTable = initStringTable(sivarOffsetTable);
    spropertyNameTable = initStringTable(spropertyNameTable);
    spropertyTypeStringTable = initStringTable(spropertyTypeStringTable);

    // also wipe out segment numbers
    for (int s = 0; s < SEG_MAX; ++s)
        seg_list[s] = 0;
}

Symbol *ObjcSymbols::getGlobal(const char* name)
{
    return symbol_name(name, SCglobal, type_fake(TYnptr));
}

Symbol *ObjcSymbols::getGlobal(const char* name, type* t)
{
    return symbol_name(name, SCglobal, t);
}

Symbol *ObjcSymbols::getFunction(const char* name)
{
    return getGlobal(name, type_fake(TYhfunc));
}

Symbol *ObjcSymbols::getMsgSend(Type *ret, int hasHiddenArg)
{
    if (hasHiddenArg)
    {   if (!msgSend_stret)
            msgSend_stret = symbol_name("_objc_msgSend_stret", SCglobal, type_fake(TYhfunc));
        return msgSend_stret;
    }
    else if (ret->isfloating())
    {   if (!msgSend_fpret)
            msgSend_fpret = symbol_name("_objc_msgSend_fpret", SCglobal, type_fake(TYnfunc));
        return msgSend_fpret;
    }
    else
    {   if (!msgSend)
            msgSend = symbol_name("_objc_msgSend", SCglobal, type_fake(TYnfunc));
        return msgSend;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getMsgSendSuper(int hasHiddenArg)
{
    if (hasHiddenArg)
    {   if (!msgSendSuper_stret)
            msgSendSuper_stret = symbol_name("_objc_msgSendSuper_stret", SCglobal, type_fake(TYhfunc));
        return msgSendSuper_stret;
    }
    else
    {   if (!msgSendSuper)
            msgSendSuper = symbol_name("_objc_msgSendSuper", SCglobal, type_fake(TYnfunc));
        return msgSendSuper;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getMsgSendFixup(Type* returnType, bool hasHiddenArg)
{
    if (hasHiddenArg)
    {
        if (!msgSend_stret_fixup)
            msgSend_stret_fixup = getFunction("_objc_msgSend_stret_fixup");
        return msgSend_stret_fixup;
    }
    else if (returnType->isfloating())
    {
        if (!msgSend_fpret_fixup)
            msgSend_fpret_fixup = getFunction("_objc_msgSend_fpret_fixup");
        return msgSend_fpret_fixup;
    }
    else
    {
        if (!msgSend_fixup)
            msgSend_fixup = getFunction("_objc_msgSend_fixup");
        return msgSend_fixup;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getStringLiteralClassRef()
{
    if (!stringLiteralClassRef)
        stringLiteralClassRef = symbol_name("___CFConstantStringClassReference", SCglobal, type_fake(TYnptr));
    return stringLiteralClassRef;
}

Symbol *ObjcSymbols::getCString(const char *str, size_t len, const char *symbolName, ObjcSegment segment)
{
    hassymbols = 1;

    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, len + 1, str);

    // find segment
    int seg = objc_getsegment(segment);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tschar));
    s->Sdt = dt;
    s->Sseg = seg;
    return s;
}

Symbol *ObjcSymbols::getUString(const void *str, size_t len, const char *symbolName)
{
    hassymbols = 1;

    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, (len + 1)*2, (const char *)str);

    // find segment
    int seg = objc_getsegment(SEGustring);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tschar));
    s->Sdt = dt;
    s->Sseg = seg;
    return s;
}

Symbol *ObjcSymbols::getImageInfo()
{
    assert(!siminfo); // only allow once per object file
    hassymbols = 1;

    dt_t *dt = NULL;
    dtdword(&dt, 0); // version
    dtdword(&dt, global.params.isObjcNonFragileAbi ? 0 : 16); // flags

    siminfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tschar));
    siminfo->Sdt = dt;
    siminfo->Sseg = objc_getsegment(SEGimage_info);
    outdata(siminfo);

    return siminfo;
}

Symbol *ObjcSymbols::getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(!smodinfo); // only allow once per object file
    smodinfo = instance->_getModuleInfo(cls, cat);
    ObjcSymbols::getImageInfo(); // make sure we also generate image info

    return smodinfo;
}

Symbol *ObjcSymbols::getSymbolMap(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(!ssymmap); // only allow once per object file

    size_t classcount = cls->dim;
    size_t catcount = cat->dim;

    dt_t *dt = NULL;
    dtdword(&dt, 0); // selector refs count (unused)
    dtdword(&dt, 0); // selector refs ptr (unused)
    dtdword(&dt, classcount + (catcount << 16)); // class count / category count (expects little-endian)

    for (size_t i = 0; i < cls->dim; ++i)
        dtxoff(&dt, cls->tdata()[i]->objc.classSymbol, 0, TYnptr); // reference to class

    for (size_t i = 0; i < catcount; ++i)
        dtxoff(&dt, cat->tdata()[i]->objc.classSymbol, 0, TYnptr); // reference to category

    ssymmap = symbol_name("L_OBJC_SYMBOLS", SCstatic, type_allocn(TYarray, tschar));
    ssymmap->Sdt = dt;
    ssymmap->Sseg = objc_getsegment(SEGsymbols);
    outdata(ssymmap);

    return ssymmap;
}

Symbol *ObjcSymbols::getClassName(ObjcClassDeclaration* objcClass)
{
    return instance->_getClassName(objcClass);
}

Symbol *ObjcSymbols::getClassName(ClassDeclaration* cdecl, bool meta)
{
    ObjcClassDeclaration* objcClass = ObjcClassDeclaration::create(cdecl, meta);
    return ObjcSymbols::getClassName(objcClass);
}

Symbol *ObjcSymbols::getClassReference(ClassDeclaration* cdecl)
{
    hassymbols = 1;
    const char* s = cdecl->objc.ident->string;
    size_t len = cdecl->objc.ident->len;

    StringValue *sv = sclassreftable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        // create data
        dt_t *dt = NULL;
        Symbol *sclsname = getClassName(cdecl);
        dtxoff(&dt, sclsname, 0, TYnptr);

        // find segment for class references
        int seg = objc_getsegment(SEGcls_refs);

        static size_t classrefcount = 0;
        const char* prefix = global.params.isObjcNonFragileAbi ? "L_OBJC_CLASSLIST_REFERENCES_$_" : "L_OBJC_CLASS_REFERENCES_%lu";

        char namestr[42];
        sprintf(namestr, prefix, classrefcount++);
        sy = symbol_name(namestr, SCstatic, type_fake(TYnptr));
        sy->Sdt = dt;
        sy->Sseg = seg;
        outdata(sy);

        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *ObjcSymbols::getMethVarName(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = smethvarnametable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_METH_VAR_NAME_%lu", classnamecount++);
        sy = getCString(s, len, namestr, SEGmethname);
        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *ObjcSymbols::getMethVarName(Identifier *ident)
{
    return getMethVarName(ident->string, ident->len);
}

Symbol *ObjcSymbols::getMethVarRef(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = smethvarreftable->update(s, len);
    Symbol *refsymbol = (Symbol *) sv->ptrvalue;
    if (refsymbol == NULL)
    {
        // create data
        dt_t *dt = NULL;
        Symbol *sselname = getMethVarName(s, len);
        dtxoff(&dt, sselname, 0*0x9877660, TYnptr);

        // find segment
        int seg = objc_getsegment(SEGselrefs);

        // create symbol
        static size_t selcount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_SELECTOR_REFERENCES_%lu", selcount);
        refsymbol = symbol_name(namestr, SCstatic, type_fake(TYnptr));

        refsymbol->Sdt = dt;
        refsymbol->Sseg = seg;
        outdata(refsymbol);
        sv->ptrvalue = refsymbol;

        ++selcount;
    }
    return refsymbol;
}

Symbol *ObjcSymbols::getMethVarRef(Identifier *ident)
{
    return getMethVarRef(ident->string, ident->len);
}


Symbol *ObjcSymbols::getMethVarType(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = smethvartypetable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_METH_VAR_TYPE_%lu", classnamecount++);
        sy = getCString(s, len, namestr, SEGmethtype);
        sv->ptrvalue = sy;
        outdata(sy);
    }
    return sy;
}

Symbol *ObjcSymbols::getMethVarType(Dsymbol **types, size_t dim)
{
    // Ensure we have a long-enough buffer for the symbol name. Previous buffer is reused.
    static char *typecode = NULL;
    static size_t typecode_cap = 0;
    size_t typecode_len = 0;

    for (size_t i = 0; i < dim; ++i) {
        Type *type;

        if (FuncDeclaration* func = types[i]->isFuncDeclaration())
            type = func->type->nextOf();
        else
            type = types[i]->getType();

        const char *typestr = getTypeEncoding(type);

        // Append character
        // Ensure enough length
        if (typecode_len + 1 >= typecode_cap)
        {   typecode_cap += typecode_len + 12;
            typecode = (char *)realloc(typecode, typecode_cap);
        }
        typecode[typecode_len] = typestr[0];
        ++typecode_len;
    }

    if (typecode_len + 1 >= typecode_cap)
    {   typecode_cap += typecode_len + 12;
        typecode = (char *)realloc(typecode, typecode_cap);
    }
    typecode[typecode_len] = 0; // zero-terminated

    return getMethVarType(typecode, typecode_len);
}

Symbol *ObjcSymbols::getMethVarType(FuncDeclaration *func)
{
    static Dsymbol **types;
    static size_t types_dim;

    size_t param_dim = func->parameters ? func->parameters->dim : 0;
    if (types_dim < 1 + param_dim)
    {   types_dim = 1 + param_dim + 8;
        types = (Dsymbol **)realloc(types, types_dim * sizeof(Dsymbol **));
    }
    types[0] = func; // return type first
    if (param_dim)
        memcpy(types+1, func->parameters->tdata(), param_dim * sizeof(Dsymbol **));

    return getMethVarType(types, 1 + param_dim);
}

Symbol *ObjcSymbols::getMethVarType(Dsymbol *s)
{
    return getMethVarType(&s, 1);
}

Symbol *ObjcSymbols::getMessageReference(ObjcSelector* selector, Type* returnType, bool hasHiddenArg)
{
    assert(selector->usesVTableDispatch());
    hassymbols = 1;

    Symbol* msgSendFixup = ObjcSymbols::getMsgSendFixup(returnType, hasHiddenArg);
    Symbol* selectorSymbol = getMethVarName(selector->stringvalue, selector->stringlen);
    size_t msgSendFixupLength = strlen(msgSendFixup->Sident);
    size_t fixupSelectorLength = 0;
    const char* fixupSelector = ObjcSelectorBuilder::fixupSelector(selector, msgSendFixup->Sident, msgSendFixupLength, &fixupSelectorLength);

    StringValue *sv = smethvarreftable->update(fixupSelector, fixupSelectorLength);
    Symbol *refsymbol = (Symbol *) sv->ptrvalue;
    if (refsymbol == NULL)
    {
        // create data
        dt_t* dt = NULL;
        dtxoff(&dt, msgSendFixup, 0, TYnptr);
        dtxoff(&dt, selectorSymbol, 0, TYnptr);

        // find segment
        int segment = objc_getsegment(SEGmessage_refs);

        // create symbol
        refsymbol = symbol_name(fixupSelector, SCstatic, type_fake(TYnptr));
        refsymbol->Sdt = dt;
        refsymbol->Sseg = segment;
        refsymbol->Salignment = 16;
        outdata(refsymbol);
        sv->ptrvalue = refsymbol;
    }
    return refsymbol;
}

Symbol *ObjcSymbols::getProtocolSymbol(ClassDeclaration *interface)
{
    hassymbols = 1;

    assert(interface->objc.meta == 0);

    StringValue *sv = sprototable->update(interface->objc.ident->string, interface->objc.ident->len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        ObjcProtocolDeclaration* p = ObjcProtocolDeclaration::create(interface);
        p->toObjFile(0);
        sy = p->symbol;
        sv->ptrvalue = sy;
    }
    return sy;
}


Symbol *ObjcSymbols::getStringLiteral(const void *str, size_t len, size_t sz)
{
    hassymbols = 1;

    // Objective-C NSString literal (also good for CFString)
    static size_t strcount = 0;
    char namestr[24];
    sprintf(namestr, "l_.str%lu", strcount);
    Symbol *sstr;
    if (sz == 1)
        sstr = getCString((const char *)str, len, namestr);
    else
        sstr = getUString(str, len, namestr);

    dt_t *dt = NULL;
    dtxoff(&dt, getStringLiteralClassRef(), 0, TYnptr);
    dtdword(&dt, sz == 1 ? 1992 : 2000);

    if (global.params.isObjcNonFragileAbi)
        dtdword(&dt, 0); // .space 4

    dtxoff(&dt, sstr, 0, TYnptr);
    dtsize_t(&dt, len);

    sprintf(namestr, "L__unnamed_cfstring_%lu", strcount++);
    Symbol *si = symbol_name(namestr, SCstatic, type_fake(TYnptr));
    si->Sdt = dt;
    si->Sseg = objc_getsegment(SEGcfstring);
    outdata(si);
    return si;
}

Symbol *ObjcSymbols::getPropertyName(const char* str, size_t len)
{
    hassymbols = 1;
    StringValue* sv = spropertyNameTable->update(str, len);
    Symbol* symbol = (Symbol*) sv->ptrvalue;

    if (!symbol)
    {
        static size_t propertyNameCount = 0;
        char nameStr[42];
        sprintf(nameStr, "L_OBJC_PROP_NAME_ATTR_%lu", propertyNameCount++);
        symbol = getCString(str, len, nameStr);
        sv->ptrvalue = symbol;
    }

    return symbol;
}

Symbol *ObjcSymbols::getPropertyName(Identifier* ident)
{
    return getPropertyName(ident->string, ident->len);
}

Symbol *ObjcSymbols::getPropertyTypeString(FuncDeclaration* property)
{
    assert(property->objc.isProperty());

    TypeFunction* type = (TypeFunction*) property->type;
    Type* propertyType = type->next->ty != TYvoid ? type->next : (*type->parameters)[0]->type;
    const char* typeEncoding = getTypeEncoding(propertyType);
    size_t len = strlen(typeEncoding);
    size_t nameLength = 1 + len;

    // Method encodings are not handled
    char* name = (char*) malloc(nameLength + 1);
    name[0] = 'T';
    memmove(name + 1, typeEncoding, len);
    name[nameLength] = 0;

    return getPropertyName(name, nameLength);
}

// MARK: FragileAbiObjcSymbols

Symbol *FragileAbiObjcSymbols::_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    dt_t *dt = NULL;

    dtdword(&dt, 7);  // version
    dtdword(&dt, 16); // size
    dtxoff(&dt, ObjcSymbols::getCString("", 0, "L_CLASS_NAME_"), 0, TYnptr); // name
    dtxoff(&dt, ObjcSymbols::getSymbolMap(cls, cat), 0, TYnptr); // symtabs

    Symbol* symbol = symbol_name("L_OBJC_MODULE_INFO", SCstatic, type_allocn(TYarray, tschar));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGmodule_info);
    outdata(symbol);

    return symbol;
}

Symbol* FragileAbiObjcSymbols::_getClassName(ObjcClassDeclaration *objcClass)
{
    hassymbols = 1;
    ClassDeclaration* cdecl = objcClass->cdecl;
    const char* s = cdecl->objc.ident->string;
    size_t len = cdecl->objc.ident->len;

    StringValue *sv = sclassnametable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_CLASS_NAME_%lu", classnamecount++);
        sy = getCString(s, len, namestr, SEGclassname);
        sv->ptrvalue = sy;
    }
    return sy;
}

// MARK: NonFragileAbiObjcSymbols

NonFragileAbiObjcSymbols *NonFragileAbiObjcSymbols::instance = NULL;

NonFragileAbiObjcSymbols::NonFragileAbiObjcSymbols()
{
    emptyCache = NULL;
    emptyVTable = NULL;
    instance = (NonFragileAbiObjcSymbols*) ObjcSymbols::instance;
}

Symbol *NonFragileAbiObjcSymbols::getClassNameRo(Identifier* ident)
{
    return getClassNameRo(ident->string, ident->len);
}

Symbol *NonFragileAbiObjcSymbols::getClassNameRo(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = sclassnametable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_CLASS_NAME_%lu", classnamecount++);
        sy = getCString(s, len, namestr, SEGclassname);
        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *NonFragileAbiObjcSymbols::getIVarOffset(ClassDeclaration* cdecl, VarDeclaration* ivar, bool outputSymbol)
{
    hassymbols = 1;

    size_t length;
    const char* name = buildIVarName(cdecl, ivar, &length);
    StringValue* stringValue = sivarOffsetTable->update(name, length);
    Symbol* symbol = (Symbol*) stringValue->ptrvalue;

    if (!symbol)
    {
        symbol = getGlobal(name);
        stringValue->ptrvalue = symbol;
        symbol->Sfl |= FLextern;
    }

    if (outputSymbol)
    {
        dt_t* dt = NULL;
        dtsize_t(&dt, ivar->offset);

        symbol->Sdt = dt;
        symbol->Sseg = objc_getsegment(SEGobjc_ivar);
        symbol->Sfl &= ~FLextern;

        outdata(symbol);
    }

    return  symbol;
}

Symbol *NonFragileAbiObjcSymbols::getEmptyCache()
{
    hassymbols = 1;

    return emptyCache = emptyCache ? emptyCache : getGlobal("__objc_empty_cache");
}

Symbol *NonFragileAbiObjcSymbols::getEmptyVTable()
{
    hassymbols = 1;

    return emptyVTable = emptyVTable ? emptyVTable : getGlobal("__objc_empty_vtable");
}

Symbol *NonFragileAbiObjcSymbols::_getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    dt_t *dt = NULL;

    for (size_t i = 0; i < cls->dim; i++)
        dtxoff(&dt, ObjcSymbols::getClassName((*cls)[i]), 0, TYnptr);

    for (size_t i = 0; i < cat->dim; i++)
        dtxoff(&dt, ObjcSymbols::getClassName((*cat)[i]), 0, TYnptr);

    Symbol* symbol = symbol_name("L_OBJC_LABEL_CLASS_$", SCstatic, type_allocn(TYarray, tschar));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGmodule_info);
    outdata(symbol);

    return symbol;
}

Symbol* NonFragileAbiObjcSymbols::_getClassName(ObjcClassDeclaration *objcClass)
{
    hassymbols = 1;
    ClassDeclaration* cdecl = objcClass->cdecl;
    const char* s = cdecl->objc.ident->string;
    size_t len = cdecl->objc.ident->len;

    const char* prefix = objcClass->ismeta ? "_OBJC_METACLASS_$_" : "_OBJC_CLASS_$_";
    const size_t prefixLength = objcClass->ismeta ? 18 : 14;
    s = prefixSymbolName(s, len, prefix, prefixLength);
    len += prefixLength;

    StringValue *sv = sclassnametable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        sy = getGlobal(s);
        sv->ptrvalue = sy;
    }
    return sy;
}

// MARK: ObjcSelectorBuilder

const char* ObjcSelectorBuilder::fixupSelector (ObjcSelector* selector, const char* fixupName, size_t fixupLength, size_t* fixupSelectorLength)
{
    assert(selector->usesVTableDispatch());

    size_t length = 1 + fixupLength + 1 + selector->stringlen + 1; // + 1 for the 'l' prefix, '_' and trailing \0
    char* fixupSelector = (char*) malloc(length * sizeof(char));
    fixupSelector[0] = 'l';
    size_t position = 1;

    memcpy(fixupSelector + position, fixupName, fixupLength);
    position += fixupLength;
    fixupSelector[position] = '_';
    position++;

    memcpy(fixupSelector + position, selector->mangledStringValue, selector->stringlen);
    fixupSelector[length - 1] = '\0';

    *fixupSelectorLength = length - 1;
    return fixupSelector;
}

void ObjcSelectorBuilder::addIdentifier(Identifier *id)
{
    assert(partCount < 10);
    parts[partCount] = id;
    slen += id->len;
    partCount += 1;
}

void ObjcSelectorBuilder::addColon()
{
    slen += 1;
    colonCount += 1;
}

int ObjcSelectorBuilder::isValid()
{
    if (colonCount == 0)
        return partCount == 1;
    else
        return partCount >= 1 && partCount <= colonCount;
}

const char *ObjcSelectorBuilder::buildString(char separator)
{
    char *s = (char*)malloc(slen + 1);
    size_t spos = 0;
    for (size_t i = 0; i < partCount; ++i)
    {
        memcpy(&s[spos], parts[i]->string, parts[i]->len);
        spos += parts[i]->len;
        if (colonCount)
        {   s[spos] = separator;
            spos += 1;
        }
    }
    assert(colonCount == 0 || partCount <= colonCount);
    if (colonCount > partCount)
    {
        for (size_t i = 0; i < colonCount - partCount; ++i)
        {   s[spos] = separator;
            spos += 1;
        }
    }
    assert(slen == spos);
    s[slen] = '\0';
    return s;
}


// MARK: Selector

StringTable ObjcSelector::stringtable;
StringTable ObjcSelector::vTableDispatchSelectors;
int ObjcSelector::incnum = 0;

void ObjcSelector::init ()
{
    stringtable._init();
    vTableDispatchSelectors._init();

    if (global.params.isObjcNonFragileAbi)
    {
        vTableDispatchSelectors.insert("alloc", 5);
        vTableDispatchSelectors.insert("class", 5);
        vTableDispatchSelectors.insert("self", 4);
        vTableDispatchSelectors.insert("isFlipped", 9);
        vTableDispatchSelectors.insert("length", 6);
        vTableDispatchSelectors.insert("count", 5);

        vTableDispatchSelectors.insert("allocWithZone:", 14);
        vTableDispatchSelectors.insert("isKindOfClass:", 14);
        vTableDispatchSelectors.insert("respondsToSelector:", 19);
        vTableDispatchSelectors.insert("objectForKey:", 13);
        vTableDispatchSelectors.insert("objectAtIndex:", 14);
        vTableDispatchSelectors.insert("isEqualToString:", 16);
        vTableDispatchSelectors.insert("isEqual:", 8);

        // These three use vtable dispatch if the Objective-C GC is disabled
        vTableDispatchSelectors.insert("retain", 6);
        vTableDispatchSelectors.insert("release", 7);
        vTableDispatchSelectors.insert("autorelease", 11);

        // These three use vtable dispatch if the Objective-C GC is enabled
        // vTableDispatchSelectors.insert("hash", 4);
        // vTableDispatchSelectors.insert("addObject:", 10);
        // vTableDispatchSelectors.insert("countByEnumeratingWithState:objects:count:", 42);
    }
}

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount, const char* mangled)
{
    stringvalue = sv;
    stringlen = len;
    paramCount = pcount;
    mangledStringValue = mangled;
}

ObjcSelector *ObjcSelector::lookup(ObjcSelectorBuilder *builder)
{
    const char* stringValue = builder->toString();
    const char* mangledStringValue = NULL;

    if (ObjcSelector::isVTableDispatchSelector(stringValue, builder->slen))
        mangledStringValue = builder->toMangledString();

    return lookup(stringValue, builder->slen, builder->colonCount, mangledStringValue);
}

ObjcSelector *ObjcSelector::lookup(const char *s)
{
	size_t len = 0;
	size_t pcount = 0;
	const char *i = s;
	while (*i != 0)
	{	++len;
		if (*i == ':') ++pcount;
		++i;
	}
	return lookup(s, len, pcount);
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount, const char* mangled)
{
    StringValue *sv = stringtable.update(s, len);
    ObjcSelector *sel = (ObjcSelector *) sv->ptrvalue;
    if (!sel)
    {
        sel = new ObjcSelector(sv->toDchars(), len, pcount, mangled);
        sv->ptrvalue = sel;
    }
    return sel;
}

ObjcSelector *ObjcSelector::create(FuncDeclaration *fdecl)
{
    OutBuffer buf;
    size_t pcount = 0;
    TypeFunction *ftype = (TypeFunction *)fdecl->type;

    // Special case: property setter
    if (ftype->isproperty && ftype->parameters && ftype->parameters->dim == 1)
    {   // rewrite "identifier" as "setIdentifier"
        char firstChar = fdecl->ident->string[0];
        if (firstChar >= 'a' && firstChar <= 'z')
            firstChar = firstChar - 'a' + 'A';

        buf.write("set", 3);
        buf.writeByte(firstChar);
        buf.write(fdecl->ident->string+1, fdecl->ident->len-1);
        buf.writeByte(':');
        goto Lcomplete;
    }

    // write identifier in selector
    buf.write(fdecl->ident->string, fdecl->ident->len);

    // add mangled type and colon for each parameter
    if (ftype->parameters && ftype->parameters->dim)
    {
        buf.writeByte('_');
        Parameters *arguments = ftype->parameters;
        size_t dim = Parameter::dim(arguments);
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = Parameter::getNth(arguments, i);
            mangleToBuffer(arg->type, &buf);
            buf.writeByte(':');
        }
        pcount = dim;
    }
Lcomplete:
    buf.writeByte('\0');

    return lookup((const char *)buf.data, buf.size, pcount);
}

bool ObjcSelector::isVTableDispatchSelector(const char* selector, size_t length)
{
    return global.params.isObjcNonFragileAbi && vTableDispatchSelectors.lookup(selector, length) != NULL;
}

Symbol *ObjcSelector::toNameSymbol()
{
    return ObjcSymbols::getMethVarName(stringvalue, stringlen);
}

Symbol *ObjcSelector::toRefSymbol()
{
    return ObjcSymbols::getMethVarRef(stringvalue, stringlen);
}

elem *ObjcSelector::toElem()
{
    return el_var(toRefSymbol());
}

// MARK: Class References

ObjcClassRefExp::ObjcClassRefExp(Loc loc, ClassDeclaration *cdecl)
    : Expression(loc, TOKobjcclsref, sizeof(ObjcClassRefExp))
{
    this->cdecl = cdecl;
    this->type = ObjcClassDeclaration::getObjcMetaClass(cdecl)->getType();
}

// MARK: .class Expression

ObjcDotClassExp::ObjcDotClassExp(Loc loc, Expression *e)
    : UnaExp(loc, TOKobjc_dotclass, sizeof(ObjcDotClassExp), e)
{
    noop = 0;
}

Expression *ObjcDotClassExp::semantic(Scope *sc)
{
    if (Expression *ex = unaSemantic(sc))
        return ex;

    if (e1->type && e1->type->ty == Tclass)
    {
        ClassDeclaration *cd = ((TypeClass *)e1->type)->sym;
        if (cd->objc.objc)
        {
            if (e1->op = TOKtype)
            {
                if (cd->isInterfaceDeclaration())
                {
                    error("%s is an interface type and has no static 'class' property", e1->type->toChars());
                    return new ErrorExp();
                }
                return new ObjcClassRefExp(loc, cd);
            }
            else if (cd->objc.meta)
            {   // this is already a class object, nothing to do
                noop = 1;
                type = cd->type;
                return this;
            }
            else
            {   // this is a regular (non-class) object, invoke class method
                type = cd->objc.metaclass->type;
                return this;
            }
        }
    }

    error("%s of type %s has no 'class' property", e1->toChars(), e1->type->toChars());
    return new ErrorExp();
}

// MARK: .interface Expression

ClassDeclaration *ObjcProtocolOfExp::protocolClassDecl = NULL;

ObjcProtocolOfExp::ObjcProtocolOfExp(Loc loc, Expression *e)
    : UnaExp(loc, TOKobjc_dotprotocolof, sizeof(ObjcProtocolOfExp), e)
{
    idecl = NULL;
}

Expression *ObjcProtocolOfExp::semantic(Scope *sc)
{
    if (Expression *ex = unaSemantic(sc))
        return ex;

    if (e1->type && e1->type->ty == Tclass)
    {
        ClassDeclaration *cd = ((TypeClass *)e1->type)->sym;
        if (cd->objc.objc)
        {
            if (e1->op = TOKtype)
            {
                if (cd->isInterfaceDeclaration())
                {
                    if (protocolClassDecl)
                    {
                        idecl = (InterfaceDeclaration *)cd;
                        type = protocolClassDecl->type;
                        return this;
                    }
                    else
                    {
                        error("'protocolof' property not available because its the 'Protocol' Objective-C class is not defined (did you forget to import objc.types?)");
                        return new ErrorExp();
                    }
                }
            }
        }
    }

    error("%s of type %s has no 'protocolof' property", e1->toChars(), e1->type->toChars());
    return new ErrorExp();
}

// MARK: ObjcClassDeclaration

ObjcClassDeclaration *ObjcClassDeclaration::create(ClassDeclaration *cdecl, int ismeta)
{
    if (global.params.isObjcNonFragileAbi)
        return new NonFragileAbiObjcClassDeclaration(cdecl, ismeta);
    else
        return new FragileAbiObjcClassDeclaration(cdecl, ismeta);
}

/* ClassDeclaration::metaclass contains the metaclass from the semantic point
 of view. This function returns the metaclass from the Objective-C runtime's
 point of view. Here, the metaclass of a metaclass is the root metaclass, not
 nil, and the root metaclass's metaclass is itself. */
ClassDeclaration *ObjcClassDeclaration::getObjcMetaClass(ClassDeclaration *cdecl)
{
    if (!cdecl->objc.metaclass && cdecl->objc.meta)
    {
        if (cdecl->baseClass)
            return getObjcMetaClass(cdecl->baseClass);
        else
            return cdecl;
    }
    else
        return cdecl->objc.metaclass;
}

ObjcClassDeclaration::ObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta)
{
    this->cdecl = cdecl;
    this->ismeta = ismeta;
    symbol = NULL;
    sprotocols = NULL;
    sproperties = NULL;
}

Symbol *NonFragileAbiObjcClassDeclaration::getIVarOffset(VarDeclaration* ivar)
{
    if (ivar->toParent() == cdecl)
        return NonFragileAbiObjcSymbols::instance->getIVarOffset(cdecl, ivar, false);

    else if (cdecl->baseClass)
        return NonFragileAbiObjcClassDeclaration(cdecl->baseClass).getIVarOffset(ivar);

    else
        assert(false || "Trying to get the base class of root class");
}

// MARK: ObjcProtocolDeclaration

ObjcProtocolDeclaration* ObjcProtocolDeclaration::create(ClassDeclaration *idecl)
{
    if (global.params.isObjcNonFragileAbi)
        return new NonFragileAbiObjcProtocolDeclaration(idecl);
    else
        return new FragileAbiObjcProtocolDeclaration(idecl);
}

ObjcProtocolDeclaration::ObjcProtocolDeclaration(ClassDeclaration *idecl)
{
    this->idecl = idecl;
    symbol = NULL;
}

/***************************** TypeObjcSelector *****************************/

TypeObjcSelector::TypeObjcSelector(Type *t)
    : TypeNext(Tobjcselector, t)
{
    assert(((TypeFunction *)t)->linkage == LINKobjc);
}

Type *TypeObjcSelector::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
        t = this;
    else
    {   t = new TypeObjcSelector(t);
        t->mod = mod;
    }
    return t;
}

Type *TypeObjcSelector::semantic(Loc loc, Scope *sc)
{
    if (deco)                   // if semantic() already run
    {
        //printf("already done\n");
        return this;
    }
    Scope* newScope = new Scope(*sc);
    newScope->linkage = LINKobjc;
    next = next->semantic(loc,newScope);

    return merge();
}

d_uns64 TypeObjcSelector::size(Loc loc)
{
    return Target::ptrsize;
}

unsigned TypeObjcSelector::alignsize()
{
    return Target::ptrsize;
}

MATCH TypeObjcSelector::implicitConvTo(Type *to)
{
    //printf("TypeDelegate::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("from: %s\n", toChars());
    //printf("to  : %s\n", to->toChars());
    if (this == to)
        return MATCHexact;
#if 0 // not allowing covariant conversions because it interferes with overriding
    if (to->ty == Tdelegate && this->nextOf()->covariant(to->nextOf()) == 1)
        return MATCHconvert;
#endif
    return MATCHnomatch;
}

Expression *TypeObjcSelector::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeObjcSelector::defaultInit() '%s'\n", toChars());
#endif
    return new NullExp(loc, this);
}

bool TypeObjcSelector::isZeroInit(Loc loc)
{
    return true;
}

bool TypeObjcSelector::checkBoolean()
{
    return true;
}

Expression *TypeObjcSelector::dotExp(Scope *sc, Expression *e, Identifier *ident, int flag)
{
#if LOGDOTEXP
    printf("TypeDelegate::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
/*    if (ident == Id::ptr)
    {
        e->type = tvoidptr;
        return e;
    }
    else if (ident == Id::funcptr)
    {
        e = e->addressOf(sc);
        e->type = tvoidptr;
        e = new AddExp(e->loc, e, new IntegerExp(PTRSIZE));
        e->type = tvoidptr;
        e = new PtrExp(e->loc, e);
        e->type = next->pointerTo();
        return e;
    }
    else*/
    {
        e = Type::dotExp(sc, e, ident, flag);
    }
    return e;
}

int TypeObjcSelector::hasPointers()
{
    return FALSE; // not in GC memory
}

TypeInfoDeclaration *TypeObjcSelector::getTypeInfoDeclaration()
{
    return TypeInfoObjcSelectorDeclaration::create(this);
}

/***************************************/

#include "cond.h"
#include "expression.h"
#include "init.h"
#include "module.h"
#include "parse.h"
#include "statement.h"
#include "typinf.c"
#include "utf.h"

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);
unsigned totym(Type *tx);

Objc_StructDeclaration::Objc_StructDeclaration()
{
    selectorTarget = false;
    isSelector = false;
}

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
    return objc;
}

bool Objc_ClassDeclaration::isRootClass()
{
    return isInterface() && !metaclass && !cdecl->baseClass;
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
    if (selector == NULL && fdecl->linkage == LINKobjc && fdecl->isVirtual() && fdecl->type)
    {
        TypeFunction *ftype = (TypeFunction *)fdecl->type;
        selector = ObjcSelector::create(fdecl);
    }
}

bool Ojbc_FuncDeclaration::isProperty()
{
    TypeFunction* t = (TypeFunction*)fdecl->type;

    return (fdecl->storage_class & STCproperty) &&
        t && t->parameters &&
        ((t->parameters->dim == 1 && t->next == Type::tvoid) ||
        (t->parameters->dim == 0 && t->next != Type::tvoid));
}

// MARK: TypeInfoObjcSelectorDeclaration

TypeInfoObjcSelectorDeclaration::TypeInfoObjcSelectorDeclaration(Type *tinfo)
: TypeInfoDeclaration(tinfo, 0)
{
    type = Type::typeinfodelegate->type;
}

TypeInfoObjcSelectorDeclaration *TypeInfoObjcSelectorDeclaration::create(Type *tinfo)
{
    return new TypeInfoObjcSelectorDeclaration(tinfo);
}

// MARK: ObjcSelectorExp

ObjcSelectorExp::ObjcSelectorExp(Loc loc, FuncDeclaration *f, int hasOverloads)
: Expression(loc, TOKobjcselector, sizeof(ObjcSelectorExp))
{
    this->func = f;
    this->selname = NULL;
    this->hasOverloads = hasOverloads;
}

ObjcSelectorExp::ObjcSelectorExp(Loc loc, char *selname, int hasOverloads)
: Expression(loc, TOKobjcselector, sizeof(ObjcSelectorExp))
{
    this->func = NULL;
    this->selname = selname;
    this->hasOverloads = hasOverloads;
}

Expression *ObjcSelectorExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("ObjcSelectorExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        type = new TypeObjcSelector(func->type);
        type = type->semantic(loc, sc);
        if (!func->needThis())
        {   error("%s isn't a member function, has no selector", func->toChars());
            return new ErrorExp();
        }
        ClassDeclaration *cd = func->toParent()->isClassDeclaration();
        if (!cd->objc.objc)
        {   error("%s isn't an Objective-C class, function has no selector", cd->toChars());
            return new ErrorExp();
        }
    }
    return this;
}

// MARK: Module::genobjfile

void objc_Module_genobjfile_initSymbols()
{
    ObjcSymbols::init();
}

// MARK: inline

void objc_inline_visit_ObjcSelectorExp(int &cost)
{
    cost = COST_MAX;
}

// MARK: interpret

void objc_interpret_visit_ObjcSelectorExp(ObjcSelectorExp *e, Expression *&result)
{
#if LOG
    printf("ObjcSelectorExp::interpret() %s\n", e->toChars());
#endif
    result = e;
}

// MARK: Type::init

void objc_Type_init(unsigned char sizeTy[TMAX])
{
    sizeTy[Tobjcselector] = sizeof(TypeObjcSelector);
}

// MARK: dotExp

void objc_Type_dotExp_TOKdotvar_setReceiver(ClassDeclaration *&receiver, DotVarExp *dv)
{
    Type* baseType = dv->e1->type->toBasetype();
    if (baseType && baseType->ty == Tclass)
        receiver = ((TypeClass*) baseType)->sym;
}

void objc_Type_dotExp_TOKvar_setReceiver(VarDeclaration *v, ClassDeclaration *&receiver)
{
    if (Dsymbol* parent = v->toParent())
        receiver = parent->isClassDeclaration();
}

void objc_Type_dotExp_offsetof(Type *self, Expression *e, ClassDeclaration *receiver)
{
    if (receiver && receiver->objc.objc)
        self->error(e->loc, ".offsetof (%s) is not available for members of Objective-C classes (%s)", e->toChars(), receiver->toChars());
}

void objc_TypeClass_dotExp_tupleof(TypeClass *self, Expression *e)
{
    if (self->sym->objc.objc)
        self->error(e->loc, ".tupleof (%s) is not available for Objective-C classes (%s)", e->toChars(), self->sym->toChars());
}

ControlFlow objc_TypeClass_dotExp_protocolof(Scope *sc, Expression *&e, Identifier *ident)
{
    if (ident == Id::protocolof)
    {
        e = new ObjcProtocolOfExp(e->loc, e);
        e = e->semantic(sc);
        return CFreturn;
    }

    return CFnone;
}

void objc_TypeClass_dotExp_TOKtype(TypeClass *self, Scope *sc, Expression *&e, Declaration *d)
{
    // Objective-C class methods uses the class object as 'this'
    DotVarExp *de = new DotVarExp(e->loc, new ObjcClassRefExp(e->loc, self->sym), d);
    e = de->semantic(sc);
}

// MARK: Expression_optimize
void objc_Expression_optimize_visit_CallExp_Tobjcselector(Type *&t1)
{
    if (t1->ty == Tobjcselector)
        t1 = t1->nextOf();
}

// MARK: parse

void objc_Parser_parseCtor_selector(Parser *self, TemplateParameters *tpl, Parameters *parameters, CtorDeclaration *f)
{
    f->objc.selector = objc_parseSelector(self);
    if (f->objc.selector)
    {
        if (tpl)
            self->error("constructor template cannot have an Objective-C selector attached");
        if (f->objc.selector->paramCount != parameters->dim)
            self->error("number of colons in Objective-C selector must match the number of parameters");
    }
}

void objc_Parser_parseDtor(Parser *self, DtorDeclaration *f)
{
    f->objc.selector = objc_parseSelector(self);
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

void objc_Parser_parseDeclarations_Tfunction(Parser *self, Type *t, TemplateParameters *tpl, FuncDeclaration *f)
{
    f->objc.selector = objc_parseSelector(self);
    if (f->objc.selector)
    {
        TypeFunction *tf = (TypeFunction *)t;
        if (tpl)
            self->error("function template cannot have an Objective-C selector attached");
        if (f->objc.selector->paramCount != tf->parameters->dim)
            self->error("number of colons in Objective-C selector must match number of parameters");
    }
}

/*****************************************
 * Parse Objective-C selector name enclosed in brackets. Such as:
 *   [setObject:forKey:otherArgs::]
 * Return NULL when no bracket found.
 */

ObjcSelector *objc_parseSelector(Parser *self)
{
    if (self->token.value != TOKlbracket)
        return NULL; // no selector

    ObjcSelectorBuilder selBuilder;
    self->nextToken();
    while (1)
    {
        switch (self->token.value)
        {
            case TOKidentifier:
            Lcaseident:
                selBuilder.addIdentifier(self->token.ident);
                break;
            case TOKcolon:
                selBuilder.addColon();
                break;
            case TOKrbracket:
                goto Lendloop;
            default:
                // special case to allow D keywords in Objective-C selector names
                if (self->token.ident)
                    goto Lcaseident;
                goto Lparseerror;
        }
        self->nextToken();
    }
Lendloop:
    self->nextToken();
    if (!selBuilder.isValid())
    {
        self->error("illegal Objective-C selector name");
        return NULL;

    }
    return ObjcSelector::lookup(&selBuilder);

Lparseerror:
    error("illegal Objective-C selector name");
    // exit bracket ignoring content
    while (self->token.value != TOKrbracket && self->token.value != TOKeof)
        self->nextToken();
    self->nextToken();
    return NULL;
}

ControlFlow objc_Parser_parsePostExp_TOKclass(Parser *self, Expression *&e, Loc loc)
{
    e = new ObjcDotClassExp(loc, e);
    self->nextToken();
    return CFcontinue;
}

// MARK: tryMain

void objc_tryMain_dObjc()
{
    VersionCondition::addPredefinedGlobalIdent("D_ObjC");

    if (global.params.isOSX && global.params.is64bit) // && isArm
    {
        global.params.isObjcNonFragileAbi = 1;
        VersionCondition::addPredefinedGlobalIdent("D_ObjCNonFragileABI");
    }
}

void objc_tryMain_init()
{
    ObjcSymbols::init();
    ObjcSelector::init();
}

// MARK: callSideEffectLevel

void objc_callSideEffectLevel_Tobjcselector(Type *t, TypeFunction *&tf)
{
    tf = (TypeFunction *)((TypeDelegate *)t)->next;
}

// MARK: lambdaHasSideEffect

void objc_lambdaHasSideEffect_TOKcall_Tobjcselector(Type *&t)
{
    t = ((TypeObjcSelector *)t)->next;
}

// MARK: Type_toCtype

void objc_Type_toCtype_visit_TypeObjcSelector(TypeObjcSelector *t)
{
    type *tn;

    //printf("TypePointer::toCtype() %s\n", t->toChars());
    if (t->ctype)
        return;

    if (1 || global.params.symdebug)
    {   /* Need to always do this, otherwise C++ name mangling
         * goes awry.
         */
        t->ctype = type_alloc(TYnptr);
        tn = tschar; // expose selector as a char*
        t->ctype->Tnext = tn;
        tn->Tcount++;
    }
    else
        t->ctype = type_fake(totym(t));
    t->ctype->Tcount++;
}

// MARK: Module::genmoduleinfo

void objc_Module_genmoduleinfo_classes(Module *self)
{
    // generate the list of objc classes and categories in this module
    ClassDeclarations objccls;
    ClassDeclarations objccat;
    for (int i = 0; i < self->members->dim; i++)
    {
        Dsymbol *member = self->members->tdata()[i];
        member->addObjcSymbols(&objccls, &objccat);
    }
    // only emit objc module info for modules with Objective-C symbols
    if (objccls.dim || objccat.dim || ObjcSymbols::hassymbols)
        ObjcSymbols::getModuleInfo(&objccls, &objccat);
}

// MARK: TypeInfo_toDt

void objc_TypeInfo_toDt_visit_TypeInfoObjcSelectorDeclaration(dt_t **pdt, TypeInfoObjcSelectorDeclaration *d)
{
    //printf("TypeInfoObjcSelectorDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfodelegate->toVtblSymbol(), 0); // vtbl for TypeInfo_ObjcSelector
    dtsize_t(pdt, 0);                        // monitor

    assert(d->tinfo->ty == Tobjcselector);

    TypeObjcSelector *tc = (TypeObjcSelector *)d->tinfo;

    tc->next->nextOf()->getTypeInfo(NULL);
    dtxoff(pdt, toSymbol(tc->next->nextOf()->vtinfo), 0); // TypeInfo for selector return value
}