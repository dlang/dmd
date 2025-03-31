/**
 * Functions for raising errors.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/errors.d, _errors.d)
 * Documentation:  https://dlang.org/phobos/dmd_errors.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/errors.d
 */

module dmd.errors;

public import core.stdc.stdarg;
public import dmd.root.string: fTuple;
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
import dmd.root.filename;
import dmd.sarif;

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

/********************************
 * Represents a diagnostic message generated during compilation, such as errors,
 * warnings, or other messages.
 */
struct Diagnostic
{
    SourceLoc loc; // The location in the source code where the diagnostic was generated (includes file, line, and column).
    string message; // The text of the diagnostic message, describing the issue.
    ErrorKind kind; // The type of diagnostic, indicating whether it is an error, warning, deprecation, etc.
}

__gshared Diagnostic[] diagnostics = [];

/***************************
 * Error message sink for D compiler.
 */
class ErrorSinkCompiler : ErrorSink
{
  nothrow:
  extern (C++):
  override:

    void verror(Loc loc, const(char)* format, va_list ap)
    {
        verrorReport(loc, format, ap, ErrorKind.error);
    }

    void verrorSupplemental(Loc loc, const(char)* format, va_list ap)
    {
        verrorReportSupplemental(loc, format, ap, ErrorKind.error);
    }

    void vwarning(Loc loc, const(char)* format, va_list ap)
    {
        verrorReport(loc, format, ap, ErrorKind.warning);
    }

    void vwarningSupplemental(Loc loc, const(char)* format, va_list ap)
    {
        verrorReportSupplemental(loc, format, ap, ErrorKind.warning);
    }

    void vdeprecation(Loc loc, const(char)* format, va_list ap)
    {
        verrorReport(loc, format, ap, ErrorKind.deprecation);
    }

    void vdeprecationSupplemental(Loc loc, const(char)* format, va_list ap)
    {
        verrorReportSupplemental(loc, format, ap, ErrorKind.deprecation);
    }

    void vmessage(Loc loc, const(char)* format, va_list ap)
    {
        verrorReport(loc, format, ap, ErrorKind.message);
    }

    void plugSink()
    {
        // Exit if there are no collected diagnostics
        if (!diagnostics.length) return;

        // Generate the SARIF report with the current diagnostics
        generateSarifReport(false);

        // Clear diagnostics after generating the report
        diagnostics.length = 0;
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
    private extern (C++) void noop(Loc loc, const(char)* format, ...) {}
else
    pragma(printf) private extern (C++) void noop(Loc loc, const(char)* format, ...) {}


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
    extern (C++) void error(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void error(Loc loc, const(char)* format, ...)
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
        const loc = SourceLoc(filename.toDString, linnum, charnum);
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
    {
        const loc = SourceLoc(filename.toDString, linnum, charnum);
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }

/// Callback for when the backend wants to report an error
extern(C++) void errorBackend(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
{
    const loc = SourceLoc(filename.toDString, linnum, charnum);
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
    extern (C++) void errorSupplemental(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.error);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void errorSupplemental(Loc loc, const(char)* format, ...)
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
    extern (C++) void warning(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void warning(Loc loc, const(char)* format, ...)
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
    extern (C++) void warningSupplemental(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.warning);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void warningSupplemental(Loc loc, const(char)* format, ...)
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
    extern (C++) void deprecation(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void deprecation(Loc loc, const(char)* format, ...)
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
    extern (C++) void deprecationSupplemental(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReportSupplemental(loc, format, ap, ErrorKind.deprecation);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void deprecationSupplemental(Loc loc, const(char)* format, ...)
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
    extern (C++) void message(Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorReport(loc, format, ap, ErrorKind.message);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void message(Loc loc, const(char)* format, ...)
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
alias DiagnosticHandler = bool delegate(const ref SourceLoc location, Color headerColor, const(char)* header, const(char)* messageFormat, va_list args, const(char)* prefix1, const(char)* prefix2);

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
    this(const ref SourceLoc loc, const ErrorKind kind, const(char)* p1 = null, const(char)* p2 = null) @safe @nogc pure nothrow
    {
        this.loc = loc;
        this.p1 = p1;
        this.p2 = p2;
        this.kind = kind;
    }

    const SourceLoc loc;              // location of error
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
private extern(C++) void verrorReport(Loc loc, const(char)* format, va_list ap, ErrorKind kind, const(char)* p1 = null, const(char)* p2 = null)
{
    return verrorReport(loc.SourceLoc, format, ap, kind, p1, p2);
}

/// ditto
private extern(C++) void verrorReport(const SourceLoc loc, const(char)* format, va_list ap, ErrorKind kind, const(char)* p1 = null, const(char)* p2 = null)
{
    auto info = ErrorInfo(loc, kind, p1, p2);

    final switch (info.kind)
    {
    case ErrorKind.error:
        global.errors++;
        if (!global.gag)
        {
            info.headerColor = Classification.error;
            if (global.params.v.messageStyle == MessageStyle.sarif)
            {
                addSarifDiagnostic(loc, format, ap, kind);
                return;
            }
            verrorPrint(format, ap, info);
            if (global.params.v.errorLimit && global.errors >= global.params.v.errorLimit)
            {
                fprintf(stderr, "error limit (%d) reached, use `-verrors=0` to show all\n", global.params.v.errorLimit);
                fatal(); // moderate blizzard of cascading messages
            }
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
        return;

    case ErrorKind.deprecation:
        if (global.params.useDeprecated == DiagnosticReporting.error)
            goto case ErrorKind.error;
        else if (global.params.useDeprecated == DiagnosticReporting.inform)
        {
            if (!global.gag)
            {
                global.deprecations++;
                if (global.params.v.errorLimit == 0 || global.deprecations <= global.params.v.errorLimit)
                {
                    info.headerColor = Classification.deprecation;
                    if (global.params.v.messageStyle == MessageStyle.sarif)
                    {
                        addSarifDiagnostic(loc, format, ap, kind);
                        return;
                    }
                    verrorPrint(format, ap, info);
                }
            }
            else
            {
                global.gaggedWarnings++;
            }
        }
        return;

    case ErrorKind.warning:
        if (global.params.useWarnings != DiagnosticReporting.off)
        {
            if (!global.gag)
            {
                info.headerColor = Classification.warning;
                if (global.params.v.messageStyle == MessageStyle.sarif)
                {
                    addSarifDiagnostic(loc, format, ap, kind);
                    return;
                }
                verrorPrint(format, ap, info);
                if (global.params.useWarnings == DiagnosticReporting.error)
                    global.warnings++;
            }
            else
            {
                global.gaggedWarnings++;
            }
        }
        return;

    case ErrorKind.tip:
        if (!global.gag)
        {
            info.headerColor = Classification.tip;
            if (global.params.v.messageStyle == MessageStyle.sarif)
            {
                addSarifDiagnostic(loc, format, ap, kind);
                return;
            }
            verrorPrint(format, ap, info);
        }
        return;

    case ErrorKind.message:
        OutBuffer tmp;
        writeSourceLoc(tmp, info.loc, Loc.showColumns, Loc.messageStyle);
        if (tmp.length)
            fprintf(stdout, "%s: ", tmp.extractChars());

        tmp.reset();
        tmp.vprintf(format, ap);
        fputs(tmp.peekChars(), stdout);
        fputc('\n', stdout);
        fflush(stdout);     // ensure it gets written out in case of compiler aborts
        if (global.params.v.messageStyle == MessageStyle.sarif)
        {
            addSarifDiagnostic(loc, format, ap, kind);
            return;
        }
        return;
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
private extern(C++) void verrorReportSupplemental(Loc loc, const(char)* format, va_list ap, ErrorKind kind)
{
    return verrorReportSupplemental(loc.SourceLoc, format, ap, kind);
}

/// ditto
private extern(C++) void verrorReportSupplemental(const SourceLoc loc, const(char)* format, va_list ap, ErrorKind kind)
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
        return;

    case ErrorKind.deprecation:
        if (global.params.useDeprecated == DiagnosticReporting.error)
            goto case ErrorKind.error;
        else if (global.params.useDeprecated == DiagnosticReporting.inform && !global.gag)
        {
            if (global.params.v.errorLimit == 0 || global.deprecations <= global.params.v.errorLimit)
            {
                info.headerColor = Classification.deprecation;
                verrorPrint(format, ap, info);
            }
        }
        return;

    case ErrorKind.warning:
        if (global.params.useWarnings != DiagnosticReporting.off && !global.gag)
        {
            info.headerColor = Classification.warning;
            verrorPrint(format, ap, info);
        }
        return;

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

    if (diagnosticHandler !is null)
    {
        if (diagnosticHandler(info.loc, info.headerColor, header, format, ap, info.p1, info.p2))
            return;
    }

    if (global.params.v.showGaggedErrors && global.gag)
        fprintf(stderr, "(spec:%d) ", global.gag);
    auto con = cast(Console) global.console;

    OutBuffer tmp;
    writeSourceLoc(tmp, info.loc, Loc.showColumns, Loc.messageStyle);
    const locString = tmp.extractSlice();
    if (con)
        con.setColorBright(true);
    if (locString.length)
    {
        fprintf(stderr, "%.*s: ", cast(int) locString.length, locString.ptr);
    }
    if (con)
        con.setColor(info.headerColor);
    fputs(header, stderr);
    if (con)
        con.resetColor();

    tmp.reset();
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
    {
        unescapeBackticks(tmp);
        fputs(tmp.peekChars(), stderr);
    }
    fputc('\n', stderr);

    __gshared SourceLoc old_loc;
    auto loc = info.loc;
    if (global.params.v.errorPrintMode != ErrorPrintMode.simpleError &&
        // ignore supplemental messages with same loc
        (loc != old_loc || !info.supplemental) &&
        // ignore invalid files
        loc != SourceLoc.init &&
        // ignore mixins for now
        !loc.filename.startsWith(".d-mixin-") &&
        !global.params.mixinOut.doOutput)
    {
        import dmd.root.filename : FileName;
        if (auto text = cast(const(char[])) global.fileManager.getFileContents(FileName(loc.filename)))
        {
            tmp.reset();
            printErrorLineContext(tmp, text, loc.fileOffset);
            fputs(tmp.peekChars(), stderr);
        }
    }
    old_loc = loc;
    fflush(stderr);     // ensure it gets written out in case of compiler aborts
}

// Given an error happening in source code `text`, at index `offset`, print the offending line
// and a caret pointing to the error into `buf`
private void printErrorLineContext(ref OutBuffer buf, const(char)[] text, size_t offset) @safe
{
    import dmd.root.utf : utf_decodeChar;

    if (offset >= text.length)
        return; // Out of bounds (can happen in pre-processed C files currently)

    // Scan backwards for beginning of line
    size_t s = offset;
    while (s > 0 && text[s - 1] != '\n')
        s--;

    const line = text[s .. $];
    const byteColumn = offset - s; // column as reported in the error message (byte offset)
    enum tabWidth = 4;

    // The number of column bytes and the number of display columns
    // occupied by a character are not the same for non-ASCII charaters.
    // https://issues.dlang.org/show_bug.cgi?id=21849
    size_t currentColumn = 0;
    size_t caretColumn = 0; // actual display column taking into account tabs and unicode characters
    for (size_t i = 0; i < line.length; )
    {
        dchar u;
        const start = i;
        const msg = utf_decodeChar(line, i, u);
        assert(msg is null, msg);
        if (u == '\t')
        {
            // How many spaces until column is the next multiple of tabWidth
            const equivalentSpaces = tabWidth - (currentColumn % tabWidth);
            foreach (j; 0 .. equivalentSpaces)
                buf.writeByte(' ');
            currentColumn += equivalentSpaces;
        }
        else if (u == '\r' || u == '\n')
            break;
        else
        {
            buf.writestring(line[start .. i]);
            currentColumn++;
        }
        if (i <= byteColumn)
            caretColumn = currentColumn;
    }
    buf.writeByte('\n');

    foreach (i; 0 .. caretColumn)
        buf.writeByte(' ');

    buf.writeByte('^');
    buf.writeByte('\n');
}

unittest
{
    OutBuffer buf;
    printErrorLineContext(buf, "int ɷ = 3;", 9);
    assert(buf.peekSlice() ==
        "int ɷ = 3;\n"~
        "        ^\n"
    );
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

    global.plugErrorSinks();

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
 * Double backticks are replaced by a single backtick without coloring.
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
                // A double backtick means it's part of the content, don't color
                if (i + 1 < buf.length && buf[i + 1] == '`')
                {
                    buf.remove(i, 1);
                    continue;
                }

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

/// Replace double backticks in `buf` with a single backtick
void unescapeBackticks(ref OutBuffer buf)
{
    for (size_t i = 0; i + 1 < buf.length; ++i)
    {
        if (buf[i] == '`' && buf[i + 1] == '`')
            buf.remove(i, 1);
    }
}

unittest
{
    OutBuffer buf;
    buf.writestring("x````");
    unescapeBackticks(buf);
    assert(buf.extractSlice() == "x``");

    buf.writestring("x````");
    colorSyntaxHighlight(buf);
    assert(buf.extractSlice() == "x``");
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
        if (c != HIGHLIGHT.Escape)
        {
            fputc(c, con.fp);
            continue;
        }

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
}
