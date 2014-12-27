/**
 * This is a driver script that runs the benchmarks.
 *
 * Copyright: Copyright Martin Nowak 2011 -.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.ascii, std.exception, std.file, std.path,
    std.process, std.regex, std.stdio, std.string, std.typecons;

// cmdline flags
bool verbose;

void runCmd(string cmd)
{
    if (verbose)
        writeln(cmd);
    enforce(!system(cmd));
}

void runTest(string pattern, string dmd, string dflags)
{
    string[] sources;
    auto re = regex(pattern, "g");
    auto self = buildPath(".", "runbench.d");
    foreach(DirEntry src; dirEntries(".", SpanMode.depth))
    {
        if (src.isFile && !match(src.name, re).empty &&
            endsWith(src.name, ".d") && src.name != self)
        {
            sources ~= src.name;
        }
    }

    immutable bindir = absolutePath("bin");

    foreach(ref src; sources)
    {
        writeln("COMPILING ", src);
        auto bin = buildPath(bindir, src.chompPrefix("./").chomp(".d"));
        auto cmd = std.string.format("%s %s -op -odobj -of%s %s", dmd, dflags, bin, src);
        runCmd(cmd);
        src = bin;
    }

    foreach(bin; sources)
    {
        import std.datetime, std.algorithm : min;
        auto sw = StopWatch(AutoStart.yes);
        auto dur = Duration.max;

        stdout.writef("RUNNING %-20s", bin.relativePath(bindir));
        stdout.flush();
        foreach (_; 0 .. 10)
        {
            sw.reset;
            runCmd(bin);
            dur = min(dur, cast(Duration)sw.peek);
        }
        auto res = dur.split!("seconds", "msecs");
        writefln(" %s.%03s s", res.seconds, res.msecs);
    }
}

void printHelp()
{
    auto helpString =
        "usage: runbench [<tests>] [<dflags>] [-v|--verbose]"~newline~newline~

        "   tests  - List of regular expressions to select tests. Default: '.*\\.d'"~newline~
        "   dflags - Flags passed to compiler. Default: '-O -release -inline'"~newline~newline~
        "Don't pass any argument to run all tests with optimized builds.";

    writeln(helpString);
}

void main(string[] args)
{
    string[] patterns;
    string[] flags;

    foreach(arg; args[1 .. $])
    {
        if (arg == "-v" || arg == "--verbose")
            verbose = true;
        else if (arg == "--help")
        {
            printHelp();
            return;
        }
        else if (arg.length && arg[0] == '-') // DFLAGS
            flags ~= arg;
        else
            patterns ~= arg;
    }

    if (!patterns.length)
        patterns ~= r".*\.d";

    auto dflags = std.string.join(flags, " ");
    if (!dflags.length)
        dflags = "-O -release -inline";

    auto dmd = getenv("DMD");
    if (!dmd.length) dmd = "dmd";

    foreach(p; patterns)
        runTest(p, dmd, dflags);
}
