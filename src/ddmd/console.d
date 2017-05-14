/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _console.d)
 */

module ddmd.console;

import core.stdc.stdio;
import core.sys.posix.unistd;
import core.sys.windows.windows;

import core.stdc.string;
import core.stdc.stdlib;

version (Windows) extern (C) int isatty(int);

enum COLOR : int
{
    COLOR_BLACK     = 0,
    COLOR_RED       = 1,
    COLOR_GREEN     = 2,
    COLOR_BLUE      = 4,
    COLOR_YELLOW    = COLOR_RED | COLOR_GREEN,
    COLOR_MAGENTA   = COLOR_RED | COLOR_BLUE,
    COLOR_CYAN      = COLOR_GREEN | COLOR_BLUE,
    COLOR_WHITE     = COLOR_RED | COLOR_GREEN | COLOR_BLUE,
}

alias COLOR_BLACK = COLOR.COLOR_BLACK;
alias COLOR_RED = COLOR.COLOR_RED;
alias COLOR_GREEN = COLOR.COLOR_GREEN;
alias COLOR_BLUE = COLOR.COLOR_BLUE;
alias COLOR_YELLOW = COLOR.COLOR_YELLOW;
alias COLOR_MAGENTA = COLOR.COLOR_MAGENTA;
alias COLOR_CYAN = COLOR.COLOR_CYAN;
alias COLOR_WHITE = COLOR.COLOR_WHITE;

version (Windows)
{
    extern (C++) static WORD consoleAttributes(HANDLE h)
    {
        static __gshared CONSOLE_SCREEN_BUFFER_INFO sbi;
        static __gshared bool sbi_inited = false;
        if (!sbi_inited)
            sbi_inited = GetConsoleScreenBufferInfo(h, &sbi) != FALSE;
        return sbi.wAttributes;
    }

    enum : int
    {
        FOREGROUND_WHITE = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE,
    }
}

extern (C++) bool isConsoleColorSupported()
{
    version (CRuntime_DigitalMars)
    {
        return isatty(stderr._file) != 0;
    }
    else version (CRuntime_Microsoft)
    {
        return isatty(fileno(stderr)) != 0;
    }
    else version (Posix)
    {
        const(char)* term = getenv("TERM");
        return isatty(STDERR_FILENO) && term && term[0] && 0 != strcmp(term, "dumb");
    }
    else
    {
        return false;
    }
}

extern (C++) void setConsoleColorBright(bool bright)
{
    version (Windows)
    {
        HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
        WORD attr = consoleAttributes(h);
        SetConsoleTextAttribute(h, attr | (bright ? FOREGROUND_INTENSITY : 0));
    }
    else
    {
        fprintf(stderr, "\033[%dm", bright ? 1 : 0);
    }
}

extern (C++) void setConsoleColor(COLOR color, bool bright)
{
    version (Windows)
    {
        HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
        WORD attr = consoleAttributes(h);
        attr = (attr & ~(FOREGROUND_WHITE | FOREGROUND_INTENSITY)) | ((color & COLOR_RED) ? FOREGROUND_RED : 0) | ((color & COLOR_GREEN) ? FOREGROUND_GREEN : 0) | ((color & COLOR_BLUE) ? FOREGROUND_BLUE : 0) | (bright ? FOREGROUND_INTENSITY : 0);
        SetConsoleTextAttribute(h, attr);
    }
    else
    {
        fprintf(stderr, "\033[%d;%dm", bright ? 1 : 0, 30 + cast(int)color);
    }
}

extern (C++) void resetConsoleColor()
{
    version (Windows)
    {
        HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
        SetConsoleTextAttribute(h, consoleAttributes(h));
    }
    else
    {
        fprintf(stderr, "\033[m");
    }
}


