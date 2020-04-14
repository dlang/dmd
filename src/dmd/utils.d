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
    if (!File.write(filename, data))
    {
        error(loc, "Error writing file '%*.s'", filename.length, filename.ptr);
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
            error(loc, "cannot create directory %*.s", pt.length, pt.ptr);
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
 * Params:
 *  p = pointer to start of string digits, ending with 0
 *  max = max allowable value (inclusive)
 * Returns:
 *  uint.max on error, otherwise converted integer
 */
uint parseDigits(const(char)*p, const uint max) pure
{
    uint value;
    bool overflow;
    for (uint d; (d = uint(*p) - uint('0')) < 10; ++p)
    {
        import core.checkedint : mulu, addu;
        value = mulu(value, 10, overflow);
        value = addu(value, d, overflow);
    }
    return (overflow || value > max || *p) ? uint.max : value;
}
