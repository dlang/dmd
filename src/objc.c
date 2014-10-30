
#include "objc.h"
#include "identifier.h"
#include "dsymbol.h"
#include "declaration.h"
#include "aggregate.h"
#include "target.h"
#include "id.h"
#include "attrib.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "objc_glue.h"

// Backend
#include "cc.h"
#include "dt.h"
#include "type.h"
#include "mtype.h"
#include "oper.h"
#include "global.h"
#include "mach.h"
#include "scope.h"

void mangleToBuffer(Type *t, OutBuffer *buf);



/***************************************/

#include "cond.h"

Objc_StructDeclaration::Objc_StructDeclaration()
{
    selectorTarget = false;
    isSelector = false;
}

// MARK: tryMain

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
