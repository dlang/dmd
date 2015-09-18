// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.nspace;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.identifier;
import ddmd.root.outbuffer;
import ddmd.visitor;

private enum LOG = false;

/* A namespace corresponding to a C++ namespace.
 * Implies extern(C++).
 */
extern (C++) final class Nspace : ScopeDsymbol
{
public:
    /* This implements namespaces.
     */
    extern (D) this(Loc loc, Identifier ident, Dsymbols* members)
    {
        super(ident);
        //printf("Nspace::Nspace(ident = %s)\n", ident->toChars());
        this.loc = loc;
        this.members = members;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        auto ns = new Nspace(loc, ident, null);
        return ScopeDsymbol.syntaxCopy(ns);
    }

    override void semantic(Scope* sc)
    {
        if (semanticRun >= PASSsemantic)
            return;
        semanticRun = PASSsemantic;
        static if (LOG)
        {
            printf("+Nspace::semantic('%s')\n", toChars());
        }
        if (_scope)
        {
            sc = _scope;
            _scope = null;
        }
        parent = sc.parent;
        if (members)
        {
            if (!symtab)
                symtab = new DsymbolTable();
            // The namespace becomes 'imported' into the enclosing scope
            for (Scope* sce = sc; 1; sce = sce.enclosing)
            {
                ScopeDsymbol sds = cast(ScopeDsymbol)sce.scopesym;
                if (sds)
                {
                    sds.importScope(this, Prot(PROTpublic));
                    break;
                }
            }
            assert(sc);
            sc = sc.push(this);
            sc.linkage = LINKcpp; // note that namespaces imply C++ linkage
            sc.parent = this;
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                //printf("add %s to scope %s\n", s->toChars(), toChars());
                s.addMember(sc, this);
            }
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                s.setScope(sc);
            }
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                s.importAll(sc);
            }
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic(sc);
            }
            sc.pop();
        }
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
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
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
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                s.semantic3(sc);
            }
            sc.pop();
        }
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        return Dsymbol.oneMember(ps, ident);
    }

    override int apply(Dsymbol_apply_ft_t fp, void* param)
    {
        if (members)
        {
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
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
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                //printf(" s = %s %s\n", s->kind(), s->toChars());
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
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                //printf("\t%s\n", s->toChars());
                s.setFieldOffset(ad, poffset, isunion);
            }
        }
    }

    override const(char)* kind()
    {
        return "namespace";
    }

    override Nspace isNspace()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
