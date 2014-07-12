
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
static CONSOLE_SCREEN_BUFFER_INFO *consoleAttributes()
{
    static CONSOLE_SCREEN_BUFFER_INFO sbi;
    static bool sbi_inited = false;
    if (!sbi_inited)
        sbi_inited = GetConsoleScreenBufferInfo(GetStdHandle(STD_ERROR_HANDLE), &sbi) != FALSE;
    return &sbi;
}
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

void setConsoleColorBright()
{
#if _WIN32
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), consoleAttributes()->wAttributes | FOREGROUND_INTENSITY);
#else
    fprintf(stderr, "\033[1m");
#endif
}

void setConsoleColorError()
{
#if _WIN32
    enum { FOREGROUND_WHITE = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE };
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), (consoleAttributes()->wAttributes & ~FOREGROUND_WHITE) | FOREGROUND_RED | FOREGROUND_INTENSITY);
#else
    fprintf(stderr, "\033[1;31m");
#endif
}

void resetConsoleColor()
{
#if _WIN32
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), consoleAttributes()->wAttributes);
#else
    fprintf(stderr, "\033[m");
#endif
}

