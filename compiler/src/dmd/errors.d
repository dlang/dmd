/**
 * Functions for raising errors.
 *
 * Copyright:   Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/errors.d, _errors.d)
 * Documentation:  https://dlang.org/phobos/dmd_errors.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/errors.d
 */

module dmd.errors;

public import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import dmd.errorsink;
import dmd.globals;
import dmd.location;
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.root.string;
import dmd.console;

nothrow:

/// Constants used to discriminate kinds of error messages.
enum ErrorKind
{
    warning,
    deprecation,
    error,
    tip,
    message,
}

/***************************
 * Error message sink for D compiler.
 */
class ErrorSinkCompiler : ErrorSink
{
  nothrow:
  extern (C++):
  override:

    void error(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }

    void errorSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }

    void warning(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }

    void warningSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }

    void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }

    void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }

    void message(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.message);
        va_end(ap);
    }
}


/**
 * Color highlighting to classify messages
 */
enum Classification : Color
{
    error = Color.brightRed,          /// for errors
    gagged = Color.brightBlue,        /// for gagged errors
    warning = Color.brightYellow,     /// for warnings
    deprecation = Color.brightCyan,   /// for deprecations
    tip = Color.brightGreen,          /// for tip messages
}


static if (__VERSION__ < 2092)
    private extern (C++) void noop(const ref Loc loc, const(char)* format, ...) {}
else
    pragma(printf) private extern (C++) void noop(const ref Loc loc, const(char)* format, ...) {}


package auto previewErrorFunc(bool isDeprecated, FeatureState featureState) @safe @nogc pure nothrow
{
    with (FeatureState) final switch (featureState)
    {
        case enabled:
            return &error;

        case disabled:
            return &noop;

        case default_:
            return isDeprecated ? &noop : &deprecation;
    }
}

package auto previewSupplementalFunc(bool isDeprecated, FeatureState featureState) @safe @nogc pure nothrow
{
    with (FeatureState) final switch (featureState)
    {
        case enabled:
            return &errorSupplemental;

        case disabled:
            return &noop;

        case default_:
            return isDeprecated ? &noop : &deprecationSupplemental;
    }
}


/**
 * Print an error message, increasing the global error count.
 * Params:
 *      loc    = location of error
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void error(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void error(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }

/**
 * Same as above, but takes a filename and line information arguments as separate parameters.
 * Params:
 *      filename = source file of error
 *      linnum   = line in the source file
 *      charnum  = column number on the line
 *      format   = printf-style format specification
 *      ...      = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
    {
        const loc = Loc(filename, linnum, charnum);
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
    {
        const loc = Loc(filename, linnum, charnum);
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }

/**
 * Print additional details about an error message.
 * Doesn't increase the error count or print an additional error prefix.
 * Params:
 *      loc    = location of error
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void errorSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void errorSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }

/**
 * Print a warning message, increasing the global warning count.
 * Params:
 *      loc    = location of warning
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void warning(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void warning(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }

/**
 * Print additional details about a warning message.
 * Doesn't increase the warning count or print an additional warning prefix.
 * Params:
 *      loc    = location of warning
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void warningSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void warningSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }

/**
 * Print a deprecation message, may increase the global warning or error count
 * depending on whether deprecations are ignored.
 * Params:
 *      loc    = location of deprecation
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }

/**
 * Print additional details about a deprecation message.
 * Doesn't increase the error count, or print an additional deprecation prefix.
 * Params:
 *      loc    = location of deprecation
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }

/**
 * Print a verbose message.
 * Doesn't prefix or highlight messages.
 * Params:
 *      loc    = location of message
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void message(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.message);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void message(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.message);
        va_end(ap);
    }

/**
 * Same as above, but doesn't take a location argument.
 * Params:
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void message(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(Loc.initial, format, ap, ErrorKind.message);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void message(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(Loc.initial, format, ap, ErrorKind.message);
        va_end(ap);
    }

/**
 * The type of the diagnostic handler
 * see verrorReport for arguments
 * Returns: true if error handling is done, false to continue printing to stderr
 */
alias DiagnosticHandler = bool delegate(const ref Loc location, Color headerColor, const(char)* header, const(char)* messageFormat, va_list args, const(char)* prefix1, const(char)* prefix2);

/**
 * The diagnostic handler.
 * If non-null it will be called for every diagnostic message issued by the compiler.
 * If it returns false, the message will be printed to stderr as usual.
 */
__gshared DiagnosticHandler diagnosticHandler;

/**
 * Print a tip message with the prefix and highlighting.
 * Params:
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void tip(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(Loc.initial, format, ap, ErrorKind.tip);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void tip(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(Loc.initial, format, ap, ErrorKind.tip);
        va_end(ap);
    }


// Encapsulates an error as described by its location, format message, and kind.
private struct ErrorInfo
{
    this(const ref Loc loc, const ErrorKind kind, const(char)* p1 = null, const(char)* p2 = null) @safe @nogc pure nothrow
    {
        this.loc = loc;
        this.p1 = p1;
        this.p2 = p2;
        this.kind = kind;
    }

    const Loc loc;              // location of error
    Classification headerColor; // color to set `header` output to
    const(char)* p1;            // additional message prefix
    const(char)* p2;            // additional message prefix
    const ErrorKind kind;       // kind of error being printed
    bool supplemental;          // true if supplemental error
}

/**
 * Implements $(D error), $(D warning), $(D deprecation), $(D message), and
 * $(D tip). Report a diagnostic error, taking a va_list parameter, and
 * optionally additional message prefixes. Whether the message gets printed
 * depends on runtime values of DiagnosticReporting and global gagging.
 * Params:
 *      loc         = location of error
 *      format      = printf-style format specification
 *      ap          = printf-style variadic arguments
 *      kind        = kind of error being printed
 *      p1          = additional message prefix
 *      p2          = additional message prefix
 */
extern (C++) void verrorReport(const ref Loc loc, const(char)* format, va_list ap, ErrorKind kind, const(char)* p1 = null, const(char)* p2 = null)
{
    auto info = ErrorInfo(loc, kind, p1, p2);
    final switch (info.kind)
    {
    case ErrorKind.error:
        global.errors++;
        if (!global.gag)
        {
            info.headerColor = Classification.error;
            verrorPrint(format, ap, info);
            if (global.params.v.errorLimit && global.errors >= global.params.v.errorLimit)
                fatal(); // moderate blizzard of cascading messages
        }
        else
        {
            if (global.params.v.showGaggedErrors)
            {
                info.headerColor = Classification.gagged;
                verrorPrint(format, ap, info);
            }
            global.gaggedErrors++;
        }
        break;

    case ErrorKind.deprecation:
        if (global.params.useDeprecated == DiagnosticReporting.error)
            goto case ErrorKind.error;
        else if (global.params.useDeprecated == DiagnosticReporting.inform)
        {
            if (!global.gag)
            {
                info.headerColor = Classification.deprecation;
                verrorPrint(format, ap, info);
            }
            else
            {
                global.gaggedWarnings++;
            }
        }
        break;

    case ErrorKind.warning:
        if (global.params.warnings != DiagnosticReporting.off)
        {
            if (!global.gag)
            {
                info.headerColor = Classification.warning;
                verrorPrint(format, ap, info);
                if (global.params.warnings == DiagnosticReporting.error)
                    global.warnings++;
            }
            else
            {
                global.gaggedWarnings++;
            }
        }
        break;

    case ErrorKind.tip:
        if (!global.gag)
        {
            info.headerColor = Classification.tip;
            verrorPrint(format, ap, info);
        }
        break;

    case ErrorKind.message:
        const p = info.loc.toChars();
        if (*p)
        {
            fprintf(stdout, "%s: ", p);
            mem.xfree(cast(void*)p);
        }
        OutBuffer tmp;
        tmp.vprintf(format, ap);
        fputs(tmp.peekChars(), stdout);
        fputc('\n', stdout);
        fflush(stdout);     // ensure it gets written out in case of compiler aborts
        break;
    }
}

/**
 * Implements $(D errorSupplemental), $(D warningSupplemental), and
 * $(D deprecationSupplemental). Report an addition diagnostic error, taking a
 * va_list parameter. Whether the message gets printed depends on runtime
 * values of DiagnosticReporting and global gagging.
 * Params:
 *      loc         = location of error
 *      format      = printf-style format specification
 *      ap          = printf-style variadic arguments
 *      kind        = kind of error being printed
 */
extern (C++) void verrorReportSupplemental(const ref Loc loc, const(char)* format, va_list ap, ErrorKind kind)
{
    auto info = ErrorInfo(loc, kind);
    info.supplemental = true;
    switch (info.kind)
    {
    case ErrorKind.error:
        if (global.gag)
        {
            if (!global.params.v.showGaggedErrors)
                return;
            info.headerColor = Classification.gagged;
        }
        else
            info.headerColor = Classification.error;
        verrorPrint(format, ap, info);
        break;

    case ErrorKind.deprecation:
        if (global.params.useDeprecated == DiagnosticReporting.error)
            goto case ErrorKind.error;
        else if (global.params.useDeprecated == DiagnosticReporting.inform && !global.gag)
        {
            info.headerColor = Classification.deprecation;
            verrorPrint(format, ap, info);
        }
        break;

    case ErrorKind.warning:
        if (global.params.warnings != DiagnosticReporting.off && !global.gag)
        {
            info.headerColor = Classification.warning;
            verrorPrint(format, ap, info);
        }
        break;

    default:
        assert(false, "internal error: unhandled kind in error report");
    }
}

/**
 * Just print to stderr, doesn't care about gagging.
 * (format,ap) text within backticks gets syntax highlighted.
 * Params:
 *      format  = printf-style format specification
 *      ap      = printf-style variadic arguments
 *      info    = context of error
 */
private void verrorPrint(const(char)* format, va_list ap, ref ErrorInfo info)
{
    const(char)* header;    // title of error message
    if (info.supplemental)
        header = "       ";
    else
    {
        final switch (info.kind)
        {
            case ErrorKind.error:       header = "Error: "; break;
            case ErrorKind.deprecation: header = "Deprecation: "; break;
            case ErrorKind.warning:     header = "Warning: "; break;
            case ErrorKind.tip:         header = "  Tip: "; break;
            case ErrorKind.message:     assert(0);
        }
    }

    if (diagnosticHandler !is null &&
        diagnosticHandler(info.loc, info.headerColor, header, format, ap, info.p1, info.p2))
        return;

    if (global.params.v.showGaggedErrors && global.gag)
        fprintf(stderr, "(spec:%d) ", global.gag);
    Console con = cast(Console) global.console;
    const p = info.loc.toChars();
    if (con)
        con.setColorBright(true);
    if (*p)
    {
        fprintf(stderr, "%s: ", p);
        mem.xfree(cast(void*)p);
    }
    if (con)
        con.setColor(info.headerColor);
    fputs(header, stderr);
    if (con)
        con.resetColor();
    OutBuffer tmp;
    if (info.p1)
    {
        tmp.writestring(info.p1);
        tmp.writestring(" ");
    }
    if (info.p2)
    {
        tmp.writestring(info.p2);
        tmp.writestring(" ");
    }
    tmp.vprintf(format, ap);

    if (con && strchr(tmp.peekChars(), '`'))
    {
        colorSyntaxHighlight(tmp);
        writeHighlights(con, tmp);
    }
    else
        fputs(tmp.peekChars(), stderr);
    fputc('\n', stderr);

    __gshared Loc old_loc;
    Loc loc = info.loc;
    if (global.params.v.printErrorContext &&
        // ignore supplemental messages with same loc
        (loc != old_loc || !info.supplemental) &&
        // ignore invalid files
        loc != Loc.initial &&
        // ignore mixins for now
        !loc.filename.strstr(".d-mixin-") &&
        !global.params.mixinOut.doOutput)
    {
        import dmd.root.filename : FileName;
        const fileName = FileName(loc.filename.toDString);
        if (auto file = global.fileManager.lookup(fileName))
        {
            const(char)[][] lines = global.fileManager.getLines(fileName);
            if (loc.linnum - 1 < lines.length)
            {
                auto line = lines[loc.linnum - 1];
                if (loc.charnum < line.length)
                {
                    fprintf(stderr, "%.*s\n", cast(int)line.length, line.ptr);
                    // The number of column bytes and the number of display columns
                    // occupied by a character are not the same for non-ASCII charaters.
                    // https://issues.dlang.org/show_bug.cgi?id=21849
                    size_t c = 0;
                    while (c < loc.charnum - 1)
                    {
                        import dmd.root.utf : utf_decodeChar;
                        dchar u;
                        const msg = utf_decodeChar(line, c, u);
                        assert(msg is null, msg);
                        fputc(' ', stderr);
                    }
                    fputc('^', stderr);
                    fputc('\n', stderr);
                }
            }
        }
    }
    old_loc = loc;
    fflush(stderr);     // ensure it gets written out in case of compiler aborts
}

/**
 * The type of the fatal error handler
 * Returns: true if error handling is done, false to do exit(EXIT_FAILURE)
 */
alias FatalErrorHandler = bool delegate();

/**
 * The fatal error handler.
 * If non-null it will be called for every fatal() call issued by the compiler.
 */
__gshared FatalErrorHandler fatalErrorHandler;

/**
 * Call this after printing out fatal error messages to clean up and exit the
 * compiler. You can also set a fatalErrorHandler to override this behaviour.
 */
extern (C++) void fatal()
{
    if (fatalErrorHandler && fatalErrorHandler())
        return;

    exit(EXIT_FAILURE);
}

/**
 * Try to stop forgetting to remove the breakpoints from
 * release builds.
 */
extern (C++) void halt() @safe
{
    assert(0);
}

/**
 * Scan characters in `buf`. Assume text enclosed by `...`
 * is D source code, and color syntax highlight it.
 * Modify contents of `buf` with highlighted result.
 * Many parallels to ddoc.highlightText().
 * Params:
 *      buf = text containing `...` code to highlight
 */
private void colorSyntaxHighlight(ref OutBuffer buf)
{
    //printf("colorSyntaxHighlight('%.*s')\n", cast(int)buf.length, buf[].ptr);
    bool inBacktick = false;
    size_t iCodeStart = 0;
    size_t offset = 0;
    for (size_t i = offset; i < buf.length; ++i)
    {
        char c = buf[i];
        switch (c)
        {
            case '`':
                if (inBacktick)
                {
                    inBacktick = false;
                    OutBuffer codebuf;
                    codebuf.write(buf[iCodeStart .. i]);
                    codebuf.writeByte(0);
                    // escape the contents, but do not perform highlighting except for DDOC_PSYMBOL
                    colorHighlightCode(codebuf);
                    buf.remove(iCodeStart, i - iCodeStart);
                    immutable pre = "";
                    i = buf.insert(iCodeStart, pre);
                    i = buf.insert(i, codebuf[]);
                    break;
                }
                inBacktick = true;
                iCodeStart = i + 1;
                break;

            default:
                break;
        }
    }
}


/**
 * Embed these highlighting commands in the text stream.
 * HIGHLIGHT.Escape indicates a Color follows.
 */
enum HIGHLIGHT : ubyte
{
    Default    = Color.black,           // back to whatever the console is set at
    Escape     = '\xFF',                // highlight Color follows
    Identifier = Color.white,
    Keyword    = Color.white,
    Literal    = Color.white,
    Comment    = Color.darkGray,
    Other      = Color.cyan,           // other tokens
}

/**
 * Highlight code for CODE section.
 * Rewrite the contents of `buf` with embedded highlights.
 * Analogous to doc.highlightCode2()
 */

private void colorHighlightCode(ref OutBuffer buf)
{
    import dmd.lexer;
    import dmd.tokens;

    __gshared int nested;
    if (nested)
    {
        // Should never happen, but don't infinitely recurse if it does
        --nested;
        return;
    }
    ++nested;

    scope Lexer lex = new Lexer(null, cast(char*)buf[].ptr, 0, buf.length - 1, 0, 1, global.errorSinkNull, &global.compileEnv);
    OutBuffer res;
    const(char)* lastp = cast(char*)buf[].ptr;
    //printf("colorHighlightCode('%.*s')\n", cast(int)(buf.length - 1), buf[].ptr);
    res.reserve(buf.length);
    res.writeByte(HIGHLIGHT.Escape);
    res.writeByte(HIGHLIGHT.Other);
    while (1)
    {
        Token tok;
        lex.scan(&tok);
        res.writestring(lastp[0 .. tok.ptr - lastp]);
        HIGHLIGHT highlight;
        switch (tok.value)
        {
        case TOK.identifier:
            highlight = HIGHLIGHT.Identifier;
            break;
        case TOK.comment:
            highlight = HIGHLIGHT.Comment;
            break;
        case TOK.int32Literal:
            ..
        case TOK.dcharLiteral:
        case TOK.string_:
            highlight = HIGHLIGHT.Literal;
            break;
        default:
            if (tok.isKeyword())
                highlight = HIGHLIGHT.Keyword;
            break;
        }
        if (highlight != HIGHLIGHT.Default)
        {
            res.writeByte(HIGHLIGHT.Escape);
            res.writeByte(highlight);
            res.writestring(tok.ptr[0 .. lex.p - tok.ptr]);
            res.writeByte(HIGHLIGHT.Escape);
            res.writeByte(HIGHLIGHT.Other);
        }
        else
            res.writestring(tok.ptr[0 .. lex.p - tok.ptr]);
        if (tok.value == TOK.endOfFile)
            break;
        lastp = lex.p;
    }
    res.writeByte(HIGHLIGHT.Escape);
    res.writeByte(HIGHLIGHT.Default);
    //printf("res = '%.*s'\n", cast(int)buf.length, buf[].ptr);
    buf.setsize(0);
    buf.write(&res);
    --nested;
}

/**
 * Write the buffer contents with embedded highlights to stderr.
 * Params:
 *      buf = highlighted text
 */
private void writeHighlights(Console con, ref const OutBuffer buf)
{
    bool colors;
    scope (exit)
    {
        /* Do not mess up console if highlighting aborts
         */
        if (colors)
            con.resetColor();
    }

    for (size_t i = 0; i < buf.length; ++i)
    {
        const c = buf[i];
        if (c == HIGHLIGHT.Escape)
        {
            const color = buf[++i];
            if (color == HIGHLIGHT.Default)
            {
                con.resetColor();
                colors = false;
            }
            else
            if (color == Color.white)
            {
                con.resetColor();
                con.setColorBright(true);
                colors = true;
            }
            else
            {
                con.setColor(cast(Color)color);
                colors = true;
            }
        }
        else
            fputc(c, con.fp);
    }
}
