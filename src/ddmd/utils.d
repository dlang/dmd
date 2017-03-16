/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 * Utility functions for DMD.
 *
 * This modules defines some utility functions for DMD.
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _utils.d)
 */

module ddmd.utils;

import core.stdc.string;
import ddmd.errors;
import ddmd.globals;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;


/**
 * Normalize path by turning forward slashes into backslashes
 *
 * Params:
 *   src = Source path, using unix-style ('/') path separators
 *
 * Returns:
 *   A newly-allocated string with '/' turned into backslashes
 */
extern (C++) const(char)* toWinPath(const(char)* src)
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
 *   f = a `ddmd.root.file.File` handle to read
 */
extern (C++) void readFile(Loc loc, File* f)
{
    if (f.read())
    {
        error(loc, "Error reading file '%s'", f.name.toChars());
        fatal();
    }
}


/**
 * Writes a file, terminate the program on error
 *
 * Params:
 *   loc = The line number information from where the call originates
 *   f = a `ddmd.root.file.File` handle to write
 */
extern (C++) void writeFile(Loc loc, File* f)
{
    if (f.write())
    {
        error(loc, "Error writing file '%s'", f.name.toChars());
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
extern (C++) void ensurePathToNameExists(Loc loc, const(char)* name)
{
    const(char)* pt = FileName.path(name);
    if (*pt)
    {
        if (FileName.ensurePathExists(pt))
        {
            error(loc, "cannot create directory %s", pt);
            fatal();
        }
    }
    FileName.free(pt);
}


/**
 * Takes a path, and escapes '(', ')' and backslashes
 *
 * Params:
 *   buf = Buffer to write the escaped path to
 *   fname = Path to escape
 */
extern (C++) void escapePath(OutBuffer* buf, const(char)* fname)
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
