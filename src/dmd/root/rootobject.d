/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC root/_rootobject.d)
 */

module dmd.root.rootobject;

import core.stdc.stdio;

import dmd.root.outbuffer;

/***********************************************************
 */

enum DYNCAST : int
{
    object,
    expression,
    dsymbol,
    type,
    identifier,
    tuple,
    parameter,
    statement,
}

alias DYNCAST_OBJECT = DYNCAST.object;
alias DYNCAST_EXPRESSION = DYNCAST.expression;
alias DYNCAST_DSYMBOL = DYNCAST.dsymbol;
alias DYNCAST_TYPE = DYNCAST.type;
alias DYNCAST_IDENTIFIER = DYNCAST.identifier;
alias DYNCAST_TUPLE = DYNCAST.tuple;
alias DYNCAST_PARAMETER = DYNCAST.parameter;
alias DYNCAST_STATEMENT = DYNCAST.statement;

/***********************************************************
 */

extern (C++) class RootObject
{
    this()
    {
    }

    bool equals(RootObject o)
    {
        return o is this;
    }

    int compare(RootObject)
    {
        assert(0);
    }

    void print()
    {
        printf("%s %p\n", toChars(), this);
    }

    const(char)* toChars()
    {
        assert(0);
    }

    void toBuffer(OutBuffer* buf)
    {
        assert(0);
    }

    DYNCAST dyncast() const
    {
        return DYNCAST_OBJECT;
    }
}
