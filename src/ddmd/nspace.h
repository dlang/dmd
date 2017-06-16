/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

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
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    Dsymbol *search(Loc loc, Identifier *ident, int flags = SearchLocalsOnly);
    int apply(Dsymbol_apply_ft_t fp, void *param);
    bool hasPointers();
    void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    const char *kind();
    Nspace *isNspace() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_NSPACE_H */
