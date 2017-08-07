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

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        ScopeDsymbol.addMember(sc, sds);
        if (members)
        {
            if (!symtab)
                symtab = new DsymbolTable();
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
            assert(sc);
            sc = sc.push(this);
            sc.linkage = LINKcpp; // namespaces default to C++ linkage
            sc.parent = this;
            foreach (s; *members)
            {
                //printf("add %s to scope %s\n", s.toChars(), toChars());
                s.addMember(sc, this);
            }
            sc.pop();
        }
    }

    override void setScope(Scope* sc)
    {
        ScopeDsymbol.setScope(sc);
        if (members)
        {
            assert(sc);
            sc = sc.push(this);
            sc.linkage = LINKcpp; // namespaces default to C++ linkage
            sc.parent = this;
            foreach (s; *members)
            {
                s.setScope(sc);
            }
            sc.pop();
        }
    }

    override void semantic(Scope* sc)
    {
        if (semanticRun != PASSinit)
            return;
        static if (LOG)
        {
            printf("+Nspace::semantic('%s')\n", toChars());
        }
        if (_scope)
        {
            sc = _scope;
            _scope = null;
        }
        if (!sc)
            return;

        semanticRun = PASSsemantic;
        parent = sc.parent;
        if (members)
        {
            assert(sc);
            sc = sc.push(this);
            sc.linkage = LINKcpp; // note that namespaces imply C++ linkage
            sc.parent = this;
            foreach (s; *members)
            {
                s.importAll(sc);
            }
            foreach (s; *members)
            {
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic(sc);
            }
            sc.pop();
        }
        semanticRun = PASSsemanticdone;
        static if (LOG)
        {
            printf("-Nspace::semantic('%s')\n", toChars());
        }
    }

    override void semantic2(Scope* sc)
    {
        if (semanticRun >= PASSsemantic2)
            return;
        semanticRun = PASSsemantic2;
        static if (LOG)
        {
            printf("+Nspace::semantic2('%s')\n", toChars());
        }
        if (members)
        {
            assert(sc);
            sc = sc.push(this);
            sc.linkage = LINKcpp;
            foreach (s; *members)
            {
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic2(sc);
            }
            sc.pop();
        }
        static if (LOG)
        {
            printf("-Nspace::semantic2('%s')\n", toChars());
        }
    }

    override void semantic3(Scope* sc)
    {
        if (semanticRun >= PASSsemantic3)
            return;
        semanticRun = PASSsemantic3;
        static if (LOG)
        {
            printf("Nspace::semantic3('%s')\n", toChars());
        }
        if (members)
        {
            sc = sc.push(this);
            sc.linkage = LINKcpp;
            foreach (s; *members)
            {
                s.semantic3(sc);
            }
            sc.pop();
        }
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        return Dsymbol.oneMember(ps, ident);
    }

    override final Dsymbol search(Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        //printf("%s.Nspace.search('%s')\n", toChars(), ident.toChars());
        if (_scope && !symtab)
            semantic(_scope);

        if (!members || !symtab) // opaque or semantic() is not yet called
        {
            error("is forward referenced when looking for '%s'", ident.toChars());
            return null;
        }

        return ScopeDsymbol.search(loc, ident, flags);
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

    override void setFieldOffset(AggregateDeclaration ad, uint* poffset, bool isunion)
    {
        //printf("Nspace::setFieldOffset() %s\n", toChars());
        if (_scope) // if fwd reference
            semantic(null); // try to resolve it
        if (members)
        {
            foreach (s; *members)
            {
                //printf("\t%s\n", s.toChars());
                s.setFieldOffset(ad, poffset, isunion);
            }
        }
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
