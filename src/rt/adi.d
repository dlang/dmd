/**
 * Implementation of dynamic array property support routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC rt/_adi.d)
 */

module rt.adi;

//debug=adi;            // uncomment to turn on debugging printf's

private
{
    debug(adi) import core.stdc.stdio;
    import core.stdc.string;
    import core.stdc.stdlib;
    import core.memory;
    import core.internal.utf;

    extern (C) void[] _adSort(void[] a, TypeInfo ti);
}

private dchar[] mallocUTF32(C)(in C[] s)
{
    size_t j = 0;
    auto p = cast(dchar*)malloc(dchar.sizeof * s.length);
    auto r = p[0..s.length]; // r[] will never be longer than s[]
    foreach (dchar c; s)
        r[j++] = c;
    return r[0 .. j];
}

/**********************************************
 * Sort array of chars.
 */

extern (C) char[] _adSortChar(char[] a)
{
    if (a.length > 1)
    {
        auto da = mallocUTF32(a);
        _adSort(*cast(void[]*)&da, typeid(da[0]));
        size_t i = 0;
        foreach (dchar d; da)
        {   char[4] buf = void;
            auto t = toUTF8(buf, d);
            a[i .. i + t.length] = t[];
            i += t.length;
        }
        free(da.ptr);
    }
    return a;
}

/**********************************************
 * Sort array of wchars.
 */

extern (C) wchar[] _adSortWchar(wchar[] a)
{
    if (a.length > 1)
    {
        auto da = mallocUTF32(a);
        _adSort(*cast(void[]*)&da, typeid(da[0]));
        size_t i = 0;
        foreach (dchar d; da)
        {   wchar[2] buf = void;
            auto t = toUTF16(buf, d);
            a[i .. i + t.length] = t[];
            i += t.length;
        }
        free(da.ptr);
    }
    return a;
}

/***************************************
 * Support for array equality test.
 * Returns:
 *      1       equal
 *      0       not equal
 */

extern (C) int _adEq(void[] a1, void[] a2, TypeInfo ti)
{
    debug(adi) printf("_adEq(a1.length = %d, a2.length = %d)\n", a1.length, a2.length);
    if (a1.length != a2.length)
        return 0; // not equal
    auto sz = ti.tsize;
    auto p1 = a1.ptr;
    auto p2 = a2.ptr;

    if (sz == 1)
        // We should really have a ti.isPOD() check for this
        return (memcmp(p1, p2, a1.length) == 0);

    for (size_t i = 0; i < a1.length; i++)
    {
        if (!ti.equals(p1 + i * sz, p2 + i * sz))
            return 0; // not equal
    }
    return 1; // equal
}

extern (C) int _adEq2(void[] a1, void[] a2, TypeInfo ti)
{
    debug(adi) printf("_adEq2(a1.length = %d, a2.length = %d)\n", a1.length, a2.length);
    if (a1.length != a2.length)
        return 0;               // not equal
    if (!ti.equals(&a1, &a2))
        return 0;
    return 1;
}
unittest
{
    debug(adi) printf("array.Eq unittest\n");

    auto a = "hello"c;

    assert(a != "hel");
    assert(a != "helloo");
    assert(a != "betty");
    assert(a == "hello");
    assert(a != "hxxxx");

    float[] fa = [float.nan];
    assert(fa != fa);
}

unittest
{
    debug(adi) printf("array.Cmp unittest\n");

    auto a = "hello"c;

    assert(a >  "hel");
    assert(a >= "hel");
    assert(a <  "helloo");
    assert(a <= "helloo");
    assert(a >  "betty");
    assert(a >= "betty");
    assert(a == "hello");
    assert(a <= "hello");
    assert(a >= "hello");
    assert(a <  "я");
}

unittest
{
    debug(adi) printf("array.CmpChar unittest\n");

    auto a = "hello"c;

    assert(a >  "hel");
    assert(a >= "hel");
    assert(a <  "helloo");
    assert(a <= "helloo");
    assert(a >  "betty");
    assert(a >= "betty");
    assert(a == "hello");
    assert(a <= "hello");
    assert(a >= "hello");
}
