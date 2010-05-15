
// Copyright (c) 1999-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/* Code to help convert to the intermediate representation
 * of the compiler back end.
 * It's specific to the Digital Mars back end, but can serve
 * as a guide to hooking up to other back ends.
 */

elem *incUsageElem(IRState *irs, Loc loc);
elem *getEthis(Loc loc, IRState *irs, Dsymbol *fd);
elem *setEthis(Loc loc, IRState *irs, elem *ey, AggregateDeclaration *ad);
int intrinsic_op(char *name);
elem *resolveLengthVar(VarDeclaration *lengthVar, elem **pe, Type *t1);

