/**
 * Control the various text mode attributes, such as color, when writing text
 * to the console.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/console.d, _console.d)
 * Documentation:  https://dlang.org/phobos/dmd_console.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/console.d
 */

module dmd.console;

import core.stdc.stdio;
extern (C) int isatty(int) nothrow;

version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.wincon;
    import core.sys.windows.windef;
}
else version (Posix)
{
    import core.sys.posix.unistd;
}
else
{
    static assert(0);
}


enum Color : int
{
    black         = 0,
    red           = 1,
    green         = 2,
    blue          = 4,
    yellow        = red | green,
    magenta       = red | blue,
    cyan          = green | blue,
    lightGray     = red | green | blue,
    bright        = 8,
    darkGray      = bright | black,
    brightRed     = bright | red,
    brightGreen   = bright | green,
    brightBlue    = bright | blue,
    brightYellow  = bright | yellow,
    brightMagenta = bright | magenta,
    brightCyan    = bright | cyan,
    white         = bright | lightGray,
}

interface Console
{
  nothrow:
    @property FILE* fp();

    /**
     * Turn on/off intensity.
     * Params:
     *      bright = turn it on
     */
    void setColorBright(bool bright);

    /**
     * Set color and intensity.
     * Params:
     *      color = the color
     */
    void setColor(Color color);

    /**
     * Reset console attributes to what they were
     * when create() was called.
     */
    void resetColor();
}

version (Windows)
private final class WindowsConsole : Console
{
  private:
    CONSOLE_SCREEN_BUFFER_INFO sbi;
    HANDLE handle;
    FILE* _fp;

  public:

    @property FILE* fp() { return _fp; }

    /*********************************
     * Create an instance of Console connected to stream fp.
     * Params:
     *      fp = io stream
     * Returns:
     *      pointer to created Console
     *      null if failed
     */
    this(FILE* fp)
    {
        DWORD nStdHandle;
        if (fp == stdout)
            nStdHandle = STD_OUTPUT_HANDLE;
        else if (fp == stderr)
            nStdHandle = STD_ERROR_HANDLE;
        else
            assert(false);

        auto h = GetStdHandle(nStdHandle);
        CONSOLE_SCREEN_BUFFER_INFO sbi;
        if (GetConsoleScreenBufferInfo(h, &sbi) == 0) // get initial state of console
            assert(false);

        this._fp = fp;
        this.handle = h;
        this.sbi = sbi;
    }

    /*******************
     * Turn on/off intensity.
     * Params:
     *      bright = turn it on
     */
    void setColorBright(bool bright)
    {
        SetConsoleTextAttribute(handle, sbi.wAttributes | (bright ? FOREGROUND_INTENSITY : 0));
    }

    /***************************
     * Set color and intensity.
     * Params:
     *      color = the color
     */
    void setColor(Color color)
    {
        enum FOREGROUND_WHITE = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE;
        WORD attr = sbi.wAttributes;
        attr = (attr & ~(FOREGROUND_WHITE | FOREGROUND_INTENSITY)) |
               ((color & Color.red)    ? FOREGROUND_RED   : 0) |
               ((color & Color.green)  ? FOREGROUND_GREEN : 0) |
               ((color & Color.blue)   ? FOREGROUND_BLUE  : 0) |
               ((color & Color.bright) ? FOREGROUND_INTENSITY : 0);
        SetConsoleTextAttribute(handle, attr);
    }

    /******************
     * Reset console attributes to what they were
     * when create() was called.
     */
    void resetColor()
    {
        SetConsoleTextAttribute(handle, sbi.wAttributes);
    }
}

version (Posix)
private final class ANSIConsole : Console
{
    /* The ANSI escape codes are used.
     * https://en.wikipedia.org/wiki/ANSI_escape_code
     * Foreground colors: 30..37
     * Background colors: 40..47
     * Attributes:
     *  0: reset all attributes
     *  1: high intensity
     *  2: low intensity
     *  3: italic
     *  4: single line underscore
     *  5: slow blink
     *  6: fast blink
     *  7: reverse video
     *  8: hidden
     */

  private:
    FILE* _fp;

  public:

    @property FILE* fp() { return _fp; }

    this(FILE* fp)
    {
        this._fp = fp;
    }

    void setColorBright(bool bright)
    {
        fprintf(_fp, "\033[%dm", bright);
    }

    void setColor(Color color)
    {
        fprintf(_fp, "\033[%d;%dm", color & Color.bright ? 1 : 0, 30 + (color & ~Color.bright));
    }

    void resetColor()
    {
        fputs("\033[m", _fp);
    }
}

/**
 Tries to detect whether DMD has been invoked from a terminal.
 Returns: `true` if a terminal has been detected, `false` otherwise
 */
bool detectTerminal() nothrow
{
    version (Windows)
    {
        auto h = GetStdHandle(STD_OUTPUT_HANDLE);
        CONSOLE_SCREEN_BUFFER_INFO sbi;
        if (GetConsoleScreenBufferInfo(h, &sbi) == 0) // get initial state of console
            return false; // no terminal detected

        version (CRuntime_DigitalMars)
        {
            return isatty(stdout._file) != 0;
        }
        else version (CRuntime_Microsoft)
        {
            return isatty(fileno(stdout)) != 0;
        }
        else
        {
            static assert(0, "Unsupported Windows runtime.");
        }
    }
    else
    version (Posix)
    {
        import core.stdc.stdlib : getenv;
        const(char)* term = getenv("TERM");
        import core.stdc.string : strcmp;
        return isatty(STDERR_FILENO) && term && term[0] && strcmp(term, "dumb") != 0;
    }
}

/**
 * Creates an instance of Console connected to stream fp.
 * Params:
 *      fp = io stream
 * Returns:
 *      reference to created Console
 */
Console createConsole(FILE* fp)
{
    if (detectTerminal())
    {
        version (Windows)
            return new WindowsConsole(fp);
        version (Posix)
            return new ANSIConsole(fp);
    }
    return null;
}
