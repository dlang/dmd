
/* Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc.h
 */

#ifndef DMD_OBJC_H
#define DMD_OBJC_H

#include "root.h"
#include "stringtable.h"

class Identifier;
class FuncDeclaration;
class ClassDeclaration;
class InterfaceDeclaration;
class ObjcSelector;

class ObjcSelector
{
public:
    static StringTable stringtable;
    static StringTable vTableDispatchSelectors;
    static int incnum;

    const char *stringvalue;
    size_t stringlen;
    size_t paramCount;

    static void init();

    ObjcSelector(const char *sv, size_t len, size_t pcount);

    static ObjcSelector *lookup(const char *s);
    static ObjcSelector *lookup(const char *s, size_t len, size_t pcount);

    static ObjcSelector *create(FuncDeclaration *fdecl);
};

struct Objc_ClassDeclaration
{
    // true if this is an Objective-C class/interface
    bool objc;

    bool isInterface();
};

struct Objc_FuncDeclaration
{
    FuncDeclaration* fdecl;

    // Objective-C method selector (member function only)
    ObjcSelector *selector;

    Objc_FuncDeclaration();
    Objc_FuncDeclaration(FuncDeclaration* fdecl);
};

void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration *cd);

void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration *id, Scope *sc);

void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration *fd, Scope *sc);
bool objc_isUdaSelector(StructDeclaration *sd);
void objc_FuncDeclaration_semantic_validateSelector(FuncDeclaration *fd);
void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration *fd);

void objc_tryMain_dObjc();
void objc_tryMain_init();

#endif /* DMD_OBJC_H */
