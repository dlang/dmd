
/**
 * Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/_objc_glue_stubs.d
 */

import core.stdc.stdio : printf;

import ddmd.func;
import ddmd.mtype;

import ddmd.backend.el;

extern (C++):

void objc_initSymbols()
{
    // noop
}

void objc_callfunc_setupEp(elem *esel, elem **ep, int reverse)
{
    // noop
}

void objc_callfunc_setupMethodSelector(Type tret, FuncDeclaration fd, Type t, elem *ehidden, elem **esel)
{
    // noop
}

void objc_callfunc_setupMethodCall(elem **ec, elem *ehidden, elem *ethis, TypeFunction tf)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
}

// MARK: Module::genmoduleinfo

void objc_Module_genmoduleinfo_classes()
{
    // noop
}
