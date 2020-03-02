/**
 * Check the arguments to `scanf` against the `format` string.
 *
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/chkscanf.d, _chkscanf.d)
 * Documentation:  https://dlang.org/phobos/dmd_chkscanf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/chkscanf.d
 */

module dmd.chkscanf;

import core.stdc.stdio : scanf;
import core.stdc.ctype : isdigit;

import dmd.errors;
import dmd.expression;
import dmd.globals;
import dmd.mtype;
import dmd.target;

/******************************************
 * Check that arguments to a scanf format string are compatible
 * with that string. Issue errors for incompatibilities.
 *
 * Follows the C99 specification for scanf.
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
 * 6. non-standard formats
 * 7. undefined behavior per C99
 *
 * Per the C Standard, extra arguments are ignored.
 *
 * No attempt is made to fix the arguments or the format string.
 *
 * Returns:
 *      `true` if errors occurred
 * References:
 * C99 7.19.6.2
 * http://www.cplusplus.com/reference/cstdio/scanf/
 */

bool checkScanfFormat(ref const Loc loc, scope const char[] format, scope Expression[] args)
{
    size_t n = 0;
    for (size_t i = 0; i < format.length;)
    {
        if (format[i] != '%')
        {
            ++i;
            continue;
        }
        bool asterisk;
        size_t j = i;
        const fmt = parseFormatSpecifier(format, j, asterisk);
        const slice = format[i .. j];
        i = j;

        if (fmt == Format.percent || asterisk)
            continue;   // "%%", "%*": no arguments

        Expression getNextArg()
        {
            if (n == args.length)
            {
                if (!asterisk)
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

        auto e = getNextArg();
        if (!e)
            return true;

        auto t = e.type.toBasetype();
        auto tnext = t.nextOf();
        const c_longsize = target.c.longsize;
        const is64bit = global.params.is64bit;

        final switch (fmt)
        {
            case Format.d:      // pointer to int
                if (!(t.ty == Tpointer && tnext.ty == Tint32))
                    errorMsg(null, slice, e, "int*", t);
                break;

            case Format.hhd:    // pointer to signed char
                if (!(t.ty == Tpointer && tnext.ty == Tint16))
                    errorMsg(null, slice, e, "byte*", t);
                break;

            case Format.hd:     // pointer to short
                if (!(t.ty == Tpointer && tnext.ty == Tint16))
                    errorMsg(null, slice, e, "short*", t);
                break;

            case Format.ld:     // pointer to long int
                if (!(t.ty == Tpointer && tnext.isintegral() && tnext.size() == c_longsize))
                    errorMsg(null, slice, e, (c_longsize == 4 ? "int*" : "long*"), t);
                break;

            case Format.lld:    // pointer to long long int
                if (!(t.ty == Tpointer && tnext.ty == Tint64))
                    errorMsg(null, slice, e, "long*", t);
                break;

            case Format.jd:     // pointer to intmax_t
                if (!(t.ty == Tpointer && tnext.ty == Tint64))
                    errorMsg(null, slice, e, "core.stdc.stdint.intmax_t*", t);
                break;

            case Format.zd:     // pointer to size_t
                if (!(t.ty == Tpointer && tnext.ty == (is64bit ? Tuns64 : Tuns32)))
                    errorMsg(null, slice, e, "size_t*", t);
                break;
            case Format.td:     // pointer to ptrdiff_t
                if (!(t.ty == Tpointer && tnext.ty == (is64bit ? Tint64 : Tint32)))
                    errorMsg(null, slice, e, "ptrdiff_t*", t);
                break;

            case Format.u:      // pointer to unsigned int
                if (!(t.ty == Tpointer && tnext.ty == Tuns32))
                    errorMsg(null, slice, e, "uint*", t);
                break;

            case Format.hhu:    // pointer to unsigned char
                if (!(t.ty == Tpointer && tnext.ty == Tuns8))
                    errorMsg(null, slice, e, "ubyte*", t);
                break;

            case Format.hu:     // pointer to unsigned short int
                if (!(t.ty == Tpointer && tnext.ty == Tuns16))
                    errorMsg(null, slice, e, "ushort*", t);
                break;

            case Format.lu:     // pointer to unsigned long int
                if (!(t.ty == Tpointer && tnext.ty == (is64bit ? Tuns64 : Tuns32)))
                    errorMsg(null, slice, e, (c_longsize == 4 ? "uint*" : "ulong*"), t);
                break;

            case Format.llu:    // pointer to unsigned long long int
                if (!(t.ty == Tpointer && tnext.ty == Tuns64))
                    errorMsg(null, slice, e, "ulong*", t);
                break;

            case Format.ju:     // pointer to uintmax_t
                if (!(t.ty == Tpointer && tnext.ty == (is64bit ? Tuns64 : Tuns32)))
                    errorMsg(null, slice, e, "ulong*", t);
                break;

            case Format.g:      // pointer to float
                if (!(t.ty == Tpointer && tnext.ty == Tfloat32))
                    errorMsg(null, slice, e, "float*", t);
                break;
            case Format.lg:     // pointer to double
                if (!(t.ty == Tpointer && tnext.ty == Tfloat64))
                    errorMsg(null, slice, e, "double*", t);
                break;
            case Format.Lg:     // pointer to long double
                if (!(t.ty == Tpointer && tnext.ty == Tfloat80))
                    errorMsg(null, slice, e, "real*", t);
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

            case Format.p:      // double pointer
                if (!(t.ty == Tpointer && tnext.ty == Tpointer))
                    errorMsg(null, slice, e, "void**", t);
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
   f, e, g, a, etc.)
 */
enum Format
{
    d,          // pointer to int
    hhd,        // pointer to signed char
    hd,         // pointer to short int
    ld,         // pointer to long int
    lld,        // pointer to long long int
    jd,         // pointer to intmax_t
    zd,         // pointer to size_t
    td,         // pointer to ptrdiff_t
    u,          // pointer to unsigned int
    hhu,        // pointer to unsigned char
    hu,         // pointer to unsigned short int
    lu,         // pointer to unsigned long int
    llu,        // pointer to unsigned long long int
    ju,         // pointer to uintmax_t
    g,          // pointer to float
    lg,         // pointer to double
    Lg,         // pointer to long double
    s,          // pointer to char string
    ls,         // pointer to wchar_t string
    p,          // double pointer
    percent,    // %% (i.e. no argument)
    error,      // invalid format specification
}


/**************************************
 * Parse the *format specifier* which is of the form:
 *
 * `%[*][width][length]specifier`
 *
 * Params:
 *      format = format string
 *      idx = index of `%` of start of format specifier,
 *          which gets updated to index past the end of it,
 *          even if Format.error is returned
 *      asterisk = set if there is a `*` sub-specifier
 * Returns:
 *      Format
 */
pure nothrow @safe
Format parseFormatSpecifier(scope const char[] format, ref size_t idx,
        out bool asterisk)
{
    auto i = idx;
    assert(format[i] == '%');
    const length = format.length;

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

    // * sub-specifier
    if (format[i] == '*')
    {
        ++i;
        if (i == length)
            return error();
        asterisk = true;
    }

    // fieldWidth
    {
        while (isdigit(format[i]))
        {
            i++;
            if (i == length)
                return error();
        }
    }

    /* Read the scanset
     * A scanset can be anything, so we just check that it is paired
     */
    if (format[i] == '[')
    {
        while (i < length)
        {
            if (format[i] == ']')
                break;
            ++i;
        }

        // no `]` found
        if (i == length)
            return error();

        ++i;
        // no specifier after `]`
        // it could be mixed with the one above, but then idx won't have the right index
        if (i == length)
            return error();
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
        case 'n':
            if (lm == 'L')
                return error();
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
                return error();
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
            else if (lm == 'l' && !lm2)
                specifier = Format.lg;
            else if (lm1 || lm2 || lm == 'h')
                return error();
            else
                specifier = Format.g;
            break;

        case 'c':
        case 's':
            if (lm == 'l' && !lm2)
                specifier = Format.ls;
            else if (lm1 || lm2 || lm == 'h')
                return error();
            else
                specifier = Format.s;
            break;

        case 'p':
            if (lm1 || lm2 || lm == 'h' || lm == 'l')
                return error();
            specifier = Format.p;
            break;

        default:
            return error();
    }

    idx = i;
    return specifier;  // success
}

unittest
{
    size_t idx;
    bool asterisk;

    // one for each Format
    idx = 0;
    assert(parseFormatSpecifier("%d", idx, asterisk) == Format.d);
    assert(idx == 2);
    assert(!asterisk);

    idx = 0;
    assert(parseFormatSpecifier("%hhd", idx, asterisk) == Format.hhd);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%hd", idx, asterisk) == Format.hd);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%ld", idx, asterisk) == Format.ld);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%lld", idx, asterisk) == Format.lld);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%jd", idx, asterisk) == Format.jd);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%zd", idx, asterisk) == Format.zd);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%td", idx, asterisk,) == Format.td);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%u", idx, asterisk) == Format.u);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%hhu", idx, asterisk,) == Format.hhu);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%hu", idx, asterisk) == Format.hu);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%lu", idx, asterisk) == Format.lu);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%llu", idx, asterisk) == Format.llu);
    assert(idx == 4);

    idx = 0;
    assert(parseFormatSpecifier("%ju", idx, asterisk) == Format.ju);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%g", idx, asterisk) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%lg", idx, asterisk) == Format.lg);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%Lg", idx, asterisk) == Format.Lg);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%p", idx, asterisk) == Format.p);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%s", idx, asterisk) == Format.s);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%ls", idx, asterisk,) == Format.ls);
    assert(idx == 3);

    idx = 0;
    assert(parseFormatSpecifier("%%", idx, asterisk) == Format.percent);
    assert(idx == 2);

    // Synonyms
    idx = 0;
    assert(parseFormatSpecifier("%i", idx, asterisk) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%n", idx, asterisk) == Format.d);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%o", idx, asterisk) == Format.u);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%x", idx, asterisk) == Format.u);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%f", idx, asterisk) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%e", idx, asterisk) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%a", idx, asterisk) == Format.g);
    assert(idx == 2);

    idx = 0;
    assert(parseFormatSpecifier("%c", idx, asterisk) == Format.s);
    assert(idx == 2);

    // asterisk
    idx = 0;
    assert(parseFormatSpecifier("%*d", idx, asterisk) == Format.d);
    assert(idx == 3);
    assert(asterisk);

    idx = 0;
    assert(parseFormatSpecifier("%9ld", idx, asterisk) == Format.ld);
    assert(idx == 4);
    assert(!asterisk);

    idx = 0;
    assert(parseFormatSpecifier("%*25984hhd", idx, asterisk) == Format.hhd);
    assert(idx == 10);
    assert(asterisk);

    // scansets
    idx = 0;
    assert(parseFormatSpecifier("%[a-zA-Z]s", idx, asterisk) == Format.s);
    assert(idx == 10);
    assert(!asterisk);

    idx = 0;
    assert(parseFormatSpecifier("%*25[a-z]hhd", idx, asterisk) == Format.hhd);
    assert(idx == 12);
    assert(asterisk);

    // Too short formats
    foreach (s; ["%", "% ", "%#", "%0", "%*", "%1", "%19",
                 "%j", "%z", "%t", "%l", "%h", "%ll", "%hh", "%K"])
    {
        idx = 0;
        assert(parseFormatSpecifier(s, idx, asterisk) == Format.error);
        assert(idx == s.length);
    }


    // Undefined format combinations
    foreach (s; ["%Ld", "%llg", "%jg", "%zg", "%tg", "%hg", "%hhg",
                 "%jc", "%zc", "%tc", "%Lc", "%hc", "%hhc", "%llc",
                 "%jp", "%zp", "%tp", "%Lp", "%hp", "%lp", "%hhp", "%llp",
                 "%-", "%+", "%#", "%0", "%.", "%Ln"])
    {
        idx = 0;
        assert(parseFormatSpecifier(s, idx, asterisk) == Format.error);
        assert(idx == s.length);

    }

    // Invalid scansets
    foreach (s; ["%[]", "%[s", "%[0-9lld", "%[", "%[a-z]"])
    {
        idx = 0;
        assert(parseFormatSpecifier(s, idx, asterisk) == Format.error);
        assert(idx == s.length);
    }

}
