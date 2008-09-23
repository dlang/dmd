/*
 *  Copyright (C) 2004-2005 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module rt.typeinfo.ti_Acreal;

private import typeinfo.ti_creal;

// creal[]

class TypeInfo_Ac : TypeInfo
{
    override string toString() { return "creal[]"; }

    override hash_t getHash(in void* p)
    {   creal[] s = *cast(creal[]*)p;
        size_t len = s.length;
        creal *str = s.ptr;
        hash_t hash = 0;

        while (len)
        {
            hash *= 9;
            hash += (cast(uint *)str)[0];
            hash += (cast(uint *)str)[1];
            hash += (cast(uint *)str)[2];
            hash += (cast(uint *)str)[3];
            hash += (cast(uint *)str)[4];
            str++;
            len--;
        }

        return hash;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        creal[] s1 = *cast(creal[]*)p1;
        creal[] s2 = *cast(creal[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return 0;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_c._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        creal[] s1 = *cast(creal[]*)p1;
        creal[] s2 = *cast(creal[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_c._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return (creal[]).sizeof;
    }

    override uint flags()
    {
        return 1;
    }

    override TypeInfo next()
    {
        return typeid(creal);
    }
}
