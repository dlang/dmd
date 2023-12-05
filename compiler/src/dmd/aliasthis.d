/**
 * Implements the `alias this` symbol.
 *
 * Specification: $(LINK2 https://dlang.org/spec/class.html#alias-this, Alias This)
 *
 * Copyright:   Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/aliasthis.d, _aliasthis.d)
 * Documentation:  https://dlang.org/phobos/dmd_aliasthis.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/aliasthis.d
 */

module dmd.aliasthis;

import core.stdc.stdio;

import dmd.dsymbol;
import dmd.identifier;
import dmd.location;
import dmd.mtype;
import dmd.visitor;

/***********************************************************
 * alias ident this;
 */
extern (C++) final class AliasThis : Dsymbol
{
    Identifier ident;
    /// The symbol this `alias this` resolves to
    Dsymbol sym;
    /// Whether this `alias this` is deprecated or not
    bool isDeprecated_;

    extern (D) this(const ref Loc loc, Identifier ident) @safe
    {
        super(loc, null);    // it's anonymous (no identifier)
        this.ident = ident;
    }

    override AliasThis syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto at = new AliasThis(loc, ident);
        at.comment = comment;
        return at;
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

    override bool isDeprecated() const
    {
        return this.isDeprecated_;
    }
}

/**************************************
 * Check and set 'att' if 't' is a recursive 'alias this' type
 *
 * The goal is to prevent endless loops when there is a cycle in the alias this chain.
 * Since there is no multiple `alias this`, the chain either ends in a leaf,
 * or it loops back on itself as some point.
 *
 * Example: S0 -> (S1 -> S2 -> S3 -> S1)
 *
 * `S0` is not a recursive alias this, so this returns `false`, and a rewrite to `S1` can be tried.
 * `S1` is a recursive alias this type, but since `att` is initialized to `null`,
 * this still returns `false`, but `att1` is set to `S1`.
 * A rewrite to `S2` and `S3` can be tried, but when we want to try a rewrite to `S1` again,
 * we notice `att == t`, so we're back at the start of the loop, and this returns `true`.
 *
 * Params:
 *   att = type reference used to detect recursion. Should be initialized to `null`.
 *   t   = type of 'alias this' rewrite to attempt
 *
 * Returns:
 *   `false` if the rewrite is safe, `true` if it would loop back around
 */
bool isRecursiveAliasThis(ref Type att, Type t)
{
    //printf("+isRecursiveAliasThis(att = %s, t = %s)\n", att ? att.toChars() : "null", t.toChars());
    auto tb = t.toBasetype();
    if (att && tb.equivalent(att))
        return true;
    else if (!att && tb.checkAliasThisRec())
        att = tb;
    return false;
}
