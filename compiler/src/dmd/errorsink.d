/**
 * Provides an abstraction for what to do with error messages.
 *
 * Copyright:   Copyright (C) 2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/errorsink.d, _errorsink.d)
 * Documentation:  https://dlang.org/phobos/dmd_errorsink.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/errorsink.d
 */

module dmd.errorsink;

import dmd.location;

/// Constants used to map compiler warnings to a specific flag.
enum DiagnosticFlag
{
    none,
    cxxcompat,
    conversion,
    dangling_else,
    ddoc,
    discarded,
    foreach_reverse_aa,
    inline_,
    obsolete,
    pragma_,
    shadow,
    unreachable,
}

/***************************************
 * Where error/warning/deprecation messages go.
 */
abstract class ErrorSink
{
  nothrow:
  extern (C++):

    void error(const ref Loc loc, const(char)* format, ...);

    void errorSupplemental(const ref Loc loc, const(char)* format, ...);

    void warning(uint flag, const ref Loc loc, const(char)* format, ...);

    void warningSupplemental(uint flag, const ref Loc loc, const(char)* format, ...);

    void message(const ref Loc loc, const(char)* format, ...);

    void deprecation(const ref Loc loc, const(char)* format, ...);

    void deprecationSupplemental(const ref Loc loc, const(char)* format, ...);
}

/*****************************************
 * Just ignores the messages.
 */
class ErrorSinkNull : ErrorSink
{
  nothrow:
  extern (C++):
  override:

    void error(const ref Loc loc, const(char)* format, ...) { }

    void errorSupplemental(const ref Loc loc, const(char)* format, ...) { }

    void warning(uint flag, const ref Loc loc, const(char)* format, ...) { }

    void warningSupplemental(uint flag, const ref Loc loc, const(char)* format, ...) { }

    void message(const ref Loc loc, const(char)* format, ...) { }

    void deprecation(const ref Loc loc, const(char)* format, ...) { }

    void deprecationSupplemental(const ref Loc loc, const(char)* format, ...) { }
}

/*****************************************
 * Simplest implementation, just sends messages to stderr.
 * See also: ErrorSinkCompiler.
 */
class ErrorSinkStderr : ErrorSink
{
    import core.stdc.stdio;
    import core.stdc.stdarg;

  nothrow:
  extern (C++):
  override:

    void error(const ref Loc loc, const(char)* format, ...)
    {
        fputs("Error: ", stderr);
        const p = loc.toChars();
        if (*p)
        {
            fprintf(stderr, "%s: ", p);
            //mem.xfree(cast(void*)p); // loc should provide the free()
        }

        va_list ap;
        va_start(ap, format);
        vfprintf(stderr, format, ap);
        fputc('\n', stderr);
        va_end(ap);
    }

    void errorSupplemental(const ref Loc loc, const(char)* format, ...) { }

    void warning(uint flag, const ref Loc loc, const(char)* format, ...)
    {
        fputs("Warning: ", stderr);
        const p = loc.toChars();
        if (*p)
        {
            fprintf(stderr, "%s: ", p);
            //mem.xfree(cast(void*)p); // loc should provide the free()
        }

        va_list ap;
        va_start(ap, format);
        vfprintf(stderr, format, ap);
        fputc('\n', stderr);
        va_end(ap);
    }

    void warningSupplemental(uint flag, const ref Loc loc, const(char)* format, ...) { }

    void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        fputs("Deprecation: ", stderr);
        const p = loc.toChars();
        if (*p)
        {
            fprintf(stderr, "%s: ", p);
            //mem.xfree(cast(void*)p); // loc should provide the free()
        }

        va_list ap;
        va_start(ap, format);
        vfprintf(stderr, format, ap);
        fputc('\n', stderr);
        va_end(ap);
    }

    void message(const ref Loc loc, const(char)* format, ...)
    {
        const p = loc.toChars();
        if (*p)
        {
            fprintf(stderr, "%s: ", p);
            //mem.xfree(cast(void*)p); // loc should provide the free()
        }

        va_list ap;
        va_start(ap, format);
        vfprintf(stderr, format, ap);
        fputc('\n', stderr);
        va_end(ap);
    }

    void deprecationSupplemental(const ref Loc loc, const(char)* format, ...) { }
}

/*****************************************
 * Cache messages to an OutBuffer.
 */
class ErrorSinkBuffer : ErrorSink
{
    import core.stdc.stdarg;
    import dmd.common.outbuffer;
    OutBuffer buffer;

  nothrow:
  extern (C++):
  override:

    enum print = q{
        if (buffer.length)
            buffer.writenl();

        const p = loc.toChars();
        if (*p)
        {
            buffer.writestring(p);
            //mem.xfree(cast(void*)p); // loc should provide the free()
            buffer.write(": ");
        }
        buffer.write(prefix);

        va_list ap;
        va_start(ap, format);
        buffer.vprintf(format, ap);
        va_end(ap);
    };

    void error(const ref Loc loc, const(char)* format, ...)
    {
        enum prefix = "Error: ";
        mixin(print);
    }

    void errorSupplemental(const ref Loc loc, const(char)* format, ...) { }

    void warning(uint flag, const ref Loc loc, const(char)* format, ...)
    {
        enum prefix = "Warning: ";
        mixin(print);
    }

    void warningSupplemental(uint flag, const ref Loc loc, const(char)* format, ...) { }

    void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        enum prefix = "Deprecation: ";
        mixin(print);
    }

    void message(const ref Loc loc, const(char)* format, ...)
    {
        enum prefix = "";
        mixin(print);
    }

    void deprecationSupplemental(const ref Loc loc, const(char)* format, ...) { }
}
