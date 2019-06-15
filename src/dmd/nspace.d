/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/nspace.d, _nspace.d)
 * Documentation:  https://dlang.org/phobos/dmd_nspace.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/nspace.d
 */

module dmd.nspace;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.expression;
import dmd.globals;
import dmd.identifier;
import dmd.visitor;
import core.stdc.stdio;

private enum LOG = false;

/***********************************************************
 * A namespace corresponding to a C++ namespace.
 * Implies extern(C++).
 */
extern (C++) final class Nspace : ScopeDsymbol
{
    /**
     * Determines whether the symbol for this namespace should be included in the symbol table.
     */
    bool mangleOnly;

    /**
     * Namespace identifier resolved during semantic.
     */
    Expression identExp;

    extern (D) this(const ref Loc loc, Identifier ident, Expression identExp, Dsymbols* members, bool mangleOnly)
    {
        super(loc, ident);
        //printf("Nspace::Nspace(ident = %s)\n", ident.toChars());
        this.members = members;
        this.identExp = identExp;
        this.mangleOnly = mangleOnly;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        auto ns = new Nspace(loc, ident, identExp, null, mangleOnly);
        return ScopeDsymbol.syntaxCopy(ns);
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        if (mangleOnly)
            parent = sds;
        else
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
                    sds2.importScope(this, Prot(Prot.Kind.public_));
                    break;
                }
            }
            assert(sc);
            sc = sc.push(this);
            sc.linkage = LINK.cpp; // namespaces default to C++ linkage
            sc.parent = this;
            members.foreachDsymbol(s => s.addMember(sc, mangleOnly ? sds : this));
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
            sc.linkage = LINK.cpp; // namespaces default to C++ linkage
            sc.parent = this;
            members.foreachDsymbol(s => s.setScope(sc));
            sc.pop();
        }
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        return Dsymbol.oneMember(ps, ident);
    }

    override Dsymbol search(const ref Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        //printf("%s.Nspace.search('%s')\n", toChars(), ident.toChars());
        if (_scope && !symtab)
            dsymbolSemantic(this, _scope);

        if (!members || !symtab) // opaque or semantic() is not yet called
        {
            error("is forward referenced when looking for `%s`", ident.toChars());
            return null;
        }

        return ScopeDsymbol.search(loc, ident, flags);
    }

    override int apply(Dsymbol_apply_ft_t fp, void* param)
    {
        return members.foreachDsymbol( (s) { return s && s.apply(fp, param); } );
    }

    override bool hasPointers()
    {
        //printf("Nspace::hasPointers() %s\n", toChars());
        return members.foreachDsymbol( (s) { return s.hasPointers(); } ) != 0;
    }

    override void setFieldOffset(AggregateDeclaration ad, uint* poffset, bool isunion)
    {
        //printf("Nspace::setFieldOffset() %s\n", toChars());
        if (_scope) // if fwd reference
            dsymbolSemantic(this, null); // try to resolve it
        members.foreachDsymbol( s => s.setFieldOffset(ad, poffset, isunion) );
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
