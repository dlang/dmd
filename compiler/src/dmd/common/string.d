/**
 * Contains various string related functions.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/common/string.d, common/_string.d)
 * Documentation:  https://dlang.org/phobos/dmd_common_string.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/common/string.d
 */

module dmd.common.string;

@safe pure nothrow @nogc:

/**
 * Strips one leading line terminator of the given string.
 *
 * The following are what the Unicode standard considers as line terminators:
 *
 * | Name                | D Escape Sequence | Unicode Code Point |
 * |---------------------|-------------------|--------------------|
 * | Line feed           | `\n`              | `U+000A`           |
 * | Line tabulation     | `\v`              | `U+000B`           |
 * | Form feed           | `\f`              | `U+000C`           |
 * | Carriage return     | `\r`              | `U+000D`           |
 * | Next line           |                   | `U+0085`           |
 * | Line separator      |                   | `U+2028`           |
 * | Paragraph separator |                   | `U+2029`           |
 *
 * This function will also strip `\r\n`.
 */
string stripLeadingLineTerminator(string str) pure nothrow @nogc @safe
{
    enum nextLine = "\xC2\x85";
    enum lineSeparator = "\xE2\x80\xA8";
    enum paragraphSeparator = "\xE2\x80\xA9";

    static assert(lineSeparator.length == paragraphSeparator.length);

    if (str.length == 0)
        return str;

    switch (str[0])
    {
        case '\r':
        {
            if (str.length >= 2 && str[1] == '\n')
                return str[2 .. $];
            goto case;
        }
        case '\v', '\f', '\n': return str[1 .. $];

        case nextLine[0]:
        {
            if (str.length >= 2 && str[0 .. 2] == nextLine)
                return str[2 .. $];
            return str;
        }

        case lineSeparator[0]:
        {
            if (str.length >= lineSeparator.length)
            {
                const prefix = str[0 .. lineSeparator.length];

                if (prefix == lineSeparator || prefix == paragraphSeparator)
                    return str[lineSeparator.length .. $];
            }

            return str;
        }

        default: return str;
    }
}

unittest
{
    assert("".stripLeadingLineTerminator == "");
    assert("foo".stripLeadingLineTerminator == "foo");
    assert("\xC2foo".stripLeadingLineTerminator == "\xC2foo");
    assert("\xE2foo".stripLeadingLineTerminator == "\xE2foo");
    assert("\nfoo".stripLeadingLineTerminator == "foo");
    assert("\vfoo".stripLeadingLineTerminator == "foo");
    assert("\ffoo".stripLeadingLineTerminator == "foo");
    assert("\rfoo".stripLeadingLineTerminator == "foo");
    assert("\u0085foo".stripLeadingLineTerminator == "foo");
    assert("\u2028foo".stripLeadingLineTerminator == "foo");
    assert("\u2029foo".stripLeadingLineTerminator == "foo");
    assert("\n\rfoo".stripLeadingLineTerminator == "\rfoo");
    assert("\r\nfoo".stripLeadingLineTerminator == "foo");
    assert("\xC2".stripLeadingLineTerminator == "\xC2");
    assert("\xE2".stripLeadingLineTerminator == "\xE2");
    assert("\xE2\x80".stripLeadingLineTerminator == "\xE2\x80");

    static assert("".stripLeadingLineTerminator == "");
    static assert("\r\nfoo".stripLeadingLineTerminator == "foo");
    static assert("\u2028foo".stripLeadingLineTerminator == "foo");
    static assert("\xC2".stripLeadingLineTerminator == "\xC2");
    static assert("\xE2\x80".stripLeadingLineTerminator == "\xE2\x80");
}

/**
 * Checks whether `str` starts with `prefix`, comparing bytes.
 *
 * The comparison is bytewise, i.e. no UTF-8 decoding is performed,
 * and no memory is allocated. An empty `prefix` always matches.
 *
 * Params:
 *     str = the string to check
 *     prefix = the prefix to look for
 * Returns:
 *     `true` if `str` starts with `prefix`
 */
bool startsWith(scope const(char)[] str, scope const(char)[] prefix)
{
    if (str.length < prefix.length)
        return false;
    return str[0 .. prefix.length] == prefix;
}

unittest
{
    assert(startsWith("", ""));
    assert(startsWith("abc", ""));
    assert(startsWith("abc", "a"));
    assert(startsWith("abc", "ab"));
    assert(startsWith("abc", "abc"));
    assert(!startsWith("abc", "abcd"));
    assert(!startsWith("abc", "abd"));
    assert(!startsWith("", "a"));

    assert(startsWith("\xC3\xA9", "\xC3"));
    assert(startsWith("\xC3\xA9", "\xC3\xA9"));
    assert(!startsWith("\xC3\xA9", "\xC3\xA8"));

    static assert(startsWith("", ""));
    static assert(startsWith("abc", ""));
    static assert(startsWith("abc", "ab"));
    static assert(!startsWith("abc", "abcx"));
    static assert(!startsWith("abc", "abd"));
    static assert(startsWith("\xC3\xA9", "\xC3"));
}
