/**
 * Provide the root object that classes in dmd inherit from.
 *
 * Copyright: Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/rootobject.d, root/_rootobject.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_rootobject.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/rootobject.d
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
    condition,
    templateparameter,
}

/***********************************************************
 */

extern (C++) class RootObject
{
    /*should be static shared*/ __gshared size_t nextSerial;

    size_t serial;

    this() nothrow @nogc
    {
        if (!__ctfe)
        {
            serial = ++nextSerial;
            // this.serial = atomicFetchAdd(nextSerial, 1);
        }
    }

    bool equals(const RootObject o) const
    {
        return o is this;
    }

    const(char)* toChars() const
    {
        assert(0);
    }

    ///
    extern(D) const(char)[] toString() const
    {
        import core.stdc.string : strlen;
        auto p = this.toChars();
        return p[0 .. strlen(p)];
    }

    DYNCAST dyncast() const nothrow pure @nogc @safe
    {
        return DYNCAST.object;
    }
}
