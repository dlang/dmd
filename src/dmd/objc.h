
/* Compiler implementation of the D programming language
 * Copyright (C) 2015-2018 by The D Language Foundation, All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/objc.h
 */

#ifndef DMD_OBJC_H
#define DMD_OBJC_H

#include "root.h"
#include "stringtable.h"

class AggregateDeclaration;
class Identifier;
class FuncDeclaration;
class ClassDeclaration;
class InterfaceDeclaration;
struct Scope;
class StructDeclaration;
class Type;

struct ObjcSelector
{
    static StringTable stringtable;
    static StringTable vTableDispatchSelectors;
    static int incnum;

    const char *stringvalue;
    size_t stringlen;
    size_t paramCount;

    static void _init();

    ObjcSelector(const char *sv, size_t len, size_t pcount);

    static ObjcSelector *lookup(const char *s);
    static ObjcSelector *lookup(const char *s, size_t len, size_t pcount);

    static ObjcSelector *create(FuncDeclaration *fdecl);
};

struct ObjcClassDeclaration
{
    bool isMeta;
    ClassDeclaration* metaclass;
};

class Objc
{
public:
    static void _init();

    virtual void setObjc(ClassDeclaration* cd) = 0;
    virtual void setObjc(InterfaceDeclaration*) = 0;

    virtual void setSelector(FuncDeclaration*, Scope* sc) = 0;
    virtual void validateSelector(FuncDeclaration* fd) = 0;
    virtual void checkLinkage(FuncDeclaration* fd) = 0;
    virtual AggregateDeclaration* isThis(FuncDeclaration* fd) = 0;

    virtual void setMetaclass(InterfaceDeclaration* id) = 0;
    virtual void setMetaclass(ClassDeclaration* id) = 0;
    virtual ClassDeclaration* getRuntimeMetaclass(ClassDeclaration* cd) = 0;
};

#endif /* DMD_OBJC_H */
