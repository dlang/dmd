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
       std.getopt, std.json, std.net.curl, std.parallelism, std.path, std.process,
       std.range, std.stdio, std.string, std.traits, core.atomic;

import tools.paths;

const scriptDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath;
immutable testDirs = ["runnable", "runnable_cxx", "dshell", "compilable", "fail_compilation"];
shared bool verbose; // output verbose logging
shared bool force; // always run all tests (ignores timestamp checking)
shared string hostDMD; // path to host DMD binary (used for building the tools)
shared string unitTestRunnerCommand;
bool uploadToGitHubChecks; // upload test results to GitHub Checks API

// These long-running runnable tests will be put in front, in this order, to
// make parallelization more effective.
immutable slowRunnableTests = [
    "test34.d",
    "test28.d",
    "issue8671.d",
    "test20855.d",
    "test18545.d",
    "test42.d",
    "lazy.d",
    "xtest46_gc.d",
    "argufilem.d",
    "xtest46.d",
    "sdtor.d",
    "arrayop.d",
    "testgc3.d",
    "link14588.d",
    "link13415.d",
    "paranoia.d",
    "template9.d",
];

enum toolsDir = testPath("tools");

enum TestTool unitTestRunner = { name: "unit_test_runner", extraArgs: [toolsDir.buildPath("paths")] };
enum TestTool testRunner = { name: "d_do_test", extraArgs: ["-I" ~ toolsDir, "-i", "-version=NoMain"] };
enum TestTool testRunnerUnittests = { name: "d_do_test-ut",
                                      customSourceFile: toolsDir.buildPath("d_do_test.d"),
                                      extraArgs: testRunner.extraArgs ~ ["-g", "-unittest"],
                                      runAfterBuild: true };
enum TestTool jsonSanitizer = { name: "sanitize_json" };
enum TestTool dshellPrebuilt = { name: "dshell_prebuilt", linksWithTests: true };

immutable struct TestTool
{
    /// The name of the tool.
    string name;

    string customSourceFile;

    /// Extra arguments that should be supplied to the compiler when compiling the tool.
    string[] extraArgs;

    /// Indicates the tool is a binary that links with tests
    bool linksWithTests;

    bool runAfterBuild;

    alias name this;
}

int main(string[] args)
{
    try
        return tryMain(args);
    catch (SilentQuit sq)
        return sq.exitCode;
}

int tryMain(string[] args)
{
    bool runUnitTests, dumpEnvironment;
    int jobs = 2 * totalCPUs;
    auto res = getopt(args,
        std.getopt.config.passThrough,
        "j|jobs", "Specifies the number of jobs (commands) to run simultaneously (default: %d)".format(jobs), &jobs,
        "v", "Verbose command output", (cast(bool*) &verbose),
        "f", "Force run (ignore timestamps and always run all tests)", (cast(bool*) &force),
        "u|unit-tests", "Runs the unit tests", &runUnitTests,
        "e|environment", "Print current environment variables", &dumpEnvironment,
        "github-checks", "Upload test results to GitHub Checks API (for CI)", &uploadToGitHubChecks,
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
    ./run.d -u -- unit/deinitialization.d -f Module              # runs the unit tests in the file "unit/deinitialization.d" with a UDA containing "Module"

Options:
`, res.options);
        "\nSee the README.md for a more in-depth explanation of the test-runner.".writeln;
        return 0;
    }

    defaultPoolThreads = jobs - 1; // main thread executes tasks as well

    // parse arguments
    args.popFront;
    args2Environment(args);

    // Run the test suite without default permutations
    if (args == ["quick"])
    {
        args = null;
        environment["ARGS"] = "";
    }

    // allow overwrites from the environment
    hostDMD = environment.get("HOST_DMD", "dmd");
    unitTestRunnerCommand = resultsDir.buildPath("unit_test_runner").exeName;

    // bootstrap all needed environment variables
    const env = getEnvironment();

    // Dump environnment
    if (verbose || dumpEnvironment)
    {
        writefln("================================================================================");
        foreach (key; env.keys.sort())
            writefln("%s=%s", key, env[key]);
        writefln("================================================================================");
        stdout.flush();
    }

    if (uploadToGitHubChecks && !getGitHubContext().isConfigured)
    {
        stderr.writeln("Warning: --github-checks specified, but required GITHUB_* environment variables are not set; disabling.");
        uploadToGitHubChecks = false;
    }

    verifyCompilerExists(env);
    prepareOutputDirectory(env);

    if (runUnitTests)
    {
        ensureToolsExists(env, unitTestRunner);
        return spawnProcess(unitTestRunnerCommand ~ args, env, Config.none, scriptDir).wait();
    }

    ensureToolsExists(env, unitTestRunner, testRunner, testRunnerUnittests, jsonSanitizer, dshellPrebuilt);

    if (args == ["tools"])
        return 0;

    // default target
    if (!args.length)
        args = ["all"];

    // move any long-running tests to the front
    static size_t sortKey(in ref Target target)
    {
        const name = target.normalizedTestName;
        if (name.startsWith("runnable"))
        {
            const i = slowRunnableTests.countUntil(name[9 .. $]);
            if (i != -1)
                return i;
        }
        return size_t.max;
    }

    auto targets = args
        .predefinedTargets // preprocess
        .array
        .filterTargets(env);

    // Do a manual schwartzSort until all host compilers have a fix
    // for the invalid "lhs internal pointer" error (probably >= v2.093)
    // See https://github.com/dlang/phobos/pull/7524
    foreach (ref target; targets)
        target.sortKey = sortKey(target);

    targets.sort!("a.sortKey < b.sortKey", SwapStrategy.stable);

    if (targets.length > 0)
    {
        shared string[] failedTargets;
        foreach (target; parallel(targets, 1))
        {
            log("run: %-(%s %)", target.args);

            GitHubUploader uploader;
            if (uploadToGitHubChecks)
                uploader = new GitHubUploader(getGitHubContext(), target);

            struct TestRunResult { int status; string output; }
            TestRunResult result;

            if (uploadToGitHubChecks)
            {
                auto execResult = execute(target.args, env, workDir: scriptDir);

                // Mirror output to console to maintain visibility, although it's now buffered.
                // This requires synchronizing access to stdout.
                if (execResult.output.length > 0)
                {
                    synchronized
                    {
                        stdout.write(execResult.output);
                        stdout.flush();
                    }
                }
                result = TestRunResult(execResult.status, execResult.output);
            }
            else
            {
                int status = spawnProcess(target.args, env, Config.none, scriptDir).wait;
                result = TestRunResult(status, ""); // No output captured
            }


            if (uploader)
                uploader.finish(result.status, result.output);

            if (result.status != 0)
            {
                const string name = target.filename
                            ? target.normalizedTestName
                            : "`unit` tests: " ~ (cast(string)unitTestRunnerCommand) ~ " " ~ join(target.args, " ");

                writeln(">>> TARGET FAILED: ", name);
                synchronized failedTargets ~= name;
            }
        }
        if (failedTargets.length > 0)
        {
            // print overview of failed targets (for CIs)
            writeln("FAILED targets:");
            failedTargets.each!(l => writeln("- ",  l));
            return 1;
        }
    }

    return 0;
}


/// Verify that the compiler has been built.
void verifyCompilerExists(const string[string] env)
{
    if (!env["DMD"].exists)
    {
        stderr.writefln("%s doesn't exist, try building dmd with:\nmake -fposix.mak -j8 -C%s", env["DMD"], scriptDir.dirName.relativePath);
        quitSilently(1);
    }
}

/// Creates the necessary directories and files for the test runner(s)
void prepareOutputDirectory(const string[string] env)
{
    // ensure output directories exist
    foreach (dir; testDirs)
        resultsDir.buildPath(dir).mkdirRecurse;

    version (Windows)
    {{
        // Environment variables are not properly propagated when using bash from WSL
        // Create an additional configuration file that exports `env` entries if missing

        File wrapper = File(env["RESULTS_DIR"] ~ "/setup_env.sh", "wb");

        foreach (const key, string value; env)
        {
            // Detect windows paths and translate them to POSIX compatible relative paths
            static immutable PATHS = [
                "DMD",
                "HOST_DMD",
                "LIB",
                "RESULTS_DIR",
            ];

            if (PATHS.canFind(key))
                value = relativePosixPath(value, scriptDir);

            // Export as env. variable if unset
            wrapper.write(`[ -z "${`, key, `+x}" ] && export `, key, `='`, value, "' ;\n");
        }
    }}
}

/**
Builds the binaries of the tools required by the testsuite.
Does nothing if the tools already exist and are newer than their source.
*/
void ensureToolsExists(const string[string] env, const TestTool[] tools ...)
{
    shared uint failCount = 0;
    foreach (tool; tools.parallel(1))
    {
        string targetBin;
        string sourceFile = tool.customSourceFile;
        if (tool.linksWithTests)
        {
            targetBin = resultsDir.buildPath(tool).objName;
            if (sourceFile is null)
                sourceFile = toolsDir.buildPath(tool, tool ~ ".d");
        }
        else
        {
            targetBin = resultsDir.buildPath(tool).exeName;
            if (sourceFile is null)
                sourceFile = toolsDir.buildPath(tool ~ ".d");
        }
        if (targetBin.timeLastModified.ifThrown(SysTime.init) >= sourceFile.timeLastModified)
        {
            log("%s is already up-to-date", tool);
            continue;
        }

        string[] buildCommand;
        bool overrideEnv;
        if (tool.linksWithTests)
        {
            // This will compile the dshell library thus needs the actual
            // DMD compiler under test
            buildCommand = [
                env["DMD"],
                "-conf=",
                "-m"~env["MODEL"],
                "-of" ~ targetBin,
                "-c",
                sourceFile
            ] ~ getPicFlags(env);
            overrideEnv = true;
        }
        else
        {
            buildCommand = [
                hostDMD,
                "-m"~env["MODEL"],
                "-of"~targetBin,
                sourceFile
            ] ~ getPicFlags(env) ~ tool.extraArgs;
        }

        writefln("Executing: %-(%s %)", buildCommand);
        stdout.flush();
        if (spawnProcess(buildCommand, overrideEnv ? env : null).wait)
        {
            stderr.writefln("failed to build '%s'", targetBin);
            atomicOp!"+="(failCount, 1);
            continue;
        }

        if (tool.runAfterBuild)
        {
            writefln("Executing: %s", targetBin);
            stdout.flush();
            if (spawnProcess([targetBin], null).wait)
            {
                stderr.writefln("'%s' failed", targetBin);
                atomicOp!"+="(failCount, 1);
            }
        }
    }
    if (failCount > 0)
        quitSilently(1); // error already printed
}

/// A single target to execute.
struct Target
{
    /**
    The filename of the target.

    Might be `null` if the target is not for a single file.
    */
    string filename;

    /// The arguments how to execute the target.
    string[] args;

    /// Returns: the normalized test name
    static string normalizedTestName(string filename)
    {
        return filename
            .absolutePath
            .dirName
            .baseName
            .buildPath(filename.baseName);
    }

    string normalizedTestName() const
    {
        return Target.normalizedTestName(filename);
    }

    /// Returns: `true` if the test exists
    bool exists() const
    {
        // This is assumed to be the `unit_tests` target which always exists
        if (filename.empty)
            return true;

        return testPath(normalizedTestName).exists;
    }

    size_t sortKey;
}

/**
Goes through the target list and replaces short-hand targets with their expanded version.
Special targets:
- clean -> removes resultsDir + immediately stops the runner
*/
Target[] predefinedTargets(string[] targets)
{
    static findFiles(string dir)
    {
        return testPath(dir).dirEntries("*{.d,.c,.i,.sh}", SpanMode.shallow).map!(e => e.name);
    }

    static Target createUnitTestTarget()
    {
        Target target = { args: [unitTestRunnerCommand] };
        return target;
    }

    static Target createTestTarget(string filename)
    {
        Target target = {
            filename: filename,
            args: [
                resultsDir.buildPath(testRunner.name.exeName),
                Target.normalizedTestName(filename)
            ]
        };

        return target;
    }

    Appender!(Target[]) newTargets;
    foreach (t; targets)
    {
        t = t.buildNormalizedPath; // remove trailing slashes
        switch (t)
        {
            case "clean":
                if (resultsDir.exists)
                    resultsDir.rmdirRecurse;
                quitSilently(0);
                break;

            case "run_runnable_tests", "runnable":
                newTargets.put(findFiles("runnable").map!createTestTarget);
                break;

            case "run_runnable_cxx_tests", "runnable_cxx":
                newTargets.put(findFiles("runnable_cxx").map!createTestTarget);
                break;

            case "run_fail_compilation_tests", "fail_compilation", "fail":
                newTargets.put(findFiles("fail_compilation").map!createTestTarget);
                break;

            case "run_compilable_tests", "compilable", "compile":
                newTargets.put(findFiles("compilable").map!createTestTarget);
                break;

            case "run_dshell_tests", "dshell":
                newTargets.put(findFiles("dshell").map!createTestTarget);
                break;

            case "all":
                version (FreeBSD) { /* ??? unittest runner fails for no good reason on GHA. */ }
                else
                    newTargets ~= createUnitTestTarget();
                foreach (testDir; testDirs)
                    newTargets.put(findFiles(testDir).map!createTestTarget);
                break;
            case "unit_tests":
                newTargets ~= createUnitTestTarget();
                break;
            default:
                newTargets ~= createTestTarget(t);
        }
    }
    return newTargets.data;
}

// Removes targets that do not need updating (i.e. their .out file exists and is newer than the source file)
Target[] filterTargets(Target[] targets, const string[string] env)
{
    bool error;
    foreach (target; targets)
    {
        if (!target.exists)
        {
            writefln("Warning: %s can't be found", target.normalizedTestName);
            error = true;
        }
    }
    if (error)
        quitSilently(1);

    Target[] targetsThatNeedUpdating;
    foreach (t; targets)
    {
        immutable testName = t.normalizedTestName;
        auto resultRunTime = resultsDir.buildPath(testName ~ ".out").timeLastModified.ifThrown(SysTime.init);
        if (!force && resultRunTime > testPath(testName).timeLastModified &&
                resultRunTime > env["DMD"].timeLastModified.ifThrown(SysTime.init))
            log("%s is already up-to-date", testName);
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
        const sep = arg.indexOf('=');
        if (sep == -1)
            return false;

        environment[arg[0 .. sep]] = arg[sep+1 .. $];
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
string setDefault(string[string] env, string key, string default_)
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
    env["OS"] = os;
    env["MODEL"] = model;
    env["DMD_MODEL"] = dmdModel;
    env["BUILD"] = build;
    env["EXE"] = exeExtension;
    env["DMD"] = dmdPath;
    env.setDefault("DMD_TEST_COVERAGE", "0");

    const generatedSuffix = "generated/%s/%s/%s".format(os, build, model);

    version(Windows)
    {
        env.setDefault("ARGS", "-inline -release -g -O");
        env["OBJ"] = ".obj";
        env["DSEP"] = `\\`;
        env["SEP"] = `\`;
        auto druntimePath = environment.get("DRUNTIME_PATH", testPath(`..\..\druntime`));
        auto phobosPath = environment.get("PHOBOS_PATH", testPath(`..\..\..\phobos`));
        env["DFLAGS"] = `-I"%s\import" -I"%s"`.format(druntimePath, phobosPath);
        env["LIB"] = phobosPath ~ ";" ~ environment.get("LIB");
    }
    else
    {
        env.setDefault("ARGS", "-inline -release -g -O -fPIC");
        env["OBJ"] = ".o";
        env["DSEP"] = "/";
        env["SEP"] = "/";
        auto druntimePath = environment.get("DRUNTIME_PATH", testPath(`../../druntime`));
        auto phobosPath = environment.get("PHOBOS_PATH", testPath(`../../../phobos`));

        // default to PIC, use PIC=1/0 to en-/disable PIC.
        // Note that shared libraries and C files are always compiled with PIC.
        bool pic = true;
        if (environment.get("PIC", "") == "0")
            pic = false;

        env["PIC_FLAG"]  = pic ? "-fPIC" : "";
        env["DFLAGS"] = "-I%s/import -I%s".format(druntimePath, phobosPath)
            ~ " -L-L%s/%s".format(phobosPath, generatedSuffix);
        bool isShared = environment.get("SHARED") != "0" && os.among("linux", "freebsd") > 0;
        if (isShared)
            env["DFLAGS"] = env["DFLAGS"] ~ " -defaultlib=libphobos2.so -L-rpath=%s/%s".format(phobosPath, generatedSuffix);

        if (pic)
            env["REQUIRED_ARGS"] = environment.get("REQUIRED_ARGS") ~ " " ~ env["PIC_FLAG"];

        version(OSX)
            version(X86_64)
                env["D_OBJC"] = "1";
    }
    return env;
}

// Logging primitive
void log(T...)(T args)
{
    if (verbose)
        writefln(args);
}

// Add the executable filename extension to the given `name` for the current OS.
string exeName(string name)
{
    version(Windows)
        name ~= ".exe";
    return name;
}

// Add the object filename extension to the given `name` for the current OS.
string objName(string name)
{
    version(Windows)
        return name ~ ".obj";
    else
        return name ~ ".o";
}

/// Return the correct pic flags as an array of strings
string[] getPicFlags(const string[string] env)
{
    version(Windows) {} else
    {
        const picFlags = env["PIC_FLAG"];
        if (picFlags.length)
            return picFlags.split();
    }
    return cast(string[])[];
}

/++
Signals a silent termination while still retaining a controlled shutdown
(including destructors, scope guards, etc).

quitSilently(...) should be used instead of exit(...)
++/
class SilentQuit : Exception
{
    /// The exit code
    const int exitCode;

    ///
    this(const int exitCode)
    {
        super(null, null, null);
        this.exitCode = exitCode;
    }
}

/++
Aborts the current execution by throwing an exception

Params:
    exitCode = the exit code

Throws: a SilentQuit instance wrapping exitCode
++/
void quitSilently(const int exitCode)
{
    throw new SilentQuit(exitCode);
}

/// Holds information needed to interact with the GitHub Checks API.
struct GitHubContext
{
    string token;
    string owner;
    string repo;
    string sha;
    string apiUrl;
    bool isConfigured;

    /// Creates a context from GitHub Actions environment variables.
    static GitHubContext create()
    {
        GitHubContext ctx;
        auto repoSlug = environment.get("GITHUB_REPOSITORY", "");
        if (!repoSlug.length) return ctx;

        auto parts = repoSlug.split('/');
        if (parts.length != 2) return ctx;

        ctx.owner = parts[0];
        ctx.repo = parts[1];
        ctx.token = environment.get("GITHUB_TOKEN", "");
        ctx.sha = environment.get("GITHUB_SHA", "");
        ctx.apiUrl = environment.get("GITHUB_API_URL", "https://api.github.com");

        if (ctx.token.length && ctx.sha.length)
            ctx.isConfigured = true;
        return ctx;
    }
}

/// Manages the lifecycle of a single GitHub Check Run for a test target.
final class GitHubUploader
{
    GitHubContext* ctx;
    long checkRunId = -1;
    SysTime startTime;

    /// Creates a GitHub Check Run and marks it as "in_progress".
    this(ref GitHubContext context, in ref Target target)
    {
        this.ctx = &context;
        this.startTime = Clock.currTime();

        auto checkName = target.normalizedTestName;

        JSONValue payload = [
            "name": checkName,
            "head_sha": ctx.sha,
            "status": "in_progress",
            "started_at": startTime.toISOString(),
        ];

        auto url = "%s/repos/%s/%s/check-runs".format(ctx.apiUrl, ctx.owner, ctx.repo);
        try
        {
            auto r = HTTP();
            r.addRequestHeader("Authorization", "token " ~ ctx.token);
            r.addRequestHeader("Accept", "application/vnd.github.v3+json");
            r.addRequestHeader("User-Agent", "DMD-Test-Runner");
            auto response = post(url, payload.toString(), r);

            auto jsonResponse = parseJSON(response);
            this.checkRunId = jsonResponse["id"].get!long;
        }
        catch (Exception e)
            stderr.writeln("Exception while creating GitHub check for ", checkName, ": ", e.msg);
    }

    /// Updates the Check Run to "completed" with the final status and output log.
    void finish(int status, string outputLog)
    {
        if (checkRunId == -1) return; // creation failed

        auto conclusion = (status == 0) ? "success" : "failure";
        auto endTime = Clock.currTime();

        // The GitHub API has a 64KB limit on the text field.
        const maxOutput = 65_000;
        if (outputLog.length > maxOutput)
            outputLog = outputLog[0 .. maxOutput] ~ "\n\n... (log truncated) ...";

        JSONValue payload = [
            "status": "completed".JSONValue,
            "completed_at": endTime.toISOString().JSONValue,
            "conclusion": conclusion.JSONValue,
            "output": [
                "title": (conclusion == "success" ? "Passed" : "Failed"),
                "summary": "Test finished with exit code " ~ to!string(status),
                "text": "```\n" ~ outputLog ~ "\n```"
            ].JSONValue
        ];

        auto url = "%s/repos/%s/%s/check-runs/%d".format(ctx.apiUrl, ctx.owner, ctx.repo, checkRunId);
        try
        {
            // Use PATCH to update the check run
            auto r = HTTP();
            r.method = HTTP.Method.patch;
            r.addRequestHeader("Authorization", "token " ~ ctx.token);
            r.addRequestHeader("Accept", "application/vnd.github.v3+json");
            r.addRequestHeader("User-Agent", "DMD-Test-Runner");

            post(url, payload.toString(), r);
        }
        catch (Exception e)
            stderr.writeln("Exception while updating GitHub check for id ", checkRunId, ": ", e.msg);
    }
}

// Lazily-initialized, shared context for GitHub API access.
__gshared GitHubContext g_ghContext;
bool g_ghContextInitialized;

ref GitHubContext getGitHubContext()
{
    synchronized
    {
        if (!g_ghContextInitialized)
        {
            g_ghContext = GitHubContext.create();
            g_ghContextInitialized = true;
        }
    }
    return g_ghContext;
}
