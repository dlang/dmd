/*
 * Some portions copyright (c) 1994-1995 by Symantec
 * Copyright (c) 1999-2015 by Digital Mars
 * All Rights Reserved
 * http://www.digitalmars.com
 * Written by Walter Bright
 *
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <ctype.h>

#if _WIN32
#include <windows.h>
#endif

#if __APPLE__
#include        <sys/syslimits.h>
#endif

#if __FreeBSD__ || __OpenBSD__ || __sun
// for PATH_MAX
#include        <limits.h>
#endif

#include        "root.h"
#include        "rmem.h"
#include        "port.h"

#define LOG     0

char *skipspace(char *p);

/*****************************
 * Find the config file
 * Input:
 *      argv0           program name (argv[0])
 *      inifile         .ini file name
 * Returns:
 *      file path of the config file or NULL
 *      Note: this is a memory leak
 */
const char *findConfFile(const char *argv0, const char *inifile)
{
#if LOG
    printf("findinifile(argv0 = '%s', inifile = '%s')\n", argv0, inifile);
#endif

    if (FileName::absolute(inifile))
        return inifile;
    if (FileName::exists(inifile))
        return inifile;

    /* Look for inifile in the following sequence of places:
     *      o current directory
     *      o home directory
     *      o exe directory (windows)
     *      o directory off of argv0
     *      o SYSCONFDIR (default=/etc/) (non-windows)
     */
    const char *filename = FileName::combine(getenv("HOME"), inifile);
    if (FileName::exists(filename))
        return filename;

#if _WIN32 // This fix by Tim Matthews
    char resolved_name[MAX_PATH + 1];
    if (GetModuleFileNameA(NULL, resolved_name, MAX_PATH + 1) && FileName::exists(resolved_name))
    {
        filename = FileName::replaceName(resolved_name, inifile);
        if (FileName::exists(filename))
            return filename;
    }
#endif

    filename = FileName::replaceName(argv0, inifile);
    if (FileName::exists(filename))
        return filename;

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    // Search PATH for argv0
    const char *p = getenv("PATH");
#if LOG
    printf("\tPATH='%s'\n", p);
#endif
    Strings *paths = FileName::splitPath(p);
    const char *abspath = FileName::searchPath(paths, argv0, false);
    if (abspath)
    {
        const char *absname = FileName::replaceName(abspath, inifile);
        if (FileName::exists(absname))
            return absname;
    }

    // Resolve symbolic links
    filename = FileName::canonicalName(abspath ? abspath : argv0);
    if (filename)
    {
        filename = FileName::replaceName(filename, inifile);
        if (FileName::exists(filename))
            return filename;
    }

    // Search /etc/ for inifile
#ifndef SYSCONFDIR
# error SYSCONFDIR not defined
#endif
    assert(SYSCONFDIR != NULL && strlen(SYSCONFDIR));
    filename = FileName::combine(SYSCONFDIR, inifile);
#endif // __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun

    return filename;
}

/*****************************
 * Read and analyze .ini file.
 * Write the entries into the process environment as
 * well as any entries in one of the specified section(s).
 *
 * Params:
 *      filename = path to config file
 *      sections[] = section namesdimension of array of section names
 */
void parseConfFile(const char *filename, Strings *sections)
{
    const char *path = FileName::path(filename); // need path for @P macro
#if LOG
    printf("\tpath = '%s', filename = '%s'\n", path, filename);
#endif

    File file(filename);

    if (file.read())
        return; // error reading file

    // Parse into lines
    bool envsection = true;     // default is to read

    OutBuffer buf;
    bool eof = false;
    for (size_t i = 0; i < file.len && !eof; i++)
    {
    Lstart:
        size_t linestart = i;

        for (; i < file.len; i++)
        {
            switch (file.buffer[i])
            {
                case '\r':
                    break;

                case '\n':
                    // Skip if it was preceded by '\r'
                    if (i && file.buffer[i - 1] == '\r')
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

        buf.reset();

        // First, expand the macros.
        // Macros are bracketed by % characters.

        for (size_t k = 0; k < i - linestart; k++)
        {
            // The line is file.buffer[linestart..i]
            char *line = (char *)&file.buffer[linestart];
            if (line[k] == '%')
            {
                for (size_t j = k + 1; j < i - linestart; j++)
                {
                    if (line[j] != '%')
                        continue;

                    if (j - k == 3 && Port::memicmp(&line[k + 1], "@P", 2) == 0)
                    {
                        // %@P% is special meaning the path to the .ini file
                        const char *p = path;
                        if (!*p)
                            p = ".";
                        buf.writestring(p);
                    }
                    else
                    {
                        size_t len2 = j - k;
                        char *p = (char *)malloc(len2);
                        len2--;
                        memcpy(p, &line[k + 1], len2);
                        p[len2] = 0;
                        Port::strupr(p);
                        char *penv = getenv(p);
                        if (penv)
                            buf.writestring(penv);
                        free(p);
                    }
                    k = j;
                    goto L1;
                }
            }
            buf.writeByte(line[k]);
         L1:
            ;
        }

        // Remove trailing spaces
        while (buf.offset && isspace(buf.data[buf.offset - 1]))
            buf.offset--;

        char *p = buf.peekString();

        // The expanded line is in p.
        // Now parse it for meaning.
        p = skipspace(p);
        switch (*p)
        {
            case ';':           // comment
            case 0:             // blank
                break;

            case '[':           // look for [Environment]
                p = skipspace(p + 1);
                char *pn;
                for (pn = p; isalnum((utf8_t)*pn); pn++)
                    ;

                if (*skipspace(pn) != ']')
                {
                    // malformed [sectionname], so just say we're not in a section
                    envsection = false;
                    break;
                }

                /* Seach sectionnamev[] for p..pn and set envsection to true if it's there
                 */
                for (size_t j = 0; 1; ++j)
                {
                    if (j == sections->dim)
                    {
                        // Didn't find it
                        envsection = false;
                        break;
                    }
                    const char *sectionname = (*sections)[j];
                    size_t len = strlen(sectionname);
                    if (pn - p == len &&
                        Port::memicmp(p, sectionname, len) == 0)
                    {
                        envsection = true;
                        break;
                    }
                }
                break;

            default:
                if (envsection)
                {
                    char *pn = p;

                    // Convert name to upper case;
                    // remove spaces bracketing =
                    for (p = pn; *p; p++)
                    {
                        if (islower((utf8_t)*p))
                            *p &= ~0x20;
                        else if (isspace((utf8_t)*p))
                        {
                            memmove(p, p + 1, strlen(p));
                            p--;
                        }
                        else if (p[0] == '?' && p[1] == '=')
                        {
                            *p = '\0';
                            if (getenv(pn))
                            {
                                pn = NULL;
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
                            while (isspace((utf8_t)*p))
                                memmove(p, p + 1, strlen(p));
                            break;
                        }
                    }

                    if (pn)
                    {
                        putenv(strdup(pn));
#if LOG
                        printf("\tputenv('%s')\n", pn);
                        //printf("getenv(\"TEST\") = '%s'\n",getenv("TEST"));
#endif
                    }
                }
                break;
        }
    }
    return;
}

/********************
 * Skip spaces.
 */

char *skipspace(char *p)
{
    while (isspace((utf8_t)*p))
        p++;
    return p;
}
