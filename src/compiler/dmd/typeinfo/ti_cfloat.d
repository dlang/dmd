/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 *
 *          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_cfloat;

// cfloat

class TypeInfo_q : TypeInfo
{
    override string toString() { return "cfloat"; }

    override hash_t getHash(in void* p)
    {
        return (cast(uint *)p)[0] + (cast(uint *)p)[1];
    }

    static equals_t _equals(cfloat f1, cfloat f2)
    {
        return f1 == f2;
    }

    static int _compare(cfloat f1, cfloat f2)
    {   int result;

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

    override equals_t equals(in void* p1, in void* p2)
    {
        return _equals(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    override size_t tsize()
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

    override void[] init()
    {   static immutable cfloat r;

        return (cast(cfloat *)&r)[0 .. 1];
    }
}
