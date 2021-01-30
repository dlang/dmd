/**
 * This module defines some utility functions for DMD.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/utils.d, _utils.d)
 * Documentation:  https://dlang.org/phobos/dmd_utils.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/utils.d
 */

module dmd.utils;

import core.stdc.string;
import dmd.errors;
import dmd.globals;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.outbuffer;
import dmd.root.string;


/**
 * Normalize path by turning forward slashes into backslashes
 *
 * Params:
 *   src = Source path, using unix-style ('/') path separators
 *
 * Returns:
 *   A newly-allocated string with '/' turned into backslashes
 */
const(char)* toWinPath(const(char)* src)
{
    if (src is null)
        return null;
    char* result = strdup(src);
    char* p = result;
    while (*p != '\0')
    {
        if (*p == '/')
            *p = '\\';
        p++;
    }
    return result;
}

/**
 * Normalize path by turning backslashes into forward slashes
 *
 * Params:
 *   src = Source path, using window-style ('\') or mixed path separators
 *
 * Returns:
 *   A newly-allocated string with '\' turned into '/'
 */
@trusted nothrow const(char)* toPosixPath(const(char)* src)
{
    if (src is null)
        return null;
    char* result = strdup(src);
    char* p = result;
    while (*p != '\0')
    {
        if (*p == '\\')
            *p = '/';
        p++;
    }
    return result;
}

/**
 * ditto
 */
@safe pure nothrow const(char)[] toPosixPath(const(char)[] src)
{
    if (!src)
        return null;
    char[] result = src.dup;
    foreach (ref c; result)
    {
        if (c == '\\')
            c = '/';
    }
    return result;
}

///
@safe nothrow unittest
{
    const(char)[] nullStr;
    const(char)* nullStrP;

    assert(toPosixPath(nullStrP) == null);
    assert(toPosixPath(nullStr) == null);

    @trusted nothrow void assertion(const(char)[] s1, const(char)[] s2)
    {
        assert(toPosixPath(s1) == s2);
        assert(strcmp(toPosixPath(s1.ptr), s2.ptr) == 0);
    }

    const posixAbsPath = `/some/path`;
    const posixRelPath = `some/path`;

    const windowsAbsPath = `C:\some\path`;
    const windowsAbsMixedPath = `C:\some/path`;
    const windowsAbsPosixPath = `C:/some/path`;
    const windowsRelPath = `some\path`;

    assertion(posixAbsPath, posixAbsPath);
    assertion(posixRelPath, posixRelPath);
    assertion(windowsAbsPath, windowsAbsPosixPath);
    assertion(windowsAbsMixedPath, windowsAbsPosixPath);
    assertion(windowsAbsPosixPath, windowsAbsPosixPath);
    assertion(windowsRelPath, posixRelPath);
}

/**
 * Reads a file, terminate the program on error
 *
 * Params:
 *   loc = The line number information from where the call originates
 *   filename = Path to file
 */
FileBuffer readFile(Loc loc, const(char)* filename)
{
    return readFile(loc, filename.toDString());
}

/// Ditto
FileBuffer readFile(Loc loc, const(char)[] filename)
{
    auto result = File.read(filename);
    if (!result.success)
    {
        error(loc, "Error reading file `%.*s`", cast(int)filename.length, filename.ptr);
        fatal();
    }
    return FileBuffer(result.extractSlice());
}


/**
 * Writes a file, terminate the program on error
 *
 * Params:
 *   loc = The line number information from where the call originates
 *   filename = Path to file
 *   data = Full content of the file to be written
 */
extern (D) void writeFile(Loc loc, const(char)[] filename, const void[] data)
{
    ensurePathToNameExists(Loc.initial, filename);
    if (!File.update(filename, data))
    {
        error(loc, "Error writing file '%*.s'", cast(int) filename.length, filename.ptr);
        fatal();
    }
}


/**
 * Ensure the root path (the path minus the name) of the provided path
 * exists, and terminate the process if it doesn't.
 *
 * Params:
 *   loc = The line number information from where the call originates
 *   name = a path to check (the name is stripped)
 */
void ensurePathToNameExists(Loc loc, const(char)[] name)
{
    const char[] pt = FileName.path(name);
    if (pt.length)
    {
        if (!FileName.ensurePathExists(pt))
        {
            error(loc, "cannot create directory %*.s", cast(int) pt.length, pt.ptr);
            fatal();
        }
    }
    FileName.free(pt.ptr);
}


/**
 * Takes a path, and escapes '(', ')' and backslashes
 *
 * Params:
 *   buf = Buffer to write the escaped path to
 *   fname = Path to escape
 */
void escapePath(OutBuffer* buf, const(char)* fname)
{
    while (1)
    {
        switch (*fname)
        {
        case 0:
            return;
        case '(':
        case ')':
        case '\\':
            buf.writeByte('\\');
            goto default;
        default:
            buf.writeByte(*fname);
            break;
        }
        fname++;
    }
}

/**
 * Convert string to integer.
 *
 * Params:
 *  T = Type of integer to parse
 *  val = Variable to store the result in
 *  p = slice to start of string digits
 *  max = max allowable value (inclusive), defaults to `T.max`
 *
 * Returns:
 *  `false` on error, `true` on success
 */
bool parseDigits(T)(ref T val, const(char)[] p, const T max = T.max)
    @safe pure @nogc nothrow
{
    import core.checkedint : mulu, addu, muls, adds;

    // mul* / add* doesn't support types < int
    static if (T.sizeof < int.sizeof)
    {
        int value;
        alias add = adds;
        alias mul = muls;
    }
    // unsigned
    else static if (T.min == 0)
    {
        T value;
        alias add = addu;
        alias mul = mulu;
    }
    else
    {
        T value;
        alias add = adds;
        alias mul = muls;
    }

    bool overflow;
    foreach (char c; p)
    {
        if (c > '9' || c < '0')
            return false;
        value = mul(value, 10, overflow);
        value = add(value, uint(c - '0'), overflow);
    }
    // If it overflows, value must be > to `max` (since `max` is `T`)
    val = cast(T) value;
    return !overflow && value <= max;
}

///
@safe pure nothrow @nogc unittest
{
    byte b;
    ubyte ub;
    short s;
    ushort us;
    int i;
    uint ui;
    long l;
    ulong ul;

    assert(b.parseDigits("42") && b  == 42);
    assert(ub.parseDigits("42") && ub == 42);

    assert(s.parseDigits("420") && s  == 420);
    assert(us.parseDigits("42000") && us == 42_000);

    assert(i.parseDigits("420000") && i  == 420_000);
    assert(ui.parseDigits("420000") && ui == 420_000);

    assert(l.parseDigits("42000000000") && l  == 42_000_000_000);
    assert(ul.parseDigits("82000000000") && ul == 82_000_000_000);

    assert(!b.parseDigits(ubyte.max.stringof));
    assert(!b.parseDigits("WYSIWYG"));
    assert(!b.parseDigits("-42"));
    assert(!b.parseDigits("200"));
    assert(ub.parseDigits("200") && ub == 200);
    assert(i.parseDigits(int.max.stringof) && i == int.max);
    assert(i.parseDigits("420", 500) && i == 420);
    assert(!i.parseDigits("420", 400));
}
