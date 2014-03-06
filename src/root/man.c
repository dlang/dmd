
/* Copyright (c) 2008-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/man.c
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#if _WIN32

#include <windows.h>

#pragma comment(lib,"shell32.lib")

void browse(const char *url)
{
    ShellExecute(NULL, "open", url, NULL, NULL, SW_SHOWNORMAL);
}

#endif

#if __linux__ || __FreeBSD__ || __OpenBSD__ || __sun

#include        <sys/types.h>
#include        <sys/wait.h>
#include        <unistd.h>

void browse(const char *url)
{
    pid_t childpid;
    const char *args[3];

    const char *browser = getenv("BROWSER");
    if (browser)
        browser = strdup(browser);
    else
        browser = "x-www-browser";

    args[0] = browser;
    args[1] = url;
    args[2] = NULL;

    childpid = fork();
    if (childpid == 0)
    {
        execvp(args[0], (char**)args);
        perror(args[0]);                // failed to execute
        return;
    }
}

#endif

#if __APPLE__

#include        <sys/types.h>
#include        <sys/wait.h>
#include        <unistd.h>

void browse(const char *url)
{
    pid_t childpid;
    const char *args[5];

    char *browser = getenv("BROWSER");
    if (browser)
    {   browser = strdup(browser);
        args[0] = browser;
        args[1] = url;
        args[2] = NULL;
    }
    else
    {
        //browser = "/Applications/Safari.app/Contents/MacOS/Safari";
        args[0] = "open";
        args[1] = "-a";
        args[2] = "/Applications/Safari.app";
        args[3] = url;
        args[4] = NULL;
    }

    childpid = fork();
    if (childpid == 0)
    {
        execvp(args[0], (char**)args);
        perror(args[0]);                // failed to execute
        return;
    }
}

#endif


