/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC root/_rootobject.d)
 */

module ddmd.root.rootobject;

import core.stdc.stdio;

import ddmd.root.outbuffer;

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
    condition,
}

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
        return DYNCAST.object;
    }
}
