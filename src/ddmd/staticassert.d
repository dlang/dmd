/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/staticassert.d, _staticassert.d)
 */

module ddmd.staticassert;

// Online documentation: https://dlang.org/phobos/ddmd_staticassert.html

import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.dsymbolsem;
import ddmd.errors;
import ddmd.expression;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.semantic;
import ddmd.visitor;

/***********************************************************
 */
extern (C++) final class StaticAssert : Dsymbol
{
    Expression exp;
    Expression msg;

    extern (D) this(Loc loc, Expression exp, Expression msg)
    {
        super(Id.empty);
        this.loc = loc;
        this.exp = exp;
        this.msg = msg;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new StaticAssert(loc, exp.syntaxCopy(), msg ? msg.syntaxCopy() : null);
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        // we didn't add anything
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        //printf("StaticAssert::oneMember())\n");
        *ps = null;
        return true;
    }

    override const(char)* kind() const
    {
        return "static assert";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
