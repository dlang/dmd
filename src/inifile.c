/*
 * Some portions copyright (c) 1994-1995 by Symantec
 * Copyright (c) 1999-2013 by Digital Mars
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

#ifndef SYSCONFDIR
#define SYSCONFDIR "/etc/"
#endif

char *skipspace(const char *p);


/*****************************
 * Read and analyze .ini file, i.e. write the entries of the specified section
 *  into the process environment
 * Input:
 *      argv0           program name (argv[0])
 *      inifile         .ini file name
 *      envsectionname  name of the section to process
 * Returns:
 *      file name of ini file
 *      Note: this is a memory leak
 */

const char *inifile(const char *argv0x, const char *inifilex, const char *envsectionname)
{
    char *argv0 = (char *)argv0x;
    char *inifile = (char *)inifilex;   // do const-correct later
    char *path;         // need path for @P macro
    char *filename;
    OutBuffer buf;
    int envsection = 0;
    size_t envsectionnamelen = strlen(envsectionname);

#if LOG
    printf("inifile(argv0 = '%s', inifile = '%s')\n", argv0, inifile);
#endif
    if (FileName::absolute(inifile))
    {
        filename = inifile;
    }
    else
    {
        /* Look for inifile in the following sequence of places:
         *      o current directory
         *      o home directory
         *      o directory off of argv0
         *      o SYSCONFDIR (default=/etc/)
         */
        if (FileName::exists(inifile))
        {
            filename = inifile;
        }
        else
        {
            filename = (char *)FileName::combine(getenv("HOME"), inifile);
            if (!FileName::exists(filename))
            {
#if _WIN32 // This fix by Tim Matthews
                char resolved_name[MAX_PATH + 1];
                if(GetModuleFileName(NULL, resolved_name, MAX_PATH + 1) && FileName::exists(resolved_name))
                {
                        filename = (char *)FileName::replaceName(resolved_name, inifile);
                        if(FileName::exists(filename))
                                goto Ldone;
                }
#endif
                filename = (char *)FileName::replaceName(argv0, inifile);
                if (!FileName::exists(filename))
                {
#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
#if __GLIBC__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun   // This fix by Thomas Kuehne
                    /* argv0 might be a symbolic link,
                     * so try again looking past it to the real path
                     */
#if __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
                    char resolved_name[PATH_MAX + 1];
                    char* real_argv0 = realpath(argv0, resolved_name);
#else
                    char* real_argv0 = realpath(argv0, NULL);
#endif
                    //printf("argv0 = %s, real_argv0 = %p\n", argv0, real_argv0);
                    if (real_argv0)
                    {
                        filename = (char *)FileName::replaceName(real_argv0, inifile);
#if __linux__
                        free(real_argv0);
#endif
                        if (FileName::exists(filename))
                            goto Ldone;
                    }
#else
#error use of glibc non-standard extension realpath(char*, NULL)
#endif
                    if (1){
                    // Search PATH for argv0
                    const char *p = getenv("PATH");
#if LOG
                    printf("\tPATH='%s'\n", p);
#endif
                    Strings *paths = FileName::splitPath(p);
                    filename = (char *)FileName::searchPath(paths, argv0, 0);
                    if (!filename)
                        goto Letc;              // argv0 not found on path
                    filename = (char *)FileName::replaceName(filename, inifile);
                    if (FileName::exists(filename))
                        goto Ldone;
                    }
                    // Search /etc/ for inifile
                Letc:
#endif
                    filename = (char *)FileName::combine((char *)SYSCONFDIR, inifile);

                Ldone:
                    ;
                }
            }
        }
    }
    path = (char *)FileName::path(filename);
#if LOG
    printf("\tpath = '%s', filename = '%s'\n", path, filename);
#endif

    File file(filename);

    if (file.read())
        return filename;                        // error reading file

    // Parse into lines
    int eof = 0;
    for (size_t i = 0; i < file.len && !eof; i++)
    {
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
                        goto Lskip;
                    break;

                case 0:
                case 0x1A:
                    eof = 1;
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
                    if (line[j] == '%')
                    {
                        char *p = NULL;
                        char *palloc = NULL;
                        if (j - k == 3 && Port::memicmp(&line[k + 1], "@P", 2) == 0)
                        {
                            // %@P% is special meaning the path to the .ini file
                            p = path;
                            if (!*p)
                                p = (char *)".";
                        }
                        else
                        {   size_t len2 = j - k;
                            char tmp[10];       // big enough most of the time

                            if (len2 <= sizeof(tmp))
                                p = tmp;
                            else
                            {   p = (char *)malloc(len2);
                                palloc = p;
                            }
                            len2--;
                            memcpy(p, &line[k + 1], len2);
                            p[len2] = 0;
                            Port::strupr(p);
                            p = getenv(p);
                            if (!p)
                                p = (char *)"";
                        }
                        buf.writestring(p);
                        if (palloc)
                            free(palloc);
                        k = j;
                        goto L1;
                    }
                }
            }
            buf.writeByte(line[k]);
         L1:
            ;
        }

        // Remove trailing spaces
        while (buf.offset && isspace(buf.data[buf.offset - 1]))
            buf.offset--;

        {
        char *p = buf.toChars();

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
                if (pn - p == envsectionnamelen &&
                    Port::memicmp(p, envsectionname, envsectionnamelen) == 0 &&
                    *skipspace(pn) == ']'
                   )
                    envsection = 1;
                else
                    envsection = 0;
                break;

            default:
                if (envsection)
                {
                    char *pn = p;

                    // Convert name to upper case;
                    // remove spaces bracketing =
                    for (p = pn; *p; p++)
                    {   if (islower((utf8_t)*p))
                            *p &= ~0x20;
                        else if (isspace((utf8_t)*p))
                            memmove(p, p + 1, strlen(p));
                        else if (*p == '=')
                        {
                            p++;
                            while (isspace((utf8_t)*p))
                                memmove(p, p + 1, strlen(p));
                            break;
                        }
                    }

                    putenv(strdup(pn));
#if LOG
                    printf("\tputenv('%s')\n", pn);
                    //printf("getenv(\"TEST\") = '%s'\n",getenv("TEST"));
#endif
                }
                break;
        }
        }

     Lskip:
        ;
    }
    return filename;
}

/********************
 * Skip spaces.
 */

char *skipspace(const char *p)
{
    while (isspace((utf8_t)*p))
        p++;
    return (char *)p;
}

