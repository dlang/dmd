module dmd.common.stringutil;

/**
 * Basic string maniuplation functions
 *
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/common/stringutil.d, _stringutil.d)
 * Documentation:  https://dlang.org/phobos/dmd_doc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/common/stringutil.d
 */


/**
 * Split a string by a delimiter, excluding the delimiter.
 * Params:
 *  s         = the string to split
 *  delimiter = the character to split by
 * Returns: the resulting array of strings
 */
string[] split(string s, char delimiter) pure @safe
{
    string[] result;
    size_t iStart = 0;
    foreach (size_t i; 0..s.length)
        if (s[i] == delimiter)
        {
            result ~= s[iStart..i];
            iStart = i + 1;
        }
        result ~= s[iStart..$];
        return result;
}

///
unittest
{
    assert(split("", ',') == [""]);
    assert(split("ab", ',') == ["ab"]);
    assert(split("a,b", ',') == ["a", "b"]);
    assert(split("a,,b", ',') == ["a", "", "b"]);
    assert(split(",ab", ',') == ["", "ab"]);
    assert(split("ab,", ',') == ["ab", ""]);
}
