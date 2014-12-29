/**
 * This is a driver script that runs the benchmarks.
 *
 * Copyright: Copyright Martin Nowak 2011 -.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.stdio;

// cmdline flags
bool verbose;

string runCmd(string cmd)
{
    import std.exception : enforce;
    import std.process : executeShell;

    if (verbose) writeln(cmd);
    auto res = executeShell(cmd);
    enforce(res.status == 0, res.output);
    return res.output;
}

void runTest(string pattern, string dmd, string dflags, string runArgs, uint repeat)
{
    import std.algorithm, std.file, std.path, std.regex, std.string;

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
        version (Windows) enum exe = "exe"; else enum exe = "";
        auto bin = buildPath(bindir, src.chompPrefix("./").setExtension(exe));
        auto cmd = std.string.format("%s %s -op -odobj -of%s %s", dmd, dflags, bin, src);
        runCmd(cmd);
        src = bin;
    }

    foreach(bin; sources)
    {
        import std.datetime, std.algorithm : min;
        auto sw = StopWatch(AutoStart.yes);
        auto minDur = Duration.max;

        stdout.writef("RUNNING %-20s", bin.relativePath(bindir));
        if (verbose) stdout.writeln();
        stdout.flush();

        auto cmd = bin ~ " " ~ runArgs;
        string gcprof;
        foreach (_; 0 .. repeat)
        {
            sw.reset;
            auto output = runCmd(cmd);
            auto dur = cast(Duration)sw.peek;
            if (verbose) stdout.write(output);

            if (dur >= minDur) continue;
            minDur = dur;

            auto lines = output.splitter(ctRegex!`\r\n|\r|\n`)
                .find!(ln => ln.startsWith("maxPoolMemory"));
            if (!lines.empty) gcprof = lines.front;
        }
        auto res = minDur.split!("seconds", "msecs");
        if (gcprof.length)
            writefln(" %s.%03s s, %s", res.seconds, res.msecs, gcprof);
        else
            writefln(" %s.%03s s", res.seconds, res.msecs, gcprof);
    }
}

void printHelp()
{
    import std.ascii : nl=newline;
    auto helpString =
        "usage: runbench [<test_regex>] [<dflags>] [-h|--help] [-v|--verbose] [-r n|--repeat=n] [-- <runargs>]"~nl~nl~

        "   tests   - Regular expressions to select tests. Default: '.*\\.d'"~nl~
        "   dflags  - Flags passed to compiler. Default: '-O -release -inline'"~nl~
        "   runargs - Arguments passed to each test, e.g. '--DRT-gcopt=profile=1'"~nl~nl~
        "Don't pass any argument to run all tests with optimized builds.";

    writeln(helpString);
}

void main(string[] args)
{
    import std.algorithm;

    string runArgs;
    {
        import std.range : only;
        string[] tmp = args;
        if (findSkip(tmp, only("--")))
        {
            runArgs = std.string.join(tmp, " ");
            args = args[0 .. $ - 1 - tmp.length];
        }
    }

    import std.getopt;
    bool help; uint repeat = 10;
    getopt(args, config.passThrough,
           "h|help", &help,
           "v|verbose", &verbose,
           "r|repeat", &repeat);

    string pattern = r".*\.d";
    if (args.length >= 2)
    {
        pattern = args[1];
        args = args.remove(1);
    }

    if (help) return printHelp();

    auto dflags = std.string.join(args[1 .. $], " ");
    if (!dflags.length)
        dflags = "-O -release -inline";

    import std.process : env=environment;
    auto dmd = env.get("DMD", "dmd");
    writeln("compiler: "~dmd~' '~dflags);

    runTest(pattern, dmd, dflags, runArgs, repeat);
}
