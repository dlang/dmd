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
module rt.typeinfo.ti_ptr;

// pointer

class TypeInfo_P : TypeInfo
{
    @trusted:
    const:
    pure:
    nothrow:

    override size_t getHash(in void* p)
    {
        return cast(uint)*cast(void* *)p;
    }

    override bool equals(in void* p1, in void* p2)
    {
        return *cast(void* *)p1 == *cast(void* *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        auto c = *cast(void* *)p1 - *cast(void* *)p2;
        if (c < 0)
            return -1;
        else if (c > 0)
            return 1;
        return 0;
    }

    override @property size_t tsize() nothrow pure
    {
        return (void*).sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        void* t;

        t = *cast(void* *)p1;
        *cast(void* *)p1 = *cast(void* *)p2;
        *cast(void* *)p2 = t;
    }

    override @property uint flags() nothrow pure
    {
        return 1;
    }
}
