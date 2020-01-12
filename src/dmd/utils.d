/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 * Utility functions for DMD.
 *
 * This modules defines some utility functions for DMD.
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
import dmd.root.rmem;


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
    auto result = File.read(filename);
    if (!result.success)
    {
        error(loc, "Error reading file '%s'", filename);
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

/// Slices a `\0`-terminated C-string, excluding the terminator
inout(char)[] toDString (inout(char)* s) pure nothrow @nogc
{
    return s ? s[0 .. strlen(s)] : null;
}

/**
Copy the content of `src` into a C-string ('\0' terminated) then call `dg`

The intent of this function is to provide an allocation-less
way to call a C function using a D slice.
The function internally allocates a buffer if needed, but frees it on exit.

Note:
The argument to `dg` is `scope`. To keep the data around after `dg` exits,
one has to copy it.

Params:
src = Slice to use to call the C function
dg  = Delegate to call afterwards

Returns:
The return value of `T`
*/
auto toCStringThen(alias dg)(const(char)[] src) nothrow
{
    const len = src.length + 1;
    char[512] small = void;
    scope ptr = (src.length < (small.length - 1))
                    ? small[0 .. len]
                    : (cast(char*)mem.xmalloc(len))[0 .. len];
    scope (exit)
    {
        if (&ptr[0] != &small[0])
            mem.xfree(&ptr[0]);
    }
    ptr[0 .. src.length] = src[];
    ptr[src.length] = '\0';
    return dg(ptr);
}

unittest
{
    assert("Hello world".toCStringThen!((v) => v == "Hello world\0"));
    assert("Hello world\0".toCStringThen!((v) => v == "Hello world\0\0"));
    assert(null.toCStringThen!((v) => v == "\0"));
}
