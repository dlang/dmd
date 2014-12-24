
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_symbols_common.c
 */

#include "aggregate.h"
#include "cc.h"
#include "dt.h"
#include "type.h"
#include "objc.h"
#include "global.h"

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

// MARK: FragileAbiObjcSymbols

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

// MARK: FragileAbiObjcSymbols

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
