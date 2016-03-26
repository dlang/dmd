// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.warnings;

import core.stdc.stdarg;
import ddmd.errors;
import ddmd.globals;

struct WarnCat
{
    alias Type = WarningCategory;

    enum Type none = 0x0;
    enum Type all  = ~none;

    enum Type general      = (0x1L << 0);
    enum Type advice       = (0x1L << 1);
    enum Type ddoc         = (0x1L << 2);
    enum Type notreachable = (0x1L << 3);

    enum Type uncat = (0x1L << 13);  // temporary category for yet uncategorized warnings
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
    if (global.params.warnings && !global.gag)
    {
        verrorPrint(loc, COLOR_YELLOW, "Warning: ", format, ap);
        //halt();
        if (global.params.warnings == 1)
            global.warnings++; // warnings don't count if gagged
    }
}

extern (C++) void vwarningSupplemental(Loc loc, const WarningCategory cat, const(char)* format, va_list ap)
{
    if (global.params.warnings && !global.gag)
        verrorPrint(loc, COLOR_YELLOW, "       ", format, ap);
}
