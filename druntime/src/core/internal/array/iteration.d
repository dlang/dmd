/**
 * This code handles decoding UTF strings for foreach and foreach_reverse loops.
 *
 * Copyright: Copyright Digital Mars 2004 - 2010.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/_internal/_array/_iteration.d)
 */
module core.internal.array.iteration;

import core.internal.utf : decode, toUTF8, onUnicodeError;

debug (apply) import core.stdc.stdio : printf;

/**********************************************/
/* 1 argument versions */

/**
Loop over a string while changing the UTF encoding

There are 6 combinations of conversions between `char`, `wchar`, and `dchar`,
and 2 of each of those.

The naming convention is as follows:

_aApply{c,d,w}{c,d,w}{1,2}

The first letter corresponds to the input string encoding, and the second letter corresponds to the target character type.

- c = `char`
- w = `wchar`
- d = `dchar`

The `1` variant only produces the character, the `2` variant also produces a loop index.

Examples:
---
void main()
{
    string str;
    wtring wstr;
    dstring dstr;

    foreach (dchar c; str) {}
    // _aApplycd1

    foreach (wchar c; dstr) {}
    // _aApplydw1

    foreach (i, wchar c; str) {}
    // _aApplycw2

    foreach (wchar w; wstr) {}
    // no conversion
}
---

Params:
    aa = input string
    dg = foreach body transformed into a delegate, similar to `opApply`

Returns:
    non-zero when the loop was exited through a `break`
*/
int _aApplycd1(dg_t)(scope const(char)[] aa, dg_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplycd1(), len = %zd\n", len);
    for (size_t i = 0; i < len; )
    {
        dchar d = aa[i];
        if (d & 0x80)
            d = decode(aa, i);
        else
            ++i;
        result = dg(d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplycd1.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach (dchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (dchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); break;
            case 1:     assert(d == '\u1234'); break;
            case 2:     assert(d == '\U000A0456'); break;
            case 3:     assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplywd1(dg_t)(scope const(wchar)[] aa, dg_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplywd1(), len = %zd\n", len);
    for (size_t i = 0; i < len; )
    {
        dchar d = aa[i];
        if (d >= 0xD800)
            d = decode(aa, i);
        else
            ++i;
        result = dg(d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplywd1.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach (dchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (dchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); break;
            case 1:     assert(d == '\u1234'); break;
            case 2:     assert(d == '\U000A0456'); break;
            case 3:     assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplycw1(dg_t)(scope const(char)[] aa, dg_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplycw1(), len = %zd\n", len);
    for (size_t i = 0; i < len; )
    {
        wchar w = aa[i];
        if (w & 0x80)
        {
            dchar d = decode(aa, i);
            if (d <= 0xFFFF)
                w = cast(wchar) d;
            else
            {
                w = cast(wchar)((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
                result = dg(w);
                if (result)
                    break;
                w = cast(wchar)(((d - 0x10000) & 0x3FF) + 0xDC00);
            }
        }
        else
            ++i;
        result = dg(w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplycw1.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach (wchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (wchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); break;
            case 1:     assert(d == 0x1234); break;
            case 2:     assert(d == 0xDA41); break;
            case 3:     assert(d == 0xDC56); break;
            case 4:     assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}

/// ditto
int _aApplywc1(dg_t)(scope const(wchar)[] aa, dg_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplywc1(), len = %zd\n", len);
    for (size_t i = 0; i < len; )
    {
        wchar w = aa[i];
        if (w & ~0x7F)
        {
            char[4] buf = void;

            dchar d = decode(aa, i);
            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(c2);
                if (result)
                    return result;
            }
        }
        else
        {
            char c = cast(char)w;
            ++i;
            result = dg(c);
            if (result)
                break;
        }
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplywc1.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach (char d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (char d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); break;
            case 1:     assert(d == 0xE1); break;
            case 2:     assert(d == 0x88); break;
            case 3:     assert(d == 0xB4); break;
            case 4:     assert(d == 0xF2); break;
            case 5:     assert(d == 0xA0); break;
            case 6:     assert(d == 0x91); break;
            case 7:     assert(d == 0x96); break;
            case 8:     assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplydc1(dg_t)(scope const(dchar)[] aa, dg_t dg)
{
    int result;

    debug(apply) printf("_aApplydc1(), len = %zd\n", aa.length);
    foreach (dchar d; aa)
    {
        if (d & ~0x7F)
        {
            char[4] buf = void;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(c2);
                if (result)
                    return result;
            }
        }
        else
        {
            char c = cast(char)d;
            result = dg(c);
            if (result)
                break;
        }
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplydc1.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach (char d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (char d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); break;
            case 1:     assert(d == 0xE1); break;
            case 2:     assert(d == 0x88); break;
            case 3:     assert(d == 0xB4); break;
            case 4:     assert(d == 0xF2); break;
            case 5:     assert(d == 0xA0); break;
            case 6:     assert(d == 0x91); break;
            case 7:     assert(d == 0x96); break;
            case 8:     assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplydw1(dg_t)(scope const(dchar)[] aa, dg_t dg)
{
    int result;

    debug(apply) printf("_aApplydw1(), len = %zd\n", aa.length);
    foreach (dchar d; aa)
    {
        wchar w;

        if (d <= 0xFFFF)
            w = cast(wchar) d;
        else
        {
            w = cast(wchar)((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
            result = dg(w);
            if (result)
                break;
            w = cast(wchar)(((d - 0x10000) & 0x3FF) + 0xDC00);
        }
        result = dg(w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplydw1.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach (wchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (wchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); break;
            case 1:     assert(d == 0x1234); break;
            case 2:     assert(d == 0xDA41); break;
            case 3:     assert(d == 0xDC56); break;
            case 4:     assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}

/**
Same as `_aApplyXXX` functions, but for `foreach_reverse`

Params:
    aa = input string
    dg = foreach body transformed into a delegate, similar to `opApply`

Returns:
    non-zero when the loop was exited through a `break`
*/
int _aApplyRcd1(dg_t)(scope const(char)[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplyRcd1(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;

        i--;
        d = aa[i];
        if (d & 0x80)
        {   char c = cast(char)d;
            uint j;
            uint m = 0x3F;
            d = 0;
            while ((c & 0xC0) != 0xC0)
            {   if (i == 0)
                    onUnicodeError("Invalid UTF-8 sequence", 0);
                i--;
                d |= (c & 0x3F) << j;
                j += 6;
                m >>= 1;
                c = aa[i];
            }
            d |= (c & m) << j;
        }
        result = dg(d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRcd1.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach_reverse (dchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (dchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); break;
            case 1:     assert(d == '\U000A0456'); break;
            case 2:     assert(d == '\u1234'); break;
            case 3:     assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplyRwd1(dg_t)(scope const(wchar)[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplyRwd1(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;

        i--;
        d = aa[i];
        if (d >= 0xDC00 && d <= 0xDFFF)
        {   if (i == 0)
                onUnicodeError("Invalid UTF-16 sequence", 0);
            i--;
            d = ((aa[i] - 0xD7C0) << 10) + (d - 0xDC00);
        }
        result = dg(d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRwd1.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach_reverse (dchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (dchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); break;
            case 1:     assert(d == '\U000A0456'); break;
            case 2:     assert(d == '\u1234'); break;
            case 3:     assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplyRcw1(dg_t)(scope const(char)[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplyRcw1(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;
        wchar w;

        i--;
        w = aa[i];
        if (w & 0x80)
        {   char c = cast(char)w;
            uint j;
            uint m = 0x3F;
            d = 0;
            while ((c & 0xC0) != 0xC0)
            {   if (i == 0)
                    onUnicodeError("Invalid UTF-8 sequence", 0);
                i--;
                d |= (c & 0x3F) << j;
                j += 6;
                m >>= 1;
                c = aa[i];
            }
            d |= (c & m) << j;

            if (d <= 0xFFFF)
                w = cast(wchar) d;
            else
            {
                w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
                result = dg(w);
                if (result)
                    break;
                w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
            }
        }
        result = dg(w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRcw1.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach_reverse (wchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (wchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); break;
            case 1:     assert(d == 0xDA41); break;
            case 2:     assert(d == 0xDC56); break;
            case 3:     assert(d == 0x1234); break;
            case 4:     assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}

/// ditto
int _aApplyRwc1(dg_t)(scope const(wchar)[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplyRwc1(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;
        char c;

        i--;
        d = aa[i];
        if (d >= 0xDC00 && d <= 0xDFFF)
        {   if (i == 0)
                onUnicodeError("Invalid UTF-16 sequence", 0);
            i--;
            d = ((aa[i] - 0xD7C0) << 10) + (d - 0xDC00);
        }

        if (d & ~0x7F)
        {
            char[4] buf = void;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(c2);
                if (result)
                    return result;
            }
            continue;
        }
        c = cast(char)d;
        result = dg(c);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRwc1.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach_reverse (char d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (char d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); break;
            case 1:     assert(d == 0xF2); break;
            case 2:     assert(d == 0xA0); break;
            case 3:     assert(d == 0x91); break;
            case 4:     assert(d == 0x96); break;
            case 5:     assert(d == 0xE1); break;
            case 6:     assert(d == 0x88); break;
            case 7:     assert(d == 0xB4); break;
            case 8:     assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplyRdc1(dg_t)(scope const(dchar)[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplyRdc1(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0;)
    {   dchar d = aa[--i];
        char c;

        if (d & ~0x7F)
        {
            char[4] buf = void;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(c2);
                if (result)
                    return result;
            }
            continue;
        }
        else
        {
            c = cast(char)d;
        }
        result = dg(c);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRdc1.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach_reverse (char d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (char d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); break;
            case 1:     assert(d == 0xF2); break;
            case 2:     assert(d == 0xA0); break;
            case 3:     assert(d == 0x91); break;
            case 4:     assert(d == 0x96); break;
            case 5:     assert(d == 0xE1); break;
            case 6:     assert(d == 0x88); break;
            case 7:     assert(d == 0xB4); break;
            case 8:     assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplyRdw1(dg_t)(scope const(dchar)[] aa, dg_t dg)
{   int result;

    debug(apply) printf("_aApplyRdw1(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d = aa[--i];
        wchar w;

        if (d <= 0xFFFF)
            w = cast(wchar) d;
        else
        {
            w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
            result = dg(w);
            if (result)
                break;
            w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
        }
        result = dg(w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRdw1.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach_reverse (wchar d; s)
    {
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (wchar d; s)
    {
        //printf("i = %d, d = %x\n", i, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); break;
            case 1:     assert(d == 0xDA41); break;
            case 2:     assert(d == 0xDC56); break;
            case 3:     assert(d == 0x1234); break;
            case 4:     assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}


/****************************************************************************/
/* 2 argument versions */

// Note: dg is extern(D), but _aApplycd2() is extern(C)

/**
Variants of _aApplyXXX that include a loop index.
*/
int _aApplycd2(dg2_t)(scope const(char)[] aa, dg2_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplycd2(), len = %zd\n", len);
    size_t n;
    for (size_t i = 0; i < len; i += n)
    {
        dchar d = aa[i];
        if (d & 0x80)
        {
            n = i;
            d = decode(aa, n);
            n -= i;
        }
        else
            n = 1;
        result = dg(i, d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplycd2.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == i);
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(d == 'a'); assert(k == 0); break;
            case 1:     assert(d == '\u1234'); assert(k == 1); break;
            case 2:     assert(d == '\U000A0456'); assert(k == 4); break;
            case 3:     assert(d == 'b'); assert(k == 8); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplywd2(dg2_t)(scope const(wchar)[] aa, dg2_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplywd2(), len = %zd\n", len);
    size_t n;
    for (size_t i = 0; i < len; i += n)
    {
        dchar d = aa[i];
        if (d & ~0x7F)
        {
            n = i;
            d = decode(aa, n);
            n -= i;
        }
        else
            n = 1;
        result = dg(i, d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplywd2.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == i);
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 0); assert(d == 'a'); break;
            case 1:     assert(k == 1); assert(d == '\u1234'); break;
            case 2:     assert(k == 2); assert(d == '\U000A0456'); break;
            case 3:     assert(k == 4); assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplycw2(dg2_t)(scope const(char)[] aa, dg2_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplycw2(), len = %zd\n", len);
    size_t n;
    for (size_t i = 0; i < len; i += n)
    {
        wchar w = aa[i];
        if (w & 0x80)
        {
            n = i;
            dchar d = decode(aa, n);
            n -= i;
            if (d <= 0xFFFF)
                w = cast(wchar) d;
            else
            {
                w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
                result = dg(i, w);
                if (result)
                    break;
                w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
            }
        }
        else
            n = 1;
        result = dg(i, w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplycw2.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == i);
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 0); assert(d == 'a'); break;
            case 1:     assert(k == 1); assert(d == 0x1234); break;
            case 2:     assert(k == 4); assert(d == 0xDA41); break;
            case 3:     assert(k == 4); assert(d == 0xDC56); break;
            case 4:     assert(k == 8); assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}

/// ditto
int _aApplywc2(dg2_t)(scope const(wchar)[] aa, dg2_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplywc2(), len = %zd\n", len);
    size_t n;
    for (size_t i = 0; i < len; i += n)
    {
        wchar w = aa[i];
        if (w & ~0x7F)
        {
            char[4] buf = void;

            n = i;
            dchar d = decode(aa, n);
            n -= i;
            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(i, c2);
                if (result)
                    return result;
            }
        }
        else
        {
            char c = cast(char)w;
            n = 1;
            result = dg(i, c);
            if (result)
                break;
        }
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplywc2.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == i);
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 0); assert(d == 'a'); break;
            case 1:     assert(k == 1); assert(d == 0xE1); break;
            case 2:     assert(k == 1); assert(d == 0x88); break;
            case 3:     assert(k == 1); assert(d == 0xB4); break;
            case 4:     assert(k == 2); assert(d == 0xF2); break;
            case 5:     assert(k == 2); assert(d == 0xA0); break;
            case 6:     assert(k == 2); assert(d == 0x91); break;
            case 7:     assert(k == 2); assert(d == 0x96); break;
            case 8:     assert(k == 4); assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplydc2(dg2_t)(scope const(dchar)[] aa, dg2_t dg)
{
    int result;
    size_t len = aa.length;

    debug(apply) printf("_aApplydc2(), len = %zd\n", len);
    for (size_t i = 0; i < len; i++)
    {
        dchar d = aa[i];
        if (d & ~0x7F)
        {
            char[4] buf = void;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(i, c2);
                if (result)
                    return result;
            }
        }
        else
        {
            char c = cast(char)d;
            result = dg(i, c);
            if (result)
                break;
        }
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplydc2.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == i);
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 0); assert(d == 'a'); break;
            case 1:     assert(k == 1); assert(d == 0xE1); break;
            case 2:     assert(k == 1); assert(d == 0x88); break;
            case 3:     assert(k == 1); assert(d == 0xB4); break;
            case 4:     assert(k == 2); assert(d == 0xF2); break;
            case 5:     assert(k == 2); assert(d == 0xA0); break;
            case 6:     assert(k == 2); assert(d == 0x91); break;
            case 7:     assert(k == 2); assert(d == 0x96); break;
            case 8:     assert(k == 3); assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplydw2(dg2_t)(scope const(dchar)[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplydw2(), len = %zd\n", aa.length);
    foreach (size_t i, dchar d; aa)
    {
        wchar w;
        auto j = i;

        if (d <= 0xFFFF)
            w = cast(wchar) d;
        else
        {
            w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
            result = dg(j, w);
            if (result)
                break;
            w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
        }
        result = dg(j, w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplydw2.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == i);
        switch (i)
        {
            case 0:     assert(d == 'h'); break;
            case 1:     assert(d == 'e'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'l'); break;
            case 4:     assert(d == 'o'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 0); assert(d == 'a'); break;
            case 1:     assert(k == 1); assert(d == 0x1234); break;
            case 2:     assert(k == 2); assert(d == 0xDA41); break;
            case 3:     assert(k == 2); assert(d == 0xDC56); break;
            case 4:     assert(k == 3); assert(d == 'b'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}

/**
Variants of _aApplyRXXX that include a loop index.
*/
int _aApplyRcd2(dg2_t)(scope const(char)[] aa, dg2_t dg)
{   int result;
    size_t i;
    size_t len = aa.length;

    debug(apply) printf("_aApplyRcd2(), len = %zd\n", len);
    for (i = len; i != 0; )
    {   dchar d;

        i--;
        d = aa[i];
        if (d & 0x80)
        {   char c = cast(char)d;
            uint j;
            uint m = 0x3F;
            d = 0;
            while ((c & 0xC0) != 0xC0)
            {   if (i == 0)
                    onUnicodeError("Invalid UTF-8 sequence", 0);
                i--;
                d |= (c & 0x3F) << j;
                j += 6;
                m >>= 1;
                c = aa[i];
            }
            d |= (c & m) << j;
        }
        result = dg(i, d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRcd2.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach_reverse (k, dchar d; s)
    {
        assert(k == 4 - i);
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(d == 'b'); assert(k == 8); break;
            case 1:     assert(d == '\U000A0456'); assert(k == 4); break;
            case 2:     assert(d == '\u1234'); assert(k == 1); break;
            case 3:     assert(d == 'a'); assert(k == 0); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplyRwd2(dg2_t)(scope const(wchar)[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplyRwd2(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;

        i--;
        d = aa[i];
        if (d >= 0xDC00 && d <= 0xDFFF)
        {   if (i == 0)
                onUnicodeError("Invalid UTF-16 sequence", 0);
            i--;
            d = ((aa[i] - 0xD7C0) << 10) + (d - 0xDC00);
        }
        result = dg(i, d);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRwd2.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach_reverse (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == 4 - i);
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (k, dchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 4); assert(d == 'b'); break;
            case 1:     assert(k == 2); assert(d == '\U000A0456'); break;
            case 2:     assert(k == 1); assert(d == '\u1234'); break;
            case 3:     assert(k == 0); assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 4);
}

/// ditto
int _aApplyRcw2(dg2_t)(scope const(char)[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplyRcw2(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;
        wchar w;

        i--;
        w = aa[i];
        if (w & 0x80)
        {   char c = cast(char)w;
            uint j;
            uint m = 0x3F;
            d = 0;
            while ((c & 0xC0) != 0xC0)
            {   if (i == 0)
                    onUnicodeError("Invalid UTF-8 sequence", 0);
                i--;
                d |= (c & 0x3F) << j;
                j += 6;
                m >>= 1;
                c = aa[i];
            }
            d |= (c & m) << j;

            if (d <= 0xFFFF)
                w = cast(wchar) d;
            else
            {
                w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
                result = dg(i, w);
                if (result)
                    break;
                w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
            }
        }
        result = dg(i, w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRcw2.unittest\n");

    auto s = "hello"c[];
    int i;

    foreach_reverse (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == 4 - i);
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 8); assert(d == 'b'); break;
            case 1:     assert(k == 4); assert(d == 0xDA41); break;
            case 2:     assert(k == 4); assert(d == 0xDC56); break;
            case 3:     assert(k == 1); assert(d == 0x1234); break;
            case 4:     assert(k == 0); assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}

/// ditto
int _aApplyRwc2(dg2_t)(scope const(wchar)[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplyRwc2(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d;
        char c;

        i--;
        d = aa[i];
        if (d >= 0xDC00 && d <= 0xDFFF)
        {   if (i == 0)
                onUnicodeError("Invalid UTF-16 sequence", 0);
            i--;
            d = ((aa[i] - 0xD7C0) << 10) + (d - 0xDC00);
        }

        if (d & ~0x7F)
        {
            char[4] buf = void;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(i, c2);
                if (result)
                    return result;
            }
            continue;
        }
        c = cast(char)d;
        result = dg(i, c);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRwc2.unittest\n");

    auto s = "hello"w[];
    int i;

    foreach_reverse (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == 4 - i);
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 4); assert(d == 'b'); break;
            case 1:     assert(k == 2); assert(d == 0xF2); break;
            case 2:     assert(k == 2); assert(d == 0xA0); break;
            case 3:     assert(k == 2); assert(d == 0x91); break;
            case 4:     assert(k == 2); assert(d == 0x96); break;
            case 5:     assert(k == 1); assert(d == 0xE1); break;
            case 6:     assert(k == 1); assert(d == 0x88); break;
            case 7:     assert(k == 1); assert(d == 0xB4); break;
            case 8:     assert(k == 0); assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplyRdc2(dg2_t)(scope const(dchar)[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplyRdc2(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d = aa[--i];
        char c;

        if (d & ~0x7F)
        {
            char[4] buf = void;

            auto b = toUTF8(buf, d);
            foreach (char c2; b)
            {
                result = dg(i, c2);
                if (result)
                    return result;
            }
            continue;
        }
        else
        {   c = cast(char)d;
        }
        result = dg(i, c);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRdc2.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach_reverse (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == 4 - i);
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (k, char d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 3); assert(d == 'b'); break;
            case 1:     assert(k == 2); assert(d == 0xF2); break;
            case 2:     assert(k == 2); assert(d == 0xA0); break;
            case 3:     assert(k == 2); assert(d == 0x91); break;
            case 4:     assert(k == 2); assert(d == 0x96); break;
            case 5:     assert(k == 1); assert(d == 0xE1); break;
            case 6:     assert(k == 1); assert(d == 0x88); break;
            case 7:     assert(k == 1); assert(d == 0xB4); break;
            case 8:     assert(k == 0); assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 9);
}

/// ditto
int _aApplyRdw2(dg2_t)(scope const(dchar)[] aa, dg2_t dg)
{   int result;

    debug(apply) printf("_aApplyRdw2(), len = %zd\n", aa.length);
    for (size_t i = aa.length; i != 0; )
    {   dchar d = aa[--i];
        wchar w;

        if (d <= 0xFFFF)
            w = cast(wchar) d;
        else
        {
            w = cast(wchar) ((((d - 0x10000) >> 10) & 0x3FF) + 0xD800);
            result = dg(i, w);
            if (result)
                break;
            w = cast(wchar) (((d - 0x10000) & 0x3FF) + 0xDC00);
        }
        result = dg(i, w);
        if (result)
            break;
    }
    return result;
}

unittest
{
    debug(apply) printf("_aApplyRdw2.unittest\n");

    auto s = "hello"d[];
    int i;

    foreach_reverse (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        assert(k == 4 - i);
        switch (i)
        {
            case 0:     assert(d == 'o'); break;
            case 1:     assert(d == 'l'); break;
            case 2:     assert(d == 'l'); break;
            case 3:     assert(d == 'e'); break;
            case 4:     assert(d == 'h'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);

    s = "a\u1234\U000A0456b";
    i = 0;
    foreach_reverse (k, wchar d; s)
    {
        //printf("i = %d, k = %d, d = %x\n", i, k, d);
        switch (i)
        {
            case 0:     assert(k == 3); assert(d == 'b'); break;
            case 1:     assert(k == 2); assert(d == 0xDA41); break;
            case 2:     assert(k == 2); assert(d == 0xDC56); break;
            case 3:     assert(k == 1); assert(d == 0x1234); break;
            case 4:     assert(k == 0); assert(d == 'a'); break;
            default:    assert(0);
        }
        i++;
    }
    assert(i == 5);
}
