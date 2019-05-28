/**
 * This module contains various string related functions.
 *
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/string.d, root/_string.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_string.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/string.d
 */
module dmd.root.string;

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
 * This function will also strip `\n\r`.
 */
string stripLeadingLineTerminator(string str)
{
    enum nextLine = "\xC2\x85";
    enum lineSeparator = "\xE2\x80\xA8";
    enum paragraphSeparator = "\xE2\x80\xA9";

    if (str.length == 0)
        return str;

    switch (str[0])
    {
        case '\n':
        {
            if (str.length >= 2 && str[1] == '\r')
                return str[2 .. $];
            goto case;
        }
        case '\v', '\f', '\r': return str[1 .. $];

        case nextLine[0]:
        {
            if (str.length >= 2 && str[0 .. 2] == nextLine)
                return str[2 .. $];

            return str;
        }

        case lineSeparator[0]:
        {
            if (str.length >= 3)
            {
                const prefix = str[0 .. 3];

                if (prefix == lineSeparator || prefix == paragraphSeparator)
                    return str[3 .. $];
            }

            return str;
        }

        default: return str;
    }
}

unittest
{
    assert("\nfoo".stripLeadingLineTerminator == "foo");
    assert("\vfoo".stripLeadingLineTerminator == "foo");
    assert("\ffoo".stripLeadingLineTerminator == "foo");
    assert("\rfoo".stripLeadingLineTerminator == "foo");
    assert("\u0085foo".stripLeadingLineTerminator == "foo");
    assert("\u2028foo".stripLeadingLineTerminator == "foo");
    assert("\u2029foo".stripLeadingLineTerminator == "foo");
    assert("\n\rfoo".stripLeadingLineTerminator == "foo");
}
