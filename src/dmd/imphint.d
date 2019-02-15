/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/imphint.d, _imphint.d)
 * Documentation:  https://dlang.org/phobos/dmd_imphint.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/imphint.d
 */

module dmd.imphint;

import dmd.utils;

/******************************************
 * Looks for undefined identifier s to see
 * if it might be undefined because an import
 * was not specified.
 * Not meant to be a comprehensive list of names in each module,
 * just the most common ones.
 */
const(char)[] importHint(const(char)[] s)
{
    if (auto entry = s in hints)
        return *entry;
    return null;
}

private immutable string[string] hints;

shared static this()
{
    // in alphabetic order
    hints = [
        "calloc": "core.stdc.stdlib",
        "cos": "std.math",
        "fabs": "std.math",
        "free": "core.stdc.stdlib",
        "malloc": "core.stdc.stdlib",
        "printf": "core.stdc.stdio",
        "realloc": "core.stdc.stdlib",
        "sin": "std.math",
        "sqrt": "std.math",
        "writefln": "std.stdio",
        "writeln": "std.stdio",
        "__va_argsave_t": "core.stdc.stdarg",
        "__va_list_tag": "core.stdc.stdarg",
    ];
}

unittest
{
    assert(importHint("printf") !is null);
    assert(importHint("fabs") !is null);
    assert(importHint("xxxxx") is null);
}
