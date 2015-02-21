// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.rootobject;

import core.stdc.stdio;

import ddmd.root.outbuffer;

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

    char* toChars()
    {
        assert(0);
    }

    void toBuffer(OutBuffer* buf)
    {
        assert(0);
    }

    int dyncast()
    {
        assert(0);
    }
}
