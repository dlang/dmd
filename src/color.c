
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
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <io.h>
#endif

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#endif

#if _WIN32
static CONSOLE_SCREEN_BUFFER_INFO sbi;
static const BOOL sbi_inited = GetConsoleScreenBufferInfo(GetStdHandle(STD_ERROR_HANDLE), &sbi);
#endif

int isConsoleColorSupported()
{
#if _WIN32
    return _isatty(_fileno(stderr));
#elif __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    const char *term = getenv("TERM");
    return isatty(STDERR_FILENO) && term && term[0] && 0 != strcmp(term, "dumb");
#else
    return 0;
#endif
}

void setConsoleColorBright()
{
#if _WIN32
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), sbi.wAttributes | FOREGROUND_INTENSITY);
#else
    fprintf(stderr, "\033[1m");
#endif
}

void setConsoleColorError()
{
#if _WIN32
    enum { FOREGROUND_WHITE = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE };
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), (sbi.wAttributes & ~FOREGROUND_WHITE) | FOREGROUND_RED | FOREGROUND_INTENSITY);
#else
    fprintf(stderr, "\033[1;31m");
#endif
}

void resetConsoleColor()
{
#if _WIN32
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), sbi.wAttributes);
#else
    fprintf(stderr, "\033[m");
#endif
}

