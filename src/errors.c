
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mars.c
 */

#include <stdio.h>

#if _WIN32
#include <windows.h>
#include <io.h>
#endif

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#endif

#include "errors.h"
#include "root/outbuffer.h"
#include "root/rmem.h"

enum COLOR
{
    COLOR_BLACK     = 0,
    COLOR_RED       = 1,
    COLOR_GREEN     = 2,
    COLOR_BLUE      = 4,

    COLOR_YELLOW    = COLOR_RED | COLOR_GREEN,
    COLOR_MAGENTA   = COLOR_RED | COLOR_BLUE,
    COLOR_CYAN      = COLOR_GREEN | COLOR_BLUE,
    COLOR_WHITE     = COLOR_RED | COLOR_GREEN | COLOR_BLUE,
};

#if _WIN32
static WORD consoleAttributes(HANDLE h)
{
    static CONSOLE_SCREEN_BUFFER_INFO sbi;
    static bool sbi_inited = false;
    if (!sbi_inited)
        sbi_inited = GetConsoleScreenBufferInfo(h, &sbi) != FALSE;
    return sbi.wAttributes;
}

enum
{
    FOREGROUND_WHITE = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE,
};
#endif

bool isConsoleColorSupported()
{
#if _WIN32
    return _isatty(_fileno(stderr)) != 0;
#elif __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    const char *term = getenv("TERM");
    return isatty(STDERR_FILENO) && term && term[0] && 0 != strcmp(term, "dumb");
#else
    return false;
#endif
}

void setConsoleColorBright(bool bright)
{
#if _WIN32
    HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
    WORD attr = consoleAttributes(h);
    SetConsoleTextAttribute(h, attr | (bright ? FOREGROUND_INTENSITY : 0));
#else
    fprintf(stderr, "\033[%dm", bright ? 1 : 0);
#endif
}

void setConsoleColor(COLOR color, bool bright)
{
#if _WIN32
    HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
    WORD attr = consoleAttributes(h);
    attr = (attr & ~(FOREGROUND_WHITE | FOREGROUND_INTENSITY)) |
           ((color & COLOR_RED)   ? FOREGROUND_RED   : 0) |
           ((color & COLOR_GREEN) ? FOREGROUND_GREEN : 0) |
           ((color & COLOR_BLUE)  ? FOREGROUND_BLUE  : 0) |
           (bright ? FOREGROUND_INTENSITY : 0);
    SetConsoleTextAttribute(h, attr);
#else
    fprintf(stderr, "\033[%d;%dm", bright ? 1 : 0, 30 + (int)color);
#endif
}

void resetConsoleColor()
{
#if _WIN32
    HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
    SetConsoleTextAttribute(h, consoleAttributes(h));
#else
    fprintf(stderr, "\033[m");
#endif
}

/**************************************
 * Print error message
 */

void error(const Loc& loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
    va_end( ap );
}

void error(const char *filename, unsigned linnum, unsigned charnum, const char *format, ...)
{
    Loc loc;
    loc.filename = filename;
    loc.linnum = linnum;
    loc.charnum = charnum;
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
    va_end( ap );
}

void errorSupplemental(const Loc& loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    verrorSupplemental(loc, format, ap);
    va_end( ap );
}

void warning(const Loc& loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarning(loc, format, ap);
    va_end( ap );
}

void warningSupplemental(const Loc& loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarningSupplemental(loc, format, ap);
    va_end( ap );
}

void deprecation(const Loc& loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vdeprecation(loc, format, ap);
    va_end( ap );
}

void deprecationSupplemental(const Loc& loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vdeprecation(loc, format, ap);
    va_end( ap );
}


/**
 * Print a verbose message.
 * Doesn't prefix or highlight messages.
 * Params:
 *      loc    = location of message
 *      format = printf-style format specification
 *      ...    = printf-style variadic arguments
 */
void message(const Loc &loc, const char *format, ...)
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
void message(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vmessage(Loc(), format, ap);
    va_end(ap);
}

// Just print, doesn't care about gagging
void verrorPrint(const Loc& loc, COLOR headerColor, const char *header, const char *format, va_list ap,
                const char *p1 = NULL, const char *p2 = NULL)
{
    const char *p = loc.toChars();

    if (global.params.color)
        setConsoleColorBright(true);
    if (*p)
        fprintf(stderr, "%s: ", p);
    mem.xfree(const_cast<char *>(p));

    if (global.params.color)
        setConsoleColor(headerColor, true);
    fputs(header, stderr);
    if (global.params.color)
        resetConsoleColor();
    if (p1)
        fprintf(stderr, "%s ", p1);
    if (p2)
        fprintf(stderr, "%s ", p2);
    OutBuffer tmp;
    tmp.vprintf(format, ap);
    fprintf(stderr, "%s\n", tmp.peekChars());
    fflush(stderr);
}

// header is "Error: " by default (see errors.h)
void verror(const Loc& loc, const char *format, va_list ap,
                const char *p1, const char *p2, const char *header)
{
    global.errors++;
    if (!global.gag)
    {
        verrorPrint(loc, COLOR_RED, header, format, ap, p1, p2);
        if (global.params.errorLimit && global.errors >= global.params.errorLimit)
            fatal();    // moderate blizzard of cascading messages
    }
    else
    {
        //fprintf(stderr, "(gag:%d) ", global.gag);
        //verrorPrint(loc, COLOR_RED, header, format, ap, p1, p2);
        global.gaggedErrors++;
    }
}

// Doesn't increase error count, doesn't print "Error:".
void verrorSupplemental(const Loc& loc, const char *format, va_list ap)
{
    if (!global.gag)
        verrorPrint(loc, COLOR_RED, "       ", format, ap);
}

void vwarning(const Loc& loc, const char *format, va_list ap)
{
    if (global.params.warnings != DIAGNOSTICoff)
    {
        if (!global.gag)
        {
            verrorPrint(loc, COLOR_YELLOW, "Warning: ", format, ap);
            if (global.params.warnings == DIAGNOSTICerror)
                global.warnings++;  // warnings don't count if gagged
        }
        else
        {
            global.gaggedWarnings++;
        }
    }
}

void vwarningSupplemental(const Loc& loc, const char *format, va_list ap)
{
    if (global.params.warnings != DIAGNOSTICoff && !global.gag)
        verrorPrint(loc, COLOR_YELLOW, "       ", format, ap);
}

void vdeprecation(const Loc& loc, const char *format, va_list ap,
                const char *p1, const char *p2)
{
    static const char *header = "Deprecation: ";
    if (global.params.useDeprecated == DIAGNOSTICerror)
        verror(loc, format, ap, p1, p2, header);
    else if (global.params.useDeprecated == DIAGNOSTICinform)
    {
       if (!global.gag)
       {
           verrorPrint(loc, COLOR_BLUE, header, format, ap, p1, p2);
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
void vmessage(const Loc &loc, const char *format, va_list ap)
{
    const char *p = loc.toChars();
    if (*p)
    {
        fprintf(stdout, "%s: ", p);
        mem.xfree(const_cast<char*>(p));
    }
    OutBuffer tmp;
    tmp.vprintf(format, ap);
    fputs(tmp.peekChars(), stdout);
    fputc('\n', stdout);
    fflush(stdout);     // ensure it gets written out in case of compiler aborts
}

void vdeprecationSupplemental(const Loc& loc, const char *format, va_list ap)
{
    if (global.params.useDeprecated == DIAGNOSTICerror)
        verrorSupplemental(loc, format, ap);
    else if (global.params.useDeprecated == DIAGNOSTICinform && !global.gag)
        verrorPrint(loc, COLOR_BLUE, "       ", format, ap);
}

/***************************************
 * Call this after printing out fatal error messages to clean up and exit
 * the compiler.
 */

void fatal()
{
#if 0
    halt();
#endif
    exit(EXIT_FAILURE);
}

/**************************************
 * Try to stop forgetting to remove the breakpoints from
 * release builds.
 */
void halt()
{
#ifdef DEBUG
    *(volatile char*)0=0;
#endif
    assert(0);
}
