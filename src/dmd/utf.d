/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/utf.d, _utf.d)
 * Documentation:  https://dlang.org/phobos/dmd_utf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/utf.d
 */

module dmd.utf;

nothrow pure @nogc:

/// The Unicode code space is the range of code points [0x000000,0x10FFFF]
/// except the UTF-16 surrogate pairs in the range [0xD800,0xDFFF]
bool utf_isValidDchar(dchar c)
{
    // TODO: Whether non-char code points should be rejected is pending review
    // largest character code point
    if (c > 0x10FFFF)
        return false;
    // 0xFFFE and 0xFFFF are valid for internal use, like Phobos std.utf.isValidDChar
    // See also https://issues.dlang.org/show_bug.cgi?id=1357
    // surrogate pairs
    if (0xD800 <= c && c <= 0xDFFF)
        return false;
    return true;
}

/*******************************
 * Return !=0 if unicode alpha.
 * Use table from C99 Appendix D.
 */
bool isUniAlpha(dchar c)
{
    static immutable dchar[2][] ALPHA_TABLE =
    [
        [0x00A8, 0x00A8],
        [0x00AA, 0x00AA],
        [0x00AD, 0x00AD],
        [0x00AF, 0x00AF],
        [0x00B2, 0x00B5],
        [0x00B7, 0x00BA],
        [0x00BC, 0x00BE],
        [0x00C0, 0x00D6],
        [0x00D8, 0x00F6],
        [0x00F8, 0x00FF],
        [0x0100, 0x167F],
        [0x1681, 0x180D],
        [0x180F, 0x1FFF],
        [0x200B, 0x200D],
        [0x202A, 0x202E],
        [0x203F, 0x2040],
        [0x2054, 0x2054],
        [0x2060, 0x206F],
        [0x2070, 0x218F],
        [0x2460, 0x24FF],
        [0x2776, 0x2793],
        [0x2C00, 0x2DFF],
        [0x2E80, 0x2FFF],
        [0x3004, 0x3007],
        [0x3021, 0x302F],
        [0x3031, 0x303F],
        [0x3040, 0xD7FF],
        [0xF900, 0xFD3D],
        [0xFD40, 0xFDCF],
        [0xFDF0, 0xFE44],
        [0xFE47, 0xFFFD],
        [0x10000, 0x1FFFD],
        [0x20000, 0x2FFFD],
        [0x30000, 0x3FFFD],
        [0x40000, 0x4FFFD],
        [0x50000, 0x5FFFD],
        [0x60000, 0x6FFFD],
        [0x70000, 0x7FFFD],
        [0x80000, 0x8FFFD],
        [0x90000, 0x9FFFD],
        [0xA0000, 0xAFFFD],
        [0xB0000, 0xBFFFD],
        [0xC0000, 0xCFFFD],
        [0xD0000, 0xDFFFD],
        [0xE0000, 0xEFFFD],
    ];

    size_t high = ALPHA_TABLE.length - 1;
    // Shortcut search if c is out of range
    size_t low = (c < ALPHA_TABLE[0][0] || ALPHA_TABLE[high][1] < c) ? high + 1 : 0;
    // Binary search
    while (low <= high)
    {
        size_t mid = (low + high) >> 1;
        if (c < ALPHA_TABLE[mid][0])
            high = mid - 1;
        else if (ALPHA_TABLE[mid][1] < c)
            low = mid + 1;
        else
        {
            assert(ALPHA_TABLE[mid][0] <= c && c <= ALPHA_TABLE[mid][1]);
            return true;
        }
    }
    return false;
}

/**
 * Returns the code length of c in code units.
 */
int utf_codeLengthChar(dchar c)
{
    if (c <= 0x7F)
        return 1;
    if (c <= 0x7FF)
        return 2;
    if (c <= 0xFFFF)
        return 3;
    if (c <= 0x10FFFF)
        return 4;
    assert(false);
}

int utf_codeLengthWchar(dchar c)
{
    return c <= 0xFFFF ? 1 : 2;
}

/**
 * Returns the code length of c in code units for the encoding.
 * sz is the encoding: 1 = utf8, 2 = utf16, 4 = utf32.
 */
int utf_codeLength(int sz, dchar c)
{
    if (sz == 1)
        return utf_codeLengthChar(c);
    if (sz == 2)
        return utf_codeLengthWchar(c);
    assert(sz == 4);
    return 1;
}

void utf_encodeChar(char* s, dchar c)
{
    assert(s !is null);
    assert(utf_isValidDchar(c));
    if (c <= 0x7F)
    {
        s[0] = cast(char)c;
    }
    else if (c <= 0x07FF)
    {
        s[0] = cast(char)(0xC0 | (c >> 6));
        s[1] = cast(char)(0x80 | (c & 0x3F));
    }
    else if (c <= 0xFFFF)
    {
        s[0] = cast(char)(0xE0 | (c >> 12));
        s[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        s[2] = cast(char)(0x80 | (c & 0x3F));
    }
    else if (c <= 0x10FFFF)
    {
        s[0] = cast(char)(0xF0 | (c >> 18));
        s[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
        s[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        s[3] = cast(char)(0x80 | (c & 0x3F));
    }
    else
        assert(0);
}

void utf_encodeWchar(wchar* s, dchar c)
{
    assert(s !is null);
    assert(utf_isValidDchar(c));
    if (c <= 0xFFFF)
    {
        s[0] = cast(wchar)c;
    }
    else
    {
        s[0] = cast(wchar)((((c - 0x010000) >> 10) & 0x03FF) + 0xD800);
        s[1] = cast(wchar)(((c - 0x010000) & 0x03FF) + 0xDC00);
    }
}

void utf_encode(int sz, void* s, dchar c)
{
    if (sz == 1)
        utf_encodeChar(cast(char*)s, c);
    else if (sz == 2)
        utf_encodeWchar(cast(wchar*)s, c);
    else
    {
        assert(sz == 4);
        *(cast(dchar*)s) = c;
    }
}

/********************************************
 * Decode a UTF-8 sequence as a single UTF-32 code point.
 * Params:
 *      s = UTF-8 sequence
 *      len = number of code units in s[]
 *      ridx = starting index in s[], updated to reflect number of code units decoded
 *      rresult = set to character decoded
 * Returns:
 *      null on success, otherwise error message string
 */
immutable(char*) utf_decodeChar(const(char)* s, size_t len, ref size_t ridx, out dchar rresult)
{
    // UTF-8 decoding errors
    static immutable char* UTF8_DECODE_OK = null; // no error
    static immutable char* UTF8_DECODE_OUTSIDE_CODE_SPACE = "Outside Unicode code space";
    static immutable char* UTF8_DECODE_TRUNCATED_SEQUENCE = "Truncated UTF-8 sequence";
    static immutable char* UTF8_DECODE_OVERLONG = "Overlong UTF-8 sequence";
    static immutable char* UTF8_DECODE_INVALID_TRAILER = "Invalid trailing code unit";
    static immutable char* UTF8_DECODE_INVALID_CODE_POINT = "Invalid code point decoded";

    /* The following encodings are valid, except for the 5 and 6 byte
     * combinations:
     *      0xxxxxxx
     *      110xxxxx 10xxxxxx
     *      1110xxxx 10xxxxxx 10xxxxxx
     *      11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
     *      111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     *      1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     */
    static immutable uint[] UTF8_STRIDE =
    [
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        4,
        4,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        0xFF,
        0xFF
    ];

    assert(s !is null);
    size_t i = ridx++;
    assert(i < len);
    char u = s[i];
    // Pre-stage results for ASCII and error cases
    rresult = u;
    //printf("utf_decodeChar(s = %02x, %02x, %02x len = %d)\n", u, s[1], s[2], len);
    // Get expected sequence length
    size_t n = UTF8_STRIDE[u];
    switch (n)
    {
    case 1:
        // ASCII
        return UTF8_DECODE_OK;
    case 2:
    case 3:
    case 4:
        // multi-byte UTF-8
        break;
    default:
        // 5- or 6-byte sequence
        return UTF8_DECODE_OUTSIDE_CODE_SPACE;
    }
    if (len < i + n) // source too short
        return UTF8_DECODE_TRUNCATED_SEQUENCE;
    // Pick off 7 - n low bits from first code unit
    dchar c = u & ((1 << (7 - n)) - 1);
    /* The following combinations are overlong, and illegal:
     *      1100000x (10xxxxxx)
     *      11100000 100xxxxx (10xxxxxx)
     *      11110000 1000xxxx (10xxxxxx 10xxxxxx)
     *      11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
     *      11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
     */
    char u2 = s[++i];
    // overlong combination
    if ((u & 0xFE) == 0xC0 || (u == 0xE0 && (u2 & 0xE0) == 0x80) || (u == 0xF0 && (u2 & 0xF0) == 0x80) || (u == 0xF8 && (u2 & 0xF8) == 0x80) || (u == 0xFC && (u2 & 0xFC) == 0x80))
        return UTF8_DECODE_OVERLONG;
    // Decode remaining bits
    for (n += i - 1; i != n; ++i)
    {
        u = s[i];
        if ((u & 0xC0) != 0x80) // trailing bytes are 10xxxxxx
            return UTF8_DECODE_INVALID_TRAILER;
        c = (c << 6) | (u & 0x3F);
    }
    if (!utf_isValidDchar(c))
        return UTF8_DECODE_INVALID_CODE_POINT;
    ridx = i;
    rresult = c;
    return UTF8_DECODE_OK;
}

/********************************************
 * Decode a UTF-16 sequence as a single UTF-32 code point.
 * Params:
 *      s = UTF-16 sequence
 *      len = number of code units in s[]
 *      ridx = starting index in s[], updated to reflect number of code units decoded
 *      rresult = set to character decoded
 * Returns:
 *      null on success, otherwise error message string
 */
immutable(char*) utf_decodeWchar(const(wchar)* s, size_t len, ref size_t ridx, out dchar rresult)
{
    // UTF-16 decoding errors
    static immutable char* UTF16_DECODE_OK = null; // no error
    static immutable char* UTF16_DECODE_TRUNCATED_SEQUENCE = "Truncated UTF-16 sequence";
    static immutable char* UTF16_DECODE_INVALID_SURROGATE = "Invalid low surrogate";
    static immutable char* UTF16_DECODE_UNPAIRED_SURROGATE = "Unpaired surrogate";
    static immutable char* UTF16_DECODE_INVALID_CODE_POINT = "Invalid code point decoded";

    assert(s !is null);
    size_t i = ridx++;
    assert(i < len);
    // Pre-stage results for ASCII and error cases
    dchar u = rresult = s[i];
    if (u < 0x80) // ASCII
        return UTF16_DECODE_OK;
    if (0xD800 <= u && u <= 0xDBFF) // Surrogate pair
    {
        if (len <= i + 1)
            return UTF16_DECODE_TRUNCATED_SEQUENCE;
        wchar u2 = s[i + 1];
        if (u2 < 0xDC00 || 0xDFFF < u)
            return UTF16_DECODE_INVALID_SURROGATE;
        u = ((u - 0xD7C0) << 10) + (u2 - 0xDC00);
        ++ridx;
    }
    else if (0xDC00 <= u && u <= 0xDFFF)
        return UTF16_DECODE_UNPAIRED_SURROGATE;
    if (!utf_isValidDchar(u))
        return UTF16_DECODE_INVALID_CODE_POINT;
    rresult = u;
    return UTF16_DECODE_OK;
}
