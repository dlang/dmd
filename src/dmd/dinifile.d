/**
 * Parses compiler settings from a .ini file.
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dinifile.d, _dinifile.d)
 * Documentation:  https://dlang.org/phobos/dmd_dinifile.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dinifile.d
 */

module dmd.dinifile;

import core.stdc.ctype;
import core.stdc.string;
import core.sys.posix.stdlib;
import core.sys.windows.winbase;
import core.sys.windows.windef;

import dmd.errors;
import dmd.globals;
import dmd.root.env;
import dmd.root.rmem;
import dmd.root.filename;
import dmd.common.outbuffer;
import dmd.root.port;
import dmd.root.string;
import dmd.root.stringtable;

private enum LOG = false;

/*****************************
 * Find the config file
 * Params:
 *      argv0 = program name (argv[0])
 *      inifile = .ini file name
 * Returns:
 *      file path of the config file or NULL
 *      Note: this is a memory leak
 */
const(char)[] findConfFile(const(char)[] argv0, const(char)[] inifile)
{
    static if (LOG)
    {
        printf("findinifile(argv0 = '%.*s', inifile = '%.*s')\n",
               cast(int)argv0.length, argv0.ptr, cast(int)inifile.length, inifile.ptr);
    }
    if (FileName.absolute(inifile))
        return inifile;
    if (FileName.exists(inifile))
        return inifile;
    /* Look for inifile in the following sequence of places:
     *      o current directory
     *      o home directory
     *      o exe directory (windows)
     *      o directory off of argv0
     *      o SYSCONFDIR=/etc (non-windows)
     */
    auto filename = FileName.combine(getenv("HOME").toDString, inifile);
    if (FileName.exists(filename))
        return filename;
    version (Windows)
    {
        // This fix by Tim Matthews
        char[MAX_PATH + 1] resolved_name;
        const len = GetModuleFileNameA(null, resolved_name.ptr, MAX_PATH + 1);
        if (len && FileName.exists(resolved_name[0 .. len]))
        {
            filename = FileName.replaceName(resolved_name[0 .. len], inifile);
            if (FileName.exists(filename))
                return filename;
        }
    }
    filename = FileName.replaceName(argv0, inifile);
    if (FileName.exists(filename))
        return filename;
    version (Posix)
    {
        // Search PATH for argv0
        const p = getenv("PATH");
        static if (LOG)
        {
            printf("\tPATH='%s'\n", p);
        }
        auto abspath = FileName.searchPath(p, argv0, false);
        if (abspath)
        {
            auto absname = FileName.replaceName(abspath, inifile);
            if (FileName.exists(absname))
                return absname;
        }
        // Resolve symbolic links
        filename = FileName.canonicalName(abspath ? abspath : argv0);
        if (filename)
        {
            filename = FileName.replaceName(filename, inifile);
            if (FileName.exists(filename))
                return filename;
        }
        // Search SYSCONFDIR=/etc for inifile
        filename = FileName.combine(import("SYSCONFDIR.imp"), inifile);
    }
    return filename;
}

/**********************************
 * Read from environment, looking for cached value first.
 * Params:
 *      environment = cached copy of the environment
 *      name = name to look for
 * Returns:
 *      environment value corresponding to name
 */
const(char)* readFromEnv(const ref StringTable!(char*) environment, const(char)* name)
{
    const len = strlen(name);
    const sv = environment.lookup(name, len);
    if (sv && sv.value)
        return sv.value; // get cached value
    return getenv(name);
}

/*********************************
 * Write to our copy of the environment, not the real environment
 */
private bool writeToEnv(ref StringTable!(char*) environment, char* nameEqValue)
{
    auto p = strchr(nameEqValue, '=');
    if (!p)
        return false;
    auto sv = environment.update(nameEqValue, p - nameEqValue);
    sv.value = p + 1;
    return true;
}

/************************************
 * Update real environment with our copy.
 * Params:
 *      environment = our copy of the environment
 */
void updateRealEnvironment(ref StringTable!(char*) environment)
{
    foreach (sv; environment)
    {
        const name = sv.toDchars();
        const value = sv.value;
        if (!value) // deleted?
            continue;
        if (putenvRestorable(name.toDString, value.toDString))
            assert(0);
    }
}

/*****************************
 * Read and analyze .ini file.
 * Write the entries into environment as
 * well as any entries in one of the specified section(s).
 *
 * Params:
 *      environment = our own cache of the program environment
 *      filename = name of the file being parsed
 *      path = what @P will expand to
 *      buffer = contents of configuration file
 *      sections = section names
 */
void parseConfFile(ref StringTable!(char*) environment, const(char)[] filename, const(char)[] path, const(ubyte)[] buffer, const(Strings)* sections)
{
    /********************
     * Skip spaces.
     */
    static inout(char)* skipspace(inout(char)* p)
    {
        while (isspace(*p))
            p++;
        return p;
    }

    // Parse into lines
    bool envsection = true; // default is to read
    OutBuffer buf;
    bool eof = false;
    int lineNum = 0;
    for (size_t i = 0; i < buffer.length && !eof; i++)
    {
    Lstart:
        const linestart = i;
        for (; i < buffer.length; i++)
        {
            switch (buffer[i])
            {
            case '\r':
                break;
            case '\n':
                // Skip if it was preceded by '\r'
                if (i && buffer[i - 1] == '\r')
                {
                    i++;
                    goto Lstart;
                }
                break;
            case 0:
            case 0x1A:
                eof = true;
                break;
            default:
                continue;
            }
            break;
        }
        ++lineNum;
        buf.setsize(0);
        // First, expand the macros.
        // Macros are bracketed by % characters.
    Kloop:
        for (size_t k = 0; k < i - linestart; ++k)
        {
            // The line is buffer[linestart..i]
            const line = cast(const char*)&buffer[linestart];
            if (line[k] == '%')
            {
                foreach (size_t j; k + 1 .. i - linestart)
                {
                    if (line[j] != '%')
                        continue;
                    if (j - k == 3 && Port.memicmp(&line[k + 1], "@P", 2) == 0)
                    {
                        // %@P% is special meaning the path to the .ini file
                        auto p = path;
                        if (!p.length)
                            p = ".";
                        buf.writestring(p);
                    }
                    else
                    {
                        auto len2 = j - k;
                        auto p = cast(char*)Mem.check(malloc(len2));
                        len2--;
                        memcpy(p, &line[k + 1], len2);
                        p[len2] = 0;
                        Port.strupr(p);
                        const penv = readFromEnv(environment, p);
                        if (penv)
                            buf.writestring(penv);
                        free(p);
                    }
                    k = j;
                    continue Kloop;
                }
            }
            buf.writeByte(line[k]);
        }

        // Remove trailing spaces
        const slice = buf[];
        auto slicelen = slice.length;
        while (slicelen && isspace(slice[slicelen - 1]))
            --slicelen;
        buf.setsize(slicelen);

        auto p = buf.peekChars();
        // The expanded line is in p.
        // Now parse it for meaning.
        p = skipspace(p);
        switch (*p)
        {
        case ';':
            // comment
        case 0:
            // blank
            break;
        case '[':
            // look for [Environment]
            p = skipspace(p + 1);
            char* pn;
            for (pn = p; isalnum(*pn); pn++)
            {
            }
            if (*skipspace(pn) != ']')
            {
                // malformed [sectionname], so just say we're not in a section
                envsection = false;
                break;
            }
            /* Search sectionnamev[] for p..pn and set envsection to true if it's there
             */
            for (size_t j = 0; 1; ++j)
            {
                if (j == sections.dim)
                {
                    // Didn't find it
                    envsection = false;
                    break;
                }
                const sectionname = (*sections)[j];
                const len = strlen(sectionname);
                if (pn - p == len && Port.memicmp(p, sectionname, len) == 0)
                {
                    envsection = true;
                    break;
                }
            }
            break;
        default:
            if (envsection)
            {
                auto pn = p;
                // Convert name to upper case;
                // remove spaces bracketing =
                for (; *p; p++)
                {
                    if (islower(*p))
                        *p &= ~0x20;
                    else if (isspace(*p))
                    {
                        memmove(p, p + 1, strlen(p));
                        p--;
                    }
                    else if (p[0] == '?' && p[1] == '=')
                    {
                        *p = '\0';
                        if (readFromEnv(environment, pn))
                        {
                            pn = null;
                            break;
                        }
                        // remove the '?' and resume parsing starting from
                        // '=' again so the regular variable format is
                        // parsed
                        memmove(p, p + 1, strlen(p + 1) + 1);
                        p--;
                    }
                    else if (*p == '=')
                    {
                        p++;
                        while (isspace(*p))
                            memmove(p, p + 1, strlen(p));
                        break;
                    }
                }
                if (pn)
                {
                    auto pns = cast(char*)Mem.check(strdup(pn));
                    if (!writeToEnv(environment, pns))
                    {
                        const loc = Loc(filename.xarraydup.ptr, lineNum, 0); // TODO: use r-value when `error` supports it
                        error(loc, "use `NAME=value` syntax, not `%s`", pn);
                        fatal();
                    }
                    static if (LOG)
                    {
                        printf("\tputenv('%s')\n", pn);
                        //printf("getenv(\"TEST\") = '%s'\n",getenv("TEST"));
                    }
                }
            }
            break;
        }
    }
}
