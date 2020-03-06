/**
 * Check the arguments to `printf` against the `format` string.
 *
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/chkprintf.d, _chkprintf.d)
 * Documentation:  https://dlang.org/phobos/dmd_chkprintf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/chkprintf.d
 */

module dmd.chkprintf;

import core.stdc.stdio : printf;

import dmd.errors;
import dmd.expression;
import dmd.globals;
import dmd.mtype;
import dmd.target;

/******************************************
 * Check that arguments to a printf format string are compatible
 * with that string. Issue errors for incompatibilities.
 *
 * Follows the C99 specification for printf.
 *
 * Takes a generous, rather than strict, view of compatiblity.
 * For example, an unsigned value can be formatted with a signed specifier.
 *
 * Diagnosed incompatibilities are:
 *
 * 1. incompatible sizes which will cause argument misalignment
 * 2. deferencing arguments that are not pointers
 * 3. insufficient number of arguments
 * 4. struct arguments
 * 5. array and slice arguments
 * 6. non-pointer arguments to `s` specifier
 * 7. non-standard formats
 * 8. undefined behavior per C99
 *
 * Per the C Standard, extra arguments are ignored.
 *
 * No attempt is made to fix the arguments or the format string.
 *
 * Returns:
 *      `true` if errors occurred
 * References:
 * C99 7.19.6.1
 * http://www.cplusplus.com/reference/cstdio/printf/
 */

bool checkPrintfFormat(ref const Loc loc, scope const char[] format, scope Expression[] args)
{
    //printf("checkPrintFormat('%.*s')\n", cast(int)format.length, format.ptr);
    size_t n = 0;
    for (size_t i = 0; i < format.length;)
    {
        if (format[i] != '%')
        {
            ++i;
            continue;
        }
        bool widthStar;
        bool precisionStar;
        size_t j = i;
        const fmt = parseFormatSpecifier(format, j, widthStar, precisionStar);
        const slice = format[i .. j];
        i = j;

        if (fmt == Format.percent)
            continue;                   // "%%", no arguments

        Expression getNextArg()
        {
            if (n == args.length)
            {
                deprecation(loc, "more format specifiers than %d arguments", cast(int)n);
                return null;
            }
            return args[n++];
        }

        void errorMsg(const char* prefix, const char[] specifier, Expression arg, const char* texpect, Type tactual)
        {
            deprecation(arg.loc, "%sargument `%s` for format specification `\"%.*s\"` must be `%s`, not `%s`",
                  prefix ? prefix : "", arg.toChars(), cast(int)slice.length, slice.ptr, texpect, tactual.toChars());
        }

        if (widthStar)
        {
            auto e = getNextArg();
            if (!e)
                return true;
            auto t = e.type.toBasetype();
            if (t.ty != Tint32 && t.ty != Tuns32)
                errorMsg("width ", slice, e, "int", t);
        }

        if (precisionStar)
        {
            auto e = getNextArg();
            if (!e)
                return true;
            auto t = e.type.toBasetype();
            if (t.ty != Tint32 && t.ty != Tuns32)
                errorMsg("precision ", slice, e, "int", t);
        }

        auto e = getNextArg();
        if (!e)
            return true;
        auto t = e.type.toBasetype();
        auto tnext = t.nextOf();
        const c_longsize = target.c.longsize;
        const is64bit = global.params.is64bit;

        final switch (fmt)
        {
            case Format.d:      // int
                if (t.ty != Tint32 && t.ty != Tuns32)
                    errorMsg(null, slice, e, "int", t);
                break;

            case Format.ld:     // long int
                if (!(t.isintegral() && t.size() == c_longsize))
                    errorMsg(null, slice, e, (c_longsize == 4 ? "int" : "long"), t);
                break;

            case Format.lld:    // long long int
                if (t.ty != Tint64 && t.ty != Tuns64)
                    errorMsg(null, slice, e, "long", t);
                break;

            case Format.jd:     // intmax_t
                if (t.ty != Tint64 && t.ty != Tuns64)
                    errorMsg(null, slice, e, "core.stdc.stdint.intmax_t", t);
                break;

            case Format.zd:     // size_t
                if (!(t.isintegral() && t.size() == (is64bit ? 8 : 4)))
                    errorMsg(null, slice, e, "size_t", t);
                break;

            case Format.td:     // ptrdiff_t
                if (!(t.isintegral() && t.size() == (is64bit ? 8 : 4)))
                    errorMsg(null, slice, e, "ptrdiff_t", t);
                break;

            case Format.g:      // double
                if (t.ty != Tfloat64 && t.ty != Timaginary64)
                    errorMsg(null, slice, e, "double", t);
                break;

            case Format.Lg:     // long double
                if (t.ty != Tfloat80 && t.ty != Timaginary80)
                    errorMsg(null, slice, e, "real", t);
                break;

            case Format.p:      // pointer
                if (t.ty != Tpointer && t.ty != Tnull && t.ty != Tclass && t.ty != Tdelegate && t.ty != Taarray)
                    errorMsg(null, slice, e, "void*", t);
                break;

            case Format.n:      // pointer to int
                if (!(t.ty == Tpointer && tnext.ty == Tint32))
                    errorMsg(null, slice, e, "int*", t);
                break;

            case Format.ln:     // pointer to long int
                if (!(t.ty == Tpointer && tnext.isintegral() && tnext.size() == c_longsize))
                    errorMsg(null, slice, e, (c_longsize == 4 ? "int*" : "long*"), t);
                break;

            case Format.lln:    // pointer to long long int
                if (!(t.ty == Tpointer && tnext.ty == Tint64))
                    errorMsg(null, slice, e, "long*", t);
                break;

            case Format.hn:     // pointer to short
                if (!(t.ty == Tpointer && tnext.ty == Tint16))
                    errorMsg(null, slice, e, "short*", t);
                break;

            case Format.hhn:    // pointer to signed char
                if (!(t.ty == Tpointer && tnext.ty == Tint16))
                    errorMsg(null, slice, e, "byte*", t);
                break;

            case Format.jn:     // pointer to intmax_t
                if (!(t.ty == Tpointer && tnext.ty == Tint64))
                    errorMsg(null, slice, e, "core.stdc.stdint.intmax_t*", t);
                break;

            case Format.zn:     // pointer to size_t
                if (!(t.ty == Tpointer && tnext.ty == (is64bit ? Tuns64 : Tuns32)))
                    errorMsg(null, slice, e, "size_t*", t);
                break;
            case Format.tn:     // pointer to ptrdiff_t
                if (!(t.ty == Tpointer && tnext.ty == (is64bit ? Tint64 : Tint32)))
                    errorMsg(null, slice, e, "ptrdiff_t*", t);
                break;

            case Format.c:      // char
                if (t.ty != Tint32 && t.ty != Tuns32)
                    errorMsg(null, slice, e, "char", t);
                break;

            case Format.lc:     // wint_t
                if (t.ty != Tint32 && t.ty != Tuns32)
                    errorMsg(null, slice, e, "wchar_t", t);
                break;

            case Format.s:      // pointer to char string
                if (!(t.ty == Tpointer && (tnext.ty == Tchar || tnext.ty == Tint8 || tnext.ty == Tuns8)))
                    errorMsg(null, slice, e, "char*", t);
                break;

            case Format.ls:     // pointer to wchar_t string
                const twchar_t = global.params.isWindows ? Twchar : Tdchar;
                if (!(t.ty == Tpointer && tnext.ty == twchar_t))
                    errorMsg(null, slice, e, "wchar_t*", t);
                break;

            case Format.error:
                deprecation(loc, "format specifier `\"%.*s\"` is invalid", cast(int)slice.length, slice.ptr);
                break;

            case Format.percent:
                assert(0);
        }
    }
    return false;
}

private:

/* Different kinds of formatting specifications, variations we don't
   care about are merged. (Like we don't care about the difference between
   a, A, g, G, etc.)
 */
enum Format
{
    d,          // int
    ld,         // long int
    lld,        // long long int
    jd,         // intmax_t
    zd,         // size_t
    td,         // ptrdiff_t
    g,          // double
    Lg,         // long double
    p,          // pointer
    n,          // pointer to int
    ln,         // pointer to long int
    lln,        // pointer to long long int
    hn,         // pointer to short
    hhn,        // pointer to signed char
    jn,         // pointer to intmax_t
    zn,         // pointer to size_t
    tn,         // pointer to ptrdiff_t
    c,          // char
    lc,         // wint_t
    s,          // pointer to char string
    ls,         // pointer to wchar_t string
    percent,    // %% (i.e. no argument)
    error,      // invalid format specification
}


/**************************************
 * Parse the *format specifier* which is of the form:
 *
 * `%[flags][field width][.precision][length modifier]specifier`
 *
 * Params:
 *      format = format string
 *      idx = index of `%` of start of format specifier,
 *          which gets updated to index past the end of it,
 *          even if Format.error is returned
 *      widthStar = set if * for width
 *      precisionStar = set if * for precision
 * Returns:
 *      Format
 */
pure nothrow @safe
Format parseFormatSpecifier(scope const char[] format, ref size_t idx,
        out bool widthStar, out bool precisionStar)
{
    auto i = idx;
    assert(format[i] == '%');
    const length = format.length;
    bool hash;
    bool zero;
    bool flags;
    bool width;
    bool precision;

    Format error()
    {
        idx = i;
        return Format.error;
    }

    ++i;
    if (i == length)
        return error();

    if (format[i] == '%')
    {
        idx = i + 1;
        return Format.percent;
    }

    /* Read the `flags`
     */
    while (1)
    {
        const c = format[i];
        if (c == '-' ||
            c == '+' ||
            c == ' ')
        {
            flags = true;
        }
        else if (c == '#')
        {
            hash = true;
        }
        else if (c == '0')
        {
            zero = true;
        }
        else
            break;
        ++i;
        if (i == length)
            return error();
    }

    /* Read the `field width`
     */
    {
        const c = format[i];
        if (c == '*')
        {
            width = true;
            widthStar = true;
            ++i;
            if (i == length)
                return error();
        }
        else if ('1' <= c && c <= '9')
        {
            width = true;
            ++i;
            if (i == length)
                return error();
            while ('0' <= format[i] && format[i] <= '9')
            {
               ++i;
               if (i == length)
                    return error();
            }
        }
    }

    /* Read the `precision`
     */
    if (format[i] == '.')
    {
        precision = true;
        ++i;
        if (i == length)
            return error();
        const c = format[i];
        if (c == '*')
        {
            precisionStar = true;
            ++i;
            if (i == length)
                return error();
        }
        else if ('0' <= c && c <= '9')
        {
            ++i;
            if (i == length)
                return error();
            while ('0' <= format[i] && format[i] <= '9')
            {
               ++i;
               if (i == length)
                    return error();
            }
        }
    }

    /* Read the `length modifier`
     */
    const lm = format[i];
    bool lm1;        // if jztL
    bool lm2;        // if `hh` or `ll`
    if (lm == 'j' ||
        lm == 'z' ||
        lm == 't' ||
        lm == 'L')
    {
        ++i;
        if (i == length)
            return error();
        lm1 = true;
    }
    else if (lm == 'h' || lm == 'l')
    {
        ++i;
        if (i == length)
            return error();
        lm2 = lm == format[i];
        if (lm2)
        {
            ++i;
            if (i == length)
                return error();
        }
    }

    /* Read the `specifier`
     */
    Format specifier;
    const sc = format[i];
    ++i;
    switch (sc)
    {
        case 'd':
        case 'i':
        case 'u':
            if (hash)
                return error();
            goto case 'o';

        case 'o':
        case 'x':
        case 'X':
            specifier = lm == 'l' && lm2 ? Format.lld :
                        lm == 'l'        ? Format.ld  :
                        lm == 'j'        ? Format.jd  :
                        lm == 'z'        ? Format.zd  :
                        lm == 't'        ? Format.td  :
                                           Format.d;
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
            else if (lm1 ||lm2 || lm == 'h')
                return error();
            else
                specifier = Format.g;
            break;

        case 'c':
            if (hash || zero ||
                lm1 || lm2 || lm == 'h')
                return error();
            specifier = lm == 'l' ? Format.lc : Format.c;
            break;

        case 's':
            if (hash || zero ||
                lm1 || lm2 || lm == 'h')
                return error();
            specifier = lm == 'l' ? Format.ls : Format.s;
            break;

        case 'p':
            if (lm1 || lm == 'h' || lm == 'l')
                return error();
            specifier = Format.p;
            break;

        case 'n':
            if (flags || hash || zero ||
                width || precision ||
                lm == 'L')
            {
                return error();
            }
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
            return error();
    }

    idx = i;
    return specifier;  // success
}

unittest
{
    //printf("parseFormatSpecifier()\n");

    size_t idx;
    bool widthStar;
    bool precisionStar;

    // one for each Format
    idx = 0;
    assert(parseFormatSpecifier("%d", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 2);
    assert(!widthStar && !precisionStar);

    idx = 0;
    assert(parseFormatSpecifier("%ld", idx, widthStar, precisionStar) == Format.ld);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%lld", idx, widthStar, precisionStar) == Format.lld);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%jd", idx, widthStar, precisionStar) == Format.jd);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%zd", idx, widthStar, precisionStar) == Format.zd);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%td", idx, widthStar, precisionStar) == Format.td);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%g", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%Lg", idx, widthStar, precisionStar) == Format.Lg);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%p", idx, widthStar, precisionStar) == Format.p);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%n", idx, widthStar, precisionStar) == Format.n);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%ln", idx, widthStar, precisionStar) == Format.ln);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%lln", idx, widthStar, precisionStar) == Format.lln);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%hn", idx, widthStar, precisionStar) == Format.hn);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%hhn", idx, widthStar, precisionStar) == Format.hhn);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%jn", idx, widthStar, precisionStar) == Format.jn);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%zn", idx, widthStar, precisionStar) == Format.zn);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%tn", idx, widthStar, precisionStar) == Format.tn);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%c", idx, widthStar, precisionStar) == Format.c);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%lc", idx, widthStar, precisionStar) == Format.lc);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%s", idx, widthStar, precisionStar) == Format.s);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%ls", idx, widthStar, precisionStar) == Format.ls);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%%", idx, widthStar, precisionStar) == Format.percent);
    assert(idx == 2);

    // Synonyms
    idx = 0;
    assert(parseFormatSpecifier("%i", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%u", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%o", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%x", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%X", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%f", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%F", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%G", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%a", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%A", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%lg", idx, widthStar, precisionStar) == Format.g);
    assert(idx == 3);

    // width, precision
    idx = 0;
    assert(parseFormatSpecifier("%*d", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 3);
    assert(widthStar && !precisionStar);

    idx = 0;
    assert(parseFormatSpecifier("%.*d", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 4);
    assert(!widthStar && precisionStar);

    idx = 0;
    assert(parseFormatSpecifier("%*.*d", idx, widthStar, precisionStar) == Format.d);
    assert(idx == 5);
    assert(widthStar && precisionStar);

    // Too short formats
    {
        foreach (s; ["%", "%-", "%+", "% ", "%#", "%0", "%*", "%1", "%19", "%.", "%.*", "%.1", "%.12",
                     "%j", "%z", "%t", "%l", "%h", "%ll", "%hh", "%K"])
        {
            idx = 0;
            assert(parseFormatSpecifier(s, idx, widthStar, precisionStar) == Format.error);
            assert(idx == s.length);
        }
    }

    // Undefined format combinations
    {
        foreach (s; ["%#d", "%llg", "%jg", "%zg", "%tg", "%hg", "%hhg",
                     "%#c", "%0c", "%jc", "%zc", "%tc", "%Lc", "%hc", "%hhc", "%llc",
                     "%#s", "%0s", "%js", "%zs", "%ts", "%Ls", "%hs", "%hhs", "%lls",
                     "%jp", "%zp", "%tp", "%Lp", "%hp", "%lp", "%hhp", "%llp",
                     "%-n", "%+n", "% n", "%#n", "%0n", "%*n", "%1n", "%19n", "%.n", "%.*n", "%.1n", "%.12n", "%Ln"])
        {
            idx = 0;
            assert(parseFormatSpecifier(s, idx, widthStar, precisionStar) == Format.error);
            assert(idx == s.length);
        }
    }
}
