
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_todt.c
 */

#include "aggregate.h"
#include "objc.h"

#include "objc_glue.h"

#include "cc.h"
#include "dt.h"
#include "global.h"
#include "type.h"

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

// MARK: ObjcSymbols

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

// MARK: ObjcClassDeclaration

Symbol *ObjcClassDeclaration::getMetaclass()
{
    if (!ismeta)
    {   // regular class: return metaclass with the same name

        ObjcClassDeclaration* meta = ObjcClassDeclaration::create(cdecl, 1);
        meta->toObjFile(0);
        sprotocols = meta->sprotocols;
        return meta->symbol;
    }
    else
    {   // metaclass: return root class's name (will be replaced with metaclass reference at load)
        ClassDeclaration *metadecl = cdecl;
        while (metadecl->baseClass)
            metadecl = metadecl->baseClass;
        return ObjcSymbols::getClassName(metadecl, true);
    }
}

Symbol *ObjcClassDeclaration::getMethodList()
{
    Dsymbols *methods = !ismeta ? &cdecl->objc.methodList : &cdecl->objc.metaclass->objc.methodList;
    int methods_count = methods->dim;

    int overridealloc = ismeta && cdecl->objc.hasPreinit;
    if (overridealloc)
        methods_count += 2; // adding alloc & allocWithZone:

    if (!methods_count) // no member, no method list.
        return NULL;

    dt_t *dt = NULL;

    if (global.params.isObjcNonFragileAbi)
        dtdword(&dt, global.params.is64bit ? 24 : 12); // sizeof(_objc_method)

    else
        dtdword(&dt, 0); // unused

    dtdword(&dt, methods_count); // method count
    for (size_t i = 0; i < methods->dim; ++i)
    {
        FuncDeclaration *func = methods->tdata()[i]->isFuncDeclaration();
        if (func && func->fbody)
        {
            assert(func->objc.selector);
            dtxoff(&dt, func->objc.selector->toNameSymbol(), 0, TYnptr); // method name
            dtxoff(&dt, ObjcSymbols::getMethVarType(func), 0, TYnptr); // method type string
            dtxoff(&dt, toSymbol(func), 0, TYnptr); // function implementation
        }
    }

    if (overridealloc)
    {   // add alloc
        dtxoff(&dt, ObjcSelector::lookup("alloc")->toNameSymbol(), 0, TYnptr); // method name
        dtxoff(&dt, ObjcSymbols::getMethVarType("?", 1), 0, TYnptr); // method type string
        dtxoff(&dt, symbol_name("__dobjc_alloc", SCglobal, type_fake(TYhfunc)), 0, TYnptr); // function implementation

        // add allocWithZone:
        dtxoff(&dt, ObjcSelector::lookup("allocWithZone:")->toNameSymbol(), 0, TYnptr); // method name
        dtxoff(&dt, ObjcSymbols::getMethVarType("?", 1), 0, TYnptr); // method type string
        dtxoff(&dt, symbol_name("__dobjc_allocWithZone", SCglobal, type_fake(TYhfunc)), 0, TYnptr); // function implementation
    }

    const char* prefix;
    size_t prefixLength;
    char *sname;

    if (!ismeta)
    {
        prefix = global.params.isObjcNonFragileAbi ? "l_OBJC_$_INSTANCE_METHODS_" : "L_OBJC_INSTANCE_METHODS_";
        prefixLength = global.params.isObjcNonFragileAbi ? 26 : 24;
    }
    else
    {
        prefix = global.params.isObjcNonFragileAbi ? "l_OBJC_$_CLASS_METHODS_" : "L_OBJC_CLASS_METHODS_";
        prefixLength = global.params.isObjcNonFragileAbi ? 23 : 21;
    }

    sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, prefix, prefixLength);
    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = objc_getsegment((!ismeta ? SEGinst_meth : SEGcls_meth));
    return sym;
}

Symbol *ObjcClassDeclaration::getProtocolList()
{
    if (sprotocols)
        return sprotocols;
    if (cdecl->interfaces_dim == 0)
        return NULL;

    dt_t *dt = NULL;

    if (!global.params.isObjcNonFragileAbi)
        dtdword(&dt, 0); // pointer to next protocol list

    dtsize_t(&dt, cdecl->interfaces_dim); // number of protocols in list

    for (size_t i = 0; i < cdecl->interfaces_dim; ++i)
    {
        if (!cdecl->interfaces[i]->base->objc.objc)
            error("Only Objective-C interfaces are supported on an Objective-C class");

        dtxoff(&dt, ObjcSymbols::getProtocolSymbol(cdecl->interfaces[i]->base), 0, TYnptr); // pointer to protocol decl
    }
    dtsize_t(&dt, 0); // null-terminate the list

    const char* prefix = global.params.isObjcNonFragileAbi ? "l_OBJC_CLASS_PROTOCOLS_$_" : "L_OBJC_CLASS_PROTOCOLS_";
    size_t prefixLength = global.params.isObjcNonFragileAbi ? 25 : 23;

    char *sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, prefix, prefixLength);
    sprotocols = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sprotocols->Sdt = dt;
    sprotocols->Sseg = objc_getsegment(SEGcat_cls_meth);
    outdata(sprotocols);
    return sprotocols;
}

Symbol *ObjcClassDeclaration::getPropertyList()
{
    if (sproperties)
        return sproperties;

    Dsymbols* properties = getProperties();

    if (properties->dim == 0)
        return  NULL;

    dt_t* dt = NULL;
    dtdword(&dt, global.params.is64bit ? 16 : 8); // sizeof (_objc_property)
    dtdword(&dt, properties->dim);

    for (size_t i = 0; i < properties->dim; i++)
    {
        FuncDeclaration* property = (FuncDeclaration*) (*properties)[i];
        dtxoff(&dt, ObjcSymbols::getPropertyName(property->ident), 0, TYnptr);
        dtxoff(&dt, ObjcSymbols::getPropertyTypeString(property), 0, TYnptr);
    }

    const char* symbolName = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, "l_OBJC_$_PROP_LIST_", 19);
    sproperties = symbol_name(symbolName, SCstatic, type_fake(TYnptr));
    sproperties->Sdt = dt;
    sproperties->Sseg = objc_getsegment(SEGproperty);
    outdata(sproperties);

    return sproperties;
}

Dsymbols* ObjcClassDeclaration::getProperties()
{
    Dsymbols* properties = new Dsymbols();
    StringTable* uniqueProperties = new StringTable();
    uniqueProperties->_init();

    for (size_t i = 0; i < cdecl->objc.methodList.dim; i++)
    {
        FuncDeclaration* method = (FuncDeclaration*) cdecl->objc.methodList[i];
        TypeFunction* type = (TypeFunction*) method->type;
        Identifier* ident = method->ident;

        if (method->objc.isProperty() && !uniqueProperties->lookup(ident->string, ident->len))
        {
            properties->push(method);
            uniqueProperties->insert(ident->string, ident->len);
        }
    }

    return properties;
}

// MARK: FragileAbiObjcClassDeclaration

void FragileAbiObjcClassDeclaration::toDt(dt_t **pdt)
{
    dtxoff(pdt, getMetaclass(), 0, TYnptr); // pointer to metaclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl->baseClass), 0, TYnptr); // name of superclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl), 0, TYnptr); // name of class
    dtdword(pdt, 0); // version (for serialization)
    dtdword(pdt, !ismeta ? 1 : 2); // info flags (0x1: regular class; 0x2: metaclass)
    dtdword(pdt, !ismeta ? cdecl->size(cdecl->loc) : 48); // instance size in bytes

    Symbol *ivars = getIVarList();
    if (ivars)    dtxoff(pdt, ivars, 0, TYnptr); // instance variable list
    else          dtdword(pdt, 0); // or null if no ivars
    Symbol *methods = getMethodList();
    if (methods)  dtxoff(pdt, methods, 0, TYnptr); // instance method list
    else           dtdword(pdt, 0); // or null if no methods
    dtdword(pdt, 0); // cache (used by runtime)
    Symbol *protocols = getProtocolList();
    if (protocols)  dtxoff(pdt, protocols, 0, TYnptr); // protocol list
    else            dtdword(pdt, 0); // or NULL if no protocol

    // extra bytes
    dtdword(pdt, 0);

    if (ismeta)
        dtxoff(pdt, getClassExtension(), 0, TYnptr);
    else
        dtdword(pdt, 0);
}

Symbol *FragileAbiObjcClassDeclaration::getIVarList()
{
    if (ismeta)
        return NULL;
    if (cdecl->fields.dim == 0)
        return NULL;

    size_t ivarcount = cdecl->fields.dim;
    dt_t *dt = NULL;

    dtdword(&dt, ivarcount); // method count
    for (size_t i = 0; i < ivarcount; ++i)
    {
        VarDeclaration *ivar = cdecl->fields.tdata()[i]->isVarDeclaration();
        assert(ivar);
        assert((ivar->storage_class & STCstatic) == 0);

        dtxoff(&dt, ObjcSymbols::getMethVarName(ivar->ident), 0, TYnptr); // ivar name
        dtxoff(&dt, ObjcSymbols::getMethVarType(ivar), 0, TYnptr); // ivar type string

        dtdword(&dt, ivar->offset); // ivar offset
    }

    char *sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, "L_OBJC_INSTANCE_VARIABLES_", 26);

    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = objc_getsegment(SEGinstance_vars);
    return sym;
}

Symbol *FragileAbiObjcClassDeclaration::getClassExtension()
{
    dt_t* dt = NULL;

    dtdword(&dt, 12);
    dtdword(&dt, 0); // weak ivar layout

    Symbol* properties = getPropertyList();
    if (properties) dtxoff(&dt, properties, 0, TYnptr);
    else dtdword(&dt, 0); // properties

    const char* symbolName = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, "L_OBJC_CLASSEXT_", 16);
    Symbol* symbol = symbol_name(symbolName, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGclass_ext);
    outdata(symbol);

    return symbol;
}

// MARK: NonFragileAbiObjcClassDeclaration

void NonFragileAbiObjcClassDeclaration::toDt(dt_t **pdt)
{
    dtxoff(pdt, getMetaclass(), 0, TYnptr); // pointer to metaclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl->baseClass, ismeta), 0, TYnptr); // pointer to superclass
    dtxoff(pdt, NonFragileAbiObjcSymbols::instance->getEmptyCache(), 0, TYnptr);
    dtxoff(pdt, NonFragileAbiObjcSymbols::instance->getEmptyVTable(), 0, TYnptr);
    dtxoff(pdt, getClassRo(), 0, TYnptr);
}

Symbol *NonFragileAbiObjcClassDeclaration::getIVarList()
{
    if (ismeta)
        return NULL;
    if (cdecl->fields.dim == 0)
        return NULL;

    size_t ivarcount = cdecl->fields.dim;
    dt_t *dt = NULL;

    dtdword(&dt, global.params.is64bit ? 32 : 20); // sizeof(_ivar_t)
    dtdword(&dt, ivarcount); // method count

    for (size_t i = 0; i < ivarcount; ++i)
    {
        VarDeclaration *ivar = cdecl->fields.tdata()[i]->isVarDeclaration();
        assert(ivar);
        assert((ivar->storage_class & STCstatic) == 0);

        dtxoff(&dt, NonFragileAbiObjcSymbols::instance->getIVarOffset(cdecl, ivar, true), 0, TYnptr); // pointer to ivar offset
        dtxoff(&dt, ObjcSymbols::getMethVarName(ivar->ident), 0, TYnptr); // ivar name
        dtxoff(&dt, ObjcSymbols::getMethVarType(ivar), 0, TYnptr); // ivar type string
        dtdword(&dt, ivar->alignment);
        dtdword(&dt, ivar->size(ivar->loc));
    }

    char *sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, "l_OBJC_$_INSTANCE_VARIABLES_", 28);

    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = objc_getsegment(SEGinstance_vars);
    return sym;
}

Symbol *NonFragileAbiObjcClassDeclaration::getIVarOffset(VarDeclaration* ivar)
{
    if (ivar->toParent() == cdecl)
        return NonFragileAbiObjcSymbols::instance->getIVarOffset(cdecl, ivar, false);

    else if (cdecl->baseClass)
        return NonFragileAbiObjcClassDeclaration(cdecl->baseClass).getIVarOffset(ivar);

    else
        assert(false || "Trying to get the base class of root class");

    return NULL;
}

Symbol *NonFragileAbiObjcClassDeclaration::getClassRo()
{
    dt_t* dt = NULL;

    dtdword(&dt, generateFlags()); // flags
    dtdword(&dt, getInstanceStart()); // instance start
    dtdword(&dt, ismeta ? 40 : cdecl->size(cdecl->loc)); // instance size in bytes
    dtdword(&dt, 0); // reserved, only for 64bit targets

    dtsize_t(&dt, 0);
    dtxoff(&dt, NonFragileAbiObjcSymbols::instance->getClassNameRo(cdecl->objc.ident), 0,TYnptr); // name of class

    Symbol* methods = getMethodList();
    if (methods) dtxoff(&dt, methods, 0, TYnptr); // instance method list
    else dtsize_t(&dt, 0); // or null if no methods

    Symbol *protocols = getProtocolList();
    if (protocols)  dtxoff(&dt, protocols, 0, TYnptr); // protocol list
    else dtsize_t(&dt, 0); // or NULL if no protocol

    if (ismeta)
    {
        dtsize_t(&dt, 0); // instance variable list
        dtsize_t(&dt, 0); // weak ivar layout
        dtsize_t(&dt, 0); // properties
    }

    else
    {
        Symbol* ivars = getIVarList();
        if (ivars && !ismeta) dtxoff(&dt, ivars, 0, TYnptr); // instance variable list
        else dtsize_t(&dt, 0); // or null if no ivars

        dtsize_t(&dt, 0); // weak ivar layout

        Symbol* properties = getPropertyList();
        if (properties) dtxoff(&dt, properties, 0, TYnptr);
        else dtsize_t(&dt, 0); // properties
    }

    const char* prefix = ismeta ? "l_OBJC_METACLASS_RO_$_" : "l_OBJC_CLASS_RO_$_";
    size_t prefixLength = ismeta ? 22 : 18;
    const char* symbolName = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, prefix, prefixLength);

    Symbol* symbol = symbol_name(symbolName, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGobjc_const);
    outdata(symbol);
    
    return symbol;
}

uint32_t NonFragileAbiObjcClassDeclaration::generateFlags ()
{
    uint32_t flags = ismeta ? nonFragileFlags_meta : 0;

    if (cdecl->objc.isRootClass())
        flags |= nonFragileFlags_root;

    return flags;
}

unsigned NonFragileAbiObjcClassDeclaration::getInstanceStart ()
{
    if (ismeta)
        return 40;

    unsigned start = cdecl->size(cdecl->loc);

    if (cdecl->members && cdecl->members->dim > 0)
    {
        for (size_t i = 0; i < cdecl->members->dim; i++)
        {
            Dsymbol* member = (*cdecl->members)[i];
            VarDeclaration* var = member->isVarDeclaration();

            if (var && var->isField())
            {
                start = var->offset;
                break;
            }
        }
    }
    
    return start;
}

// MARK: ObjcProtocolDeclaration

void ObjcProtocolDeclaration::toDt(dt_t **pdt)
{
    dtsize_t(pdt, 0); // isa pointer, initialized by the runtime
    Symbol* className = getClassName();
    dtxoff(pdt, className, 0, TYnptr); // protocol name

    Symbol *protocols = getProtocolList();
    if (protocols)  dtxoff(pdt, protocols, 0, TYnptr); // protocol list
    else            dtsize_t(pdt, 0); // or NULL if no protocol
    Symbol *imethods = getMethodList(0);
    if (imethods)  dtxoff(pdt, imethods, 0, TYnptr); // instance method list
    else           dtsize_t(pdt, 0); // or null if no methods
    Symbol *cmethods = getMethodList(1);
    if (cmethods)  dtxoff(pdt, cmethods, 0, TYnptr); // class method list
    else           dtsize_t(pdt, 0); // or null if no methods
}

Symbol *ObjcProtocolDeclaration::getMethodList(int wantsClassMethods)
{
    Dsymbols *methods = !wantsClassMethods ? &idecl->objc.methodList : &idecl->objc.metaclass->objc.methodList;
    if (!methods->dim) // no member, no method list.
        return NULL;

    dt_t *dt = NULL;

    if (global.params.isObjcNonFragileAbi)
        dtdword(&dt, global.params.is64bit ? 24 : 12); // sizeof(_objc_method)

    dtdword(&dt, methods->dim); // method count
    for (size_t i = 0; i < methods->dim; ++i)
    {
        FuncDeclaration *func = methods->tdata()[i]->isFuncDeclaration();
        assert(func);
        assert(func->objc.selector);
        dtxoff(&dt, func->objc.selector->toNameSymbol(), 0, TYnptr); // method name
        dtxoff(&dt, ObjcSymbols::getMethVarType(func), 0, TYnptr); // method type string

        if (global.params.isObjcNonFragileAbi)
            dtsize_t(&dt, 0); // NULL, protocol methods have no implemention
    }

    char *sname;
    const char* prefix;
    size_t prefixLength;

    if (!wantsClassMethods)
    {
        prefix = global.params.isObjcNonFragileAbi ? "l_OBJC_$_PROTOCOL_INSTANCE_METHODS_" : "L_OBJC_PROTOCOL_INSTANCE_METHODS_";
        prefixLength = global.params.isObjcNonFragileAbi ? 35 : 33;
    }
    else
    {
        prefix = global.params.isObjcNonFragileAbi ? "l_OBJC_$_PROTOCOL_CLASS_METHODS_" : "L_OBJC_PROTOCOL_CLASS_METHODS_";
        prefixLength = global.params.isObjcNonFragileAbi ? 32 : 30;
    }

    sname = prefixSymbolName(idecl->objc.ident->string, idecl->objc.ident->len, prefix, prefixLength);
    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = objc_getsegment((!wantsClassMethods ? SEGcat_inst_meth : SEGcat_cls_meth));
    return sym;
}

Symbol *ObjcProtocolDeclaration::getProtocolList()
{
    if (idecl->interfaces_dim == 0)
        return NULL;

    dt_t *dt = NULL;
    dtdword(&dt, 0); // pointer to next protocol list
    dtdword(&dt, idecl->interfaces_dim); // number of protocols in list

    for (size_t i = 0; i < idecl->interfaces_dim; ++i)
    {
        if (!idecl->interfaces[i]->base->objc.objc)
            error("Only Objective-C interfaces are supported on an Objective-C interface");

        dtxoff(&dt, ObjcSymbols::getProtocolSymbol(idecl->interfaces[i]->base), 0, TYnptr); // pointer to protocol decl
    }
    dtdword(&dt, 0); // null-terminate the list

    const char* prefix = global.params.isObjcNonFragileAbi ? "l_OBJC_$_PROTOCOL_REFS_" : "L_OBJC_PROTOCOL_REFS_";
    size_t prefixLength = global.params.isObjcNonFragileAbi ? 23 : 21;

    char *sname = prefixSymbolName(idecl->objc.ident->string, idecl->objc.ident->len, prefix, prefixLength);
    Symbol *sprotocols = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sprotocols->Sdt = dt;
    sprotocols->Sseg = objc_getsegment(SEGcat_cls_meth);
    outdata(sprotocols);
    return sprotocols;
}

Symbol* FragileAbiObjcProtocolDeclaration::getClassName()
{
    return ObjcSymbols::getClassName(idecl);
}

// MARK: NonFragileAbiObjcProtocolDeclaration

void NonFragileAbiObjcProtocolDeclaration::toDt(dt_t **pdt)
{
    ObjcProtocolDeclaration::toDt(pdt);

    dtsize_t(pdt, 0); // null, optional instance methods, currently not supported
    dtsize_t(pdt, 0); // null, optional class methods, currently not supported

    ::ObjcClassDeclaration* c = ::ObjcClassDeclaration::create(idecl);
    Symbol* properties = c->getPropertyList();
    if (properties) dtxoff(pdt, properties, 0, TYnptr);
    else dtsize_t(pdt, 0); // properites

    dtdword(pdt, global.params.is64bit ? 80 : 44); // sizeof(_protocol_t)
    dtdword(pdt, 0); // flags

    Symbol* methodTypes = getMethodTypes();
    if (methodTypes) dtxoff(pdt, methodTypes, TYnptr); // extended method types
    else dtsize_t(pdt, 0); // or NULL if no method types
}

Symbol* NonFragileAbiObjcProtocolDeclaration::getMethodTypes ()
{
    if (idecl->objc.methodList.dim == 0)
        return NULL;

    dt_t* dt = NULL;

    Dsymbols *methods = &idecl->objc.methodList;

    for (size_t i = 0; i < methods->dim; ++i)
    {
        FuncDeclaration *func = methods->tdata()[i]->isFuncDeclaration();
        assert(func);
        assert(func->objc.selector);
        dtxoff(&dt, ObjcSymbols::getMethVarType(func), 0, TYnptr);
    }

    const char* symbolName = prefixSymbolName(idecl->objc.ident->string, idecl->objc.ident->len, "l_OBJC_$_PROTOCOL_METHOD_TYPES_", 31);
    Symbol* symbol = symbol_name(symbolName, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGobjc_const);
    outdata(symbol);
    
    return symbol;
}

Symbol* NonFragileAbiObjcProtocolDeclaration::getClassName()
{
    return NonFragileAbiObjcSymbols::instance->getClassNameRo(idecl->objc.ident);
}

// MARK: ObjcSelector

Symbol *ObjcSelector::toNameSymbol()
{
    return ObjcSymbols::getMethVarName(stringvalue, stringlen);
}
