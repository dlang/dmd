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
module rt.typeinfo.ti_char;

// char

class TypeInfo_a : TypeInfo
{
    override string toString() { return "char"; }

    override hash_t getHash(in void* p)
    {
        return *cast(char *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(char *)p1 == *cast(char *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(char *)p1 - *cast(char *)p2;
    }

    @property override size_t tsize() nothrow pure
    {
        return char.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        char t;

        t = *cast(char *)p1;
        *cast(char *)p1 = *cast(char *)p2;
        *cast(char *)p2 = t;
    }

    override void[] init() nothrow pure
    {   static immutable char c;

        return (cast(char *)&c)[0 .. 1];
    }
}
