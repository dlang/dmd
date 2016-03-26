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

extern (C++) void warning(Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarning(loc, format, ap);
    va_end(ap);
}

extern (C++) void warningSupplemental(Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarningSupplemental(loc, format, ap);
    va_end(ap);
}

extern (C++) void vwarning(Loc loc, const(char)* format, va_list ap)
{
    if (global.params.warnings && !global.gag)
    {
        verrorPrint(loc, COLOR_YELLOW, "Warning: ", format, ap);
        //halt();
        if (global.params.warnings == 1)
            global.warnings++; // warnings don't count if gagged
    }
}

extern (C++) void vwarningSupplemental(Loc loc, const(char)* format, va_list ap)
{
    if (global.params.warnings && !global.gag)
        verrorPrint(loc, COLOR_YELLOW, "       ", format, ap);
}
