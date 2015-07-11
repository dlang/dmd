// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.objc_stubs;

import core.stdc.stdio;
import ddmd.dclass, ddmd.dscope, ddmd.dstruct, ddmd.func, ddmd.globals, ddmd.id, ddmd.root.stringtable;

class ObjcSelector
{
    // MARK: ObjcSelector
    extern (D) this(const(char)* sv, size_t len, size_t pcount)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
    }

    static ObjcSelector lookup(const(char)* s)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
        return null;
    }

    static ObjcSelector lookup(const(char)* s, size_t len, size_t pcount)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
        return null;
    }

    static ObjcSelector create(FuncDeclaration fdecl)
    {
        printf("Should never be called when D_OBJC is false\n");
        assert(0);
        return null;
    }
}

struct Objc_ClassDeclaration
{
    // MARK: Objc_ClassDeclaration
    extern (C++) bool isInterface()
    {
        return false;
    }
}

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
    return false;
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
