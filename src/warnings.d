// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.warnings;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.string;

import ddmd.errors;
import ddmd.globals;
import ddmd.root.outbuffer;
import ddmd.root.rmem;

struct WarnCat
{
    alias Type = WarningCategory;

    enum Type none = 0;
    enum Type all  = ~none;

    enum Type general      = (1 << 0);
    enum Type advice       = (1 << 1);
    enum Type ddoc         = (1 << 2);
    enum Type notreachable = (1 << 3);

    enum Type uncat = (1 << 13);  // temporary category for yet uncategorized warnings
}

const (char*)[] warningTable =
[
    "general",
    "advice",
    "ddoc",
    "not-reachable",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "11",
    "12",
    "uncat",
];


// If cat is a combination of multiple categories, the lowest index category is chosen.
const(char)* warnCatToString(const WarningCategory cat)
{
    if (!cat) return "";

    import core.bitop : bsf;
    size_t idx = bsf(cat);
    assert(idx < warningTable.length);
    return warningTable[idx];
}

// Linear search through known strings, returns WarnCat.none if none found
WarningCategory warnStringToCat(const(char)* str)
{
    foreach(i, elem; warningTable)
    {
        if (strcmp(str, elem) == 0)
        {
            return 1 << i;
        }
    }

    return WarnCat.none;
}

extern (C++) void warning(Loc loc, const WarningCategory cat, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarning(loc, cat, format, ap);
    va_end(ap);
}

extern (C++) void warningSupplemental(Loc loc, const WarningCategory cat, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarningSupplemental(loc, cat, format, ap);
    va_end(ap);
}

extern (C++) void vwarning(Loc loc, const WarningCategory cat, const(char)* format, va_list ap)
{
    auto filtered_cat = cat & global.params.enabledWarnings;
    if (filtered_cat && !global.gag)
    {
        vwarningPrint(loc, COLOR_YELLOW, "Warning: ", format, ap, warnCatToString(filtered_cat));
        //halt();
        if (global.params.warnings == 1)
            global.warnings++; // warnings don't count if gagged
    }
}

extern (C++) void vwarningSupplemental(Loc loc, const WarningCategory cat, const(char)* format, va_list ap)
{
    auto filtered_cat = cat & global.params.enabledWarnings;
    if (filtered_cat && !global.gag)
        vwarningPrint(loc, COLOR_YELLOW, "       ", format, ap);
}

// Just print, doesn't care about gagging
extern (C++) void vwarningPrint(Loc loc, COLOR headerColor, const(char)* header, const(char)* format, va_list ap, const(char)* warncat = null)
{
    // Print location
    const p = loc.toChars();
    if (global.params.color)
        setConsoleColorBright(true);
    if (*p)
        fprintf(stderr, "%s: ", p);
    mem.xfree(cast(void*)p);

    // Print header
    if (global.params.color)
        setConsoleColor(headerColor, true);
    fputs(header, stderr);
    if (global.params.color)
        resetConsoleColor();

    // Print user message
    OutBuffer tmp;
    tmp.vprintf(format, ap);
    fprintf(stderr, "%s", tmp.peekString());

    // Print warning category
    if (warncat)
    {
        fprintf(stderr, " (");
        if (global.params.color)
            setConsoleColor(headerColor, true);
        fprintf(stderr, "-W%s", warncat);
        if (global.params.color)
            resetConsoleColor();
        fprintf(stderr, ")");
    }

    fprintf(stderr, "\n");
    fflush(stderr);
}
