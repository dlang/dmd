// utf.c
// Copyright (c) 2003-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Description of UTF-8 at:
// http://www.cl.cam.ac.uk/~mgk25/unicode.html#utf-8

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "utf.h"

int utf_isValidDchar(dchar_t c)
{
    return c < 0xD800 ||
        (c > 0xDFFF && c <= 0x10FFFF && c != 0xFFFE && c != 0xFFFF);
}

static const unsigned char UTF8stride[256] =
{
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,0xFF,0xFF,
};

/**
 * stride() returns the length of a UTF-8 sequence starting at index i
 * in string s.
 * Returns:
 *  The number of bytes in the UTF-8 sequence or
 *  0xFF meaning s[i] is not the start of of UTF-8 sequence.
 */

unsigned stride(unsigned char* s, size_t i)
{
    unsigned result = UTF8stride[s[i]];
    return result;
}

/********************************************
 * Decode a single UTF-8 character sequence.
 * Returns:
 *      NULL    success
 *      !=NULL  error message string
 */

const char *utf_decodeChar(unsigned char *s, size_t len, size_t *pidx, dchar_t *presult)
{
    dchar_t V;
    size_t i = *pidx;
    unsigned char u = s[i];

    //printf("utf_decodeChar(s = %02x, %02x, %02x len = %d)\n", u, s[1], s[2], len);

    assert(i >= 0 && i < len);

    if (u & 0x80)
    {   unsigned n;
        unsigned char u2;

        /* The following encodings are valid, except for the 5 and 6 byte
         * combinations:
         *      0xxxxxxx
         *      110xxxxx 10xxxxxx
         *      1110xxxx 10xxxxxx 10xxxxxx
         *      11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
         *      111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
         *      1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
         */
        for (n = 1; ; n++)
        {
            if (n > 4)
                goto Lerr;              // only do the first 4 of 6 encodings
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
            goto Lerr;                  // off end of string

        /* The following combinations are overlong, and illegal:
         *      1100000x (10xxxxxx)
         *      11100000 100xxxxx (10xxxxxx)
         *      11110000 1000xxxx (10xxxxxx 10xxxxxx)
         *      11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
         *      11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
         */
        u2 = s[i + 1];
        if ((u & 0xFE) == 0xC0 ||
            (u == 0xE0 && (u2 & 0xE0) == 0x80) ||
            (u == 0xF0 && (u2 & 0xF0) == 0x80) ||
            (u == 0xF8 && (u2 & 0xF8) == 0x80) ||
            (u == 0xFC && (u2 & 0xFC) == 0x80))
            goto Lerr;                  // overlong combination

        for (unsigned j = 1; j != n; j++)
        {
            u = s[i + j];
            if ((u & 0xC0) != 0x80)
                goto Lerr;                      // trailing bytes are 10xxxxxx
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
 *      NULL    success
 *      !=NULL  error message string
 */

const char *utf_validateString(unsigned char *s, size_t len)
{
    size_t idx;
    const char *err = NULL;
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
 *      NULL    success
 *      !=NULL  error message string
 */


const char *utf_decodeWchar(unsigned short *s, size_t len, size_t *pidx, dchar_t *presult)
{
    const char *msg;
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

void utf_encodeChar(unsigned char *s, dchar_t c)
{
    if (c <= 0x7F)
    {
        s[0] = (char) c;
    }
    else if (c <= 0x7FF)
    {
        s[0] = (char)(0xC0 | (c >> 6));
        s[1] = (char)(0x80 | (c & 0x3F));
    }
    else if (c <= 0xFFFF)
    {
        s[0] = (char)(0xE0 | (c >> 12));
        s[1] = (char)(0x80 | ((c >> 6) & 0x3F));
        s[2] = (char)(0x80 | (c & 0x3F));
    }
    else if (c <= 0x10FFFF)
    {
        s[0] = (char)(0xF0 | (c >> 18));
        s[1] = (char)(0x80 | ((c >> 12) & 0x3F));
        s[2] = (char)(0x80 | ((c >> 6) & 0x3F));
        s[3] = (char)(0x80 | (c & 0x3F));
    }
    else
        assert(0);
}

void utf_encodeWchar(unsigned short *s, dchar_t c)
{
    if (c <= 0xFFFF)
    {
        s[0] = (wchar_t) c;
    }
    else
    {
        s[0] = (wchar_t) ((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
        s[1] = (wchar_t) (((c - 0x10000) & 0x3FF) + 0xDC00);
    }
}


/**
 * Returns the code length of c in the encoding.
 * The code is returned in character count, not in bytes.
 */

int utf_codeLengthChar(dchar_t c)
{
    return
        c <= 0x7F ? 1
        : c <= 0x7FF ? 2
        : c <= 0xFFFF ? 3
        : c <= 0x10FFFF ? 4
        : (assert(false), 6);
}

int utf_codeLengthWchar(dchar_t c)
{
    return c <= 0xFFFF ? 1 : 2;
}

/**
 * Returns the code length of c in the encoding.
 * sz is the encoding: 1 = utf8, 2 = utf16, 4 = utf32.
 * The code is returned in character count, not in bytes.
 */
int utf_codeLength(int sz, dchar_t c)
{
    if (sz == 1)
        return utf_codeLengthChar(c);
    if (sz == 2)
        return utf_codeLengthWchar(c);
    assert(sz == 4);
    return 1;
}

void utf_encode(int sz, void *s, dchar_t c)
{
    if (sz == 1)
        utf_encodeChar((unsigned char *)s, c);
    else if (sz == 2)
        utf_encodeWchar((unsigned short *)s, c);
    else
    {
        assert(sz == 4);
        memcpy((unsigned char *)s, &c, sz);
    }
}

