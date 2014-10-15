/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_creal;

private import rt.util.hash;

// creal

class TypeInfo_c : TypeInfo
{
    @trusted:
    pure:
    nothrow:

    static bool _equals(creal f1, creal f2)
    {
        return f1 == f2;
    }

    static int _compare(creal f1, creal f2)
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

    override string toString() const pure nothrow @safe { return "creal"; }

    override size_t getHash(in void* p)
    {
        return hashOf(p, creal.sizeof);
    }

    override bool equals(in void* p1, in void* p2)
    {
        return _equals(*cast(creal *)p1, *cast(creal *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(creal *)p1, *cast(creal *)p2);
    }

    override @property size_t tsize() nothrow pure
    {
        return creal.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        creal t;

        t = *cast(creal *)p1;
        *cast(creal *)p1 = *cast(creal *)p2;
        *cast(creal *)p2 = t;
    }

    override const(void)[] init() nothrow pure
    {
        static immutable creal r;

        return (cast(creal *)&r)[0 .. 1];
    }

    override @property size_t talign() nothrow pure
    {
        return creal.alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        arg1 = typeid(real);
        arg2 = typeid(real);
        return 0;
    }
}
