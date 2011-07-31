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
module rt.typeinfo.ti_Adouble;

private import rt.typeinfo.ti_double;
private import rt.util.hash;

// double[]

class TypeInfo_Ad : TypeInfo
{
    override string toString() { return "double[]"; }

    override hash_t getHash(in void* p)
    {   double[] s = *cast(double[]*)p;
        return hashOf(s.ptr, s.length * double.sizeof);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        double[] s1 = *cast(double[]*)p1;
        double[] s2 = *cast(double[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return 0;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_d._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        double[] s1 = *cast(double[]*)p1;
        double[] s2 = *cast(double[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_d._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    @property override size_t tsize() nothrow pure
    {
        return (double[]).sizeof;
    }

    @property override uint flags() nothrow pure
    {
        return 1;
    }

    @property override TypeInfo next() nothrow pure
    {
        return typeid(double);
    }

    @property override size_t talign() nothrow pure
    {
        return (double[]).alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        //arg1 = typeid(size_t);
        //arg2 = typeid(void*);
        return 0;
    }
}

// idouble[]

class TypeInfo_Ap : TypeInfo_Ad
{
    override string toString() { return "idouble[]"; }

    @property override TypeInfo next() nothrow pure
    {
        return typeid(idouble);
    }
}
