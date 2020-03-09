#!/usr/bin/env rdmd
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
    string pattern = r".*\.d", dmd = "dmd", dflags = "-mcpu=native -O -release -inline", args;
    bool help, verbose, compile = true;
    uint repeat = 10;
}

string runCmd(string cmd, bool verbose, in char[] workDir = null)
{
    import std.exception : enforce;
    import std.process : executeShell, Config;

    if (verbose) writeln(cmd);
    auto res = executeShell(cmd, null, Config.none, size_t.max, workDir);
    enforce(res.status == 0, res.output);
    return res.output;
}

string extraSourceOf(string path)
{
    import std.path, std.string;

    string dir = path.dirName;
    while(dir != path)
    {
        string base = dir.baseName;
        if(base.endsWith(".extra"))
            return dir[0..$-6] ~ ".d";
        path = dir;
        dir = path.dirName;
    }
    return null;
}

void runTests(Config cfg)
{
    import std.algorithm, std.file, std.path, std.regex, std.string;

    if (exists("gcx.log")) remove("gcx.log");

    string[] sources;
    string[string] extra_sources;
    auto re = regex(cfg.pattern, "g");
    auto cwd = __FILE_FULL_PATH__.dirName;
    auto self = buildPath(cwd, "runbench.d");
    foreach(DirEntry src; dirEntries(cwd, "*.d", SpanMode.depth))
    {
        if (!src.isFile || src.name == self || src.name.withExtension(".ignore").exists)
            continue;

        string mainsrc = extraSourceOf(src.name);
        if (mainsrc)
        {
            if (cfg.verbose) writeln(src.name, " is extra file for ", mainsrc);
            extra_sources[mainsrc] ~= " " ~ src.name;
        }
        else if (!match(src.name, re).empty)
            sources ~= src.name;
    }

    import std.parallelism : parallel;
    immutable bindir = absolutePath("bin", cwd);
    immutable objdir = absolutePath("obj", cwd);

    foreach(ref src; sources.parallel(1))
    {
        version (Windows) enum exe = "exe"; else enum exe = "";
        auto bin = buildPath(bindir, src.relativePath(cwd).setExtension(exe));
        auto obj = buildPath(objdir, src.relativePath(cwd).setExtension(exe));
        auto cmd = std.string.format("%s %s -op -od%s -of%s %s", cfg.dmd, cfg.dflags, obj, bin, src);
        if (auto ex = src in extra_sources)
            cmd ~= " -I" ~ src[0..$-2] ~ ".extra" ~ *ex;
        if (cfg.compile)
        {
            writeln("COMPILING ", src);
            runCmd(cmd, cfg.verbose);
        }
        src = bin;
    }

    foreach(bin; sources)
    {
        import core.time : Duration;
        import std.algorithm : min;
        import std.datetime.stopwatch : AutoStart, StopWatch;
        auto sw = StopWatch(AutoStart.yes);
        auto minDur = Duration.max;
        string minGCProf;

        immutable benchName = bin.baseName.stripExtension;

        void report(string pfx, Duration dur, string gcProf)
        {
            auto parts = dur.split!("seconds", "msecs");
            if (gcProf.length)
                writefln("%s %-16s %s.%03s s, %s", pfx, benchName, parts.seconds, parts.msecs, gcProf);
            else
                writefln("%s %-16s %s.%03s s", pfx, benchName, parts.seconds, parts.msecs);
        }

        auto cmd = bin ~ " " ~ cfg.args;
        foreach (_; 0 .. cfg.repeat)
        {
            sw.reset;
            auto output = runCmd(cmd, cfg.verbose, cwd);
            auto dur = cast(Duration)sw.peek;

            auto parts = dur.split!("seconds", "msecs");

            if (cfg.verbose) stdout.write(output);

            string gcProf;
            if (exists("gcx.log"))
            {
                auto tgt = bin.setExtension("gcx.log");
                rename("gcx.log", tgt);
                auto lines = File(tgt, "r").byLine()
                    .find!(ln => ln.canFind("GC summary:"));
                if (!lines.empty) gcProf = lines.front.find("GC summary:")[11..$].idup;
            }
            else
            {
                auto lines = output.splitter(ctRegex!`\r\n|\r|\n`)
                    .find!(ln => ln.startsWith("GC summary:"));
                if (!lines.empty) gcProf = lines.front[11..$];
            }
            if (cfg.verbose) report("RUN", dur, gcProf);

            if (dur < minDur)
            {
                minDur = dur;
                minGCProf = gcProf;
            }
        }
        report("MIN", minDur, minGCProf);
    }
}

void printHelp()
{
    import std.ascii : nl=newline;
    auto helpString =
        "usage: runbench [-h|--help] [-v|--verbose] [-r n|--repeat=n] [<test_regex>] [<dflags>] [-- <runargs>]"~nl~nl~

        "   tests   - Regular expressions to select tests. Default: '.*\\.d'"~nl~
        "   dflags  - Flags passed to compiler. Default: '-mcpu=native -O -release -inline'"~nl~
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
           "N|no-compile", (string option) { cfg.compile = false; },
           "dflags", &cfg.dflags,
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
    if (cfg.compile)
        writeln("compiler: "~cfg.dmd~' '~cfg.dflags);

    runTests(cfg);
}
