
/* Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_glue_stubs.c
 */

#include <assert.h>
#include <stdio.h>

class FuncDeclaration;
class Type;
class TypeFunction;
struct elem;

void objc_callfunc_setupEp(elem *esel, elem **ep, int reverse)
{
    // noop
}

void objc_callfunc_setupMethodSelector(Type *tret, FuncDeclaration *fd, Type *t, elem *ehidden, elem **esel)
{
    // noop
}

void objc_callfunc_setupMethodCall(elem **ec, elem *ehidden, elem *ethis, TypeFunction *tf)
{
    printf("Should never be called when D_OBJC is false\n");
    assert(0);
}

// MARK: Module::genmoduleinfo

void objc_Module_genmoduleinfo_classes()
{
    // noop
}
