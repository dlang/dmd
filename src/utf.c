// utf.c
// Copyright (c) 2003-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/// Description of UTF-8 in [1].  Unicode non-characters and private-use
/// code points described in [2],[4].
///
/// References:
/// [1] http://www.cl.cam.ac.uk/~mgk25/unicode.html#utf-8
/// [2] http://en.wikipedia.org/wiki/Unicode
/// [3] http://unicode.org/faq/utf_bom.html
/// [4] http://www.unicode.org/versions/Unicode6.1.0/ch03.pdf

#include <assert.h>

#include "utf.h"

namespace
{

/* The following encodings are valid, except for the 5 and 6 byte
 * combinations:
 *      0xxxxxxx
 *      110xxxxx 10xxxxxx
 *      1110xxxx 10xxxxxx 10xxxxxx
 *      11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
 *      111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
 *      1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
 */
static const unsigned UTF8_STRIDE[256] =
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

}   // namespace

char const UTF8_DECODE_OUTSIDE_CODE_SPACE[] = "Outside Unicode code space";
char const UTF8_DECODE_TRUNCATED_SEQUENCE[] = "Truncated UTF-8 sequence";
char const UTF8_DECODE_OVERLONG[]           = "Overlong UTF-8 sequence";
char const UTF8_DECODE_INVALID_TRAILER[]    = "Invalid trailing code unit";
char const UTF8_DECODE_INVALID_CODE_POINT[] = "Invalid code point decoded";

/// The Unicode code space is the range of code points [0x000000,0x10FFFF]
/// except the UTF-16 surrogate pairs in the range [0xD800,0xDFFF]
/// and non-characters (which end in 0xFFFE or 0xFFFF).  The D language
/// reference also rejects Private-Use code points.
bool utf_isValidDchar(dchar_t c)
{
    return c <= 0x0EFFFD                        // largest non-private code point
        && !(0xD800 <= c && c <= 0xDFFF)        // surrogate pairs
        && (c & 0xFFFE) != 0xFFFE               // non-characters
        && !(0x00FDD0 <= c && c <= 0x00FDEF)    // non-characters
        && !(0x00E000 <= c && c <= 0x00F8FF)    // private-use
//      && !(0x0F0000 <= c && c <= 0x0FFFFD)    // private-use supp. A
//      && !(0x100000 <= c && c <= 0x10FFFD)    // private-use supp. B
        ;
}

/********************************************
 * Decode a UTF-8 sequence as a single UCS code point.
 * Returns:
 *      NULL    success
 *      !=NULL  error message string
 */

const char *utf_decodeChar(utf8_t const *s, size_t len, size_t *pidx, dchar_t *presult)
{
    assert(s != NULL);
    assert(pidx != NULL);
    assert(presult != NULL);

    size_t i = (*pidx)++;
    assert(i < len);
    utf8_t u = s[i];
    // Pre-stage results for ASCII and error cases
    *presult = u;

    //printf("utf_decodeChar(s = %02x, %02x, %02x len = %d)\n", u, s[1], s[2], len);

    // Get expected sequence length
    unsigned n = UTF8_STRIDE[u];
    switch (n)
    {
    case 1:                             // ASCII
        return UTF8_DECODE_OK;
    case 2: case 3: case 4:             // multi-byte UTF-8
        break;
    default:                            // 5- or 6-byte sequence
        return UTF8_DECODE_OUTSIDE_CODE_SPACE;
    }
    if (len < i + n)                    // source too short
        return UTF8_DECODE_TRUNCATED_SEQUENCE;

    // Pick off 7 - n low bits from first code unit
    dchar_t V = u & ((1 << (7 - n)) - 1);

    /* The following combinations are overlong, and illegal:
     *      1100000x (10xxxxxx)
     *      11100000 100xxxxx (10xxxxxx)
     *      11110000 1000xxxx (10xxxxxx 10xxxxxx)
     *      11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
     *      11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
     */
    utf8_t u2 = s[++i];
    if ((u & 0xFE) == 0xC0 ||           // overlong combination
        (u == 0xE0 && (u2 & 0xE0) == 0x80) ||
        (u == 0xF0 && (u2 & 0xF0) == 0x80) ||
        (u == 0xF8 && (u2 & 0xF8) == 0x80) ||
        (u == 0xFC && (u2 & 0xFC) == 0x80))
        return UTF8_DECODE_OVERLONG;
    // Decode remaining bits
    for (n += i - 1; i != n; ++i)
    {
        u = s[i];
        if ((u & 0xC0) != 0x80)         // trailing bytes are 10xxxxxx
            return UTF8_DECODE_INVALID_TRAILER;
        V = (V << 6) | (u & 0x3F);
    }
    if (!utf_isValidDchar(V))
        return UTF8_DECODE_INVALID_CODE_POINT;
    *pidx = i;
    *presult = V;
    return UTF8_DECODE_OK;
}

/***************************************************
 * Validate a UTF-8 string.
 * Returns:
 *      NULL    success
 *      !=NULL  error message string
 */

const char *utf_validateString(utf8_t const *s, size_t len)
{
    assert(s != NULL);
    const char *err = NULL;
    for (size_t idx = 0; idx < len; )
    {
        dchar_t dc = 0;
        err = utf_decodeChar(s, len, &idx, &dc);
        if (err) break;
    }
    return err;
}

/********************************************
 * Decode a single UTF-16 character sequence.
 * Returns:
 *      NULL    success
 *      !=NULL  error message string
 */

const char *utf_decodeWchar(utf16_t const *s, size_t len, size_t *pidx, dchar_t *presult)
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

void utf_encodeChar(utf8_t *s, dchar_t c)
{
    assert(utf_isValidDchar(c));
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

void utf_encodeWchar(utf16_t *s, dchar_t c)
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
        utf_encodeChar((utf8_t *)s, c);
    else if (sz == 2)
        utf_encodeWchar((utf16_t *)s, c);
    else
    {
        assert(sz == 4);
        *((utf32_t *)s) = c;
    }
}
