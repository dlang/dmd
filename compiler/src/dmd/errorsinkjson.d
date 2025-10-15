/**
 * JSON error sink — outputs diagnostics in JSON format.
 *
 * Copyright:
 *  Copyright (C) 1999-2025 by The D Language Foundation
 * License:
 *  $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:
 *  SAoC Project (Error message improvements and LSP integration)
 */

module dmd.errorsinkjson;

import core.stdc.stdio;
import core.stdc.stdarg;
import dmd.errorsink : ErrorSink;
import dmd.location;

/**
 * ErrorSinkJson serializes diagnostics into a JSON array and writes to stdout.
 */
class ErrorSinkJson : ErrorSink
{
    import core.stdc.stdio;
    import core.stdc.stdarg;
  
  nothrow:

    extern(C++) override void verror(Loc loc, const(char)* format, va_list ap)
    {
        printJSONObject("error",loc,format,ap);
    }

    extern(C++) override void verrorSupplemental(Loc loc, const(char)* format, va_list ap)
    {
    }

    extern(C++) override void vwarning(Loc loc, const(char)* format, va_list ap)
    {
        printJSONObject("warning",loc,format,ap);
    }

    extern(C++) override void vwarningSupplemental(Loc loc, const(char)* format, va_list ap)
    {
    }

    extern(C++) override void vdeprecation(Loc loc, const(char)* format, va_list ap)
    {
        printJSONObject("deprecation",loc,format,ap);
    }

    extern(C++) override void vdeprecationSupplemental(Loc loc, const(char)* format, va_list ap)
    {
    }

    extern(C++) override void vmessage(Loc loc, const(char)* format, va_list ap)
    {
        printJSONObject("message",loc,format,ap);
    }

    private void printJSONObject(const(char)* type, Loc loc, const(char)* format, va_list ap) @system nothrow
    {
        const(char)* filename = null;
        uint line = 0;
        uint column = 0;
        if(loc.filename !is null)
        {
            filename = loc.filename;
            line = loc.linnum;
            column = loc.charnum;
        }
        fputc('{',stdout);
        fprintf(stdout, "\"type\":\"%s\",", type);
        fprintf(stdout, "\"file\":\"%s\",", filename ? filename : "");
        fprintf(stdout, "\"line\":%u,", line);
        fprintf(stdout, "\"column\":%u,", column);
        fprintf(stdout, "\"message\":\"");
        vfprintf(stdout, format, ap);
        fputs("}\n", stdout);
    }
}

unittest
{
    import core.stdc.stdio;
    import core.stdc.string : strcmp;

    auto sink = new ErrorSinkJSON();

    Loc loc;
    loc.filename = "main.d".ptr;
    loc.linnum = 1;
    loc.charnum = 2;

    sink.verror(loc, "Test error %d", 42);
   
    va_list ap;
    va_start(ap, "unused"); // dummy for demonstration
    sink.verror(loc, "Undefined variable: %s", ap); // would print directly
    va_end(ap);
}
