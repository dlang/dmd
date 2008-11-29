
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

// Simple ASCII char classification functions

module util.ctype;

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
    _SPC =	8,
    _CTL =	0x20,
    _BLK =	0x40,
    _HEX =	0x80,
    _UC  =	1,
    _LC  =	2,
    _PNC =	0x10,
    _DIG =	4,
    _ALP =	_UC|_LC,
}

ubyte _ctype[128] =
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
