#!/usr/bin/env rdmd
/**
DMD testsuite runner

Usage:
  ./run.d <test-file>...

Example:
  ./run.d runnable/template2962.d fail_compilation/fail282.d

See the README.md for all available test targets
*/

import std.algorithm, std.conv, std.datetime, std.exception, std.file, std.format,
       std.getopt, std.parallelism, std.path, std.process, std.range, std.stdio, std.string;
import core.stdc.stdlib : exit;

const scriptDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath;
string resultsDir = scriptDir.buildPath("test_results");
immutable testDirs = ["runnable", "compilable", "fail_compilation"];
shared bool verbose; // output verbose logging
shared bool force; // always run all tests (ignores timestamp checking)
shared string hostDMD; // path to host DMD binary (used for building the tools)

void main(string[] args)
{
    int jobs = totalCPUs;
    auto res = getopt(args,
        "j|jobs", "Specifies the number of jobs (commands) to run simultaneously (default: %d)".format(totalCPUs), &jobs,
        "v", "Verbose command output", (cast(bool*) &verbose),
        "f", "Force run (ignore timestamps and always run all tests)", (cast(bool*) &force),
    );
    if (res.helpWanted)
    {
        defaultGetoptPrinter(`./run.d <test-file>...

Examples:

    ./run.d runnable/template2962.d                              # runs a specific tests
    ./run.d runnable/template2962.d fail_compilation/fail282.d   # runs multiple specific tests
    ./run.d fail_compilation                                     # runs all tests in fail_compilation
    ./run.d all                                                  # runs all tests
    ./run.d clean                                                # remove all test results

Options:
`, res.options);
        "\nSee the README.md for a more in-depth explanation of the test-runner.".writeln;
        return;
    }

    // parse arguments
    args.popFront;
    args2Environment(args);

    // allow overwrites from the environment
    resultsDir = environment.get("RESULTS_DIR", resultsDir);
    hostDMD = environment.get("HOST_DMD", "dmd");

    // bootstrap all needed environment variables
    auto env = getEnvironment;

    // default target
    if (!args.length)
        args = ["all"];

    alias normalizeTestName = f => f.absolutePath.dirName.baseName.buildPath(f.baseName);
    auto targets = args
        .predefinedTargets // preprocess
        .map!normalizeTestName
        .array
        .filterTargets;

    if (targets.length > 0)
    {
        if (!env["DMD"].exists)
        {
            stderr.writefln("%s doesn't exist, try building dmd with:\nmake -fposix.mak -j8 -C%s", env["DMD"], scriptDir.dirName.relativePath);
            exit(1);
        }

        if (verbose)
        {
            log("================================================================================");
            foreach (key, value; env)
                log("%s=%s", key, value);
            log("================================================================================");
        }
        
        int ret;
        auto taskPool = new TaskPool(jobs);
        scope(exit) taskPool.finish();
        ensureToolsExists;
        foreach (target; taskPool.parallel(targets, 1))
        {
            auto args = [resultsDir.buildPath("d_do_test"), target];
            log("run: %-(%s %)", args);
            ret |= spawnProcess(args, env, Config.none, scriptDir).wait;
        }
        if (ret)
            exit(1);
    }
}

/**
Builds the binary of the tools required by the testsuite.
Does nothing if the tools already exist and are newer than their source.
*/
void ensureToolsExists()
{
    static toolsDir = scriptDir.buildPath("tools");
    resultsDir.mkdirRecurse;
    auto tools = [
        "d_do_test",
        "sanitize_json",
    ];
    foreach (tool; tools.parallel(1))
    {
        auto targetBin = resultsDir.buildPath(tool).exeName;
        auto sourceFile = toolsDir.buildPath(tool ~ ".d");
        if (targetBin.timeLastModified.ifThrown(SysTime.init) >= sourceFile.timeLastModified)
            writefln("%s is already up-to-date", tool);
        else
        {
            auto command = [hostDMD, "-of"~targetBin, sourceFile];
            writefln("Executing: %-(%s %)", command);
            spawnProcess(command).wait;
        }
    }

    // ensure output directories exist
    foreach (dir; testDirs)
        resultsDir.buildPath(dir).mkdirRecurse;
}

/**
Goes through the target list and replaces short-hand targets with their expanded version.
Special targets:
- clean -> removes resultsDir + immediately stops the runner
*/
auto predefinedTargets(string[] targets)
{
    static findFiles(string dir)
    {
        return scriptDir.buildPath(dir).dirEntries("*{.d,.sh}", SpanMode.shallow).map!(e => e.name);
    }

    Appender!(string[]) newTargets;
    foreach (t; targets)
    {
        t = t.buildNormalizedPath; // remove trailing slashes
        switch (t)
        {
            case "clean":
                resultsDir.rmdirRecurse;
                exit(0);
                break;

            case "run_runnable_tests", "runnable":
                newTargets.put(findFiles("runnable"));
                break;

            case "run_fail_compilation_tests", "fail_compilation", "fail":
                newTargets.put(findFiles("fail_compilation"));
                break;

            case "run_compilable_tests", "compilable", "compile":
                newTargets.put(findFiles("compilable"));
                break;

            case "all":
                foreach (testDir; testDirs)
                    newTargets.put(findFiles(testDir));
                break;

            default:
                newTargets ~= t;
        }
    }
    return newTargets.data;
}

// Removes targets that do not need updating (i.e. their .out file exists and is newer than the source file)
auto filterTargets(string[] targets)
{
    bool error;
    foreach (target; targets)
    {
        if (!scriptDir.buildPath(target).exists)
        {
            writefln("Warning: %s can't be found", target);
            error = true;
        }
    }
    if (error)
        exit(1);

    string[] targetsThatNeedUpdating;
    foreach (t; targets)
    {
        if (!force && resultsDir.buildPath(t ~ ".out").timeLastModified.ifThrown(SysTime.init) >
                scriptDir.buildPath(t).timeLastModified)
            writefln("%s is already up-to-date", t);
        else
            targetsThatNeedUpdating ~= t;
    }
    return targetsThatNeedUpdating;
}

// Add additional make-like assignments to the environment
// e.g. ./run.d ARGS=foo -> sets ARGS to 'foo'
void args2Environment(ref string[] args)
{
    bool tryToAdd(string arg)
    {
        if (!arg.canFind("="))
            return false;

        auto sp = arg.splitter("=");
        environment[sp.front] = sp.dropOne.front;
        return true;
    }
    args = args.filter!(a => !tryToAdd(a)).array;
}

/**
Checks whether the environment already contains a value for key and if so, sets
the found value to the new environment object.
Otherwise uses the `default_` value as fallback.

Params:
    env = environment to write the check to
    key = key to check for existence and write into the new env
    default_ = fallback value if the key doesn't exist in the global environment
*/
auto getDefault(string[string] env, string key, string default_)
{
    if (key in environment)
        env[key] = environment[key];
    else
        env[key] = default_;

    return env[key];
}

// Sets the environment variables required by d_do_test and sh_do_test.sh
string[string] getEnvironment()
{
    string[string] env;

    env["RESULTS_DIR"] = resultsDir;
    auto os = env.getDefault("OS", detectOS);
    auto build = env.getDefault("BUILD", "release");
    env.getDefault("DMD_TEST_COVERAGE", "0");

    version(Windows)
    {
        env.getDefault("ARGS", "-inline -release -g -O");
        auto exe = env["EXE"] = ".exe";
        env["OBJ"] = ".obj";
        env["DSEP"] = `\\`;
        env["SEP"] = `\`;
        auto druntimePath = environment.get("DRUNTIME_PATH", `..\..\druntime`);
        auto phobosPath = environment.get("PHOBOS_PATH", `..\..\phobos`);
        env["DFLAGS"] = `-I%s\import -I%s`.format(druntimePath, phobosPath);
        env["LIB"] = phobosPath;

        // auto-tester might run the testsuite with a different $(MODEL) than DMD
        // has been compiled with. Hence we manually check which binary exists.
        // For windows the $(OS) during build is: `windows`
        int dmdModel = "../generated/windows/%s/64/dmd%s".format(build, exe).exists ? 64 : 32;
        env.getDefault("MODEL", dmdModel.text);
        env["DMD"] = "../generated/windows/%s/%d/dmd%s".format(build, dmdModel, exe);
    }
    else
    {
        env.getDefault("ARGS", "-inline -release -g -O -fPIC");
        env["EXE"] = "";
        env["OBJ"] = ".o";
        env["DSEP"] = "/";
        env["SEP"] = "/";
        auto druntimePath = environment.get("DRUNTIME_PATH", scriptDir ~ `/../../druntime`);
        auto phobosPath = environment.get("PHOBOS_PATH", scriptDir ~ `/../../phobos`);

        // auto-tester might run the testsuite with a different $(MODEL) than DMD
        // has been compiled with. Hence we manually check which binary exists.
        int dmdModel = scriptDir ~ "../generated/%s/%s/64/dmd".format(os, build).exists ? 64 : 32;
        env.getDefault("MODEL", dmdModel.text);

        auto generatedSuffix = "generated/%s/%s/%s".format(os, build, dmdModel);
        env["DMD"] = scriptDir ~ "/../" ~ generatedSuffix ~ "/dmd";

        // default to PIC on x86_64, use PIC=1/0 to en-/disable PIC.
        // Note that shared libraries and C files are always compiled with PIC.
        bool pic;
        version(X86_64)
            pic = true;
        else version(X86)
            pic = false;
        if (environment.get("PIC", "0") == "1")
            pic = true;

        env["PIC_FLAGS"]  = pic ? "-fPIC" : "";
        env["DFLAGS"] = "-I%s/import -I%s".format(druntimePath, phobosPath)
            ~ " -L-L%s/%s".format(phobosPath, generatedSuffix);
        bool isShared = os.among("linux", "freebsd") >= 0;
        if (isShared)
            env["DFLAGS"] = env["DFLAGS"] ~ " -defaultlib=libphobos2.so -L-rpath=%s/%s".format(phobosPath, generatedSuffix);

        env["REQUIRED_ARGS"] = environment.get("REQUIRED_ARGS") ~  env["PIC_FLAGS"];

        version(OSX)
            version(X86_64)
                env["D_OBJC"] = "1";
    }
    return env;
}

/*
Detects the host OS.

Returns: a string from `{windows, osx,linux,freebsd,openbsd,netbsd,dragonflybsd,solaris}`
*/
string detectOS()
{
    version(Windows)
        return "windows";
    else version(OSX)
        return "osx";
    else version(linux)
        return "linux";
    else version(FreeBSD)
        return "freebsd";
    else version(OpenBSD)
        return "openbsd";
    else version(NetBSD)
        return "netbsd";
    else version(DragonFlyBSD)
        return "dragonflybsd";
    else version(Solaris)
        return "solaris";
    else version(SunOS)
        return "solaris";
    else
        static assert(0, "Unrecognized or unsupported OS.");
}

// Logging primitive
auto log(T...)(T args)
{
    if (verbose)
        writefln(args);
}

// Add the executable filename extension to the given `name` for the current OS.
auto exeName(T)(T name)
{
    version(Windows)
        name ~= ".exe";
    return name;
}
