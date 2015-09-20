
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/toelfdebug.c
 */

import ddmd.denum;
import ddmd.dstruct;
import ddmd.dclass;

/****************************
 * Emit symbolic debug info in Dwarf2 format.
 */

extern(C++) void toDebug(EnumDeclaration ed)
{
    //printf("EnumDeclaration::toDebug('%s')\n", ed.toChars());
}

extern(C++) void toDebug(StructDeclaration sd)
{
}

extern(C++) void toDebug(ClassDeclaration cd)
{
}
