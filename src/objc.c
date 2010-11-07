
#include "objc.h"
#include "identifier.h"
#include "dsymbol.h"
#include "declaration.h"
#include "aggregate.h"

#include <assert.h>
#include <stdio.h>

// Backend
#include "cc.h"
#include "dt.h"
#include "type.h"
#include "mtype.h"
#include "oper.h"
#include "global.h"
#include "mach.h"
// declaration from mach backend
extern int mach_getsegment(const char *sectname, const char *segname, int align, int flags, int flags2);

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



Symbol *ObjcSymbols::msgSend = NULL;
Symbol *ObjcSymbols::msgSend_stret = NULL;
Symbol *ObjcSymbols::msgSend_fpret = NULL;

Symbol *ObjcSymbols::getMsgSend(Type *ret, int hasHiddenArg)
{
    if (hasHiddenArg)
    {	if (!msgSend_stret)
            msgSend_stret = symbol_name("_objc_msgSend_stret", SCglobal, type_fake(TYhfunc));
        return msgSend_stret;
    }	
    else if (ret->isfloating())
    {	if (!msgSend_fpret)
            msgSend_fpret = symbol_name("_objc_msgSend_fpret", SCglobal, type_fake(TYnfunc));
        return msgSend_fpret;
    }
    else
    {	if (!msgSend)
            msgSend = symbol_name("_objc_msgSend", SCglobal, type_fake(TYnfunc));
        return msgSend;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getCString(const char *str, size_t len, const char *symbolName)
{
    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, len + 1, str);

    // find segment
    static int seg = -1;
    if (seg == -1)
        seg = mach_getsegment("__cstring", "__TEXT", sizeof(size_t), S_CSTRING_LITERALS, 0);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tschar));
    s->Sdt = dt;
    s->Sseg = seg;
    return s;
}

Symbol *ObjcSymbols::getImageInfo()
{
    static Symbol *sinfo = NULL;
    if (!sinfo) {
        dt_t *dt = NULL;
        dtdword(&dt, 0); // version
        dtdword(&dt, 16); // flags

        sinfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tschar));
        sinfo->Sdt = dt;
        sinfo->Sseg = mach_getsegment("__image_info", "__OBJC", sizeof(size_t), 0);
        outdata(sinfo);
    }
    return sinfo;
}

Symbol *ObjcSymbols::getModuleInfo(ClassDeclarations *cls, ClassDeclarations *cat)
{
    static Symbol *sinfo = NULL;
    if (!sinfo) {
        dt_t *dt = NULL;
        dtdword(&dt, 7);  // version
        dtdword(&dt, 16); // size
        dtxoff(&dt, ObjcSymbols::getCString("", 0, "L_CLASS_NAME_"), 0, TYnptr); // name
        dtxoff(&dt, ObjcSymbols::getSymbolMap(cls, cat), 0, TYnptr); // symtabs

        sinfo = symbol_name("L_OBJC_MODULE_INFO", SCstatic, type_allocn(TYarray, tschar));
        sinfo->Sdt = dt;
        sinfo->Sseg = mach_getsegment("__module_info", "__OBJC", sizeof(size_t), 0);
        outdata(sinfo);
        
        ObjcSymbols::getImageInfo();
    }
    return sinfo;
}

Symbol *ObjcSymbols::getSymbolMap(ClassDeclarations *cls, ClassDeclarations *cat)
{
    static Symbol *sinfo = NULL;
    if (!sinfo) {
        size_t classcount = cls->dim;
        size_t catcount = cat->dim;
    
        dt_t *dt = NULL;
        dtdword(&dt, 0); // selector refs count (unused)
        dtdword(&dt, 0); // selector refs ptr (unused)
        dtdword(&dt, classcount + (catcount << 16)); // class count / category count (expects little-endian)
        
        for (size_t i = 0; i < cls->dim; ++i)
            dtxoff(&dt, ((ClassDeclaration *)cls->data[i])->sobjccls, 0, TYnptr); // reference to class
            
        for (size_t i = 0; i < catcount; ++i)
            dtxoff(&dt, ((ClassDeclaration *)cat->data[i])->sobjccls, 0, TYnptr); // reference to category

        sinfo = symbol_name("L_OBJC_SYMBOLS", SCstatic, type_allocn(TYarray, tschar));
        sinfo->Sdt = dt;
        sinfo->Sseg = mach_getsegment("__symbols", "__OBJC", sizeof(size_t), 0);
        outdata(sinfo);
    }
    return sinfo;
}

Symbol *ObjcSymbols::getClassName(const char *s, size_t len)
{
	static StringTable stringtable;
    StringValue *sv = stringtable.update(s, len);
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
	static StringTable stringtable;
	StringValue *sv = stringtable.update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
		// create data
        dt_t *dt = NULL;
        Symbol *sclsname = getClassName(s, len);
        dtxoff(&dt, sclsname, 0, TYnptr);
	
        // find segment for class references
        static int seg = -1;
        if (seg == -1)
            seg = mach_getsegment("__cls_refs", "__OBJC", sizeof(size_t), S_LITERAL_POINTERS | S_ATTR_NO_DEAD_STRIP, 0);
        
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
	static StringTable stringtable;
    StringValue *sv = stringtable.update(s, len);
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

Symbol *ObjcSymbols::getMethVarType(const char *s, size_t len)
{
	static StringTable stringtable;
    StringValue *sv = stringtable.update(s, len);
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
        memcpy(types+1, func->parameters->data, param_dim * sizeof(Dsymbol **));
    
    return getMethVarType(types, 1 + param_dim);
}

Symbol *ObjcSymbols::getMethVarType(Dsymbol *s)
{
    return getMethVarType(&s, 1);
}


Symbol *ObjcSymbols::getProtocolSymbol(ClassDeclaration *interface)
{
	assert(interface->objcmeta == 0);
	
	static StringTable stringtable;
    StringValue *sv = stringtable.update(interface->ident->string, interface->ident->len);
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
    for (size_t i = 0; i < partCount; ++i) {
        memcpy(&s[spos], parts[i]->string, parts[i]->len);
        spos += parts[i]->len;
        s[spos] = ':';
        spos += 1;
    }
    s[slen] = '\0';
    return s;
}


// MARK: Selector

StringTable ObjcSelector::stringtable;
int ObjcSelector::incnum = 0;

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount)
{
    stringvalue = sv;
    stringlen = len;
    paramCount = pcount;
    namesymbol = NULL;
    refsymbol = NULL;
}	

ObjcSelector *ObjcSelector::lookup(ObjcSelectorBuilder *builder)
{
    return lookup(builder->toString(), builder->slen, builder->colonCount);
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount)
{
    StringValue *sv = stringtable.update(s, len);
    ObjcSelector *sel = (ObjcSelector *) sv->ptrvalue;
    if (!sel)
    {
        sel = new ObjcSelector(sv->lstring.string, len, pcount);
        sv->ptrvalue = sel;
    }
    return sel;
}

ObjcSelector *ObjcSelector::create(Identifier *ident, size_t pcount)
{
    // create a selector by adding a semicolon for each parameter
    ObjcSelectorBuilder selbuilder;
    selbuilder.addIdentifier(ident);
    for (size_t i = 0; i < pcount; ++i)
        selbuilder.addColon();
    
    return lookup(&selbuilder);
}


Symbol *ObjcSelector::toNameSymbol()
{
    if (namesymbol == NULL)
		namesymbol = ObjcSymbols::getMethVarName(stringvalue, stringlen);
    return namesymbol;
}

Symbol *ObjcSelector::toRefSymbol()
{
    if (refsymbol == NULL)
    {
		// create data
        dt_t *dt = NULL;
        Symbol *sselname = toNameSymbol();
        dtxoff(&dt, sselname, 0*0x9877660, TYnptr);
    
        
        // find segment
        static int seg = -1;
        if (seg == -1)
            seg = mach_getsegment("__message_refs", "__OBJC", sizeof(size_t), S_LITERAL_POINTERS | S_ATTR_NO_DEAD_STRIP, 0);
        
        // create symbol
        static size_t selcount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_SELECTOR_REFERENCES_%lu", selcount);
        refsymbol = symbol_name(namestr, SCstatic, type_fake(TYnptr));
        refsymbol->Sdt = dt;
        refsymbol->Sseg = seg;
        outdata(refsymbol);
        
        ++selcount;
    }
    return refsymbol; // not creating a copy can cause problems with optimizer
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
	this->type = cdecl->getObjCMetaClass()->getType();
}

void ObjcClassRefExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(cdecl->ident->string);
    buf->writestring(".class");
}

elem *ObjcClassRefExp::toElem(IRState *irs)
{
    return el_var(ObjcSymbols::getClassReference(cdecl->ident));
}


// MARK: ObjcClassDeclaration

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
        sname = prefixSymbolName(cdecl->ident->string, cdecl->ident->len, "L_OBJC_CLASS_", 13);
    else
        sname = prefixSymbolName(cdecl->ident->string, cdecl->ident->len, "L_OBJC_METACLASS_", 17);
    symbol = symbol_name(sname, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = mach_getsegment((!ismeta ? "__class" : "__metaclass"), "__OBJC", sizeof(size_t), 0);
    outdata(symbol);
}

void ObjcClassDeclaration::toDt(dt_t **pdt)
{
    dtxoff(pdt, getMetaclass(), 0, TYnptr); // pointer to metaclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl->baseClass->ident), 0, TYnptr); // name of superclass
    dtxoff(pdt, ObjcSymbols::getClassName(cdecl->ident), 0, TYnptr); // name of class
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
	{	// regular class: return metaclass with the same name
		ObjcClassDeclaration meta(cdecl, 1);
        meta.toObjFile(0);
        sprotocols = meta.sprotocols;
        return meta.symbol;
	}
	else
	{	// metaclass: return root class's name (will be replaced with metaclass reference at load)
        ClassDeclaration *metadecl = cdecl;
        while (metadecl->baseClass)
            metadecl = metadecl->baseClass;
		return ObjcSymbols::getClassName(metadecl->ident);
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
        VarDeclaration *ivar = ((Dsymbol *)cdecl->fields.data[i])->isVarDeclaration();
        assert(ivar);
        assert((ivar->storage_class & STCstatic) == 0);
        
        dtxoff(&dt, ObjcSymbols::getMethVarName(ivar->ident), 0, TYnptr); // ivar name
        dtxoff(&dt, ObjcSymbols::getMethVarType(ivar), 0, TYnptr); // ivar type string
        dtdword(&dt, ivar->offset); // ivar offset
    }
   
    char *sname = prefixSymbolName(cdecl->ident->string, cdecl->ident->len, "L_OBJC_INSTANCE_VARIABLES_", 26);
    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = mach_getsegment("__instance_vars", "__OBJC", sizeof(size_t), 0);
    return sym;
}

Symbol *ObjcClassDeclaration::getMethodList()
{
    Array *methods = !ismeta ? &cdecl->objcMethodList : &cdecl->getObjCMetaClass()->objcMethodList;
    if (!methods->dim) // no member, no method list.
        return NULL;
    
    dt_t *dt = NULL;
    dtdword(&dt, 0); // unused
    dtdword(&dt, methods->dim); // method count
    for (size_t i = 0; i < methods->dim; ++i)
    {
        FuncDeclaration *func = ((Dsymbol *)methods->data[i])->isFuncDeclaration();
        if (func && func->fbody)
        {
            assert(func->objcSelector);
            dtxoff(&dt, func->objcSelector->toNameSymbol(), 0, TYnptr); // method name
            dtxoff(&dt, ObjcSymbols::getMethVarType(func), 0, TYnptr); // method type string
            dtxoff(&dt, func->toSymbol(), 0, TYnptr); // function implementation
        }
    }
    
    char *sname;
    if (!ismeta)
        sname = prefixSymbolName(cdecl->ident->string, cdecl->ident->len, "L_OBJC_INSTANCE_METHODS_", 24);
    else
        sname = prefixSymbolName(cdecl->ident->string, cdecl->ident->len, "L_OBJC_CLASS_METHODS_", 21);
    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = mach_getsegment((!ismeta ? "__inst_meth" : "__cls_meth"), "__OBJC", sizeof(size_t), 0);
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
    
    char *sname = prefixSymbolName(cdecl->ident->string, cdecl->ident->len, "L_OBJC_CLASS_PROTOCOLS_", 23);
    sprotocols = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sprotocols->Sdt = dt;
    sprotocols->Sseg = mach_getsegment("__cat_cls_meth", "__OBJC", sizeof(size_t), 0);
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
    
    char *sname = prefixSymbolName(idecl->ident->string, idecl->ident->len, "L_OBJC_PROTOCOL_", 16);
    symbol = symbol_name(sname, SCstatic, type_fake(TYnptr));
    symbol->Sdt = dt;
    symbol->Sseg = mach_getsegment("__protocol", "__OBJC", sizeof(size_t), 0);
    outdata(symbol);
}

void ObjcProtocolDeclaration::toDt(dt_t **pdt)
{
    dtdword(pdt, 0); // isa pointer, initialized by the runtime
    dtxoff(pdt, ObjcSymbols::getClassName(idecl->ident), 0, TYnptr); // protocol name
    
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
    Array *methods = !wantsClassMethods ? &idecl->objcMethodList : &idecl->getObjCMetaClass()->objcMethodList;
    if (!methods->dim) // no member, no method list.
        return NULL;

	dt_t *dt = NULL;
    dtdword(&dt, methods->dim); // method count
    for (size_t i = 0; i < methods->dim; ++i)
	{
		FuncDeclaration *func = ((Dsymbol *)methods->data[i])->isFuncDeclaration();
		assert(func);
		assert(func->objcSelector);
		dtxoff(&dt, func->objcSelector->toNameSymbol(), 0, TYnptr); // method name
		dtxoff(&dt, ObjcSymbols::getMethVarType(func), 0, TYnptr); // method type string
	}
    
    char *sname;
    if (!wantsClassMethods)
        sname = prefixSymbolName(idecl->ident->string, idecl->ident->len, "L_OBJC_PROTOCOL_INSTANCE_METHODS_", 33);
    else
        sname = prefixSymbolName(idecl->ident->string, idecl->ident->len, "L_OBJC_PROTOCOL_CLASS_METHODS_", 30);
    Symbol *sym = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sym->Sdt = dt;
    sym->Sseg = mach_getsegment((!wantsClassMethods ? "__cat_inst_meth" : "__cat_cls_meth"), "__OBJC", sizeof(size_t), 0);
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
    
    char *sname = prefixSymbolName(idecl->ident->string, idecl->ident->len, "L_OBJC_PROTOCOL_REFS_", 21);
    Symbol *sprotocols = symbol_name(sname, SCstatic, type_fake(TYnptr));
    sprotocols->Sdt = dt;
    sprotocols->Sseg = mach_getsegment("__cat_cls_meth", "__OBJC", sizeof(size_t), 0);
    outdata(sprotocols);
    return sprotocols;
}