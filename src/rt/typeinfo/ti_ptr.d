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
module rt.typeinfo.ti_ptr;

// pointer

class TypeInfo_P : TypeInfo
{
    override hash_t getHash(in void* p)
    {
        return cast(uint)*cast(void* *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
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

    @property override size_t tsize() nothrow pure
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

    @property override uint flags() nothrow pure
    {
        return 1;
    }
}
