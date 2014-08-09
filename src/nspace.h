
// Compiler implementation of the D programming language
// Copyright: Copyright (c) 2014 by Digital Mars, All Rights Reserved
// Authors: Walter Bright, http://www.digitalmars.com
// License: http://boost.org/LICENSE_1_0.txt
// Source: https://github.com/D-Programming-Language/dmd/blob/master/src/nspace.h


#ifndef DMD_NSPACE_H
#define DMD_NSPACE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

/* A namespace corresponding to a C++ namespace.
 * Implies extern(C++).
 */

class Nspace : public ScopeDsymbol
{
  public:
    Nspace(Loc loc, Identifier *ident, Dsymbols *members);

    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    int apply(Dsymbol_apply_ft_t fp, void *param);
    bool hasPointers();
    void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    const char *kind();
    void toObjFile(bool multiobj);
    Nspace *isNspace() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_NSPACE_H */
