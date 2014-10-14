/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_cfloat;

private import rt.util.hash;

// cfloat

class TypeInfo_q : TypeInfo
{
    @trusted:
    pure:
    nothrow:

    static bool _equals(cfloat f1, cfloat f2)
    {
        return f1 == f2;
    }

    static int _compare(cfloat f1, cfloat f2)
    {
        int result;

        if (f1.re < f2.re)
            result = -1;
        else if (f1.re > f2.re)
            result = 1;
        else if (f1.im < f2.im)
            result = -1;
        else if (f1.im > f2.im)
            result = 1;
        else
            result = 0;
        return result;
    }

    const:

    override string toString() const pure nothrow @safe { return "cfloat"; }

    override size_t getHash(in void* p)
    {
        return rt.util.hash.hashOf(p, cfloat.sizeof);
    }

    override bool equals(in void* p1, in void* p2)
    {
        return _equals(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    override @property size_t tsize() nothrow pure
    {
        return cfloat.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        cfloat t;

        t = *cast(cfloat *)p1;
        *cast(cfloat *)p1 = *cast(cfloat *)p2;
        *cast(cfloat *)p2 = t;
    }

    override const(void)[] init() nothrow pure
    {
        static immutable cfloat r;

        return (cast(cfloat *)&r)[0 .. 1];
    }

    override @property size_t talign() nothrow pure
    {
        return cfloat.alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        arg1 = typeid(double);
        return 0;
    }
}
