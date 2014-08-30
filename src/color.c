
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mars.c
 */

#include "color.h"

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

