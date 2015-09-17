// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.objc;

import core.stdc.stdio;
import ddmd.dclass;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.root.stringtable;

struct ObjcSelector
{
    extern (C++) static __gshared StringTable stringtable;
    extern (C++) static __gshared StringTable vTableDispatchSelectors;
    extern (C++) static __gshared int incnum;
    const(char)* stringvalue;
    size_t stringlen;
    size_t paramCount;

    extern (C++) static void _init();

    // MARK: ObjcSelector
    extern (D) this(const(char)* sv, size_t len, size_t pcount)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
    }

    extern (C++) static ObjcSelector* lookup(const(char)* s)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
    }

    extern (C++) static ObjcSelector* lookup(const(char)* s, size_t len, size_t pcount)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
    }

    extern (C++) static ObjcSelector* create(FuncDeclaration fdecl)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
    }
}

struct Objc_ClassDeclaration
{
    // true if this is an Objective-C class/interface
    bool objc;

    // MARK: Objc_ClassDeclaration
    extern (C++) bool isInterface()
    {
        return false;
    }
}

struct Objc_FuncDeclaration
{
    FuncDeclaration fdecl;
    // Objective-C method selector (member function only)
    ObjcSelector* selector;

    extern (D) this(FuncDeclaration fdecl)
    {
        this.fdecl = fdecl;
    }
}

// MARK: semantic
extern (C++) void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration cd)
{
    cd.error("Objective-C classes not supported");
}

extern (C++) void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration id, Scope* sc)
{
    if (sc.linkage == LINKobjc)
        id.error("Objective-C interfaces not supported");
}

// MARK: semantic
extern (C++) void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration fd, Scope* sc)
{
    // noop
}

extern (C++) bool objc_isUdaSelector(StructDeclaration sd)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
}

extern (C++) void objc_FuncDeclaration_semantic_validateSelector(FuncDeclaration fd)
{
    // noop
}

extern (C++) void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration fd)
{
    // noop
}

extern (C++) void objc_tryMain_dObjc()
{
    // noop
}

extern (C++) void objc_tryMain_init()
{
    // noop
}
