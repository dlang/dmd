// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.man;

import core.stdc.stdio, core.stdc.stdlib, core.stdc.string, core.sys.posix.sys.types, core.sys.posix.sys.wait, core.sys.posix.unistd, core.sys.windows.windows;

version (Windows)
{
    extern (C++) void browse(const(char)* url)
    {
        ShellExecuteA(null, "open", url, null, null, SW_SHOWNORMAL);
    }
}
else version (OSX)
{
    extern (C++) void browse(const(char)* url)
    {
        pid_t childpid;
        const(char)*[5] args;
        char* browser = getenv("BROWSER");
        if (browser)
        {
            browser = strdup(browser);
            args[0] = browser;
            args[1] = url;
            args[2] = null;
        }
        else
        {
            //browser = "/Applications/Safari.app/Contents/MacOS/Safari";
            args[0] = "open";
            args[1] = "-a";
            args[2] = "/Applications/Safari.app";
            args[3] = url;
            args[4] = null;
        }
        childpid = fork();
        if (childpid == 0)
        {
            execvp(args[0], cast(char**)args);
            perror(args[0]); // failed to execute
            return;
        }
    }
}
else version (Posix)
{
    extern (C++) void browse(const(char)* url)
    {
        pid_t childpid;
        const(char)*[3] args;
        const(char)* browser = getenv("BROWSER");
        if (browser)
            browser = strdup(browser);
        else
            browser = "x-www-browser";
        args[0] = browser;
        args[1] = url;
        args[2] = null;
        childpid = fork();
        if (childpid == 0)
        {
            execvp(args[0], cast(char**)args);
            perror(args[0]); // failed to execute
            return;
        }
    }
}
