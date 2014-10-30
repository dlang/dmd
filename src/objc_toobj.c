
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_toobj.c
 */

#include "aggregate.h"
#include "module.h"
#include "objc.h"

#include "cc.h"
#include "dt.h"
#include "global.h"
#include "mach.h"
#include "type.h"

// MARK: ObjcSymbols

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

// MARK: NonFragileAbiObjcSymbols

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


// MARK: FragileAbiObjcProtocolDeclaration

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

// MARK: ClassDeclaration

ControlFlow objc_ClassDeclaration_toObjFile(ClassDeclaration *self, bool multiobj)
{
    if (self->objc.objc)
    {
        if (!self->objc.meta)
        {
            ObjcClassDeclaration* objcdecl = ObjcClassDeclaration::create(self);
            objcdecl->toObjFile(multiobj);
            self->objc.classSymbol = objcdecl->symbol;
        }
        return CFreturn; // skip rest of output
    }

    return CFnone;
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
