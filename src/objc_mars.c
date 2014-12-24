
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_mars.c
 */

#include "mars.h"
#include "arraytypes.h"
#include "visitor.h"
#include "cond.h"
#include "objc.h"

void objc_tryMain_dObjc()
{
    VersionCondition::addPredefinedGlobalIdent("D_ObjC");

    if (global.params.isOSX && global.params.is64bit) // && isArm
    {
        global.params.isObjcNonFragileAbi = 1;
        VersionCondition::addPredefinedGlobalIdent("D_ObjCNonFragileABI");
    }
}

void objc_tryMain_init()
{
    ObjcSymbols::init();
    ObjcSelector::init();
}
