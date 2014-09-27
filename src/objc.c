
#include "objc.h"
#include "identifier.h"
#include "dsymbol.h"
#include "declaration.h"
#include "aggregate.h"
#include "target.h"
#include "id.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

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

static void error (const char* format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::error(Loc(), format, ap);
    va_end(ap);
}

// Utility for concatenating names with a prefix
static char *prefixSymbolName(const char *name, size_t name_len, const char *prefix, size_t prefix_len)
{
    // Ensure we have a long-enough buffer for the symbol name. Previous buffer is reused.
    static char *sname = NULL;
    static size_t sdim = 0;
    if (name_len + prefix_len + 1 >= sdim)
    {   sdim = name_len + prefix_len + 12;
        sname = (char *)realloc(sname, sdim);
    }

    // Create symbol name L_OBJC_CLASS_PROTOCOLS_<ProtocolName>
    memmove(sname, prefix, prefix_len);
    memmove(sname+prefix_len, name, name_len);
    sname[prefix_len+name_len] = 0;

    return sname;
}

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

static int seg_list[SEG_MAX] = {0};

static int objc_getsegment(ObjcSegment segid)
{
    int *seg = seg_list;
    if (seg[segid] != 0)
        return seg[segid];

    // initialize
    int align = 2;

    if (global.params.isObjcNonFragileAbi)
    {
        align = 3;

        seg[SEGselrefs] = MachObj::getsegment("__objc_selrefs", "__DATA", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
        seg[SEGcls_refs] = MachObj::getsegment("__objc_classrefs", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGimage_info] = MachObj::getsegment("__objc_imageinfo", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGmethname] = MachObj::getsegment("__objc_methname", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGmethtype] = MachObj::getsegment("__objc_methtype", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclassname] = MachObj::getsegment("__objc_classname", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclass] = MachObj::getsegment("__objc_data", "__DATA", align, S_REGULAR);
        seg[SEGmeta_class] = MachObj::getsegment("__objc_data", "__DATA", align, S_REGULAR);
        seg[SEGmodule_info] = MachObj::getsegment("__objc_classlist", "__DATA", align, S_REGULAR | S_ATTR_NO_DEAD_STRIP);
        seg[SEGprotocol] = MachObj::getsegment("__datacoal_nt", "__DATA", align, S_COALESCED);
        seg[SEGcat_cls_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_REGULAR);
        seg[SEGcat_inst_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_REGULAR);
        seg[SEGcls_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGinstance_vars] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);

        seg[SEGmessage_refs] = MachObj::getsegment("__objc_msgrefs", "__DATA", align, S_COALESCED);
        seg[SEGobjc_const] = MachObj::getsegment("__objc_const", "__DATA", align, S_REGULAR);
        seg[SEGinst_meth] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGobjc_ivar] = MachObj::getsegment("__objc_ivar", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGobjc_protolist] = MachObj::getsegment("__objc_protolist", "__DATA", align, S_COALESCED | S_ATTR_NO_DEAD_STRIP);
        seg[SEGproperty] = MachObj::getsegment("__objc_const", "__DATA", align, S_ATTR_NO_DEAD_STRIP);
    }

    else
    {
        seg[SEGselrefs] = MachObj::getsegment("__message_refs", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
        seg[SEGcls_refs] = MachObj::getsegment("__cls_refs", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
        seg[SEGimage_info] = MachObj::getsegment("__image_info", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGmethname] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGmethtype] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclassname] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
        seg[SEGclass] = MachObj::getsegment("__class", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGmeta_class] = MachObj::getsegment("__meta_class", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGinst_meth] = MachObj::getsegment("__inst_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGmodule_info] = MachObj::getsegment("__module_info", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGprotocol] = MachObj::getsegment("__protocol", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGcat_cls_meth] = MachObj::getsegment("__cat_cls_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGcat_inst_meth] = MachObj::getsegment("__cat_inst_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGproperty] = MachObj::getsegment("__property", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_REGULAR);
        seg[SEGcls_meth] = MachObj::getsegment("__cls_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
        seg[SEGinstance_vars] = MachObj::getsegment("__instance_vars", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);

        seg[SEGclass_ext] = MachObj::getsegment("__class_ext", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_REGULAR);
    }

    seg[SEGstring_object] = MachObj::getsegment("__string_object", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcstring_object] = MachObj::getsegment("__cstring_object", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGsel_fixup] = MachObj::getsegment("__sel_fixup", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcstring] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
    seg[SEGustring] = MachObj::getsegment("__ustring", "__TEXT", align, S_REGULAR);
    seg[SEGcfstring] = MachObj::getsegment("__cfstring", "__DATA", align, S_REGULAR);
    seg[SEGcategory] = MachObj::getsegment("__category", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGclass_vars] = MachObj::getsegment("__class_vars", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGsymbols] = MachObj::getsegment("__symbols", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGprotocol_ext] = MachObj::getsegment("__protocol_ext", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);

    return seg[segid];
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
    assert(property->isObjcProperty());

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
            assert(func->objcSelector);
            dtxoff(&dt, func->objcSelector->toNameSymbol(), 0, TYnptr); // method name
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

        if (method->isObjcProperty() && !uniqueProperties->lookup(ident->string, ident->len))
        {
            properties->push(method);
            uniqueProperties->insert(ident->string, ident->len);
        }
    }

    return properties;
}

// MARK: FragileAbiObjcClassDeclaration

void FragileAbiObjcClassDeclaration::toObjFile(int multiobj)
{
    if (cdecl->objc.extern_)
        return; // only a declaration for an externally-defined class

    dt_t *dt = NULL;
    toDt(&dt);

    char *sname;
    if (!ismeta)
        sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, "L_OBJC_CLASS_", 13);
    else
        sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, "L_OBJC_METACLASS_", 17);
    symbol = symbol_name(sname, SCstatic, type_fake(TYnptr));

    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment((!ismeta ? SEGclass : SEGmeta_class));
    outdata(symbol);

    if (!ismeta)
    {
        dt_t *dt2 = NULL;
        dtdword(&dt2, 0); // version (for serialization)
        char* sname = prefixSymbolName(cdecl->objc.ident->string, cdecl->objc.ident->len, ".objc_class_name_", 17);
        Symbol* symbol = symbol_name(sname, SCglobal, type_fake(TYnptr));
        symbol->Sdt = dt2;
        symbol->Sseg = MachObj::getsegment("__text", "__TEXT", 2, S_ATTR_NO_DEAD_STRIP);
        outdata(symbol);
    }
}

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

void NonFragileAbiObjcClassDeclaration::toObjFile(int multiobj)
{
    if (cdecl->objc.extern_)
        return; // only a declaration for an externally-defined class

    dt_t *dt = NULL;
    toDt(&dt);

    symbol = ObjcSymbols::getClassName(this);
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment((!ismeta ? SEGclass : SEGmeta_class));
    outdata(symbol);
}

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
        assert(func->objcSelector);
        dtxoff(&dt, func->objcSelector->toNameSymbol(), 0, TYnptr); // method name
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

// MARK: FragileAbi::ObjcProtocolDeclaration

void FragileAbiObjcProtocolDeclaration::toObjFile(int multiobj)
{
    dt_t *dt = NULL;
    toDt(&dt);

    char *sname = prefixSymbolName(idecl->objc.ident->string, idecl->objc.ident->len, "L_OBJC_PROTOCOL_", 16);
    symbol = symbol_name(sname, SCstatic, type_fake(TYnptr));

    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGprotocol);
    outdata(symbol, 1);
}

Symbol* FragileAbiObjcProtocolDeclaration::getClassName()
{
    return ObjcSymbols::getClassName(idecl);
}

// MARK: NonFragileAbiObjcProtocolDeclaration

void NonFragileAbiObjcProtocolDeclaration::toObjFile(int multiobj)
{
    dt_t *dt = NULL;
    toDt(&dt);

    char *sname = prefixSymbolName(idecl->objc.ident->string, idecl->objc.ident->len, "l_OBJC_PROTOCOL_$_", 18);
    symbol = ObjcSymbols::getGlobal(sname);

    symbol->Sclass = SCcomdat; // weak symbol
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGprotocol);
    outdata(symbol, 1);

    dt = NULL;
    dtxoff(&dt, symbol, 0, TYnptr);

    const char* symbolName = prefixSymbolName(idecl->objc.ident->string, idecl->objc.ident->len, "l_OBJC_LABEL_PROTOCOL_$_", 24);
    Symbol* labelSymbol = ObjcSymbols::getGlobal(sname);

    labelSymbol->Sclass = SCcomdat; // weak symbol
    labelSymbol->Sdt = dt;
    labelSymbol->Sseg = objc_getsegment(SEGobjc_protolist);
    outdata(labelSymbol);
}

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
        assert(func->objcSelector);
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

/***************************************/

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

    if (cdecl->ident && cdecl->ident == Id::ObjcThrowable)
    {
        if (ClassDeclaration::objcthrowable)
            ClassDeclaration::objcthrowable->error("%s", msg);

        ClassDeclaration::objcthrowable = cdecl;
    }
}

bool Objc_ClassDeclaration::isInterface()
{
    return objc;
}

bool Objc_ClassDeclaration::isRootClass()
{
    return isInterface() && !metaclass && !cdecl->baseClass;
}

void Objc_ClassDeclaration::addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories)
{
    if (objc && !extern_ && !meta)
        classes->push(cdecl);
}