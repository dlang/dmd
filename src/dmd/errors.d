/**
 * Functions for raising errors.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
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
import dmd.root.string;
import dmd.console;

nothrow:

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

alias MessageFunc = extern (C++) void function(const ref Loc loc, const(char)* format, ...);

private struct FragmentInfo
{
    const(char)* start; /// points to the first character of the `FRAGMENT_PREFIX_START` prefix for this fragment.

    const(char)* name;
    size_t nameLen;

    const(char)* params; /// can be null.
    size_t paramsLen;

    const(char)* innerText;
    size_t innerTextLen;
}

private immutable FRAGMENT_PREFIX = "\033¬\r!\033¬\t*"; // super random series of weird characters that no user code would ever really use. Change to e.g. "__PREFIX__" when debugging.
private immutable FRAGMENT_PREFIX_START = FRAGMENT_PREFIX ~ "$[";
private immutable FRAGMENT_PREFIX_BODY_END = FRAGMENT_PREFIX ~ '}';

/**
 * Print an error message using the extended string format, increasing the global error count.
 * Params:
 *      loc    = location of error
 *      format = extended format specification
 *      ...    = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void errorEx(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorEx(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void errorEx(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorEx(loc, format, ap);
        va_end(ap);
    }

/**
 * Similar to `verror` except it uses the extended format string described by `verrorFormatPrint`.
 * Params:
 *      loc    = location of error
 *      format = extended format specification
 *      ap     = printf-style argument list
 */
extern (C++) void verrorEx(const ref Loc loc, const(char)* format, va_list ap)
{
    verrorFormatPrint(loc, format, ap, &error, &errorSupplemental);
}

static if (__VERSION__ < 2092)
    private extern (C++) void noop(const ref Loc loc, const(char)* format, ...) {}
else
    pragma(printf) private extern (C++) void noop(const ref Loc loc, const(char)* format, ...) {}

package auto previewErrorFunc(bool isDeprecated, FeatureState featureState) @safe @nogc pure nothrow
{
    if (featureState == FeatureState.enabled)
        return &error;
    else if (featureState == FeatureState.disabled || isDeprecated)
        return &noop;
    else
        return &deprecation;
}

package auto previewSupplementalFunc(bool isDeprecated, FeatureState featureState) @safe @nogc pure nothrow
{
    if (featureState == FeatureState.enabled)
        return &errorSupplemental;
    else if (featureState == FeatureState.disabled || isDeprecated)
        return &noop;
    else
        return &deprecationSupplemental;
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
        verror(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void error(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
    {
        const loc = Loc(filename, linnum, charnum);
        va_list ap;
        va_start(ap, format);
        verror(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void errorSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorSupplemental(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void errorSupplemental(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void warning(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vwarning(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void warning(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void warningSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vwarningSupplemental(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void warningSupplemental(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vdeprecation(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void deprecation(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vdeprecationSupplemental(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void message(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vmessage(loc, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void message(const ref Loc loc, const(char)* format, ...)
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
static if (__VERSION__ < 2092)
    extern (C++) void message(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vmessage(Loc.initial, format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void message(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vmessage(Loc.initial, format, ap);
        va_end(ap);
    }

/**
 * The type of the diagnostic handler
 * see verrorPrint for arguments
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
        vtip(format, ap);
        va_end(ap);
    }
else
    pragma(printf) extern (C++) void tip(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vtip(format, ap);
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
    if (diagnosticHandler && diagnosticHandler(loc, headerColor, header, format, ap, p1, p2))
        return;

    if (global.params.showGaggedErrors && global.gag)
        fprintf(stderr, "(spec:%d) ", global.gag);
    Console con = cast(Console) global.console;
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
    OutBuffer tmp;
    if (p1)
    {
        tmp.writestring(p1);
        tmp.writestring(" ");
    }
    if (p2)
    {
        tmp.writestring(p2);
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
    verrorPrintContext(loc);
    fflush(stderr);     // ensure it gets written out in case of compiler aborts
}

private void verrorPrintContext(const ref Loc loc)
{
    if (global.params.printErrorContext &&
        // ignore invalid files
        loc != Loc.initial &&
        // ignore mixins for now
        !loc.filename.strstr(".d-mixin-") &&
        !global.params.mixinOut)
    {
        import dmd.filecache : FileCache;
        auto fllines = FileCache.fileCache.addOrGetFile(loc.filename.toDString());

        if (loc.linnum - 1 < fllines.lines.length)
        {
            auto line = fllines.lines[loc.linnum - 1];
            if (loc.charnum < line.length)
            {
                fprintf(stderr, "%.*s\n", cast(int)line.length, line.ptr);
                // The number of column bytes and the number of display columns
                // occupied by a character are not the same for non-ASCII charaters.
                // https://issues.dlang.org/show_bug.cgi?id=21849
                size_t c = 0;
                while (c < loc.charnum - 1)
                {
                    import dmd.utf : utf_decodeChar;
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
            verrorPrint(loc, Classification.gagged, header, format, ap, p1, p2);
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
static if (__VERSION__ < 2092)
    extern (C++) void verrorSupplemental(const ref Loc loc, const(char)* format, va_list ap)
    {
        _verrorSupplemental(loc, format, ap);
    }
else
    pragma(printf) extern (C++) void verrorSupplemental(const ref Loc loc, const(char)* format, va_list ap)
    {
        _verrorSupplemental(loc, format, ap);
    }

private void _verrorSupplemental(const ref Loc loc, const(char)* format, va_list ap)
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
static if (__VERSION__ < 2092)
    extern (C++) void vwarning(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vwarning(loc, format, ap);
    }
else
    pragma(printf) extern (C++) void vwarning(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vwarning(loc, format, ap);
    }

private void _vwarning(const ref Loc loc, const(char)* format, va_list ap)
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
static if (__VERSION__ < 2092)
    extern (C++) void vwarningSupplemental(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vwarningSupplemental(loc, format, ap);
    }
else
    pragma(printf) extern (C++) void vwarningSupplemental(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vwarningSupplemental(loc, format, ap);
    }

private void _vwarningSupplemental(const ref Loc loc, const(char)* format, va_list ap)
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
static if (__VERSION__ < 2092)
    extern (C++) void vmessage(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vmessage(loc, format, ap);
    }
else
    pragma(printf) extern (C++) void vmessage(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vmessage(loc, format, ap);
    }

private void _vmessage(const ref Loc loc, const(char)* format, va_list ap)
{
    const p = loc.toChars();
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
}

/**
 * Same as $(D tip), but takes a va_list parameter.
 * Params:
 *      format    = printf-style format specification
 *      ap        = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void vtip(const(char)* format, va_list ap)
    {
        _vtip(format, ap);
    }
else
    pragma(printf) extern (C++) void vtip(const(char)* format, va_list ap)
    {
        _vtip(format, ap);
    }
private void _vtip(const(char)* format, va_list ap)
{
    if (!global.gag)
    {
        Loc loc = Loc.init;
        verrorPrint(loc, Classification.tip, "  Tip: ", format, ap);
    }
}

/**
 * Same as $(D deprecationSupplemental), but takes a va_list parameter.
 * Params:
 *      loc    = location of deprecation
 *      format = printf-style format specification
 *      ap     = printf-style variadic arguments
 */
static if (__VERSION__ < 2092)
    extern (C++) void vdeprecationSupplemental(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vdeprecationSupplemental(loc, format, ap);
    }
else
    pragma(printf) extern (C++) void vdeprecationSupplemental(const ref Loc loc, const(char)* format, va_list ap)
    {
        _vdeprecationSupplemental(loc, format, ap);
    }

private void _vdeprecationSupplemental(const ref Loc loc, const(char)* format, va_list ap)
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
private void colorSyntaxHighlight(ref OutBuffer buf)
{
    //printf("colorSyntaxHighlight('%.*s')\n", cast(int)buf.length, buf.data);
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

    auto gaggedErrorsSave = global.startGagging();
    scope Lexer lex = new Lexer(null, cast(char*)buf[].ptr, 0, buf.length - 1, 0, 1);
    OutBuffer res;
    const(char)* lastp = cast(char*)buf[].ptr;
    //printf("colorHighlightCode('%.*s')\n", cast(int)(buf.length - 1), buf.data);
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
    //printf("res = '%.*s'\n", cast(int)buf.length, buf.data);
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

/**
 * Similar to `verrorPrint` except this function uses an extended format string syntax, and
 * outsources the actual printing to external functions.
 *
 * Notes:
 *  When this comment mentions about inserting a new line, what really happens it that is makes
 *  a call to `printSupplemental` instead of manually messing around with new lines.
 *
 * Format:
 *  The given `format` string can be used as a normal printf-style string, but it has additional syntax
 *  to perform additional formatting options, such as indenting text depending on the error format level set by the compiler caller.
 *
 *  To specify a 'format fragment' you must use the syntax `$[formatter_name:formatter_params]{text to format}`.
 *
 *  formatter_params (and the ':' before it) are optional, everything else is mandatory.
 *
 *  e.g. `$[indent:1]{This text is put onto a new line and indented by 1 'tab'}`
 *
 *  e.g. `There might be a new line $[indent:0]{} between these two pieces of text!`
 *
 * Formatters:
 *  indent:indent_level = If the error formatting level is 1 or higher, then a new line is made and a tab (4 spaces) is inserted `indent_level`
 *                        times, which is then followed up by the text to format. Technically there's no need to provide specific text to this formatter,
 *                        but it makes it more clear on what you're attempting to do.
 *
 * Params:
 *  loc                 = The location of the error.
 *  format              = The extended format string to use.
 *  ap                  = The argument list to use with the `format` string.
 *  print               = The print function to use for the first line printed.
 *  printSupplemental   = The print function to use for every line printed after the first line.
 */
private void verrorFormatPrint(const ref Loc loc, const(char)* format, va_list ap, MessageFunc print, MessageFunc printSupplemental)
{
    const prefixedFormat = verrorFormatPrefixString(format, ap);
    if (!prefixedFormat)
        assert(0, "BAD FORMAT STRING - verrorFormatPrefixString returned null.");
    scope (exit) mem.xfree(cast(void*)prefixedFormat);

    bool firstPrint = true;
    void push(const(char)* text)
    {
        if (firstPrint)
            print(loc, "%s", text);
        else
            printSupplemental(loc, "%s", text);
        firstPrint = false;
    }

    OutBuffer buf;
    const(char)* nextFormat = prefixedFormat;
    while (*nextFormat != '\0')
    {
        const nextFragment = strstr(nextFormat, FRAGMENT_PREFIX_START.ptr);
        if (nextFragment && nextFragment == nextFormat)
        {
            FragmentInfo info;
            if (!verrorFormatNextFragment(nextFormat, info, nextFormat))
                assert(0, "BAD FORMAT STRING - FRAGMENT_PREFIX_START was found but could not be parsed.");

            // TODO: Perhaps dispatch into different functions in the future, otherwise this might get messy.
            if (!strncmp(info.name, "indent", info.nameLen))
            {
                if (global.params.formatLevel < 1)
                {
                    buf.write(info.innerText, info.innerTextLen);
                    continue;
                }
                push(buf.peekChars());
                buf.reset();
                uint indentLevel;
                if (info.params)
                    if (!sscanf(info.params, "%u", &indentLevel))
                        assert(0, "BAD FORMAT STRING - 'indent' could not parse numeric parameter of: "~info.params[0..info.paramsLen]);
                foreach (i; 0..indentLevel)
                    buf.writestring("    ");
                buf.write(info.innerText, info.innerTextLen);
            }
            else
                assert(0, "BAD FORMAT STRING - Formatter '"~info.name[0..info.nameLen]~"' does not exist.");
            continue;
        }

        const length = nextFragment ? (nextFragment - nextFormat) : strlen(nextFormat);
        buf.write(nextFormat, length);
        nextFormat += length;
    }
    if (buf.length)
        push(buf.peekChars());
}

/**
 * Provides a new string where all the formatting fragments inside of `format` are
 * prefixed with an unusual string of characters in order to make it harder for code
 * to confuse compiler-proivded fragments from things like `myclass!"$[blah]"`.
 *
 * After prefixing, the format string is fully resolved with the given argument list.
 *
 * Please note that the returned string must be freed manually.
 *
 * Params:
 *      format = The format string to prefix and resolve.
 *      ap     = The argument list to resolve the format string with.
 *
 * Returns:
 *  A new string (that must be freed) containing the fully resolved and prefixed `format` string.
 */
private const(char)* verrorFormatPrefixString(const(char)* format, va_list ap)
{
    OutBuffer buf;

    // First, find any formatting fragments, and prefix them with a silly string of chars.
    // This is to make it almost impossible for things like `myClass!"$[]"` from accidentally being
    // detected as a format fragment.
    //
    // This is stupid, and silly, but I'm too dumb to think of anything else without making something even more clunky.
    auto start = format;
    auto delim = start;
    while ((delim = strstr(start, "$[")) !is null)
    {
        const beforeLen = (delim - start);
        buf.write(start, beforeLen);
        buf.writestring(FRAGMENT_PREFIX);

        // Full format is $[name:?params?]{text?} so there *should* be a '{' and '}'. We want to prefix the '}'.
        const endParams = strchr(delim, ']');
        if (!endParams)
            return null;
        const startBody = strchr(endParams, '{');
        if (!startBody || (startBody - endParams) != 1)
            return null;
        const endBody = strchr(startBody, '}');
        if (!endBody)
            return null;

        start = endBody + 1;
        buf.write(delim, (endBody - delim));
        buf.writestring(FRAGMENT_PREFIX);
        buf.writeByte('}');
    }
    buf.writestring(start);

    // Now that the developer-made fragments have their silly prefix, we'll now expand the string.
    const prefixedFormat = buf.extractChars();
    scope (exit) mem.xfree(cast(void*)prefixedFormat);
    buf.vprintf(prefixedFormat, ap);

    // Now verrorFormatNextFragment can be used on the result.
    return buf.extractChars();
}

/**
 * Retrieves the next fragment from within `prefixedFormat`.
 *
 * Params:
 *      prefixedFormat      = The output of `verrorFormatPrefixString` or the result of `nextPrefixedFormat` from a previous call to this function.
 *      info                = The `FragmentInfo` to populate.
 *      nextPrefxiedFormat  = `prefixedFormat` but advanced to just after the fragment that was read in.
 *                            This value is left unmodified if no fragment was read.
 *
 * Returns:
 *      `false` on error or if there's no more fragments, `true` if a fragment was read in.
 */
private bool verrorFormatNextFragment(const(char)* prefixedFormat, out FragmentInfo info, ref const(char)* nextPrefixedFormat)
{
    auto start = prefixedFormat;
    auto delim = strstr(start, FRAGMENT_PREFIX_START.ptr);
    if (delim !is null)
    {
        info.start = delim;
        delim += FRAGMENT_PREFIX_START.length;
        info.name = delim;

        // read name + params
        while (true) // Loop is terminated by the null check if statement, and the ']' check.
        {
            if (*delim == '\0')
                return false;
            else if (*delim == ':')
            {
                info.params = delim + 1;
                info.nameLen = (delim - info.name);
            }
            else if (*delim == ']')
            {
                if (!info.params)
                    info.nameLen = (delim - info.name);
                else
                    info.paramsLen = (delim - info.params);
                delim++;
                break;
            }
            delim++;
        }

        // read inner text
        if (*delim != '{')
            return false;
        delim++;

        const innerTextEnd = strstr(delim, FRAGMENT_PREFIX_BODY_END.ptr);
        if (!innerTextEnd)
            return false;
        info.innerText = delim;
        info.innerTextLen = (innerTextEnd - delim);
        nextPrefixedFormat = innerTextEnd + FRAGMENT_PREFIX_BODY_END.length;
        return true;
    }

    return false;
}
