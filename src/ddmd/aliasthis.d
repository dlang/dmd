/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/aliasthis.d, _aliasthis.d)
 */

module ddmd.aliasthis;

// Online documentation: https://dlang.org/phobos/ddmd_aliasthis.html

import core.stdc.stdio;
import ddmd.aggregate;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.globals;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.opover;
import ddmd.tokens;
import ddmd.semantic;
import ddmd.visitor;

/***********************************************************
 * alias ident this;
 */
extern (C++) final class AliasThis : Dsymbol
{
    Identifier ident;

    extern (D) this(Loc loc, Identifier ident)
    {
        super(null);    // it's anonymous (no identifier)
        this.loc = loc;
        this.ident = ident;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new AliasThis(loc, ident);
    }

    override const(char)* kind() const
    {
        return "alias this";
    }

    AliasThis isAliasThis()
    {
        return this;
    }

    override void accept(Visitor v)
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
        e = e.expressionSemantic(sc);
        if (tthis && ad.aliasthis.needThis())
        {
            if (e.op == TOKvar)
            {
                if (auto fd = (cast(VarExp)e).var.isFuncDeclaration())
                {
                    // https://issues.dlang.org/show_bug.cgi?id=13009
                    // Support better match for the overloaded alias this.
                    bool hasOverloads;
                    if (auto f = fd.overloadModMatch(loc, tthis, hasOverloads))
                    {
                        if (!hasOverloads)
                            fd = f;     // use exact match
                        e = new VarExp(loc, fd, hasOverloads);
                        e.type = f.type;
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
            e = e.expressionSemantic(sc);
        }
        e = resolveProperties(sc, e);
        if (gag && global.endGagging(olderrors))
            e = null;
    }
    return e;
}
