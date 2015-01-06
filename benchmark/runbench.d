/**
 * This is a driver script that runs the benchmarks.
 *
 * Copyright: Copyright Martin Nowak 2011 -.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.stdio;

extern(C) __gshared bool rt_cmdline_enabled = false;

struct Config
{
    string pattern = r".*\.d", dmd = "dmd", dflags = "-O -release -inline", args;
    bool help, verbose;
    uint repeat = 10;
}

string runCmd(string cmd, bool verbose)
{
    import std.exception : enforce;
    import std.process : executeShell;

    if (verbose) writeln(cmd);
    auto res = executeShell(cmd);
    enforce(res.status == 0, res.output);
    return res.output;
}

void runTests(Config cfg)
{
    import std.algorithm, std.file, std.path, std.regex, std.string;

    if (exists("gcx.log")) remove("gcx.log");

    string[] sources;
    auto re = regex(cfg.pattern, "g");
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
        auto cmd = std.string.format("%s %s -op -odobj -of%s %s", cfg.dmd, cfg.dflags, bin, src);
        runCmd(cmd, cfg.verbose);
        src = bin;
    }

    foreach(bin; sources)
    {
        import std.datetime, std.algorithm : min;
        auto sw = StopWatch(AutoStart.yes);
        auto minDur = Duration.max;

        stdout.writef("R %-16s", bin.baseName.stripExtension);
        if (cfg.verbose) stdout.writeln();
        stdout.flush();

        auto cmd = bin ~ " " ~ cfg.args;
        string gcprof;
        foreach (_; 0 .. cfg.repeat)
        {
            sw.reset;
            auto output = runCmd(cmd, cfg.verbose);
            auto dur = cast(Duration)sw.peek;
            if (cfg.verbose) stdout.write(output);

            if (dur >= minDur) continue;
            minDur = dur;

            if (exists("gcx.log"))
            {
                auto tgt = bin.setExtension("gcx.log");
                rename("gcx.log", tgt);
                auto lines = File(tgt, "r").byLine()
                    .find!(ln => ln.canFind("maxPoolMemory"));
                if (!lines.empty) gcprof = lines.front.find("GC summary:")[11..$].idup;
            }
            else
            {
                auto lines = output.splitter(ctRegex!`\r\n|\r|\n`)
                    .find!(ln => ln.startsWith("GC summary:"));
                if (!lines.empty) gcprof = lines.front[11..$];
            }
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
        "usage: runbench [-h|--help] [-v|--verbose] [-r n|--repeat=n] [<test_regex>] [<dflags>] [-- <runargs>]"~nl~nl~

        "   tests   - Regular expressions to select tests. Default: '.*\\.d'"~nl~
        "   dflags  - Flags passed to compiler. Default: '-O -release -inline'"~nl~
        "   runargs - Arguments passed to each test, e.g. '--DRT-gcopt=profile=1'"~nl~nl~
        "Don't pass any argument to run all tests with optimized builds.";

    writeln(helpString);
}

Config parseArgs(string[] args)
{
    import std.algorithm, std.string : join;

    Config cfg;
    {
        import std.range : only;
        string[] tmp = args;
        if (findSkip(tmp, only("--")))
        {
            import std.process : escapeShellCommand;
            cfg.args = escapeShellCommand(tmp);
            args = args[0 .. $ - 1 - tmp.length];
        }
    }

    import std.getopt;
    getopt(args, config.stopOnFirstNonOption,
           config.passThrough,
           "h|help", &cfg.help,
           "v|verbose", &cfg.verbose,
           "r|repeat", &cfg.repeat);

    if (args.length >= 2 && !args[1].startsWith("-"))
    {
        cfg.pattern = args[1];
        args = args.remove(1);
    }

    if (args.length > 1)
        cfg.dflags = join(args[1 .. $], " ");

    return cfg;
}

unittest
{
    template cfg(N...)
    {
        static Config cfg(T...)(T vals) if (T.length == N.length)
        {
            Config res;
            foreach (i, ref v; vals) __traits(getMember, res, N[i]) = v;
            return res;
        }
    }

    import std.typecons : t=tuple;
    auto check = [
        t(["bin"], cfg),
        t(["bin", "-h"], cfg!("help")(true)),
        t(["bin", "-v"], cfg!("verbose")(true)),
        t(["bin", "-h", "-v"], cfg!("help", "verbose")(true, true)),
        t(["bin", "gcbench"], cfg!("pattern")("gcbench")),
        t(["bin", "-v", "gcbench"], cfg!("pattern", "verbose")("gcbench", true)),
        t(["bin", "-r", "4", "gcbench"], cfg!("pattern", "repeat")("gcbench", 4)),
        t(["bin", "-g"], cfg!("dflags")("-g")),
        t(["bin", "gcbench", "-g"], cfg!("pattern", "dflags")("gcbench", "-g")),
        t(["bin", "-r", "2", "gcbench", "-g"], cfg!("pattern", "dflags", "repeat")("gcbench", "-g", 2)),
        t(["bin", "--", "--DRT-gcopt=profile:1"], cfg!("args")("--DRT-gcopt=profile:1")),
        t(["bin", "--", "foo", "bar"], cfg!("args")("foo bar")),
        t(["bin", "gcbench", "--", "args"], cfg!("pattern", "args")("gcbench", "args")),
        t(["bin", "--repeat=5", "gcbench", "--", "args"], cfg!("pattern", "args", "repeat")("gcbench", "args", 5)),
    ];
    foreach (pair; check)
        assert(parseArgs(pair[0]) == pair[1]);
}

void main()
{
    import core.runtime;
    // use Runtime.args for --DRT-gcopt
    auto cfg = parseArgs(Runtime.args);
    if (cfg.help) return printHelp();

    import std.process : env=environment;
    cfg.dmd = env.get("DMD", "dmd");
    writeln("compiler: "~cfg.dmd~' '~cfg.dflags);

    runTests(cfg);
}
