
#include "objc.h"
#include "identifier.h"
#include "dsymbol.h"
#include "declaration.h"
#include "aggregate.h"
#include "target.h"

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
    SEG_MAX
};


static int seg_list[SEG_MAX] = {0};

static int objc_getsegment(enum ObjcSegment segid)
{
    int *seg = seg_list;
    if (seg[segid] != 0)
        return seg[segid];

    // initialize
    int align = 2;
    seg[SEGcat_cls_meth] = MachObj::getsegment("__cat_cls_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcat_inst_meth] = MachObj::getsegment("__cat_inst_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGstring_object] = MachObj::getsegment("__string_object", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcstring_object] = MachObj::getsegment("__cstring_object", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGmessage_refs] = MachObj::getsegment("__message_refs", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
    seg[SEGsel_fixup] = MachObj::getsegment("__sel_fixup", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcls_refs] = MachObj::getsegment("__cls_refs", "__OBJC", align, S_ATTR_NO_DEAD_STRIP | S_LITERAL_POINTERS);
    seg[SEGclass] = MachObj::getsegment("__class", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGmeta_class] = MachObj::getsegment("__meta_class", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcls_meth] = MachObj::getsegment("__cls_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGinst_meth] = MachObj::getsegment("__inst_meth", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGprotocol] = MachObj::getsegment("__protocol", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGcstring] = MachObj::getsegment("__cstring", "__TEXT", align, S_CSTRING_LITERALS);
    seg[SEGustring] = MachObj::getsegment("__ustring", "__TEXT", align, S_REGULAR);
    seg[SEGcfstring] = MachObj::getsegment("__cfstring", "__DATA", align, S_REGULAR);
    seg[SEGcategory] = MachObj::getsegment("__category", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGclass_vars] = MachObj::getsegment("__class_vars", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGinstance_vars] = MachObj::getsegment("__instance_vars", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGmodule_info] = MachObj::getsegment("__module_info", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGsymbols] = MachObj::getsegment("__symbols", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGprotocol_ext] = MachObj::getsegment("__protocol_ext", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGclass_ext] = MachObj::getsegment("__class_ext", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGproperty] = MachObj::getsegment("__property", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);
    seg[SEGimage_info] = MachObj::getsegment("__image_info", "__OBJC", align, S_ATTR_NO_DEAD_STRIP);

    return seg[segid];
}

int ObjcSymbols::hassymbols = 0;

Symbol *ObjcSymbols::msgSend = NULL;
Symbol *ObjcSymbols::msgSend_stret = NULL;
Symbol *ObjcSymbols::msgSend_fpret = NULL;
Symbol *ObjcSymbols::msgSendSuper = NULL;
Symbol *ObjcSymbols::msgSendSuper_stret = NULL;
Symbol *ObjcSymbols::stringLiteralClassRef = NULL;
Symbol *ObjcSymbols::siminfo = NULL;
Symbol *ObjcSymbols::smodinfo = NULL;
Symbol *ObjcSymbols::ssymmap = NULL;

StringTable *ObjcSymbols::sclassnametable = NULL;
StringTable *ObjcSymbols::sclassreftable = NULL;
StringTable *ObjcSymbols::smethvarnametable = NULL;
StringTable *ObjcSymbols::smethvarreftable = NULL;
StringTable *ObjcSymbols::smethvartypetable = NULL;
StringTable *ObjcSymbols::sprototable = NULL;

static StringTable *initStringTable(StringTable *stringtable)
{
    delete stringtable;
    stringtable = new StringTable();
    stringtable->init();

    return stringtable;
}

void ObjcSymbols::init()
{
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

    // also wipe out segment numbers
    for (int s = 0; s < SEG_MAX; ++s)
        seg_list[s] = 0;

    ObjcSelector::init();
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

Symbol *ObjcSymbols::getStringLiteralClassRef()
{
    if (!stringLiteralClassRef)
        stringLiteralClassRef = symbol_name("___CFConstantStringClassReference", SCglobal, type_fake(TYnptr));
    return stringLiteralClassRef;
}

Symbol *ObjcSymbols::getCString(const char *str, size_t len, const char *symbolName)
{
    hassymbols = 1;

    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, len + 1, str);

    // find segment
    int seg = objc_getsegment(SEGcstring);

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
    dtdword(&dt, 16); // flags

    siminfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tschar));
    siminfo->Sdt = dt;
    siminfo->Sseg = objc_getsegment(SEGimage_info);
    outdata(siminfo);

    return siminfo;
}

Symbol *ObjcSymbols::getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    assert(!smodinfo); // only allow once per object file

    dt_t *dt = NULL;
    dtdword(&dt, 7);  // version
    dtdword(&dt, 16); // size
    dtxoff(&dt, ObjcSymbols::getCString("", 0, "L_CLASS_NAME_"), 0, TYnptr); // name
    dtxoff(&dt, ObjcSymbols::getSymbolMap(cls, cat), 0, TYnptr); // symtabs

    smodinfo = symbol_name("L_OBJC_MODULE_INFO", SCstatic, type_allocn(TYarray, tschar));
    smodinfo->Sdt = dt;
    smodinfo->Sseg = objc_getsegment(SEGmodule_info);
    outdata(smodinfo);

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
        dtxoff(&dt, cls->tdata()[i]->sobjccls, 0, TYnptr); // reference to class

    for (size_t i = 0; i < catcount; ++i)
        dtxoff(&dt, cat->tdata()[i]->sobjccls, 0, TYnptr); // reference to category

    ssymmap = symbol_name("L_OBJC_SYMBOLS", SCstatic, type_allocn(TYarray, tschar));
    ssymmap->Sdt = dt;
    ssymmap->Sseg = objc_getsegment(SEGsymbols);
    outdata(ssymmap);

    return ssymmap;
}

Symbol *ObjcSymbols::getClassName(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = sclassnametable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_CLASS_NAME_%lu", classnamecount++);
        sy = getCString(s, len, namestr);
        sv->ptrvalue = sy;
        classnamecount;
    }
    return sy;
}

Symbol *ObjcSymbols::getClassName(Identifier *ident)
{
    return getClassName(ident->string, ident->len);
}


Symbol *ObjcSymbols::getClassReference(const char *s, size_t len)
{
    hassymbols = 1;

    StringValue *sv = sclassreftable->update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        // create data
        dt_t *dt = NULL;
        Symbol *sclsname = getClassName(s, len);
        dtxoff(&dt, sclsname, 0, TYnptr);

        // find segment for class references
        int seg = objc_getsegment(SEGcls_refs);

        static size_t classrefcount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_CLASS_REFERENCES_%lu", classrefcount++);
        sy = symbol_name(namestr, SCstatic, type_fake(TYnptr));
        sy->Sdt = dt;
        sy->Sseg = seg;
        outdata(sy);

        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *ObjcSymbols::getClassReference(Identifier *ident)
{
    return getClassReference(ident->string, ident->len);
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
        sy = getCString(s, len, namestr);
        sv->ptrvalue = sy;
        ++classnamecount;
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
        int seg = objc_getsegment(SEGmessage_refs);

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
        sy = getCString(s, len, namestr);
        sv->ptrvalue = sy;
        outdata(sy);
        ++classnamecount;
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
        Type *type = types[i]->getType();
        const char *typestr;
        if (type == Type::tvoid)            typestr = "v";
        else if (type == Type::tint8)       typestr = "c";
        else if (type == Type::tuns8)       typestr = "C";
        else if (type == Type::tchar)       typestr = "C";
        else if (type == Type::tint16)      typestr = "s";
        else if (type == Type::tuns16)      typestr = "S";
        else if (type == Type::twchar)      typestr = "S";
        else if (type == Type::tint32)      typestr = "l";
        else if (type == Type::tuns32)      typestr = "L";
        else if (type == Type::tdchar)      typestr = "L";
        else if (type == Type::tint64)      typestr = "q";
        else if (type == Type::tuns64)      typestr = "Q";
        else if (type == Type::tfloat32)     typestr = "f";
        else if (type == Type::timaginary32) typestr = "f";
        else if (type == Type::tfloat64)     typestr = "d";
        else if (type == Type::timaginary64) typestr = "d";
        // "float80" is "long double" in Objective-C, but "long double" has no specific
        // encoding character documented. Since @encode in Objective-C outputs "d",
        // which is the same as "double", that's what we do here. But it doesn't look right.
        else if (type == Type::tfloat80)     typestr = "d";
        else if (type == Type::timaginary80) typestr = "d";
        else                                 typestr = "?"; // unknown
        // TODO: add "B" BOOL, "*" char*, "#" Class, "@" id, ":" SEL
        // TODO: add "^"<type> indirection and "^^" double indirection

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


Symbol *ObjcSymbols::getProtocolSymbol(ClassDeclaration *interface)
{
    hassymbols = 1;

    assert(interface->objcmeta == 0);

    StringValue *sv = sprototable->update(interface->objcident->string, interface->objcident->len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        ObjcProtocolDeclaration p(interface);
        p.toObjFile(0);
        sy = p.symbol;
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
    sprintf(namestr, "L_STR_LITERAL_%lu", strcount++);
    Symbol *sstr;
    if (sz == 1)
        sstr = getCString((const char *)str, len, namestr);
    else
        sstr = getUString(str, len, namestr);

    dt_t *dt = NULL;
    dtxoff(&dt, getStringLiteralClassRef(), 0, TYnptr);
    dtdword(&dt, sz == 1 ? 1992 : 2000);
    dtxoff(&dt, sstr, 0, TYnptr);
    dtdword(&dt, len);

    Symbol *si = symbol_generate(SCstatic,type_allocn(TYarray, tschar));
    si->Sdt = dt;
    si->Sseg = objc_getsegment(SEGcfstring);
    outdata(si);
    return si;
}


// MARK: ObjcSelectorBuilder

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

const char *ObjcSelectorBuilder::toString()
{
    char *s = (char*)malloc(slen + 1);
    size_t spos = 0;
    for (size_t i = 0; i < partCount; ++i)
    {
        memcpy(&s[spos], parts[i]->string, parts[i]->len);
        spos += parts[i]->len;
        if (colonCount)
        {   s[spos] = ':';
            spos += 1;
        }
    }
    assert(colonCount == 0 || partCount <= colonCount);
    if (colonCount > partCount)
    {
        for (size_t i = 0; i < colonCount - partCount; ++i)
        {   s[spos] = ':';
            spos += 1;
        }
    }
    assert(slen == spos);
    s[slen] = '\0';
    return s;
}


// MARK: Selector

StringTable ObjcSelector::stringtable;
int ObjcSelector::incnum = 0;

void ObjcSelector::init ()
{
    stringtable.init();
}

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount)
{
    stringvalue = sv;
    stringlen = len;
    paramCount = pcount;
}

ObjcSelector *ObjcSelector::lookup(ObjcSelectorBuilder *builder)
{
    return lookup(builder->toString(), builder->slen, builder->colonCount);
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

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount)
{
    StringValue *sv = stringtable.update(s, len);
    ObjcSelector *sel = (ObjcSelector *) sv->ptrvalue;
    if (!sel)
    {
        sel = new ObjcSelector(sv->toDchars(), len, pcount);
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
        if (cd->objc)
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
            else if (cd->objcmeta)
            {   // this is already a class object, nothing to do
                noop = 1;
                type = cd->type;
                return this;
            }
            else
            {   // this is a regular (non-class) object, invoke class method
                type = cd->metaclass->type;
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
        if (cd->objc)
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

/* ClassDeclaration::metaclass contains the metaclass from the semantic point
 of view. This function returns the metaclass from the Objective-C runtime's
 point of view. Here, the metaclass of a metaclass is the root metaclass, not
 nil, and the root metaclass's metaclass is itself. */
ClassDeclaration *ObjcClassDeclaration::getObjcMetaClass(ClassDeclaration *cdecl)
{
    if (!cdecl->metaclass && cdecl->objcmeta)
    {
        if (cdecl->baseClass)
            return getObjcMetaClass(cdecl->baseClass);
        else
            return cdecl;
    }
    else
        return cdecl->metaclass;
}

ObjcClassDeclaration::ObjcClassDeclaration(ClassDeclaration *cdecl, int ismeta)
{
    this->cdecl = cdecl;
    this->ismeta = ismeta;
    symbol = NULL;
    sprotocols = NULL;
}


void ObjcClassDeclaration::toObjFile(int multiobj)
{
    if (cdecl->objcextern)
        return; // only a declaration for an externally-defined class

    dt_t *dt = NULL;
    toDt(&dt);

    char *sname;
    if (!ismeta)
        sname = prefixSymbolName(cdecl->objcident->string, cdecl->objcident->len, "L_OBJC_CLASS_", 13);
    else
        sname = prefixSymbolName(cdecl->objcident->string, cdecl->objcident->len, "L_OBJC_METACLASS_", 17);
    symbol = symbol_name(sname, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment((!ismeta ? SEGclass : SEGmeta_class));
    outdata(symbol);
}

void ObjcClassDeclaration::toDt(dt_t **pdt)
{
    dtxoff(pdt, getMetaclass(), 0, TYnptr); // pointer to metaclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl->baseClass->objcident), 0, TYnptr); // name of superclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl->objcident), 0, TYnptr); // name of class
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
    dtdword(pdt, 0);
}

Symbol *ObjcClassDeclaration::getMetaclass()
{
    if (!ismeta)
    {   // regular class: return metaclass with the same name
        ObjcClassDeclaration meta(cdecl, 1);
        meta.toObjFile(0);
        sprotocols = meta.sprotocols;
        return meta.symbol;
    }
    else
    {   // metaclass: return root class's name (will be replaced with metaclass reference at load)
        ClassDeclaration *metadecl = cdecl;
        while (metadecl->baseClass)
            metadecl = metadecl->baseClass;
        return ObjcSymbols::getClassName(metadecl->objcident);
    }
}

Symbol *ObjcClassDeclaration::getIVarList()
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

    char *sname = prefixSymbolName(cdecl->objcident->string, cdecl->objcident->len, "L_OBJC_INSTANCE_VARIABLES_", 26);
    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = objc_getsegment(SEGinstance_vars);
    return sym;
}

Symbol *ObjcClassDeclaration::getMethodList()
{
    Dsymbols *methods = !ismeta ? &cdecl->objcMethodList : &cdecl->metaclass->objcMethodList;
    int methods_count = methods->dim;

    int overridealloc = ismeta && cdecl->objchaspreinit;
    if (overridealloc)
        methods_count += 2; // adding alloc & allocWithZone:

    if (!methods_count) // no member, no method list.
        return NULL;

    dt_t *dt = NULL;
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

    char *sname;
    if (!ismeta)
        sname = prefixSymbolName(cdecl->objcident->string, cdecl->objcident->len, "L_OBJC_INSTANCE_METHODS_", 24);
    else
        sname = prefixSymbolName(cdecl->objcident->string, cdecl->objcident->len, "L_OBJC_CLASS_METHODS_", 21);
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
    dtdword(&dt, 0); // pointer to next protocol list
    dtdword(&dt, cdecl->interfaces_dim); // number of protocols in list

    for (size_t i = 0; i < cdecl->interfaces_dim; ++i)
    {
        if (!cdecl->interfaces[i]->base->objc)
            error("Only Objective-C interfaces are supported on an Objective-C class");

        dtxoff(&dt, ObjcSymbols::getProtocolSymbol(cdecl->interfaces[i]->base), 0, TYnptr); // pointer to protocol decl
    }
    dtdword(&dt, 0); // null-terminate the list

    char *sname = prefixSymbolName(cdecl->objcident->string, cdecl->objcident->len, "L_OBJC_CLASS_PROTOCOLS_", 23);
    sprotocols = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sprotocols->Sdt = dt;
    sprotocols->Sseg = objc_getsegment(SEGcat_cls_meth);
    outdata(sprotocols);
    return sprotocols;
}


// MARK: ObjcProtocolDeclaration

ObjcProtocolDeclaration::ObjcProtocolDeclaration(ClassDeclaration *idecl)
{
    this->idecl = idecl;
    symbol = NULL;
}


void ObjcProtocolDeclaration::toObjFile(int multiobj)
{
    dt_t *dt = NULL;
    toDt(&dt);

    char *sname = prefixSymbolName(idecl->objcident->string, idecl->objcident->len, "L_OBJC_PROTOCOL_", 16);
    symbol = symbol_name(sname, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = objc_getsegment(SEGprotocol);
    outdata(symbol, 1);
}

void ObjcProtocolDeclaration::toDt(dt_t **pdt)
{
    dtdword(pdt, 0); // isa pointer, initialized by the runtime
    dtxoff(pdt, ObjcSymbols::getClassName(idecl->objcident), 0, TYnptr); // protocol name

    Symbol *protocols = getProtocolList();
    if (protocols)  dtxoff(pdt, protocols, 0, TYnptr); // protocol list
    else            dtdword(pdt, 0); // or NULL if no protocol
    Symbol *imethods = getMethodList(0);
    if (imethods)  dtxoff(pdt, imethods, 0, TYnptr); // instance method list
    else           dtdword(pdt, 0); // or null if no methods
    Symbol *cmethods = getMethodList(1);
    if (cmethods)  dtxoff(pdt, cmethods, 0, TYnptr); // class method list
    else           dtdword(pdt, 0); // or null if no methods
}

Symbol *ObjcProtocolDeclaration::getMethodList(int wantsClassMethods)
{
    Dsymbols *methods = !wantsClassMethods ? &idecl->objcMethodList : &idecl->metaclass->objcMethodList;
    if (!methods->dim) // no member, no method list.
        return NULL;

    dt_t *dt = NULL;
    dtdword(&dt, methods->dim); // method count
    for (size_t i = 0; i < methods->dim; ++i)
    {
        FuncDeclaration *func = methods->tdata()[i]->isFuncDeclaration();
        assert(func);
        assert(func->objcSelector);
        dtxoff(&dt, func->objcSelector->toNameSymbol(), 0, TYnptr); // method name
        dtxoff(&dt, ObjcSymbols::getMethVarType(func), 0, TYnptr); // method type string
    }

    char *sname;
    if (!wantsClassMethods)
        sname = prefixSymbolName(idecl->objcident->string, idecl->objcident->len, "L_OBJC_PROTOCOL_INSTANCE_METHODS_", 33);
    else
        sname = prefixSymbolName(idecl->objcident->string, idecl->objcident->len, "L_OBJC_PROTOCOL_CLASS_METHODS_", 30);
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
        if (!idecl->interfaces[i]->base->objc)
            error("Only Objective-C interfaces are supported on an Objective-C interface");

        dtxoff(&dt, ObjcSymbols::getProtocolSymbol(idecl->interfaces[i]->base), 0, TYnptr); // pointer to protocol decl
    }
    dtdword(&dt, 0); // null-terminate the list

    char *sname = prefixSymbolName(idecl->objcident->string, idecl->objcident->len, "L_OBJC_PROTOCOL_REFS_", 21);
    Symbol *sprotocols = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sprotocols->Sdt = dt;
    sprotocols->Sseg = objc_getsegment(SEGcat_cls_meth);
    outdata(sprotocols);
    return sprotocols;
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
