
/* Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
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

class ClassDeclaration;
class FuncDeclaration;
class Identifier;
class InterfaceDeclaration;

// MARK: ObjcSelector

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
}

ObjcSelector *ObjcSelector::lookup(const char *s)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
    return NULL;
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
    return NULL;
}

ObjcSelector *ObjcSelector::create(FuncDeclaration *fdecl)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
    return NULL;
}

// MARK: semantic

void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration *cd)
{
    cd->error("Objective-C classes not supported");
}

void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration *id, Scope *sc)
{
    if (sc->linkage == LINKobjc)
        id->error("Objective-C interfaces not supported");
}

// MARK: Objc_ClassDeclaration

bool Objc_ClassDeclaration::isInterface()
{
    return false;
}

// MARK: Objc_FuncDeclaration

Objc_FuncDeclaration::Objc_FuncDeclaration()
{
    this->fdecl = fdecl;
    selector = NULL;
}

Objc_FuncDeclaration::Objc_FuncDeclaration(FuncDeclaration* fdecl)
{
    this->fdecl = fdecl;
    selector = NULL;
}

bool objc_isUdaSelector (StructDeclaration *sd)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
    return false;
}

// MARK: semantic

void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration *fd, Scope *sc)
{
    // noop
}

void objc_FuncDeclaration_semantic_validateSelector (FuncDeclaration *fd)
{
    // noop
}

void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration *fd)
{
    // noop
}

void objc_tryMain_dObjc()
{
    // noop
}

void objc_tryMain_init()
{
    // noop
}
