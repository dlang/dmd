/**
 * Contains various string related functions.
 *
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/string.d, root/_string.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_string.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/string.d
 */
module dmd.root.string;

/// Slices a `\0`-terminated C-string, excluding the terminator
inout(char)[] toDString (inout(char)* s) pure nothrow @nogc
{
    import core.stdc.string : strlen;
    return s ? s[0 .. strlen(s)] : null;
}

/**
Compare two slices for equality, in a case-insensitive way

Comparison is based on `char` and does not do decoding.
As a result, it's only really accurate for plain ASCII strings.

Params:
s1 = string to compare
s2 = string to compare

Returns:
`true` if `s1 == s2` regardless of case
*/
extern(D) static bool iequals(const(char)[] s1, const(char)[] s2)
{
    import core.stdc.ctype : toupper;

    if (s1.length != s2.length)
        return false;

    foreach (idx, c1; s1)
    {
        // Since we did a length check, it is safe to bypass bounds checking
        const c2 = s2.ptr[idx];
        if (c1 != c2)
            if (toupper(c1) != toupper(c2))
                return false;
    }
    return true;
}

/**
Copy the content of `src` into a C-string ('\0' terminated) then call `dg`

The intent of this function is to provide an allocation-less
way to call a C function using a D slice.
The function internally allocates a buffer if needed, but frees it on exit.

Note:
The argument to `dg` is `scope`. To keep the data around after `dg` exits,
one has to copy it.

Params:
src = Slice to use to call the C function
dg  = Delegate to call afterwards

Returns:
The return value of `T`
*/
auto toCStringThen(alias dg)(const(char)[] src) nothrow
{
    import dmd.root.rmem : mem;

    const len = src.length + 1;
    char[512] small = void;
    scope ptr = (src.length < (small.length - 1))
                    ? small[0 .. len]
                    : (cast(char*)mem.xmalloc(len))[0 .. len];
    scope (exit)
    {
        if (&ptr[0] != &small[0])
            mem.xfree(&ptr[0]);
    }
    ptr[0 .. src.length] = src[];
    ptr[src.length] = '\0';
    return dg(ptr);
}

unittest
{
    assert("Hello world".toCStringThen!((v) => v == "Hello world\0"));
    assert("Hello world\0".toCStringThen!((v) => v == "Hello world\0\0"));
    assert(null.toCStringThen!((v) => v == "\0"));
}

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
string stripLeadingLineTerminator(string str) pure nothrow @nogc @safe
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
    assert("\n\rfoo".stripLeadingLineTerminator == "foo");
}

/**
 * A string comparison functions that returns the same result as strcmp
 *
 * Note: Strings are compared based on their ASCII values, no UTF-8 decoding.
 *
 * Some C functions (e.g. `qsort`) require a `int` result for comparison.
 * See_Also: Druntime's `core.internal.string`
 */
int dstrcmp()( scope const char[] s1, scope const char[] s2 ) @trusted
{
    immutable len = s1.length <= s2.length ? s1.length : s2.length;
    if (__ctfe)
    {
        foreach (const u; 0 .. len)
        {
            if (s1[u] != s2[u])
                return s1[u] > s2[u] ? 1 : -1;
        }
    }
    else
    {
        import core.stdc.string : memcmp;

        const ret = memcmp( s1.ptr, s2.ptr, len );
        if ( ret )
            return ret;
    }
    return s1.length < s2.length ? -1 : (s1.length > s2.length);
}

//
unittest
{
    assert(dstrcmp("Fraise", "Fraise")      == 0);
    assert(dstrcmp("Baguette", "Croissant") == -1);
    assert(dstrcmp("Croissant", "Baguette") == 1);

    static assert(dstrcmp("Baguette", "Croissant") == -1);

    // UTF-8 decoding for the CT variant
    assert(dstrcmp("안녕하세요!", "안녕하세요!") == 0);
    static assert(dstrcmp("안녕하세요!", "안녕하세요!") == 0);
}
