// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.objc;

import core.stdc.stdio;
import ddmd.dclass, ddmd.dscope, ddmd.dstruct, ddmd.func, ddmd.globals, ddmd.id, ddmd.root.stringtable;

class ObjcSelector
{
public:
    extern (C++) static __gshared StringTable stringtable;
    extern (C++) static __gshared StringTable vTableDispatchSelectors;
    extern (C++) static __gshared int incnum;
    const(char)* stringvalue;
    size_t stringlen;
    size_t paramCount;

    static void _init();

    // MARK: ObjcSelector
    extern (D) this(const(char)* sv, size_t len, size_t pcount);
    static ObjcSelector lookup(const(char)* s);
    static ObjcSelector lookup(const(char)* s, size_t len, size_t pcount);
    static ObjcSelector create(FuncDeclaration fdecl);
}

struct Objc_ClassDeclaration
{
    // true if this is an Objective-C class/interface
    bool objc;

    // MARK: Objc_ClassDeclaration
    extern (C++) bool isInterface();
}

struct Objc_FuncDeclaration
{
    FuncDeclaration fdecl;
    // Objective-C method selector (member function only)
    ObjcSelector selector;
}

// MARK: semantic
extern (C++) void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration cd);
extern (C++) void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration id, Scope* sc);

// MARK: semantic
extern (C++) void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration fd, Scope* sc);
extern (C++) bool objc_isUdaSelector(StructDeclaration sd);
extern (C++) void objc_FuncDeclaration_semantic_validateSelector(FuncDeclaration fd);
extern (C++) void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration fd);
extern (C++) void objc_tryMain_dObjc();
extern (C++) void objc_tryMain_init();
