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

import core.stdc.stdarg;
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
        verror(loc, format, ap);
        va_end(ap);
    }

    void errorSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        verrorSupplemental(loc, format, ap);
        va_end(ap);
    }

    void warning(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vwarning(loc, format, ap);
        va_end(ap);
    }

    void deprecation(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vdeprecation(loc, format, ap);
        va_end(ap);
    }

    void deprecationSupplemental(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vdeprecationSupplemental(loc, format, ap);
        va_end(ap);
    }

    void message(const ref Loc loc, const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vmessage(loc, format, ap);
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

    __gshared Loc old_loc;
    if (global.params.printErrorContext &&
        // ignore supplemental messages with same loc
        (loc != old_loc || strchr(header, ':')) &&
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
    static immutable header = "Deprecation: ";
    if (global.params.useDeprecated == DiagnosticReporting.error)
        verror(loc, format, ap, p1, p2, header.ptr);
    else if (global.params.useDeprecated == DiagnosticReporting.inform)
    {
        if (!global.gag)
        {
            verrorPrint(loc, Classification.deprecation, header.ptr, format, ap, p1, p2);
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

    __gshared ErrorSinkNull errorSinkNull;
    if (!errorSinkNull)
        errorSinkNull = new ErrorSinkNull;

    scope Lexer lex = new Lexer(null, cast(char*)buf[].ptr, 0, buf.length - 1, 0, 1, errorSinkNull, &global.compileEnv);
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
