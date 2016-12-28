/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _imphint.d)
 */

module ddmd.imphint;

import core.stdc.string;

/******************************************
 * Looks for undefined identifier s to see
 * if it might be undefined because an import
 * was not specified.
 * Not meant to be a comprehensive list of names in each module,
 * just the most common ones.
 */
extern (C++) const(char)* importHint(const(char)* s)
{
    static __gshared const(char)** modules = ["core.stdc.stdio", "std.stdio", "std.math", null];
    static __gshared const(char)** names =
    [
        "printf",
        null,
        "writeln",
        null,
        "sin",
        "cos",
        "sqrt",
        "fabs",
        null
    ];
    int m = 0;
    for (int n = 0; modules[m]; n++)
    {
        const(char)* p = names[n];
        if (p is null)
        {
            m++;
            continue;
        }
        assert(modules[m]);
        if (strcmp(s, p) == 0)
            return modules[m];
    }
    return null; // didn't find it
}

unittest
{
    const(char)* p;
    p = importHint("printf");
    assert(p);
    p = importHint("fabs");
    assert(p);
    p = importHint("xxxxx");
    assert(!p);
}
