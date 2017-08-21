/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _nspace.d)
 */

module ddmd.nspace;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.globals;
import ddmd.identifier;
import ddmd.visitor;
import core.stdc.stdio;

private enum LOG = false;

/***********************************************************
 * A namespace corresponding to a C++ namespace.
 * Implies extern(C++).
 */
extern (C++) final class Nspace : ScopeDsymbol
{
    extern (D) this(Loc loc, Identifier ident, Dsymbols* members)
    {
        super(ident);
        //printf("Nspace::Nspace(ident = %s)\n", ident.toChars());
        this.loc = loc;
        this.members = members;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        auto ns = new Nspace(loc, ident, null);
        return ScopeDsymbol.syntaxCopy(ns);
    }

    override void setScope(Scope* sc)
    {
        super.setScope(sc);

        // The namespace becomes 'imported' into the enclosing scope
        for (Scope* sce = sc; 1; sce = sce.enclosing)
        {
            ScopeDsymbol sds2 = sce.scopesym;
            if (sds2)
            {
                sds2.importScope(this, Prot(PROTpublic));
                break;
            }
        }
    }

    override Scope* newScope()
    {
        auto sc = super.newScope();
        sc.linkage = LINKcpp; // namespaces default to C++ linkage
        sc.parent = this;
        return sc;
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        return Dsymbol.oneMember(ps, ident);
    }

    override int apply(Dsymbol_apply_ft_t fp, void* param)
    {
        if (members)
        {
            foreach (s; *members)
            {
                if (s)
                {
                    if (s.apply(fp, param))
                        return 1;
                }
            }
        }
        return 0;
    }

    override bool hasPointers()
    {
        //printf("Nspace::hasPointers() %s\n", toChars());
        if (members)
        {
            foreach (s; *members)
            {
                //printf(" s = %s %s\n", s.kind(), s.toChars());
                if (s.hasPointers())
                {
                    return true;
                }
            }
        }
        return false;
    }

    override const(char)* kind() const
    {
        return "namespace";
    }

    override inout(Nspace) isNspace() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
