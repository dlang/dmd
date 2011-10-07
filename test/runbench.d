/**
 * This is a driver script that runs the benchmarks.
 *
 * Copyright: Copyright David Simcha 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   David Simcha
 */

/*          Copyright David Simcha 2011 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
import std.datetime, std.exception, std.file, std.getopt,
    std.path, std.process, std.regex, std.stdio, std.string, std.typecons;

// cmdline flags
bool verbose;

void runCmd(string cmd)
{
    if (verbose)
        writeln(cmd);
    enforce(!system(cmd));
}

void runTest(string pattern)
{
    string[] sources;
    auto re = regex(pattern, "g");
    auto self = buildPath(curdir, "runbench.d");
    foreach(DirEntry src; dirEntries(curdir, SpanMode.depth))
    {
        if (src.isFile && !match(src.name, re).empty &&
            endsWith(src.name, ".d") && src.name != self)
        {
            sources ~= src.name;
        }
    }

    foreach(ref src; sources)
    {
        writeln("COMPILING ", src);
        auto bin = buildPath("bin", src.chomp(".d"));
        runCmd("dmd -O -release -inline -op -odobj -of" ~ bin ~ " " ~ src);
        src = bin;
    }

    foreach(bin; sources)
    {
        StopWatch sw;

        version (Windows)
            bin = bin.chompPrefix("./");

        writeln("RUNNING ", baseName(bin));
        sw.start;
        runCmd(bin);
        sw.stop;

        auto p = sw.peek;
        writefln("  took %s.%s sec.", p.seconds, p.msecs % 1000);
        sw.reset;
    }
}

void main(string[] args) {
    getopt(args,
           "verbose|v", &verbose,
    );

    args = args[1 .. $];
    foreach(arg; args.length ? args : [r".*\.d"])
        runTest(arg);
}
