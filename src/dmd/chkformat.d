/**
 * Parse the `format` string. Made for `scanf` and `printf` checks.
 *
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/chkformat.d, _chkformat.d)
 * Documentation:  https://dlang.org/phobos/dmd_chkformat.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/chkformat.d
 */
module dmd.chkformat;

/* Different kinds of formatting specifications, variations we don't
   care about are merged. (Like we don't care about the difference between
   f, e, g, a, etc.)

   For `scanf`, every format is a pointer.
 */
enum Format
{
    d,          // int
    hhd,        // signed char
    hd,         // short int
    ld,         // long int
    lld,        // long long int
    jd,         // intmax_t
    zd,         // size_t
    td,         // ptrdiff_t
    u,          // unsigned int
    hhu,        // unsigned char
    hu,         // unsigned short int
    lu,         // unsigned long int
    llu,        // unsigned long long int
    ju,         // uintmax_t
    g,          // float (scanf) / double (printf)
    lg,         // double (scanf)
    Lg,         // long double (both)
    s,          // char string (both)
    ls,         // wchar_t string (both)
    c,          // char (printf)
    lc,         // wint_t (printf)
    p,          // pointer
    n,          // pointer to int
    hhn,        // pointer to signed char
    hn,         // pointer to short
    ln,         // pointer to long int
    lln,        // pointer to long long int
    jn,         // pointer to intmax_t
    zn,         // pointer to size_t
    tn,         // pointer to ptrdiff_t
    percent,    // %% (i.e. no argument)
    error,      // invalid format specification
}

/**************************************
 * Parse the *length specifier* and the *specifier* of the following form:
 * `[length]specifier`
 *
 * Params:
 *      format = format string
 *      idx = index of of start of format specifier,
 *          which gets updated to index past the end of it,
 *          even if `Format.error` is returned
 *      genSpecifier = Generic specifier. For instance, it will be set to `d` if the
 *           format is `hdd`.
 * Returns:
 *      Format
 */
pure @safe nothrow
Format parseGenericFormatSpecifier(scope const char[] format,
    ref size_t idx, out char genSpecifier)
{
    const length = format.length;

    /* Read the `length modifier`
     */
    const lm = format[idx];
    bool lm1;        // if jztL
    bool lm2;        // if `hh` or `ll`
    if (lm == 'j' ||
        lm == 'z' ||
        lm == 't' ||
        lm == 'L')
    {
        ++idx;
        if (idx == length)
            return Format.error;
        lm1 = true;
    }
    else if (lm == 'h' || lm == 'l')
    {
        ++idx;
        if (idx == length)
            return Format.error;
        lm2 = lm == format[idx];
        if (lm2)
        {
            ++idx;
            if (idx == length)
                return Format.error;
        }
    }

    /* Read the `specifier`
     */
    Format specifier;
    const sc = format[idx];
    genSpecifier = sc;
    switch (sc)
    {
        case 'd':
        case 'i':
            if (lm == 'L')
                specifier = Format.error;
            else
                specifier = lm == 'h' && lm2 ? Format.hhd :
                            lm == 'h'        ? Format.hd  :
                            lm == 'l' && lm2 ? Format.lld :
                            lm == 'l'        ? Format.ld  :
                            lm == 'j'        ? Format.jd  :
                            lm == 'z'        ? Format.zd  :
                            lm == 't'        ? Format.td  :
                                               Format.d;
            break;

        case 'u':
        case 'o':
        case 'x':
        case 'X':
            if (lm == 'L')
                specifier = Format.error;
            else
                specifier = lm == 'h' && lm2 ? Format.hhu :
                            lm == 'h'        ? Format.hu  :
                            lm == 'l' && lm2 ? Format.llu :
                            lm == 'l'        ? Format.lu  :
                            lm == 'j'        ? Format.ju  :
                            lm == 'z'        ? Format.zd  :
                            lm == 't'        ? Format.td  :
                                               Format.u;
            break;

        case 'f':
        case 'F':
        case 'e':
        case 'E':
        case 'g':
        case 'G':
        case 'a':
        case 'A':
            if (lm == 'L')
                specifier = Format.Lg;
            else if (lm1 || lm2 || lm == 'h')
                specifier = Format.error;
            else
                specifier = lm == 'l' ? Format.lg : Format.g;
            break;

        case 'c':
            if (lm1 || lm2 || lm == 'h')
                specifier = Format.error;
            else
                specifier = lm == 'l' ? Format.lc : Format.c;
            break;

        case 's':
            if (lm1 || lm2 || lm == 'h')
                specifier = Format.error;
            else
                specifier = lm == 'l' ? Format.ls : Format.s;
            break;

        case 'p':
            if (lm1 || lm2 || lm == 'h' || lm == 'l')
                specifier = Format.error;
            else
                specifier = Format.p;
            break;

        case 'n':
            if (lm == 'L')
                specifier = Format.error;
            else
                specifier = lm == 'l' && lm2 ? Format.lln :
                            lm == 'l'        ? Format.ln  :
                            lm == 'h' && lm2 ? Format.hhn :
                            lm == 'h'        ? Format.hn  :
                            lm == 'j'        ? Format.jn  :
                            lm == 'z'        ? Format.zn  :
                            lm == 't'        ? Format.tn  :
                                               Format.n;
            break;

        default:
            specifier = Format.error;
            break;
    }

    ++idx;
    return specifier; // success
}

unittest
{
    char genSpecifier;
    size_t idx;

    assert(parseGenericFormatSpecifier("hhd", idx, genSpecifier) == Format.hhd);
    assert(genSpecifier == 'd');

    idx = 0;
    assert(parseGenericFormatSpecifier("hn", idx, genSpecifier) == Format.hn);
    assert(genSpecifier == 'n');

    idx = 0;
    assert(parseGenericFormatSpecifier("ji", idx, genSpecifier) == Format.jd);
    assert(genSpecifier == 'i');

    idx = 0;
    assert(parseGenericFormatSpecifier("lu", idx, genSpecifier) == Format.lu);
    assert(genSpecifier == 'u');

    idx = 0;
    assert(parseGenericFormatSpecifier("k", idx, genSpecifier) == Format.error);
}
