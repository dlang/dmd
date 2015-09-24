// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.aliasthis;

import ddmd.aggregate, ddmd.declaration, ddmd.dscope, ddmd.dsymbol, ddmd.errors, ddmd.expression, ddmd.func, ddmd.globals, ddmd.hdrgen, ddmd.identifier, ddmd.mtype, ddmd.opover, ddmd.root.outbuffer, ddmd.tokens, ddmd.visitor;

/**************************************************************/
extern (C++) final class AliasThis : Dsymbol
{
public:
    // alias Identifier this;
    Identifier ident;

    // it's anonymous (no identifier)
    extern (D) this(Loc loc, Identifier ident)
    {
        super(null);
        this.loc = loc;
        this.ident = ident;
    }

    Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        /* Since there is no semantic information stored here,
         * we don't need to copy it.
         */
        return this;
    }

    void semantic(Scope* sc)
    {
        Dsymbol p = sc.parent.pastMixin();
        AggregateDeclaration ad = p.isAggregateDeclaration();
        if (!ad)
        {
            .error(loc, "alias this can only be a member of aggregate, not %s %s", p.kind(), p.toChars());
            return;
        }
        assert(ad.members);
        Dsymbol s = ad.search(loc, ident);
        if (!s)
        {
            s = sc.search(loc, ident, null);
            if (s)
                .error(loc, "%s is not a member of %s", s.toChars(), ad.toChars());
            else
                .error(loc, "undefined identifier %s", ident.toChars());
            return;
        }
        else if (ad.aliasthis && s != ad.aliasthis)
        {
            .error(loc, "there can be only one alias this");
            return;
        }
        if (ad.type.ty == Tstruct && (cast(TypeStruct)ad.type).sym != ad)
        {
            AggregateDeclaration ad2 = (cast(TypeStruct)ad.type).sym;
            assert(ad2.type == Type.terror);
            ad.aliasthis = ad2.aliasthis;
            return;
        }
        /* disable the alias this conversion so the implicit conversion check
         * doesn't use it.
         */
        ad.aliasthis = null;
        Dsymbol sx = s;
        if (sx.isAliasDeclaration())
            sx = sx.toAlias();
        Declaration d = sx.isDeclaration();
        if (d && !d.isTupleDeclaration())
        {
            Type t = d.type;
            assert(t);
            if (ad.type.implicitConvTo(t) > MATCHnomatch)
            {
                .error(loc, "alias this is not reachable as %s already converts to %s", ad.toChars(), t.toChars());
            }
        }
        ad.aliasthis = s;
    }

    const(char)* kind()
    {
        return "alias this";
    }

    AliasThis isAliasThis()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) Expression resolveAliasThis(Scope* sc, Expression e, bool gag = false)
{
    AggregateDeclaration ad = isAggregate(e.type);
    if (ad && ad.aliasthis)
    {
        uint olderrors = gag ? global.startGagging() : 0;
        Loc loc = e.loc;
        Type tthis = (e.op == TOKtype ? e.type : null);
        e = new DotIdExp(loc, e, ad.aliasthis.ident);
        e = e.semantic(sc);
        if (tthis && ad.aliasthis.needThis())
        {
            if (e.op == TOKvar)
            {
                if (FuncDeclaration f = (cast(VarExp)e).var.isFuncDeclaration())
                {
                    // Bugzilla 13009: Support better match for the overloaded alias this.
                    Type t;
                    f = f.overloadModMatch(loc, tthis, t);
                    if (f && t)
                    {
                        e = new VarExp(loc, f, 0); // use better match
                        e = new CallExp(loc, e);
                        goto L1;
                    }
                }
            }
            /* non-@property function is not called inside typeof(),
             * so resolve it ahead.
             */
            {
                int save = sc.intypeof;
                sc.intypeof = 1; // bypass "need this" error check
                e = resolveProperties(sc, e);
                sc.intypeof = save;
            }
        L1:
            e = new TypeExp(loc, new TypeTypeof(loc, e));
            e = e.semantic(sc);
        }
        e = resolveProperties(sc, e);
        if (gag && global.endGagging(olderrors))
            e = null;
    }
    return e;
}
