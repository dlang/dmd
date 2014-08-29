
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mars.c
 */

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

extern bool isConsoleColorSupported();
extern void setConsoleColorBright(bool bright);
extern void setConsoleColor(COLOR color, bool bright);
extern void resetConsoleColor();

