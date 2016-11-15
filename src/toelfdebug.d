/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _toelfdebug.d)
 */

module ddmd.toelfdebug;

import ddmd.denum;
import ddmd.dstruct;
import ddmd.dclass;

/****************************
 * Emit symbolic debug info in Dwarf2 format.
 */

extern (C++) void toDebug(EnumDeclaration ed)
{
    //printf("EnumDeclaration::toDebug('%s')\n", ed.toChars());
}

extern (C++) void toDebug(StructDeclaration sd)
{
}

extern (C++) void toDebug(ClassDeclaration cd)
{
}
