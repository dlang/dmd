/**
 * Part of the D programming language runtime library.
 */

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
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

/*
 *  Modified by Sean Kelly for use with the D Runtime Project
 */

module rt.aApply;

/* This code handles decoding UTF strings for foreach loops.
 * There are 6 combinations of conversions between char, wchar,
 * and dchar, and 2 of each of those.
 */

private import rt.util.utf;

/**********************************************
 */

// dg is D, but _aApplycd() is C
extern (D) typedef int delegate(void *) dg_t;

extern (C) int _aApplycd1(char[] aa, dg_t dg)
{   int result;
    size_t i;
    size_t len = aa.length;

    debug(apply) printf("_aApplycd1(), len = %d\n", len);
    for (i = 0; i < len; )
    {   dchar d;

        d = aa[i];
        if (d & 0x80)
            d = decode(aa, i);
        else
            i++;
        result = dg(cast(void *)&d);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplywd1(wchar[] aa, dg_t dg)
{   int result;
    size_t i;
    size_t len = aa.length;

    debug(apply) printf("_aApplywd1(), len = %d\n", len);
    for (i = 0; i < len; )
    {   dchar d;

        d = aa[i];
        if (d & ~0x7F)
            d = decode(aa, i);
        else
            i++;
        result = dg(cast(void *)&d);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplycw1(char[] aa, dg_t dg)
{   int result;
    size_t i;
    size_t len = aa.length;

    debug(apply) printf("_aApplycw1(), len = %d\n", len);
    for (i = 0; i < len; )
    {   dchar d;
        wchar w;

        w = aa[i];
        if (w & 0x80)
        {   d = decode(aa, i);
            if (d <= 0xFFFF)
                w = cast(wchar) d;
            else
            {
                w = cast(wchar)((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
                result = dg(cast(void *)&w);
                if (result)
                    break;
                w = cast(wchar)(((d - 0x10000) & 0x3FF) + 0xDC00);
            }
        }
        else
            i++;
        result = dg(cast(void *)&w);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplywc1(wchar[] aa, dg_t dg)
{   int result;
    size_t i;
    size_t len = aa.length;

    debug(apply) printf("_aApplywc1(), len = %d\n", len);
    for (i = 0; i < len; )
    {   dchar d;
        wchar w;
        char c;

        w = aa[i];
        if (w & ~0x7F)
        {
            char[4] buf;

            d = decode(aa, i);
            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(cast(void *)&c2);
                if (result)
                    return result;
            }
            continue;
        }
        else
        {   c = cast(char)w;
            i++;
        }
        result = dg(cast(void *)&c);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplydc1(dchar[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplydc1(), len = %d\n", aa.length);
    foreach (dchar d; aa)
    {
        char c;

        if (d & ~0x7F)
        {
            char[4] buf;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(cast(void *)&c2);
                if (result)
                    return result;
            }
            continue;
        }
        else
        {
            c = cast(char)d;
        }
        result = dg(cast(void *)&c);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplydw1(dchar[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplydw1(), len = %d\n", aa.length);
    foreach (dchar d; aa)
    {
        wchar w;

        if (d <= 0xFFFF)
            w = cast(wchar) d;
        else
        {
            w = cast(wchar)((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
            result = dg(cast(void *)&w);
            if (result)
                break;
            w = cast(wchar)(((d - 0x10000) & 0x3FF) + 0xDC00);
        }
        result = dg(cast(void *)&w);
        if (result)
            break;
    }
    return result;
}


/****************************************************************************/

// dg is D, but _aApplycd2() is C
extern (D) typedef int delegate(void *, void *) dg2_t;

extern (C) int _aApplycd2(char[] aa, dg2_t dg)
{   int result;
    size_t i;
    size_t n;
    size_t len = aa.length;

    debug(apply) printf("_aApplycd2(), len = %d\n", len);
    for (i = 0; i < len; i += n)
    {   dchar d;

        d = aa[i];
        if (d & 0x80)
        {
            n = i;
            d = decode(aa, n);
            n -= i;
        }
        else
            n = 1;
        result = dg(&i, cast(void *)&d);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplywd2(wchar[] aa, dg2_t dg)
{   int result;
    size_t i;
    size_t n;
    size_t len = aa.length;

    debug(apply) printf("_aApplywd2(), len = %d\n", len);
    for (i = 0; i < len; i += n)
    {   dchar d;

        d = aa[i];
        if (d & ~0x7F)
        {
            n = i;
            d = decode(aa, n);
            n -= i;
        }
        else
            n = 1;
        result = dg(&i, cast(void *)&d);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplycw2(char[] aa, dg2_t dg)
{   int result;
    size_t i;
    size_t n;
    size_t len = aa.length;

    debug(apply) printf("_aApplycw2(), len = %d\n", len);
    for (i = 0; i < len; i += n)
    {   dchar d;
        wchar w;

        w = aa[i];
        if (w & 0x80)
        {   n = i;
            d = decode(aa, n);
            n -= i;
            if (d <= 0xFFFF)
                w = cast(wchar) d;
            else
            {
                w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
                result = dg(&i, cast(void *)&w);
                if (result)
                    break;
                w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
            }
        }
        else
            n = 1;
        result = dg(&i, cast(void *)&w);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplywc2(wchar[] aa, dg2_t dg)
{   int result;
    size_t i;
    size_t n;
    size_t len = aa.length;

    debug(apply) printf("_aApplywc2(), len = %d\n", len);
    for (i = 0; i < len; i += n)
    {   dchar d;
        wchar w;
        char c;

        w = aa[i];
        if (w & ~0x7F)
        {
            char[4] buf;

            n = i;
            d = decode(aa, n);
            n -= i;
            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(&i, cast(void *)&c2);
                if (result)
                    return result;
            }
            continue;
        }
        else
        {   c = cast(char)w;
            n = 1;
        }
        result = dg(&i, cast(void *)&c);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplydc2(dchar[] aa, dg2_t dg)
{   int result;
    size_t i;
    size_t len = aa.length;

    debug(apply) printf("_aApplydc2(), len = %d\n", len);
    for (i = 0; i < len; i++)
    {   dchar d;
        char c;

        d = aa[i];
        if (d & ~0x7F)
        {
            char[4] buf;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(&i, cast(void *)&c2);
                if (result)
                    return result;
            }
            continue;
        }
        else
        {   c = cast(char)d;
        }
        result = dg(&i, cast(void *)&c);
        if (result)
            break;
    }
    return result;
}

extern (C) int _aApplydw2(dchar[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplydw2(), len = %d\n", aa.length);
    foreach (size_t i, dchar d; aa)
    {
        wchar w;
        auto j = i;

        if (d <= 0xFFFF)
            w = cast(wchar) d;
        else
        {
            w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
            result = dg(&j, cast(void *)&w);
            if (result)
                break;
            w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
        }
        result = dg(&j, cast(void *)&w);
        if (result)
            break;
    }
    return result;
}
