#!/usr/bin/env rdmd
/**
Generate the DMD man page automatically.

Copyright: D Language Foundation 2017.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

const header =
`.TH DMD 1 "%s" "The D Language Foundation" "The D Language Foundation"
.SH NAME
dmd \- Digital Mars D2.x Compiler
.SH SYNOPSIS
.B dmd \fIfiles\fR ... [ \fI-switch\fR ... ]
.SH DESCRIPTION
.B dmd
Compiles source code written in the D programming language.
.SH OPTIONS
.IP "file, file.d, file.htm, file.html"
D source files to compile
.IP file.di
D interface files
.IP file.o
Object files to link in
.IP file.a
Library files to link in
.IP @cmdfile
A file to read more command-line arguments from,
which may contain # single-line comments`;

const footer =
`.SH LINKING
Linking is done directly by the
.B dmd
compiler after a successful compile. To prevent
.B dmd
from running the linker, use the
.B -c
switch.
.PP
The actual linking is done by running \fBgcc\fR.
This ensures compatibility with modules compiled with
\fBgcc\fR.
.SH FILES
.I /etc/dmd.conf
dmd will look for the initialization file
.I dmd.conf
in the directory \fI/etc\fR.
If found, environment variable settings in the file will
override any existing settings.
.SH ENVIRONMENT
The D compiler dmd uses the following environment
variables:
.IP DFLAGS 10
The value of
.B DFLAGS
is treated as if it were appended on the command line to
\fBdmd\fR.
.SH AUTHOR
Copyright (c) 1999-%s by The D Language Foundation written by Walter Bright
.SH "ONLINE DOCUMENTATION"
.UR https://dlang.org/dmd.html
https://dlang.org/dmd.html
.UE
.SH "SEE ALSO"
.BR dmd.conf (5)
.BR rdmd (1)
.BR dumpobj (1)
.BR obj2asm (1)
.BR gcc (1)`;


string bold(string w)
{
    return `\fI` ~ w ~ `\fR`;
}

// capitalize the first letter
auto capitalize(string w)
{
    import std.range, std.uni;
    return w.take(1).asUpperCase.chain(w.dropOne);
}

void main()
{
    import std.algorithm, std.array, std.conv, std.datetime, std.range, std.stdio, std.uni;
    import std.process : environment;
    import dmd.cli;

    auto now = Clock.currTime;
    auto diffable = environment.get("DIFFABLE", "0");
    if (diffable == "1")
        now = SysTime(DateTime(2018, 1, 1));

    writefln(header, now.toISOExtString.take(10));

    foreach (option; Usage.options)
    {
        if (option.os.isCurrentTargetOS)
        {
            auto flag = option.flag.dup;
            string help = option.helpText.dup;
            if (flag.canFind("<") && flag.canFind(">"))
            {
                // detect special words in <...> and highlight them
                auto specialWord = flag.findSplit("<")[2].until(">").to!string;
                flag = flag.replace("<" ~ specialWord ~ ">", specialWord.bold);

                // highlight individual words in the description
                help = help.splitter(" ")
                    .map!((w){
                        auto wPlain = w.filter!(c => !c.among('<', '>', '`', '\'')).to!string;
                        return wPlain == specialWord ? wPlain.bold  : w;
                    })
                    .joiner(" ")
                    .to!string;
            }
            writefln(".IP -%s", flag);
            // Capitalize the first letter
            writeln(help.capitalize);
        }
    }

    writeln(`.SH TRANSITIONS
Language changes listed by \fB-transition=id\fR:`);
    foreach (transition; Usage.transitions)
    {
        if (!transition.documented)
            continue;
        string additionalOptions;
        writefln(".IP %s", transition.name.bold);
        writeln(transition.helpText.capitalize);
    }

    writefln(footer, now.year);
}
