/**
 * Implementation of dynamic array property support routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.adi;

//debug=adi;            // uncomment to turn on debugging printf's

private
{
    debug(adi) import core.stdc.stdio;
    import core.stdc.string;
    import core.stdc.stdlib;
    import core.memory;
    import rt.util.utf;

    extern (C) void[] _adSort(void[] a, TypeInfo ti);
}


/**********************************************
 * Reverse array of chars.
 * Handled separately because embedded multibyte encodings should not be
 * reversed.
 */

extern (C) char[] _adReverseChar(char[] a)
{
    if (a.length > 1)
    {
        char[6] tmp;
        char[6] tmplo;
        char* lo = a.ptr;
        char* hi = &a[$ - 1];

        while (lo < hi)
        {   auto clo = *lo;
            auto chi = *hi;

            debug(adi) printf("lo = %d, hi = %d\n", lo, hi);
            if (clo <= 0x7F && chi <= 0x7F)
            {
                debug(adi) printf("\tascii\n");
                *lo = chi;
                *hi = clo;
                lo++;
                hi--;
                continue;
            }

            uint stridelo = UTF8stride[clo];

            uint stridehi = 1;
            while ((chi & 0xC0) == 0x80)
            {
                chi = *--hi;
                stridehi++;
                assert(hi >= lo);
            }
            if (lo == hi)
                break;

            debug(adi) printf("\tstridelo = %d, stridehi = %d\n", stridelo, stridehi);
            if (stridelo == stridehi)
            {

                memcpy(tmp.ptr, lo, stridelo);
                memcpy(lo, hi, stridelo);
                memcpy(hi, tmp.ptr, stridelo);
                lo += stridelo;
                hi--;
                continue;
            }

            /* Shift the whole array. This is woefully inefficient
             */
            memcpy(tmp.ptr, hi, stridehi);
            memcpy(tmplo.ptr, lo, stridelo);
            memmove(lo + stridehi, lo + stridelo , cast(size_t)((hi - lo) - stridelo));
            memcpy(lo, tmp.ptr, stridehi);
            memcpy(hi + stridehi - stridelo, tmplo.ptr, stridelo);

            lo += stridehi;
            hi = hi - 1 + cast(int)(stridehi - stridelo);
        }
    }
    return a;
}

unittest
{
    auto a = "abcd"c[];

    auto r = _adReverseChar(a.dup);
    //writefln(r);
    assert(r == "dcba");

    a = "a\u1235\u1234c";
    //writefln(a);
    r = _adReverseChar(a.dup);
    //writefln(r);
    assert(r == "c\u1234\u1235a");

    a = "ab\u1234c";
    //writefln(a);
    r = _adReverseChar(a.dup);
    //writefln(r);
    assert(r == "c\u1234ba");

    a = "\u3026\u2021\u3061\n";
    r = _adReverseChar(a.dup);
    assert(r == "\n\u3061\u2021\u3026");
}


/**********************************************
 * Reverse array of wchars.
 * Handled separately because embedded multiword encodings should not be
 * reversed.
 */

extern (C) wchar[] _adReverseWchar(wchar[] a)
{
    if (a.length > 1)
    {
        wchar[2] tmplo = void;
        wchar[2] tmphi = void;
        wchar* lo = a.ptr;
        wchar* hi = &a[$ - 1];

        while (lo < hi)
        {   auto clo = *lo;
            auto chi = *hi;

            if ((clo < 0xD800 || clo > 0xDFFF) &&
                (chi < 0xD800 || chi > 0xDFFF))
            {
                *lo = chi;
                *hi = clo;
                lo++;
                hi--;
                continue;
            }

            int stridelo = 1 + (clo >= 0xD800 && clo <= 0xDBFF);

            int stridehi = 1;
            if (chi >= 0xDC00 && chi <= 0xDFFF)
            {
                chi = *--hi;
                stridehi++;
                assert(hi >= lo);
            }
            if (lo == hi)
                break;

            if (stridelo == stridehi)
            {
                wchar[2] stmp;

                assert(stridelo == 2);
                stmp = lo[0 .. 2];
                lo[0 .. 2] = hi[0 .. 2];
                hi[0 .. 2] = stmp;
                lo += stridelo;
                hi--;
                continue;
            }

            /* Shift the whole array. This is woefully inefficient
             */
            memcpy(tmplo.ptr, lo, stridelo * wchar.sizeof);
            memcpy(tmphi.ptr, hi, stridehi * wchar.sizeof);
            memmove(lo + stridehi, lo + stridelo , (hi - (lo + stridelo)) * wchar.sizeof);
            memcpy(lo, tmphi.ptr, stridehi * wchar.sizeof);
            memcpy(hi + (stridehi - stridelo), tmplo.ptr, stridelo * wchar.sizeof);

            lo += stridehi;
            hi = hi - 1 + (stridehi - stridelo);
        }
    }
    return a;
}

unittest
{
  {
    wstring a = "abcd";

    auto r = _adReverseWchar(a.dup);
    assert(r == "dcba");

    a = "a\U00012356\U00012346c";
    r = _adReverseWchar(a.dup);
    assert(r == "c\U00012346\U00012356a");

    a = "ab\U00012345c";
    r = _adReverseWchar(a.dup);
    assert(r == "c\U00012345ba");
  }
  {
    wstring a = "a\U00000081b\U00002000c\U00010000";
    wchar[] b = a.dup;

    _adReverseWchar(b);
    _adReverseWchar(b);
    assert(b == "a\U00000081b\U00002000c\U00010000");
  }
}


/**********************************************
 * Support for array.reverse property.
 */

extern (C) void[] _adReverse(void[] a, size_t szelem)
out (result)
{
    assert(result is a);
}
body
{
    if (a.length >= 2)
    {
        byte*    tmp;
        byte[16] buffer;

        void* lo = a.ptr;
        void* hi = a.ptr + (a.length - 1) * szelem;

        tmp = buffer.ptr;
        if (szelem > 16)
        {
            //version (Windows)
                tmp = cast(byte*) alloca(szelem);
            //else
                //tmp = GC.malloc(szelem);
        }

        for (; lo < hi; lo += szelem, hi -= szelem)
        {
            memcpy(tmp, lo,  szelem);
            memcpy(lo,  hi,  szelem);
            memcpy(hi,  tmp, szelem);
        }

        version (Windows)
        {
        }
        else
        {
            //if (szelem > 16)
                // BUG: bad code is generate for delete pointer, tries
                // to call delclass.
                //GC.free(tmp);
        }
    }
    return a;
}

unittest
{
    debug(adi) printf("array.reverse.unittest\n");

    int[] a = new int[5];
    int[] b;

    for (auto i = 0; i < 5; i++)
        a[i] = i;
    *(cast(void[]*)&b) = _adReverse(*cast(void[]*)&a, a[0].sizeof);
    assert(b is a);
    for (auto i = 0; i < 5; i++)
        assert(a[i] == 4 - i);

    struct X20
    {   // More than 16 bytes in size
        int a;
        int b, c, d, e;
    }

    X20[] c = new X20[5];
    X20[] d;

    for (auto i = 0; i < 5; i++)
    {   c[i].a = i;
        c[i].e = 10;
    }
    *(cast(void[]*)&d) = _adReverse(*(cast(void[]*)&c), c[0].sizeof);
    assert(d is c);
    for (auto i = 0; i < 5; i++)
    {
        assert(c[i].a == 4 - i);
        assert(c[i].e == 10);
    }
}

private dchar[] mallocUTF32(C)(in C[] s)
{
    size_t j = 0;
    auto p = cast(dchar*)malloc(dchar.sizeof * s.length);
    auto r = p[0..s.length]; // r[] will never be longer than s[]
    for (size_t i = 0; i < s.length; )
    {
        dchar c = s[i];
        if (c >= 0x80)
            c = decode(s, i);
        else
            i++;                // c is ascii, no need for decode
        r[j++] = c;
    }
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
        {   char[4] buf;
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
        {   wchar[2] buf;
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

/***************************************
 * Support for array compare test.
 */

extern (C) int _adCmp(void[] a1, void[] a2, TypeInfo ti)
{
    debug(adi) printf("adCmp()\n");
    auto len = a1.length;
    if (a2.length < len)
        len = a2.length;
    auto sz = ti.tsize;
    void *p1 = a1.ptr;
    void *p2 = a2.ptr;

    if (sz == 1)
    {   // We should really have a ti.isPOD() check for this
        auto c = memcmp(p1, p2, len);
        if (c)
            return c;
    }
    else
    {
        for (size_t i = 0; i < len; i++)
        {
            auto c = ti.compare(p1 + i * sz, p2 + i * sz);
            if (c)
                return c;
        }
    }
    if (a1.length == a2.length)
        return 0;
    return (a1.length > a2.length) ? 1 : -1;
}

extern (C) int _adCmp2(void[] a1, void[] a2, TypeInfo ti)
{
    debug(adi) printf("_adCmp2(a1.length = %d, a2.length = %d)\n", a1.length, a2.length);
    return ti.compare(&a1, &a2);
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

/***************************************
 * Support for array compare test.
 */

extern (C) int _adCmpChar(void[] a1, void[] a2)
{
  version (D_InlineAsm_X86)
  {
    asm
    {   naked                   ;

        push    EDI             ;
        push    ESI             ;

        mov    ESI,a1+4[4+ESP]  ;
        mov    EDI,a2+4[4+ESP]  ;

        mov    ECX,a1[4+ESP]    ;
        mov    EDX,a2[4+ESP]    ;

        cmp     ECX,EDX         ;
        jb      GotLength       ;

        mov     ECX,EDX         ;

GotLength:
        cmp    ECX,4            ;
        jb    DoBytes           ;

        // Do alignment if neither is dword aligned
        test    ESI,3           ;
        jz    Aligned           ;

        test    EDI,3           ;
        jz    Aligned           ;
DoAlign:
        mov    AL,[ESI]         ; //align ESI to dword bounds
        mov    DL,[EDI]         ;

        cmp    AL,DL            ;
        jnz    Unequal          ;

        inc    ESI              ;
        inc    EDI              ;

        test    ESI,3           ;

        lea    ECX,[ECX-1]      ;
        jnz    DoAlign          ;
Aligned:
        mov    EAX,ECX          ;

        // do multiple of 4 bytes at a time

        shr    ECX,2            ;
        jz    TryOdd            ;

        repe                    ;
        cmpsd                   ;

        jnz    UnequalQuad      ;

TryOdd:
        mov    ECX,EAX          ;
DoBytes:
        // if still equal and not end of string, do up to 3 bytes slightly
        // slower.

        and    ECX,3            ;
        jz    Equal             ;

        repe                    ;
        cmpsb                   ;

        jnz    Unequal          ;
Equal:
        mov    EAX,a1[4+ESP]    ;
        mov    EDX,a2[4+ESP]    ;

        sub    EAX,EDX          ;
        pop    ESI              ;

        pop    EDI              ;
        ret                     ;

UnequalQuad:
        mov    EDX,[EDI-4]      ;
        mov    EAX,[ESI-4]      ;

        cmp    AL,DL            ;
        jnz    Unequal          ;

        cmp    AH,DH            ;
        jnz    Unequal          ;

        shr    EAX,16           ;

        shr    EDX,16           ;

        cmp    AL,DL            ;
        jnz    Unequal          ;

        cmp    AH,DH            ;
Unequal:
        sbb    EAX,EAX          ;
        pop    ESI              ;

        or     EAX,1            ;
        pop    EDI              ;

        ret                     ;
    }
  }
  else
  {
    debug(adi) printf("adCmpChar()\n");
    auto len = a1.length;
    if (a2.length < len)
        len = a2.length;
    auto c = memcmp(cast(char *)a1.ptr, cast(char *)a2.ptr, len);
    if (!c)
        c = cast(int)a1.length - cast(int)a2.length;
    return c;
  }
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
