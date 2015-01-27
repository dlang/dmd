
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/toelfdebug.c
 */

#include <stdio.h>
#include <stddef.h>
#include <time.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "statement.h"
#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "id.h"
#include "import.h"
#include "template.h"

#include "rmem.h"
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cv4.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

/****************************
 * Emit symbolic debug info in Dwarf2 format.
 */

void toDebug(EnumDeclaration *ed)
{
    //printf("EnumDeclaration::toDebug('%s')\n", ed->toChars());
}

void toDebug(StructDeclaration *sd)
{
}

void toDebug(ClassDeclaration *cd)
{
}
