/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_cdouble;

private import rt.util.hash;

// cdouble

class TypeInfo_r : TypeInfo
{
    override string toString() { return "cdouble"; }

    override hash_t getHash(in void* p)
    {
        return hashOf(p, cdouble.sizeof);
    }

    static equals_t _equals(cdouble f1, cdouble f2)
    {
        return f1 == f2;
    }

    static int _compare(cdouble f1, cdouble f2)
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
        return _equals(*cast(cdouble *)p1, *cast(cdouble *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(cdouble *)p1, *cast(cdouble *)p2);
    }

    @property override size_t tsize() nothrow pure
    {
        return cdouble.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        cdouble t;

        t = *cast(cdouble *)p1;
        *cast(cdouble *)p1 = *cast(cdouble *)p2;
        *cast(cdouble *)p2 = t;
    }

    override void[] init() nothrow pure
    {   static immutable cdouble r;

        return (cast(cdouble *)&r)[0 .. 1];
    }

    @property override size_t talign() nothrow pure
    {
        return cdouble.alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {   arg1 = typeid(double);
        arg2 = typeid(double);
        return 0;
    }
}
