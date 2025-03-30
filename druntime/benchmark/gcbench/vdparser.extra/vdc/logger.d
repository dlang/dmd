// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.logger;

import std.stdio;
import std.datetime;
import std.conv;
import std.string;
import std.array;

extern(Windows) void OutputDebugStringA(const char* lpOutputString);
extern(Windows) uint GetCurrentThreadId();

import core.sys.windows.windows;

__gshared int   gLogIndent = 0;
__gshared bool  gLogFirst = true;
__gshared const string gLogFile = "c:/tmp/parser.log";

//debug version = enableLog;

version(enableLog) {

    struct LogIndent
    {
        this(int n)
        {
            indent = n;
            gLogIndent += indent;
        }
        ~this()
        {
            gLogIndent -= indent;
        }
        int indent;
    }

    mixin template logIndent(int n = 1)
    {
        LogIndent indent = LogIndent(n);
    }

    class logSync {}

    void logInfo(...)
    {
        auto buffer = new char[17 + 1];
        SysTime now = Clock.currTime();
        uint tid = GetCurrentThreadId();
        auto len = sprintf(buffer.ptr, "%02d:%02d:%02d - %04x - ",
                           now.hour, now.minute, now.second, tid);
        string s = to!string(buffer[0..len]);
        s ~= replicate(" ", gLogIndent);

        void putc(dchar c)
        {
            s ~= c;
        }

        try {
            std.format.doFormat(&putc, _arguments, _argptr);
        }
        catch(Exception e)
        {
            string msg = e.toString();
            s ~= " EXCEPTION";
        }

        log_string(s);
    }

    void log_string(string s)
    {
        s ~= "\n";
        if(gLogFile.length == 0)
            OutputDebugStringA(toStringz(s));
        else
            synchronized(typeid(logSync))
            {
                if(gLogFirst)
                {
                    gLogFirst = false;
                    s = "\n" ~ replicate("=", 80) ~ "\n" ~ s;
                }
                std.file.append(gLogFile, s);
            }
    }
}
else
{
    import core.vararg;

    struct LogIndent
    {
        this(int n)
        {
        }
    }
    void logInfo(...)
    {
    }
    void log_string(string s)
    {
    }
}
