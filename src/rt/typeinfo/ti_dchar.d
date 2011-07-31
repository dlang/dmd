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
module rt.typeinfo.ti_dchar;

// dchar

class TypeInfo_w : TypeInfo
{
    override string toString() { return "dchar"; }

    override hash_t getHash(in void* p)
    {
        return *cast(dchar *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(dchar *)p1 == *cast(dchar *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(dchar *)p1 - *cast(dchar *)p2;
    }

    @property override size_t tsize() nothrow pure
    {
        return dchar.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        dchar t;

        t = *cast(dchar *)p1;
        *cast(dchar *)p1 = *cast(dchar *)p2;
        *cast(dchar *)p2 = t;
    }

    override void[] init() nothrow pure
    {   static immutable dchar c;

        return (cast(dchar *)&c)[0 .. 1];
    }
}
