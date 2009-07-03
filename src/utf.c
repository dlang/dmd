// utf.c
// Copyright (c) 2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Description of UTF-8 at:
// http://www.cl.cam.ac.uk/~mgk25/unicode.html#utf-8

#include <stdio.h>
#include <assert.h>

#include "utf.h"

int utf_isValidDchar(dchar_t c)
{
    return c < 0xD800 ||
	(c > 0xDFFF && c <= 0x10FFFF && c != 0xFFFE && c != 0xFFFF);
}

/********************************************
 * Decode a single UTF-8 character sequence.
 * Returns:
 *	NULL	success
 *	!=NULL	error message string
 */

char *utf_decodeChar(unsigned char *s, size_t len, size_t *pidx, dchar_t *presult)
{
    dchar_t V;
    size_t i = *pidx;
    unsigned char u = s[i];

    assert(i >= 0 && i < len);

    if (u & 0x80)
    {   unsigned n;
	unsigned char u2;

	/* The following encodings are valid, except for the 5 and 6 byte
	 * combinations:
	 *	0xxxxxxx
	 *	110xxxxx 10xxxxxx
	 *	1110xxxx 10xxxxxx 10xxxxxx
	 *	11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
	 *	111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
	 *	1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
	 */
	for (n = 1; ; n++)
	{
	    if (n > 4)
		goto Lerr;		// only do the first 4 of 6 encodings
	    if (((u << n) & 0x80) == 0)
	    {
		if (n == 1)
		    goto Lerr;
		break;
	    }
	}

	// Pick off (7 - n) significant bits of B from first byte of octet
	V = (dchar_t)(u & ((1 << (7 - n)) - 1));

	if (i + (n - 1) >= len)
	    goto Lerr;			// off end of string

	/* The following combinations are overlong, and illegal:
	 *	1100000x (10xxxxxx)
	 *	11100000 100xxxxx (10xxxxxx)
	 *	11110000 1000xxxx (10xxxxxx 10xxxxxx)
	 *	11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
	 *	11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
	 */
	u2 = s[i + 1];
	if ((u & 0xFE) == 0xC0 ||
	    (u == 0xE0 && (u2 & 0xE0) == 0x80) ||
	    (u == 0xF0 && (u2 & 0xF0) == 0x80) ||
	    (u == 0xF8 && (u2 & 0xF8) == 0x80) ||
	    (u == 0xFC && (u2 & 0xFC) == 0x80))
	    goto Lerr;			// overlong combination

	for (unsigned j = 1; j != n; j++)
	{
	    u = s[i + j];
	    if ((u & 0xC0) != 0x80)
		goto Lerr;			// trailing bytes are 10xxxxxx
	    V = (V << 6) | (u & 0x3F);
	}
	if (!utf_isValidDchar(V))
	    goto Lerr;
	i += n;
    }
    else
    {
	V = (dchar_t) u;
	i++;
    }

    assert(utf_isValidDchar(V));
    *pidx = i;
    *presult = V;
    return NULL;

  Lerr:
    *presult = (dchar_t) s[i];
    *pidx = i + 1;
    return "invalid UTF-8 sequence";
}

/***************************************************
 * Validate a UTF-8 string.
 * Returns:
 *	NULL	success
 *	!=NULL	error message string
 */

char *utf_validateString(unsigned char *s, size_t len)
{
    size_t idx;
    char *err = NULL;
    dchar_t dc;

    for (idx = 0; idx < len; )
    {
	err = utf_decodeChar(s, len, &idx, &dc);
	if (err)
	    break;
    }
    return err;
}


/********************************************
 * Decode a single UTF-16 character sequence.
 * Returns:
 *	NULL	success
 *	!=NULL	error message string
 */


char *utf_decodeWchar(unsigned short *s, size_t len, size_t *pidx, dchar_t *presult)
{
    char *msg;
    size_t i = *pidx;
    unsigned u = s[i];

    assert(i >= 0 && i < len);
    if (u & ~0x7F)
    {   if (u >= 0xD800 && u <= 0xDBFF)
	{   unsigned u2;

	    if (i + 1 == len)
	    {   msg = "surrogate UTF-16 high value past end of string";
		goto Lerr;
	    }
	    u2 = s[i + 1];
	    if (u2 < 0xDC00 || u2 > 0xDFFF)
	    {   msg = "surrogate UTF-16 low value out of range";
		goto Lerr;
	    }
	    u = ((u - 0xD7C0) << 10) + (u2 - 0xDC00);
	    i += 2;
	}
	else if (u >= 0xDC00 && u <= 0xDFFF)
	{   msg = "unpaired surrogate UTF-16 value";
	    goto Lerr;
	}
	else if (u == 0xFFFE || u == 0xFFFF)
	{   msg = "illegal UTF-16 value";
	    goto Lerr;
	}
	else
	    i++;
    }
    else
    {
	i++;
    }

    assert(utf_isValidDchar(u));
    *pidx = i;
    *presult = (dchar_t)u;
    return NULL;

  Lerr:
    *presult = (dchar_t)s[i];
    *pidx = i + 1;
    return msg;
}

