/**
 * Simple ASCII char classification functions.
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
module rt.util.ctype;

int isalnum(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG) : 0; }
int isalpha(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP)      : 0; }
int iscntrl(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_CTL)      : 0; }
int isdigit(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_DIG)      : 0; }
int islower(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_LC)       : 0; }
int ispunct(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_PNC)      : 0; }
int isspace(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_SPC)      : 0; }
int isupper(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_UC)       : 0; }
int isxdigit(dchar c) { return (c <= 0x7F) ? _ctype[c] & (_HEX)      : 0; }
int isgraph(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC) : 0; }
int isprint(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC|_BLK) : 0; }
int isascii(dchar c)  { return c <= 0x7F; }

dchar tolower(dchar c)
out (result)
{
    assert(!isupper(result));
}
body
{
    return isupper(c) ? c + (cast(dchar)'a' - 'A') : c;
}

dchar toupper(dchar c)
out (result)
{
    assert(!islower(result));
}
body
{
    return islower(c) ? c - (cast(dchar)'a' - 'A') : c;
}

private:

enum
{
    _SPC =      8,
    _CTL =      0x20,
    _BLK =      0x40,
    _HEX =      0x80,
    _UC  =      1,
    _LC  =      2,
    _PNC =      0x10,
    _DIG =      4,
    _ALP =      _UC|_LC,
}

immutable ubyte _ctype[128] =
[
        _CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,
        _CTL,_CTL|_SPC,_CTL|_SPC,_CTL|_SPC,_CTL|_SPC,_CTL|_SPC,_CTL,_CTL,
        _CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,
        _CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,
        _SPC|_BLK,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _PNC,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,
        _DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,
        _PNC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _PNC,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC,
        _UC,_UC,_UC,_UC,_UC,_UC,_UC,_UC,
        _UC,_UC,_UC,_UC,_UC,_UC,_UC,_UC,
        _UC,_UC,_UC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _PNC,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC,
        _LC,_LC,_LC,_LC,_LC,_LC,_LC,_LC,
        _LC,_LC,_LC,_LC,_LC,_LC,_LC,_LC,
        _LC,_LC,_LC,_PNC,_PNC,_PNC,_PNC,_CTL
];


unittest
{
    assert(isspace(' '));
    assert(!isspace('z'));
    assert(toupper('a') == 'A');
    assert(tolower('Q') == 'q');
    assert(!isxdigit('G'));
}
