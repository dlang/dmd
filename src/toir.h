
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/toir.h
 */

/* Code to help convert to the intermediate representation
 * of the compiler back end.
 * It's specific to the Digital Mars back end, but can serve
 * as a guide to hooking up to other back ends.
 */

elem *incUsageElem(IRState *irs, Loc loc);
elem *getEthis(Loc loc, IRState *irs, Dsymbol *fd);
elem *setEthis(Loc loc, IRState *irs, elem *ey, AggregateDeclaration *ad);
int intrinsic_op(FuncDeclaration *name);
elem *resolveLengthVar(VarDeclaration *lengthVar, elem **pe, Type *t1);

