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

module rt.typeinfo.ti_Afloat;

private import typeinfo.ti_float;

// float[]

class TypeInfo_Af : TypeInfo
{
    string toString() { return "float[]"; }

    hash_t getHash(in void* p)
    {   float[] s = *cast(float[]*)p;
        size_t len = s.length;
        auto str = s.ptr;
        hash_t hash = 0;

        while (len)
        {
            hash *= 9;
            hash += *cast(uint *)str;
            str++;
            len--;
        }

        return hash;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        float[] s1 = *cast(float[]*)p1;
        float[] s2 = *cast(float[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return 0;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_f._equals(s1[u], s2[u]);
            if (c == 0)
                return 0;
        }
        return 1;
    }

    int compare(in void* p1, in void* p2)
    {
        float[] s1 = *cast(float[]*)p1;
        float[] s2 = *cast(float[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_f._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    size_t tsize()
    {
        return (float[]).sizeof;
    }

    uint flags()
    {
        return 1;
    }

    TypeInfo next()
    {
        return typeid(float);
    }
}

// ifloat[]

class TypeInfo_Ao : TypeInfo_Af
{
    string toString() { return "ifloat[]"; }

    TypeInfo next()
    {
        return typeid(ifloat);
    }
}
