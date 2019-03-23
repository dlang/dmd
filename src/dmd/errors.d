/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/errors.d, _errors.d)
 * Documentation:  https://dlang.org/phobos/dmd_errors.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/errors.d
 */

module dmd.errors;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import dmd.globals;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.console;

auto toStringzThen(alias func)(const(char)[] str)
{
    import core.stdc.stdlib: malloc, free;

    if (str.length == 0)
        return func("".ptr);

    char[1024] staticBuffer;
    const newLength = str.length + 1;
    char[] buffer;

    if (str.length >= buffer.length)
        buffer = (cast(char*) malloc(newLength * char.sizeof))[0 .. newLength];
    else
        buffer = staticBuffer[0 .. newLength];

    scope (exit)
    {
        if (&buffer[0] != &staticBuffer[0])
            free(&buffer[0]);
    }

    buffer[0 .. $ - 1] = str;
    buffer[$ - 1] = '\0';

    return func(&buffer[0]);
}

struct Diagnosed(T)
{
    T value;
    DiagnosticSet diagnosticSet;
}

T unwrap(T)(Diagnosed!T diagnosed, ref DiagnosticSet diagnosticSet)
{
    diagnosticSet ~= diagnosed.diagnosticSet;
    return diagnosed.value;
}

T unwrap(alias func, T)(Diagnosed!T diagnosed)
{
    func(diagnosed.diagnosticSet);
    return diagnosed.value;
}

Diagnosed!T diagnosed(T)(T value, DiagnosticSet diagnosticSet)
{
    return Diagnosed!(T)(value, diagnosticSet);
}

auto map(alias func, T)(Diagnosed!T diagnosed)
{
    return .diagnosed(func(diagnosed.value), diagnosed.diagnosticSet);
}

auto chainedMap(alias func, T)(Diagnosed!T diagnosed)
{
    auto diagnosedResult = func(diagnosed.value);
    auto originalSet = diagnosed.diagnosticSet;
    auto resultSet = diagnosedResult.diagnosticSet;

    return .diagnosed(diagnosedResult.value, originalSet ~ resultSet);
}

/// Diagnostic severity.
enum Severity
{
    /// An error occurred.
    error,

    /// A warning occurred.
    warning,

    /// A deprecation occurred.
    deprecation,
}

struct DiagnosticSet
{
    private Diagnostic[] _diagnostics;

    void add(Diagnostic diagnostic) pure nothrow @safe
    {
        _diagnostics ~= diagnostic;
    }

    DiagnosticSet opBinary(string op)(DiagnosticSet set) pure nothrow @safe
    if (op == "~")
    {
        DiagnosticSet newSet;
        newSet ~= this;
        newSet ~= set;

        return newSet;
    }

    DiagnosticSet opOpAssign(string op)(Diagnostic diagnostic) pure nothrow @safe
    if (op == "~")
    {
        _diagnostics ~= diagnostic;
        return this;
    }

    DiagnosticSet opOpAssign(string op)(DiagnosticSet set) pure nothrow @safe
    if (op == "~")
    {
        _diagnostics ~= set._diagnostics;
        return this;
    }

    void addSupplemental(const Diagnostic diagnostic) pure nothrow @safe
    {
        _diagnostics[$ - 1].addSupplementalDiagnostic(diagnostic);
    }

    const(Diagnostic) front() const pure nothrow @nogc @safe
    {
        return _diagnostics[0];
    }

    void popFront() pure nothrow @nogc @safe
    {
        _diagnostics = _diagnostics[1 .. $];
    }

    bool empty() const pure nothrow @nogc @safe
    {
        return _diagnostics.length == 0;
    }

    size_t length() const pure nothrow @nogc @safe
    {
        return _diagnostics.length;
    }

    const(Diagnostic) opIndex(size_t index) const pure nothrow @nogc @safe
    {
        return _diagnostics[index];
    }
}

/// A single diagnostic message.
abstract class Diagnostic
{
    /// The location of where the diagnostic occurred.
    const Loc loc;

    /// The severity of the diagnostic.
    const Severity severity;

    /// The message.
    abstract string message() const nothrow;

    private const(Diagnostic)[] _supplementalDiagnostics;

    this(const ref Loc loc, const Severity severity) pure nothrow @nogc @safe
    {
        this.loc = loc;
        this.severity = severity;
    }

    final const(Diagnostic[]) supplementalDiagnostics() const pure nothrow @nogc @safe
    {
        return _supplementalDiagnostics;
    }

    private final void addSupplementalDiagnostic(const Diagnostic diagnostic) pure nothrow @safe
    in
    {
        assert(diagnostic.severity == severity);
    }
    body
    {
        _supplementalDiagnostics ~= diagnostic;
    }
}

class FormattedDiagnostic(Args...) : Diagnostic
{
    private const string formatString;
    private const Args args;

    this(const ref Loc loc, const Severity severity, const string formatString,
        const Args args) pure nothrow @nogc @safe
    {
        super(loc, severity);
        this.formatString = formatString;
        this.args = args;
    }

    override string message() const nothrow
    {
        OutBuffer buffer;
        formatString.toStringzThen!(str => buffer.printf(str, args));

        return cast(string) buffer.extractSlice();
    }
}

void printDiagnostics(DiagnosticSet set, DiagnosticReporter reporter)
{
    alias DiagnosticFunction = void delegate(
        ref const(Loc) loc, const(char)* format, ...);

    static void printMessage(const Diagnostic diagnostic,
        DiagnosticFunction diagnosticFunc)
    {
        const message = diagnostic.message;

        diagnosticFunc(diagnostic.loc, "%.*s",
            cast(int) message.length, message.ptr);
    }

    static void printSupplementalMessages(const Diagnostic[] diagnostics,
        DiagnosticFunction diagnosticFunc)
    {
        foreach (diagnostic; diagnostics)
            printMessage(diagnostic, diagnosticFunc);
    }

    foreach (diagnostic; set)
    {
        const message = diagnostic.message;

        final switch (diagnostic.severity)
        {
            case Severity.deprecation:
                printMessage(diagnostic, &reporter.deprecation);
                printSupplementalMessages(diagnostic.supplementalDiagnostics,
                    &reporter.deprecationSupplemental);
            break;

            case Severity.error:
                printMessage(diagnostic, &reporter.error);
                printSupplementalMessages(diagnostic.supplementalDiagnostics,
                    &reporter.errorSupplemental);
            break;

            case Severity.warning:
                printMessage(diagnostic, &reporter.warning);
                printSupplementalMessages(diagnostic.supplementalDiagnostics,
                    &reporter.warningSupplemental);
            break;
        }
    }
}

/// Interface for diagnostic reporting.
abstract class DiagnosticReporter
{
    /// Returns: the number of errors that occurred during lexing or parsing.
    abstract int errorCount();

    /// Returns: the number of warnings that occurred during lexing or parsing.
    abstract int warningCount();

    /// Returns: the number of deprecations that occurred during lexing or parsing.
    abstract int deprecationCount();

    /**
    Reports an error message.

    Params:
        loc = Location of error
        format = format string for error
        ... = format string arguments
    */
    final void error(const ref Loc loc, const(char)* format, ...)
    {
        va_list args;
        va_start(args, format);
        error(loc, format, args);
        va_end(args);
    }

    /// ditto
    abstract void error(const ref Loc loc, const(char)* format, va_list args);

    /**
    Reports additional details about an error message.

    Params:
        loc = Location of error
        format = format string for supplemental message
        ... = format string arguments
    */
    final void errorSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list args;
        va_start(args, format);
        errorSupplemental(loc, format, args);
        va_end(args);
    }

    /// ditto
    abstract void errorSupplemental(const ref Loc loc, const(char)* format, va_list);

    /**
    Reports a warning message.

    Params:
        loc = Location of warning
        format = format string for warning
        ... = format string arguments
    */
    final void warning(const ref Loc loc, const(char)* format, ...)
    {
        va_list args;
        va_start(args, format);
        warning(loc, format, args);
        va_end(args);
    }

    /// ditto
    abstract void warning(const ref Loc loc, const(char)* format, va_list args);

    /**
    Reports additional details about a warning message.

    Params:
        loc = Location of warning
        format = format string for supplemental message
        ... = format string arguments
    */
    final void warningSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list args;
        va_start(args, format);
        warningSupplemental(loc, format, args);
        va_end(args);
    }

    /// ditto
    abstract void warningSupplemental(const ref Loc loc, const(char)* format, va_list);

    /**
    Reports a deprecation message.

    Params:
        loc = Location of the deprecation
        format = format string for the deprecation
        ... = format string arguments
    */
    final void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        va_list args;
        va_start(args, format);
        deprecation(loc, format, args);
        va_end(args);
    }

    /// ditto
    abstract void deprecation(const ref Loc loc, const(char)* format, va_list args);

    /**
    Reports additional details about a deprecation message.

    Params:
        loc = Location of deprecation
        format = format string for supplemental message
        ... = format string arguments
    */
    final void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list args;
        va_start(args, format);
        deprecationSupplemental(loc, format, args);
        va_end(args);
    }

    /// ditto
    abstract void deprecationSupplemental(const ref Loc loc, const(char)* format, va_list);
}

/**
Diagnostic reporter which prints the diagnostic messages to stderr.

This is usually the default diagnostic reporter.
*/
final class StderrDiagnosticReporter : DiagnosticReporter
{
    private const DiagnosticReporting useDeprecated;

    private int errorCount_;
    private int warningCount_;
    private int deprecationCount_;

    /**
    Initializes this object.

    Params:
        useDeprecated = indicates how deprecation diagnostics should be
            handled
    */
    this(DiagnosticReporting useDeprecated)
    {
        this.useDeprecated = useDeprecated;
    }

    override int errorCount()
    {
        return errorCount_;
    }

    override int warningCount()
    {
        return warningCount_;
    }

    override int deprecationCount()
    {
        return deprecationCount_;
    }

    override void error(const ref Loc loc, const(char)* format, va_list args)
    {
        verror(loc, format, args);
        errorCount_++;
    }

    override void errorSupplemental(const ref Loc loc, const(char)* format, va_list args)
    {
        verrorSupplemental(loc, format, args);
    }

    override void warning(const ref Loc loc, const(char)* format, va_list args)
    {
        vwarning(loc, format, args);
        warningCount_++;
    }

    override void warningSupplemental(const ref Loc loc, const(char)* format, va_list args)
    {
        vwarningSupplemental(loc, format, args);
    }

    override void deprecation(const ref Loc loc, const(char)* format, va_list args)
    {
        vdeprecation(loc, format, args);

        if (useDeprecated == DiagnosticReporting.error)
            errorCount_++;
        else
            deprecationCount_++;
    }

    override void deprecationSupplemental(const ref Loc loc, const(char)* format, va_list args)
    {
        vdeprecationSupplemental(loc, format, args);
    }
}

/**
 * Color highlighting to classify messages
 */
enum Classification
{
    error = Color.brightRed,          /// for errors
    gagged = Color.brightBlue,        /// for gagged errors
    warning = Color.brightYellow,     /// for warnings
    deprecation = Color.brightCyan,   /// for deprecations
}

/**
 * Print an error message, increasing the global error count.
 * Params:
 *      loc    = location of error
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
extern (C++) void error(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
    va_end(ap);
}

/**
 * Same as above, but allows Loc() literals to be passed.
 * Params:
 *      loc    = location of error
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
extern (D) void error(Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
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
extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
{
    const loc = Loc(filename, linnum, charnum);
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
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
extern (C++) void errorSupplemental(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    verrorSupplemental(loc, format, ap);
    va_end(ap);
}

/**
 * Print a warning message, increasing the global warning count.
 * Params:
 *      loc    = location of warning
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
extern (C++) void warning(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarning(loc, format, ap);
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
extern (C++) void warningSupplemental(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarningSupplemental(loc, format, ap);
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
extern (C++) void deprecation(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vdeprecation(loc, format, ap);
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
extern (C++) void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vdeprecationSupplemental(loc, format, ap);
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
extern (C++) void message(const ref Loc loc, const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vmessage(loc, format, ap);
    va_end(ap);
}

/**
 * Same as above, but doesn't take a location argument.
 * Params:
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
extern (C++) void message(const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    vmessage(Loc.initial, format, ap);
    va_end(ap);
}

/**
 * Just print to stderr, doesn't care about gagging.
 * (format,ap) text within backticks gets syntax highlighted.
 * Params:
 *      loc         = location of error
 *      headerColor = color to set `header` output to
 *      header      = title of error message
 *      format      = printf-style format specification
 *      ap          = printf-style variadic arguments
 *      p1          = additional message prefix
 *      p2          = additional message prefix
 */
private void verrorPrint(const ref Loc loc, Color headerColor, const(char)* header,
        const(char)* format, va_list ap, const(char)* p1 = null, const(char)* p2 = null)
{
    Console* con = cast(Console*)global.console;
    const p = loc.toChars();
    if (con)
        con.setColorBright(true);
    if (*p)
    {
        fprintf(stderr, "%s: ", p);
        mem.xfree(cast(void*)p);
    }
    if (con)
        con.setColor(headerColor);
    fputs(header, stderr);
    if (con)
        con.resetColor();
    if (p1)
        fprintf(stderr, "%s ", p1);
    if (p2)
        fprintf(stderr, "%s ", p2);
    OutBuffer tmp;
    tmp.vprintf(format, ap);

    if (con && strchr(tmp.peekString(), '`'))
    {
        colorSyntaxHighlight(&tmp);
        writeHighlights(con, &tmp);
    }
    else
        fputs(tmp.peekString(), stderr);
    fputc('\n', stderr);

    if (global.params.printErrorContext &&
        // ignore invalid files
        loc != Loc.initial &&
        // ignore mixins for now
        !loc.filename.strstr(".d-mixin-") &&
        !global.params.mixinOut)
    {
        import dmd.filecache : FileCache;
        auto fllines = FileCache.fileCache.addOrGetFile(loc.filename[0 .. strlen(loc.filename)]);

        if (loc.linnum - 1 < fllines.lines.length)
        {
            auto line = fllines.lines[loc.linnum - 1];
            if (loc.charnum < line.length)
            {
                fprintf(stderr, "%.*s\n", cast(int)line.length, line.ptr);
                foreach (_; 1 .. loc.charnum)
                    fputc(' ', stderr);

                fputc('^', stderr);
                fputc('\n', stderr);
            }
        }
    }
end:
    fflush(stderr);     // ensure it gets written out in case of compiler aborts
}

/**
 * Same as $(D error), but takes a va_list parameter, and optionally additional message prefixes.
 * Params:
 *      loc    = location of error
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 *      p1     = additional message prefix
 *      p2     = additional message prefix
 *      header = title of error message
 */
extern (C++) void verror(const ref Loc loc, const(char)* format, va_list ap, const(char)* p1 = null, const(char)* p2 = null, const(char)* header = "Error: ")
{
    global.errors++;
    if (!global.gag)
    {
        verrorPrint(loc, Classification.error, header, format, ap, p1, p2);
        if (global.params.errorLimit && global.errors >= global.params.errorLimit)
            fatal(); // moderate blizzard of cascading messages
    }
    else
    {
        if (global.params.showGaggedErrors)
        {
            fprintf(stderr, "(spec:%d) ", global.gag);
            verrorPrint(loc, Classification.gagged, header, format, ap, p1, p2);
        }
        global.gaggedErrors++;
    }
}

/**
 * Same as $(D errorSupplemental), but takes a va_list parameter.
 * Params:
 *      loc    = location of error
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 */
extern (C++) void verrorSupplemental(const ref Loc loc, const(char)* format, va_list ap)
{
    Color color;
    if (global.gag)
    {
        if (!global.params.showGaggedErrors)
            return;
        color = Classification.gagged;
    }
    else
        color = Classification.error;
    verrorPrint(loc, color, "       ", format, ap);
}

/**
 * Same as $(D warning), but takes a va_list parameter.
 * Params:
 *      loc    = location of warning
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 */
extern (C++) void vwarning(const ref Loc loc, const(char)* format, va_list ap)
{
    if (global.params.warnings != DiagnosticReporting.off)
    {
        if (!global.gag)
        {
            verrorPrint(loc, Classification.warning, "Warning: ", format, ap);
            if (global.params.warnings == DiagnosticReporting.error)
                global.warnings++;
        }
        else
        {
            global.gaggedWarnings++;
        }
    }
}

/**
 * Same as $(D warningSupplemental), but takes a va_list parameter.
 * Params:
 *      loc    = location of warning
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 */
extern (C++) void vwarningSupplemental(const ref Loc loc, const(char)* format, va_list ap)
{
    if (global.params.warnings != DiagnosticReporting.off && !global.gag)
        verrorPrint(loc, Classification.warning, "       ", format, ap);
}

/**
 * Same as $(D deprecation), but takes a va_list parameter, and optionally additional message prefixes.
 * Params:
 *      loc    = location of deprecation
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 *      p1     = additional message prefix
 *      p2     = additional message prefix
 */
extern (C++) void vdeprecation(const ref Loc loc, const(char)* format, va_list ap, const(char)* p1 = null, const(char)* p2 = null)
{
    __gshared const(char)* header = "Deprecation: ";
    if (global.params.useDeprecated == DiagnosticReporting.error)
        verror(loc, format, ap, p1, p2, header);
    else if (global.params.useDeprecated == DiagnosticReporting.inform)
    {
        if (!global.gag)
        {
            verrorPrint(loc, Classification.deprecation, header, format, ap, p1, p2);
        }
        else
        {
            global.gaggedWarnings++;
        }
    }
}

/**
 * Same as $(D message), but takes a va_list parameter.
 * Params:
 *      loc       = location of message
 *      format    = printf-style format specification
 *      ap        = printf-style variadic arguments
 */
extern (C++) void vmessage(const ref Loc loc, const(char)* format, va_list ap)
{
    const p = loc.toChars();
    if (*p)
    {
        fprintf(stdout, "%s: ", p);
        mem.xfree(cast(void*)p);
    }
    OutBuffer tmp;
    tmp.vprintf(format, ap);
    fputs(tmp.peekString(), stdout);
    fputc('\n', stdout);
    fflush(stdout);     // ensure it gets written out in case of compiler aborts
}

/**
 * Same as $(D deprecationSupplemental), but takes a va_list parameter.
 * Params:
 *      loc    = location of deprecation
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 */
extern (C++) void vdeprecationSupplemental(const ref Loc loc, const(char)* format, va_list ap)
{
    if (global.params.useDeprecated == DiagnosticReporting.error)
        verrorSupplemental(loc, format, ap);
    else if (global.params.useDeprecated == DiagnosticReporting.inform && !global.gag)
        verrorPrint(loc, Classification.deprecation, "       ", format, ap);
}

/**
 * Call this after printing out fatal error messages to clean up and exit
 * the compiler.
 */
extern (C++) void fatal()
{
    version (none)
    {
        halt();
    }
    exit(EXIT_FAILURE);
}

/**
 * Try to stop forgetting to remove the breakpoints from
 * release builds.
 */
extern (C++) void halt()
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
private void colorSyntaxHighlight(OutBuffer* buf)
{
    //printf("colorSyntaxHighlight('%.*s')\n", cast(int)buf.offset, buf.data);
    bool inBacktick = false;
    size_t iCodeStart = 0;
    size_t offset = 0;
    for (size_t i = offset; i < buf.offset; ++i)
    {
        char c = buf.data[i];
        switch (c)
        {
            case '`':
                if (inBacktick)
                {
                    inBacktick = false;
                    OutBuffer codebuf;
                    codebuf.write(buf.peekSlice().ptr + iCodeStart + 1, i - (iCodeStart + 1));
                    codebuf.writeByte(0);
                    // escape the contents, but do not perform highlighting except for DDOC_PSYMBOL
                    colorHighlightCode(&codebuf);
                    buf.remove(iCodeStart, i - iCodeStart + 1); // also trimming off the current `
                    immutable pre = "";
                    i = buf.insert(iCodeStart, pre);
                    i = buf.insert(i, codebuf.peekSlice());
                    i--; // point to the ending ) so when the for loop does i++, it will see the next character
                    break;
                }
                inBacktick = true;
                iCodeStart = i;
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

private void colorHighlightCode(OutBuffer* buf)
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

    auto gaggedErrorsSave = global.startGagging();
    scope diagnosticReporter = new StderrDiagnosticReporter(global.params.useDeprecated);
    scope Lexer lex = new Lexer(null, cast(char*)buf.data, 0, buf.offset - 1, 0, 1);
    OutBuffer res;
    const(char)* lastp = cast(char*)buf.data;
    //printf("colorHighlightCode('%.*s')\n", cast(int)(buf.offset - 1), buf.data);
    res.reserve(buf.offset);
    res.writeByte(HIGHLIGHT.Escape);
    res.writeByte(HIGHLIGHT.Other);
    while (1)
    {
        Token tok;
        lex.scan(&tok)
            .printDiagnostics(diagnosticReporter);
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
    //printf("res = '%.*s'\n", cast(int)buf.offset, buf.data);
    buf.setsize(0);
    buf.write(&res);
    global.endGagging(gaggedErrorsSave);
    --nested;
}

/**
 * Write the buffer contents with embedded highlights to stderr.
 * Params:
 *      buf = highlighted text
 */
private void writeHighlights(Console* con, const OutBuffer *buf)
{
    bool colors;
    scope (exit)
    {
        /* Do not mess up console if highlighting aborts
         */
        if (colors)
            con.resetColor();
    }

    for (size_t i = 0; i < buf.offset; ++i)
    {
        const c = buf.data[i];
        if (c == HIGHLIGHT.Escape)
        {
            const color = buf.data[++i];
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
