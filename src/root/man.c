
// Compiler implementation of the D programming language
// Copyright (c) 2008-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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

#if linux || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4

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


