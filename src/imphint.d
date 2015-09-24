// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

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
    static __gshared const(char)** modules = ["core.stdc.stdio", "std.stdio", "std.math", "core.vararg", null];
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
        null,
        "__va_argsave_t",
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

version (unittest)
{
    extern (C++) void unittest_importHint()
    {
        const(char)* p;
        p = importHint("printf");
        assert(p);
        p = importHint("fabs");
        assert(p);
        p = importHint("xxxxx");
        assert(!p);
    }
}
