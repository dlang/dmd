#!/usr/bin/env rdmd
/**
DMD builder

Usage:
  ./build.d dmd

See `--help` for targets.

detab, tolf, install targets - require the D Language Tools (detab.exe, tolf.exe)
  https://github.com/dlang/tools.

zip target - requires Info-ZIP or equivalent (zip32.exe)
  http://www.info-zip.org/Zip.html#Downloads
*/

version(CoreDdoc) {} else:

import std.algorithm, std.conv, std.datetime, std.exception, std.file, std.format, std.functional,
       std.getopt, std.path, std.process, std.range, std.stdio, std.string, std.traits;

import std.parallelism : TaskPool, totalCPUs;

const thisBuildScript = __FILE_FULL_PATH__.buildNormalizedPath;
const srcDir = thisBuildScript.dirName;
const compilerDir = srcDir.dirName;
const dmdRepo = compilerDir.dirName;
const testDir = compilerDir.buildPath("test");

shared bool verbose; // output verbose logging
shared bool force; // always build everything (ignores timestamp checking)
shared bool dryRun; /// dont execute targets, just print command to be executed
__gshared int jobs; // Number of jobs to run in parallel

__gshared string[string] env;
__gshared string[][string] flags;
__gshared typeof(sourceFiles()) sources;
__gshared TaskPool taskPool;

/// Array of build rules through which all other build rules can be reached
immutable rootRules = [
    &dmdDefault,
    &dmdPGO,
    &runDmdUnittest,
    &clean,
    &checkwhitespace,
    &runTests,
    &buildFrontendHeaders,
    &runCxxHeadersTest,
    &runCxxUnittest,
    &detab,
    &tolf,
    &zip,
    &html,
    &toolchainInfo,
    &style,
    &man,
    &installCopy,
];

int main(string[] args)
{
    try
    {
        runMain(args);
        return 0;
    }
    catch (BuildException e)
    {
        writeln(e.msg);
        if (e.details)
        {
            writeln("DETAILS:\n");
            writeln(e.details);
        }
        return 1;
    }
}

void runMain(string[] args)
{
    jobs = totalCPUs;
    bool calledFromMake = false;
    auto res = getopt(args,
        "j|jobs", "Specifies the number of jobs (commands) to run simultaneously (default: %d)".format(totalCPUs), &jobs,
        "v|verbose", "Verbose command output", cast(bool*) &verbose,
        "f|force", "Force run (ignore timestamps and always run all tests)", cast(bool*) &force,
        "d|dry-run", "Print commands instead of executing them", cast(bool*) &dryRun,
        "called-from-make", "Calling the build script from the Makefile", &calledFromMake
    );
    void showHelp()
    {
        defaultGetoptPrinter(`./build.d <targets>...

Examples
--------

    ./build.d dmd           # build DMD
    ./build.d unittest      # runs internal unittests
    ./build.d clean         # remove all generated files
    ./build.d generated/linux/release/64/dmd.conf
    ./build.d dmd-pgo       # builds dmd with PGO data, currently only LDC is supported

Important variables:
--------------------

HOST_DMD:             Host D compiler to use for bootstrapping
AUTO_BOOTSTRAP:       Enable auto-boostrapping by downloading a stable DMD binary
MODEL:                Target architecture to build for (32,64) - defaults to the host architecture

Build modes:
------------
BUILD: release (default) | debug (enabled a build with debug instructions)

Opt-in build features:

ENABLE_RELEASE:       Optimized release build
ENABLE_DEBUG:         Add debug instructions and symbols (set if ENABLE_RELEASE isn't set)
ENABLE_ASSERTS:       Don't use -release if ENABLE_RELEASE is set
ENABLE_LTO:           Enable link-time optimizations
ENABLE_UNITTEST:      Build dmd with unittests (sets ENABLE_COVERAGE=1)
ENABLE_PROFILE:       Build dmd with a profiling recorder (D)
ENABLE_COVERAGE       Build dmd with coverage counting
ENABLE_SANITIZERS     Build dmd with sanitizer (e.g. ENABLE_SANITIZERS=address,undefined)

Targets
-------
` ~ targetsHelp ~ `
The generated files will be in generated/$(OS)/$(BUILD)/$(MODEL) (` ~ env["G"] ~ `)

Command-line parameters
-----------------------
`, res.options);
        return;
    }

    // workaround issue https://issues.dlang.org/show_bug.cgi?id=13727
    version (CRuntime_DigitalMars)
    {
        pragma(msg, "Warning: Parallel builds disabled because of Issue 13727!");
        jobs = min(jobs, 1); // Fall back to a sequential build
    }

    if (jobs <= 0)
        abortBuild("Invalid number of jobs: %d".format(jobs));

    taskPool = new TaskPool(jobs - 1); // Main thread is active too
    scope (exit) taskPool.finish();
    scope (failure) taskPool.stop();

    // parse arguments
    args.popFront;
    args2Environment(args);
    parseEnvironment;
    processEnvironment;
    processEnvironmentCxx;
    sources = sourceFiles;

    if (res.helpWanted)
        return showHelp;

    // Since we're ultimately outputting to a TTY, force colored output
    // A more proper solution would be to redirect DMD's output to this script's
    // output using `std.process`', but it's more involved and the following
    // "just works"
    version(Posix) // UPDATE: only when ANSII color codes are supported, that is. Don't do this on Windows.
    if (!flags["DFLAGS"].canFind("-color=off") &&
        [env["HOST_DMD_RUN"], "-color=on", "-h"].tryRun().status == 0)
        flags["DFLAGS"] ~= "-color=on";
    // default target
    if (!args.length)
        args = ["dmd"];

    auto targets = predefinedTargets(args); // preprocess

    if (targets.length == 0)
        return showHelp;

    if (verbose)
    {
        log("================================================================================");
        foreach (key, value; env)
            log("%s=%s", key, value);
        foreach (key, value; flags)
            log("%s=%-(%s %)", key, value);
        log("================================================================================");
    }
    {
        File lockFile;
        if (calledFromMake)
        {
            // If called from make, use an interprocess lock so that parallel builds don't stomp on each other
            lockFile = File(env["GENERATED"].buildPath("build.lock"), "w");
            lockFile.lock();
        }
        scope (exit)
        {
            if (calledFromMake)
            {
                lockFile.unlock();
                lockFile.close();
            }
        }

        Scheduler.build(targets);
    }

    writeln("Success");
}

/// Generate list of targets for use in the help message
string targetsHelp()
{
    string result = "";
    foreach (rule; BuildRuleRange(rootRules.map!(a => a()).array))
    {
        if (rule.name)
        {
            enum defaultPrefix = "\n                      ";
            result ~= rule.name;
            string prefix = defaultPrefix[1 + rule.name.length .. $];
            void add(string msg)
            {
                result ~= format("%s%s", prefix, msg);
                prefix = defaultPrefix;
            }
            if (rule.description)
                add(rule.description);
            else if (rule.targets)
            {
                foreach (target; rule.targets)
                {
                    add(target.relativePath);
                }
            }
            result ~= "\n";
        }
    }
    return result;
}

/**
D build rules
====================

The strategy of this script is to emulate what the Makefile is doing.

Below all individual rules of DMD are defined.
They have a target path, sources paths and an optional name.
When a rule is needed either its command or custom commandFunction is executed.
A rule will be skipped if all targets are older than all sources.
This script is by default part of the sources and thus any change to the build script,
will trigger a full rebuild.

*/

/// Returns: the rule that builds the lexer object file
alias lexer = makeRuleWithArgs!((MethodInitializer!BuildRule builder, BuildRule rule,
                                 string suffix, string[] extraFlags)
    => builder
    .name("lexer")
    .target(env["G"].buildPath("lexer" ~ suffix).objName)
    .sources(sources.lexer)
    .deps([
        versionFile,
        sysconfDirFile,
        common(suffix, extraFlags)
    ])
    .msg("(DC) LEXER" ~ suffix)
    .command([env["HOST_DMD_RUN"],
        "-c",
        "-of" ~ rule.target,
        "-vtls",
        "-J" ~ env["RES"]]
        .chain(flags["DFLAGS"],
            extraFlags,
            // source files need to have relative paths in order for the code coverage
            // .lst files to be named properly for CodeCov to find them
            rule.sources.map!(e => e.relativePath(compilerDir))
        ).array
    )
);

/// Returns: the rule that generates the dmd.conf/sc.ini file in the output folder
alias dmdConf = makeRule!((builder, rule) {
    string exportDynamic;
    version(OSX) {} else
        exportDynamic = " -L--export-dynamic";

    version (Windows)
    {
        enum confFile = "sc.ini";
        enum conf = `[Environment]
DFLAGS="-I%@P%\..\..\..\..\druntime\import" "-I%@P%\..\..\..\..\..\phobos"
LIB="%@P%\..\..\..\..\..\phobos"

[Environment32]
DFLAGS=%DFLAGS% -L/OPT:NOICF

[Environment64]
DFLAGS=%DFLAGS% -L/OPT:NOICF
`;
    }
    else
    {
        enum confFile = "dmd.conf";
        enum conf = `[Environment32]
DFLAGS=-I%@P%/../../../../druntime/import -I%@P%/../../../../../phobos -L-L%@P%/../../../../../phobos/generated/{OS}/{BUILD}/32{exportDynamic} -fPIC

[Environment64]
DFLAGS=-I%@P%/../../../../druntime/import -I%@P%/../../../../../phobos -L-L%@P%/../../../../../phobos/generated/{OS}/{BUILD}/64{exportDynamic} -fPIC
`;
    }

    builder
        .name("dmdconf")
        .target(env["G"].buildPath(confFile))
        .msg("(TX) DMD_CONF")
        .commandFunction(() {
            const expConf = conf
                .replace("{exportDynamic}", exportDynamic)
                .replace("{BUILD}", env["BUILD"])
                .replace("{OS}", env["OS"]);

            writeText(rule.target, expConf);
        });
});

/// Returns: the rule that builds the common object file
alias common = makeRuleWithArgs!((MethodInitializer!BuildRule builder, BuildRule rule,
                                   string suffix, string[] extraFlags) => builder
    .name("common")
    .target(env["G"].buildPath("common" ~ suffix).objName)
    .sources(sources.common)
    .msg("(DC) COMMON" ~ suffix)
    .command([
        env["HOST_DMD_RUN"],
        "-c",
        "-of" ~ rule.target,
        ]
        .chain(
            flags["DFLAGS"], extraFlags,

            // source files need to have relative paths in order for the code coverage
            // .lst files to be named properly for CodeCov to find them
            rule.sources.map!(e => e.relativePath(compilerDir))
        ).array)
);


alias validateCommonBetterC = makeRule!((builder, rule) => builder
    .name("common-betterc")
    .description("Verify that common is -betterC compatible")
    .deps([ common("-betterc", ["-betterC"]) ])
);

/// Returns: the rule that builds the backend object file
alias backend = makeRuleWithArgs!((MethodInitializer!BuildRule builder, BuildRule rule,
                                   string suffix, string[] extraFlags) => builder
    .name("backend")
    .target(env["G"].buildPath("backend" ~ suffix).objName)
    .sources(sources.backend)
    .deps([
        common(suffix, extraFlags)
    ])
    .msg("(DC) BACKEND" ~ suffix)
    .command([
        env["HOST_DMD_RUN"],
        "-c",
        "-of" ~ rule.target,
        ]
        .chain(
            flags["DFLAGS"], extraFlags,

            // source files need to have relative paths in order for the code coverage
            // .lst files to be named properly for CodeCov to find them
            rule.sources.map!(e => e.relativePath(compilerDir))
        ).array)
);

/// Returns: the rules that generate required string files: VERSION and SYSCONFDIR.imp
alias versionFile = makeRule!((builder, rule) {
    alias contents = memoize!(() {
        if (dmdRepo.buildPath(".git").exists)
        {
            bool validVersionNumber(string version_)
            {
                // ensure tag has initial 'v'
                if (!version_.length || !version_[0] == 'v')
                    return false;
                size_t i = 1;
                // validate full major version number
                for (; i < version_.length; i++)
                {
                    if ('0' <= version_[i] && version_[i] <= '9')
                        continue;
                    if (version_[i] == '.')
                        break;
                    return false;
                }
                // ensure tag has point
                if (i >= version_.length || version_[i++] != '.')
                    return false;
                // only validate first digit of minor version number
                if ('0' > version_[i] || version_[i] > '9')
                    return false;
                return true;
            }
            auto gitResult = tryRun([env["GIT"], "describe", "--dirty"]);
            if (gitResult.status == 0 && validVersionNumber(gitResult.output))
                return gitResult.output.strip;
        }
        // version fallback
        return dmdRepo.buildPath("VERSION").readText;
    });
    builder
    .target(env["G"].buildPath("VERSION"))
    .condition(() => !rule.target.exists || rule.target.readText != contents)
    .msg("(TX) VERSION")
    .commandFunction(() => writeText(rule.target, contents));
});

alias sysconfDirFile = makeRule!((builder, rule) => builder
    .target(env["G"].buildPath("SYSCONFDIR.imp"))
    .condition(() => !rule.target.exists || rule.target.readText != env["SYSCONFDIR"])
    .msg("(TX) SYSCONFDIR")
    .commandFunction(() => writeText(rule.target, env["SYSCONFDIR"]))
);

/// BuildRule to create a directory if it doesn't exist.
alias directoryRule = makeRuleWithArgs!((MethodInitializer!BuildRule builder, BuildRule rule, string dir) => builder
   .target(dir)
   .condition(() => !exists(dir))
   .msg("mkdirRecurse '%s'".format(dir))
   .commandFunction(() => mkdirRecurse(dir))
);
alias dmdSymlink = makeRule!((builder, rule) => builder
    .commandFunction((){
        import std.process;
        version(Windows)
        {

        }
        else
        {
            spawnProcess(["ln", "-sf", env["DMD_PATH"], "./dmd"]);
        }
    })
);
/**
BuildRule for the DMD executable.

Params:
  extra_flags = Flags to apply to the main build but not the rules
*/
alias dmdExe = makeRuleWithArgs!((MethodInitializer!BuildRule builder, BuildRule rule,
                                  string targetSuffix, string[] extraFlags, string[] depFlags) {
    const dmdSources = sources.dmd.all.chain(sources.root).array;

    string[] platformArgs;
    version (Windows)
        platformArgs = ["-L/STACK:16777216"];

    auto lexer = lexer(targetSuffix, depFlags);
    auto backend = backend(targetSuffix, depFlags);
    auto common = common(targetSuffix, depFlags);
    builder
        // include lexer.o, common.o, and backend.o
        .sources(dmdSources.chain(lexer.targets, backend.targets, common.targets).array)
        .target(env["DMD_PATH"] ~ targetSuffix)
        .msg("(DC) DMD" ~ targetSuffix)
        .deps([versionFile, sysconfDirFile, lexer, backend, common])
        .command([
            env["HOST_DMD_RUN"],
            "-of" ~ rule.target,
            "-vtls",
            "-J" ~ env["RES"],
            ].chain(extraFlags, platformArgs, flags["DFLAGS"],
                // source files need to have relative paths in order for the code coverage
                // .lst files to be named properly for CodeCov to find them
                rule.sources.map!(e => e.relativePath(compilerDir))
            ).array);
});

alias dmdDefault = makeRule!((builder, rule) => builder
    .name("dmd")
    .description("Build dmd")
    .deps([dmdExe(null, null, null), dmdConf])
);
struct PGOState
{
    //Does the host compiler actually support PGO, if not print a message
    static bool checkPGO(string x)
    {
        switch (env["HOST_DMD_KIND"])
        {
            case "dmd":
                abortBuild(`DMD does not support PGO!`);
                break;
            case "ldc":
                return true;
                break;
            case "gdc":
                abortBuild(`PGO (or AutoFDO) builds are not yet supported for gdc`);
                break;
            default:
                assert(false, "Unknown host compiler kind: " ~ env["HOST_DMD_KIND"]);
        }
        assert(0);
    }
    this(string set)
    {
        hostKind = set;
        profDirPath = buildPath(env["G"], "dmd_profdata");
        mkdirRecurse(profDirPath);
    }
    string profDirPath;
    string hostKind;
    string[] pgoGenerateFlags() const
    {
        switch(hostKind)
        {
            case "ldc":
                return ["-fprofile-instr-generate=" ~ pgoDataPath ~ "/data.%p.raw"];
            default:
                return [""];
        }
    }
    string[] pgoUseFlags() const
    {
        switch(hostKind)
        {
            case "ldc":
                return ["-fprofile-instr-use=" ~ buildPath(pgoDataPath(), "merged.data")];
            default:
                return [""];
        }
    }
    string pgoDataPath() const
    {
        return profDirPath;
    }
}
 // Compiles the test runner
alias testRunner = methodInit!(BuildRule, (rundBuilder, rundRule) => rundBuilder
    .msg("(DC) RUN.D")
    .sources([ testDir.buildPath( "run.d") ])
    .target(env["GENERATED"].buildPath("run".exeName))
    .command([ env["HOST_DMD_RUN"], "-of=" ~ rundRule.target, "-i", "-I" ~ testDir] ~ rundRule.sources));


alias dmdPGO = makeRule!((builder, rule) {
    const dmdKind = env["HOST_DMD_KIND"];
    PGOState pgoState = PGOState(dmdKind);

    alias buildInstrumentedDmd = methodInit!(BuildRule, (rundBuilder, rundRule) => rundBuilder
        .msg("Built dmd with PGO instrumentation")
        .deps([dmdExe(null, pgoState.pgoGenerateFlags(), pgoState.pgoGenerateFlags()), dmdConf]));

    alias genDmdData = methodInit!(BuildRule, (rundBuilder, rundRule) => rundBuilder
        .msg("Compiling dmd testsuite to generate PGO data")
        .sources([ testDir.buildPath( "run.d") ])
        .deps([buildInstrumentedDmd, testRunner])
        .commandFunction({
            // Run dmd test suite to get data
            const scope cmd = [ testRunner.targets[0], "compilable", "-j" ~ jobs.to!string ];
            log("%-(%s %)", cmd);
            if (spawnProcess(cmd, null, Config.init, testDir).wait())
                stderr.writeln("dmd tests failed! This will not end the PGO build because some data may have been gathered");
        }));
    alias genPhobosData = methodInit!(BuildRule, (rundBuilder, rundRule) => rundBuilder
        .msg("Compiling phobos testsuite to generate PGO data")
        .deps([buildInstrumentedDmd])
        .commandFunction({
            // Run phobos unittests
            //TODO makefiles
            //generated/linux/release/64/unittest/test_runner builds the unittests without running them.
            const scope cmd = ["make", "-C", "../phobos", "-j" ~ jobs.to!string, "generated/linux/release/64/unittest/test_runner", "DMD_DIR="~compilerDir];
            log("%-(%s %)", cmd);
            if (spawnProcess(cmd, null, Config.init, compilerDir).wait())
                stderr.writeln("Phobos Tests failed! This will not end the PGO build because some data may have been gathered");
        }));
    alias finalDataMerge = methodInit!(BuildRule, (rundBuilder, rundRule) => rundBuilder
        .msg("Merging PGO data")
        .deps([genDmdData])
        .commandFunction({
            // Run dmd test suite to get data
            scope cmd = ["ldc-profdata", "merge", "--output=merged.data"];
            import std.file : dirEntries;
            auto files = dirEntries(pgoState.pgoDataPath, "*.raw", SpanMode.shallow).map!(f => f.name);

            // Use a separate file to work around the windows command limit
            version (Windows)
            {{
                const listFile = buildPath(env["G"], "pgo_file_list.txt");
                File list = File(listFile, "w");
                foreach (file; files)
                    list.writeln(file);
                cmd ~= [ "--input-files=" ~ listFile ];
            }}
            else
                cmd = chain(cmd, files).array;
            log("%-(%s %)", cmd);
            if (spawnProcess(cmd, null, Config.init, pgoState.pgoDataPath).wait())
                abortBuild("Merge failed");
            files.each!(f => remove(f));
        }));
    builder
        .name("dmd-pgo")
        .description("Build dmd with PGO data collected from the dmd and phobos testsuites")
        .msg("Build with collected PGO data")
        .condition(() => PGOState.checkPGO(dmdKind))
        .deps([finalDataMerge])
        .commandFunction({
            const extraFlags = pgoState.pgoUseFlags ~ "-wi";
            const scope cmd = [thisExePath, "HOST_DMD="~env["HOST_DMD_RUN"],
                "ENABLE_RELEASE=1", "ENABLE_LTO=1", "DFLAGS="~extraFlags.join(" "),
                "--force", "-j"~jobs.to!string];
            log("%-(%s %)", cmd);
            if (spawnProcess(cmd, null, Config.init).wait())
                abortBuild("PGO Compilation failed");
        });
}
);

/// Run's the test suite (unittests & `run.d`)
alias runTests = makeRule!((testBuilder, testRule)
{
    // Reference header assumes Linux64
    auto headerCheck = env["OS"] == "linux" && env["MODEL"] == "64"
                    ? [ runCxxHeadersTest ] : null;

    testBuilder
        .name("test")
        .description("Run the test suite using test/run.d")
        .msg("(RUN) TEST")
        .deps([dmdDefault, runDmdUnittest, testRunner] ~ headerCheck)
        .commandFunction({
            // Use spawnProcess to avoid output redirection for `command`s
            const scope cmd = [ testRunner.targets[0], "-j" ~ jobs.to!string ];
            log("%-(%s %)", cmd);
            if (spawnProcess(cmd, null, Config.init, testDir).wait())
                abortBuild("Tests failed!");
        });
});

/// BuildRule to run the DMD unittest executable.
alias runDmdUnittest = makeRule!((builder, rule) {
auto dmdUnittestExe = dmdExe("-unittest", ["-version=NoMain", "-unittest", env["HOST_DMD_KIND"] == "gdc" ? "-fmain" : "-main"], ["-unittest"]);
    builder
        .name("unittest")
        .description("Run the dmd unittests")
        .msg("(RUN) DMD-UNITTEST")
        .deps([dmdUnittestExe])
        .command(dmdUnittestExe.targets);
});

/**
BuildRule to run the DMD frontend header generation
For debugging, use `./build.d cxx-headers DFLAGS="-debug=Debug_DtoH"` (clean before)
*/
alias buildFrontendHeaders = makeRule!((builder, rule) {
    const dmdSources = sources.dmd.frontend ~ sources.root ~ sources.common ~ sources.lexer;
    const dmdExeFile = dmdDefault.deps[0].target;
    builder
        .name("cxx-headers")
        .description("Build the C++ frontend headers ")
        .msg("(DMD) CXX-HEADERS")
        .deps([dmdDefault])
        .target(env["G"].buildPath("frontend.h"))
        .command([dmdExeFile] ~
            flags["DFLAGS"]
              .filter!(f => startsWith(f, "-debug=", "-version=", "-I", "-J")).array ~
            ["-J" ~ env["RES"], "-c", "-o-", "-HCf="~rule.target,
            // Enforce the expected target architecture
            "-m64", "-os=linux",
            ] ~ dmdSources ~
            // Set druntime up to be imported explicitly,
            //  so that druntime doesn't have to be built to run the updating of c++ headers.
            ["-I../druntime/src"]);
});

alias runCxxHeadersTest = makeRule!((builder, rule) {
    builder
        .name("cxx-headers-test")
        .description("Check that the C++ interface matches `src/dmd/frontend.h`")
        .msg("(TEST) CXX-HEADERS")
        .deps([buildFrontendHeaders])
        .commandFunction(() {
            const cxxHeaderGeneratedPath = buildFrontendHeaders.target;
            const cxxHeaderReferencePath = env["D"].buildPath("frontend.h");
            log("Comparing referenceHeader(%s) <-> generatedHeader(%s)",
                cxxHeaderReferencePath, cxxHeaderGeneratedPath);
            auto generatedHeader = cxxHeaderGeneratedPath.readText;
            auto referenceHeader = cxxHeaderReferencePath.readText;

            // Ignore carriage return to unify the expected newlines
            version (Windows)
            {
                generatedHeader = generatedHeader.replace("\r\n", "\n"); // \r added by OutBuffer
                referenceHeader = referenceHeader.replace("\r\n", "\n"); // \r added by Git's if autocrlf is enabled
            }

            if (generatedHeader != referenceHeader) {
                if (env.getNumberedBool("AUTO_UPDATE"))
                {
                    generatedHeader.toFile(cxxHeaderReferencePath);
                    writeln("NOTICE: Reference header file (" ~ cxxHeaderReferencePath ~
                     ") has been auto-updated.");
                }
                else
                {
                    import core.runtime : Runtime;

                    string message = "ERROR: Newly generated header file (" ~ cxxHeaderGeneratedPath ~
                        ") doesn't match with the reference header file (" ~
                        cxxHeaderReferencePath ~ ")\n";
                    auto diff = tryRun(["git", "diff", "--no-index", cxxHeaderReferencePath, cxxHeaderGeneratedPath], runDir).output;
                    diff ~= "\n===============
The file `src/dmd/frontend.h` seems to be out of sync. This is likely because
changes were made which affect the C++ interface used by GDC and LDC.

Make sure that those changes have been properly reflected in the relevant header
files (e.g. `src/dmd/scope.h` for changes in `src/dmd/dscope.d`).

To update `frontend.h` and fix this error, run the following command:

`" ~ Runtime.args[0] ~ " cxx-headers-test AUTO_UPDATE=1`

Note that the generated code need not be valid, as the header generator
(`src/dmd/dtoh.d`) is still under development.

To read more about `frontend.h` and its usage, see src/README.md#cxx-headers-test
";
                    abortBuild(message, diff);
                }
            }
        });
});

/// Runs the C++ unittest executable
alias runCxxUnittest = makeRule!((runCxxBuilder, runCxxRule) {

    /// Compiles the C++ frontend test files
    alias cxxFrontend = methodInit!(BuildRule, (frontendBuilder, frontendRule) => frontendBuilder
        .name("cxx-frontend")
        .description("Build the C++ frontend")
        .msg("(CXX) CXX-FRONTEND")
        .sources(srcDir.buildPath("tests", "cxxfrontend.cc") ~ .sources.frontendHeaders ~ .sources.commonHeaders ~ .sources.rootHeaders /* Andrei ~ .sources.dmd.driver ~ .sources.dmd.frontend ~ .sources.root*/)
        .target(env["G"].buildPath("cxxfrontend").objName)
        // No explicit if since CXX_KIND will always be either g++ or clang++
        .command([ env["CXX"], "-xc++", "-std=c++11",
                   "-c", frontendRule.sources[0], "-o" ~ frontendRule.target, "-I" ~ env["D"] ] ~ flags["CXXFLAGS"])
    );

    alias cxxUnittestExe = methodInit!(BuildRule, (exeBuilder, exeRule) => exeBuilder
        .name("cxx-unittest")
        .description("Build the C++ unittests")
        .msg("(DC) CXX-UNITTEST")
        .deps([lexer(null, null), cxxFrontend])
        .sources(sources.dmd.driver ~ sources.dmd.frontend ~ sources.root ~ sources.common ~ env["D"].buildPath("cxxfrontend.d"))
        .target(env["G"].buildPath("cxx-unittest").exeName)
        .command([ env["HOST_DMD_RUN"], "-of=" ~ exeRule.target, "-vtls", "-J" ~ env["RES"],
                    "-L-lstdc++", "-version=NoMain", "-version=NoBackend"
            ].chain(
                flags["DFLAGS"], exeRule.sources, exeRule.deps.map!(d => d.target)
            ).array)
    );

    runCxxBuilder
        .name("cxx-unittest")
        .description("Run the C++ unittests")
        .msg("(RUN) CXX-UNITTEST");
    version (Windows) runCxxBuilder
        .commandFunction({ abortBuild("Running the C++ unittests is not supported on Windows yet"); });
    else runCxxBuilder
        .deps([cxxUnittestExe])
        .command([cxxUnittestExe.target]);
});

/// BuildRule that removes all generated files
alias clean = makeRule!((builder, rule) => builder
    .name("clean")
    .description("Remove the generated directory")
    .msg("(RM) " ~ env["G"])
    .commandFunction(delegate() {
        if (env["G"].exists)
            env["G"].rmdirRecurse;
    })
);

alias toolsRepo = makeRule!((builder, rule) => builder
    .target(env["TOOLS_DIR"])
    .msg("(GIT) DLANG/TOOLS")
    .condition(() => !exists(rule.target))
    .commandFunction(delegate() {
        auto toolsDir = env["TOOLS_DIR"];
        version(Win32)
            // Win32-git seems to confuse C:\... as a relative path
            toolsDir = toolsDir.relativePath(compilerDir);
        run([env["GIT"], "clone", "--depth=1", env["GIT_HOME"] ~ "/tools", toolsDir]);
    })
);

alias checkwhitespace = makeRule!((builder, rule) => builder
    .name("checkwhitespace")
    .description("Check for trailing whitespace and tabs")
    .msg("(RUN) checkwhitespace")
    .deps([toolsRepo])
    .sources(allRepoSources)
    .commandFunction(delegate() {
        const cmdPrefix = [env["HOST_DMD_RUN"], "-run", env["TOOLS_DIR"].buildPath("checkwhitespace.d")];
        auto chunkLength = allRepoSources.length;
        version (Win32)
            chunkLength = 80; // avoid command-line limit on win32
        foreach (nextSources; taskPool.parallel(allRepoSources.chunks(chunkLength), 1))
        {
            const nextCommand = cmdPrefix ~ nextSources;
            run(nextCommand);
        }
    })
);

alias style = makeRule!((builder, rule)
{
    const dscannerDir = env["GENERATED"].buildPath("dscanner");
    alias dscannerRepo = methodInit!(BuildRule, (repoBuilder, repoRule) => repoBuilder
        .msg("(GIT) DScanner")
        .target(dscannerDir)
        .condition(() => !exists(dscannerDir))
        .command([
            // FIXME: Omitted --shallow-submodules because it requires a more recent
            //        git version which is not available on buildkite
            env["GIT"], "clone", "--depth=1", "--recurse-submodules",
            "--branch=v0.14.0",
            "https://github.com/dlang-community/D-Scanner", dscannerDir
        ])
    );

    alias dscanner = methodInit!(BuildRule, (dscannerBuilder, dscannerRule) {
        dscannerBuilder
            .name("dscanner")
            .description("Build custom DScanner")
            .deps([dscannerRepo]);

        version (Windows) dscannerBuilder
            .msg("(CMD) DScanner")
            .target(dscannerDir.buildPath("bin", "dscanner".exeName))
            .commandFunction(()
            {
                // The build script expects to be run inside dscannerDir
                run([dscannerDir.buildPath("build.bat")], dscannerDir);
            });

        else dscannerBuilder
            .msg("(MAKE) DScanner")
            .target(dscannerDir.buildPath("dsc".exeName))
            .command([
                // debug build is faster but disable trace output
                env["MAKE"], "-C", dscannerDir, "debug",
                "DEBUG_VERSIONS=-version=StdLoggerDisableWarning"
            ]);
    });

    builder
        .name("style")
        .description("Check for style errors using D-Scanner")
        .msg("(DSCANNER) dmd")
        .deps([dscanner])
        // Disabled because we need to build a patched dscanner version
        // .command([
        //     "dub", "-q", "run", "-y", "dscanner", "--", "--styleCheck", "--config",
        //     srcDir.buildPath(".dscanner.ini"), srcDir.buildPath("dmd"), "-I" ~ srcDir
        // ])
        .command([
            dscanner.target, "--styleCheck", "--config", srcDir.buildPath(".dscanner.ini"),
            srcDir.buildPath("dmd"), "-I" ~ srcDir
        ]);
});

/// BuildRule to generate man pages
alias man = makeRule!((builder, rule) {
    alias genMan = methodInit!(BuildRule, (genManBuilder, genManRule) => genManBuilder
        .target(env["G"].buildPath("gen_man"))
        .sources([
            compilerDir.buildPath("docs", "gen_man.d"),
            env["D"].buildPath("cli.d")])
        .command([
            env["HOST_DMD_RUN"],
            "-I" ~ srcDir,
            "-of" ~ genManRule.target]
            ~ flags["DFLAGS"]
            ~ genManRule.sources)
        .msg(genManRule.command.join(" "))
    );

    const genManDir = env["GENERATED"].buildPath("docs", "man");
    alias dmdMan = methodInit!(BuildRule, (dmdManBuilder, dmdManRule) => dmdManBuilder
        .target(genManDir.buildPath("man1", "dmd.1"))
        .deps([genMan, directoryRule(dmdManRule.target.dirName)])
        .msg("(GEN_MAN) " ~ dmdManRule.target)
        .commandFunction(() {
            writeText(dmdManRule.target, genMan.target.execute.output);
        })
    );
    builder
    .name("man")
    .description("Generate and prepare man files")
    .deps([dmdMan].chain(
        "man1/dumpobj.1 man1/obj2asm.1 man5/dmd.conf.5".split
        .map!(e => methodInit!(BuildRule, (manFileBuilder, manFileRule) => manFileBuilder
            .target(genManDir.buildPath(e))
            .sources([compilerDir.buildPath("docs", "man", e)])
            .deps([directoryRule(manFileRule.target.dirName)])
            .commandFunction(() => copyAndTouch(manFileRule.sources[0], manFileRule.target))
            .msg("copy '%s' to '%s'".format(manFileRule.sources[0], manFileRule.target))
        ))
    ).array);
});

alias detab = makeRule!((builder, rule) => builder
    .name("detab")
    .description("Replace hard tabs with spaces")
    .command([env["DETAB"]] ~ allRepoSources)
    .msg("(DETAB) DMD")
);

alias tolf = makeRule!((builder, rule) => builder
    .name("tolf")
    .description("Convert to Unix line endings")
    .command([env["TOLF"]] ~ allRepoSources)
    .msg("(TOLF) DMD")
);

alias zip = makeRule!((builder, rule) => builder
    .name("zip")
    .target(srcDir.buildPath("dmdsrc.zip"))
    .description("Archive all source files")
    .sources(allBuildSources)
    .msg("ZIP " ~ rule.target)
    .commandFunction(() {
        if (exists(rule.target))
            remove(rule.target);
        run([env["ZIP"], rule.target, thisBuildScript] ~ rule.sources);
    })
);

alias html = makeRule!((htmlBuilder, htmlRule) {
    htmlBuilder
        .name("html")
        .description("Generate html docs, requires DMD and STDDOC to be set");
    static string d2html(string sourceFile)
    {
        const ext = sourceFile.extension();
        assert(ext == ".d" || ext == ".di", sourceFile);
        const htmlFilePrefix = (sourceFile.baseName == "package.d") ?
            sourceFile[0 .. $ - "package.d".length - 1] :
            sourceFile[0 .. $ - ext.length];
        return htmlFilePrefix ~ ".html";
    }
    const stddocs = env.get("STDDOC", "").split();
    auto docSources = .sources.common ~ .sources.root ~ .sources.lexer ~ .sources.dmd.all ~ env["D"].buildPath("frontend.d");
    htmlBuilder.deps(docSources.chunks(1).map!(sourceArray =>
        methodInit!(BuildRule, (docBuilder, docRule) {
            const source = sourceArray[0];
            docBuilder
            .sources(sourceArray)
            .target(env["DOC_OUTPUT_DIR"].buildPath(d2html(source)[srcDir.length + 1..$]
                .replace(dirSeparator, "_")))
            .deps([dmdDefault, versionFile, sysconfDirFile])
            .command([
                dmdDefault.deps[0].target,
                "-o-",
                "-c",
                "-Dd" ~ env["DOCSRC"],
                "-J" ~ env["RES"],
                "-I" ~ env["D"],
                srcDir.buildPath("project.ddoc")
                ] ~ stddocs ~ [
                    "-Df" ~ docRule.target,
                    // Need to use a short relative path to make sure ddoc links are correct
                    source.relativePath(runDir)
                ] ~ flags["DFLAGS"])
            .msg("(DDOC) " ~ source);
        })
    ).array);
});

alias toolchainInfo = makeRule!((builder, rule) => builder
    .name("toolchain-info")
    .description("Show informations about used tools")
    .commandFunction(() {
        scope Appender!(char[]) app;

        void show(string what, string[] cmd)
        {
            const res = tryRun(cmd);
            const output = res.status != -1
                        ? res.output
                        :  "<Not available>";

            app.formattedWrite("%s (%s): %s\n", what, cmd[0], output);
        }

        app.put("==== Toolchain Information ====\n");

        version (Windows)
            show("SYSTEM", ["systeminfo"]);
        else
            show("SYSTEM", ["uname", "-a"]);

        show("MAKE", [env["MAKE"], "--version"]);
        version (Posix)
            show("SHELL", [env.getDefault("SHELL", nativeShell), "--version"]);  // cmd.exe --version hangs
        show("HOST_DMD", [env["HOST_DMD_RUN"], "--version"]);
        version (Posix)
            show("HOST_CXX", [env["CXX"], "--version"]);
        show("ld", ["ld", "-v"]);
        show("gdb", ["gdb", "--version"]);

        app.put("==== Toolchain Information ====\n\n");

        writeln(app.data);
    })
);

alias installCopy = makeRule!((builder, rule) => builder
    .name("install-copy")
    .description("Legacy alias for install")
    .deps([install])
);

alias install = makeRule!((builder, rule) {
    const dmdExeFile = dmdDefault.deps[0].target;
    auto sourceFiles = allBuildSources ~ [
        env["D"].buildPath("README.md"),
        env["D"].buildPath("boostlicense.txt"),
    ];
    builder
    .name("install")
    .description("Installs dmd into $(INSTALL)")
    .deps([dmdDefault])
    .sources(sourceFiles)
    .commandFunction(() {
        version (Windows)
        {
            enum conf = "sc.ini";
            enum bin = "bin";
        }
        else
        {
            enum conf = "dmd.conf";
            version (OSX)
                enum bin = "bin";
            else
                const bin = "bin" ~ env["MODEL"];
        }

        installRelativeFiles(env["INSTALL"].buildPath(env["OS"], bin), dmdExeFile.dirName, dmdExeFile.only, octal!755);

        version (Windows)
            installRelativeFiles(env["INSTALL"], compilerDir, sourceFiles);

        const scPath = buildPath(env["OS"], bin, conf);
        const iniPath = buildPath(compilerDir, "ini");

        // The sources distributed alongside an official release only include the
        // configuration of the current OS at the root directory instead of the
        // whole `ini` folder in the project root.
        const confPath = iniPath.exists()
                        ? buildPath(iniPath, scPath)
                        : buildPath(dmdRepo, scPath);

        copyAndTouch(confPath, buildPath(env["INSTALL"], scPath));

        version (Posix)
            copyAndTouch(sourceFiles[$-1], env["INSTALL"].buildPath("dmd-boostlicense.txt"));

    });
});

/**
Goes through the target list and replaces short-hand targets with their expanded version.
Special targets:
- clean -> removes generated directory + immediately stops the builder

Params:
    targets = the target list to process
Returns:
    the expanded targets
*/
BuildRule[] predefinedTargets(string[] targets)
{
    import std.functional : toDelegate;
    Appender!(BuildRule[]) newTargets;
LtargetsLoop:
    foreach (t; targets)
    {
        t = t.buildNormalizedPath; // remove trailing slashes

        // check if `t` matches any rule names first
        foreach (rule; BuildRuleRange(rootRules.map!(a => a()).array))
        {
            if (t == rule.name)
            {
                newTargets.put(rule);
                continue LtargetsLoop;
            }
        }

        switch (t)
        {
            case "all":
                // "all" must include dmd + dmd.conf
                newTargets ~= dmdDefault;
                break;

            default:
                // check this last, target paths should be checked after predefined names
                const tAbsolute = t.absolutePath.buildNormalizedPath;
                foreach (rule; BuildRuleRange(rootRules.map!(a => a()).array))
                {
                    foreach (ruleTarget; rule.targets)
                    {
                        if (ruleTarget.endsWith(t, tAbsolute))
                        {
                            newTargets.put(rule);
                            continue LtargetsLoop;
                        }
                    }
                }

                abortBuild("Target `" ~ t ~ "` is unknown.");
        }
    }
    return newTargets.data;
}

/// An input range for a recursive set of rules
struct BuildRuleRange
{
    private BuildRule[] next;
    private bool[BuildRule] added;
    this(BuildRule[] rules) { addRules(rules); }
    bool empty() const { return next.length == 0; }
    auto front() inout { return next[0]; }
    void popFront()
    {
        auto save = next[0];
        next = next[1 .. $];
        addRules(save.deps);
    }
    void addRules(BuildRule[] rules)
    {
        foreach (rule; rules)
        {
            if (!added.get(rule, false))
            {
                next ~= rule;
                added[rule] = true;
            }
        }
    }
}

/// Sets the environment variables
void parseEnvironment()
{
    if (!verbose)
        verbose = "1" == env.getDefault("VERBOSE", null);

    // This block is temporary until we can remove the windows make files
    if ("DDEBUG" in environment)
        abortBuild("ERROR: the DDEBUG variable is deprecated!");

    version (Windows)
    {
        // On windows, the OS environment variable is already being used by the system.
        // For example, on a default Windows7 system it's configured by the system
        // to be "Windows_NT".
        //
        // However, there are a good number of components in this repo and the other
        // repos that set this environment variable to "windows" without checking whether
        // it's already configured, i.e.
        //      dmd\src\win32.mak (OS=windows)
        //      druntime\win32.mak (OS=windows)
        //      phobos\win32.mak (OS=windows)
        //
        // It's necessary to emulate the same behavior in this tool in order to make this
        // new tool compatible with existing tools. We can do this by also setting the
        // environment variable to "windows" whether or not it already has a value.
        //
        const os = env["OS"] = "windows";
    }
    else
        const os = env.setDefault("OS", detectOS);
    auto build = env.setDefault("BUILD", "release");
    enforce(build.among("release", "debug"), "BUILD must be 'debug' or 'release'");

    if (build == "debug")
        env.setDefault("ENABLE_DEBUG", "1");

    // detect Model
    auto model = env.setDefault("MODEL", detectModel);
    if (env.getDefault("DFLAGS", "").canFind("-mtriple", "-march"))
    {
        // Don't pass `-m32|64` flag when explicitly passing triple or arch.
        env["MODEL_FLAG"] = "";
    }
    else
    {
        env["MODEL_FLAG"] = "-m" ~ env["MODEL"];
    }

    // detect PIC
    version(Posix)
    {
        // default to PIC if the host compiler supports, use PIC=1/0 to en-/disable PIC.
        // Note that shared libraries and C files are always compiled with PIC.
        bool pic = true;
        const picValue = env.getDefault("PIC", "");
        switch (picValue)
        {
            case "": /** Keep the default **/ break;
            case "0": pic = false; break;
            case "1": pic = true; break;
            default:
                throw abortBuild(format("Variable 'PIC' should be '0', '1' or <empty> but got '%s'", picValue));
        }
        version (X86)
        {
            // https://issues.dlang.org/show_bug.cgi?id=20466
            static if (__VERSION__ < 2090)
            {
                pragma(msg, "Warning: PIC will be off by default for this build of DMD because of Issue 20466!");
                pic = false;
            }
        }

        env["PIC_FLAG"]  = pic ? "-fPIC" : "";
    }
    else
    {
        env["PIC_FLAG"] = "";
    }

    env.setDefault("GIT", "git");
    env.setDefault("GIT_HOME", "https://github.com/dlang");
    env.setDefault("SYSCONFDIR", "/etc");
    env.setDefault("TMP", tempDir);
    env.setDefault("RES", srcDir.buildPath("dmd", "res"));
    env.setDefault("MAKE", "make");

    version (Windows)
        enum installPref = "";
    else
        enum installPref = "..";

    env.setDefault("INSTALL", environment.get("INSTALL_DIR", compilerDir.buildPath(installPref, "install")));

    env.setDefault("DOCSRC", compilerDir.buildPath("dlang.org"));
    env.setDefault("DOCDIR", srcDir);
    env.setDefault("DOC_OUTPUT_DIR", env["DOCDIR"]);

    auto d = env["D"] = srcDir.buildPath("dmd");
    env["C"] = d.buildPath("backend");
    env["COMMON"] = d.buildPath("common");
    env["ROOT"] = d.buildPath("root");
    env["EX"] = srcDir.buildPath("examples");
    auto generated = env["GENERATED"] = dmdRepo.buildPath("generated");
    auto g = env["G"] = generated.buildPath(os, build, model);
    mkdirRecurse(g);
    env.setDefault("TOOLS_DIR", compilerDir.dirName.buildPath("tools"));

    auto hostDmdDef = env.getDefault("HOST_DMD", null);
    if (hostDmdDef.length == 0)
    {
        const hostDmd = env.getDefault("HOST_DC", null);
        env["HOST_DMD"] = hostDmd.length ? hostDmd : "dmd";
    }
    else
        // HOST_DMD may be defined in the environment
        env["HOST_DMD"] = hostDmdDef;

    // Auto-bootstrapping of a specific host compiler
    if (env.getNumberedBool("AUTO_BOOTSTRAP"))
    {
        auto hostDMDVer = env.getDefault("HOST_DMD_VER", "2.095.0");
        writefln("Using Bootstrap compiler: %s", hostDMDVer);
        auto hostDMDRoot = env["G"].buildPath("host_dmd-"~hostDMDVer);
        auto hostDMDBase = hostDMDVer~"."~(os == "freebsd" ? os~"-"~model : os);
        auto hostDMDURL = "https://downloads.dlang.org/releases/2.x/"~hostDMDVer~"/dmd."~hostDMDBase;
        env["HOST_DMD"] = hostDMDRoot.buildPath("dmd2", os, os == "osx" ? "bin" : "bin"~model, "dmd");
        env["HOST_DMD_PATH"] = env["HOST_DMD"];
        // TODO: use dmd.conf from the host too (in case there's a global or user-level dmd.conf)
        env["HOST_DMD_RUN"] = env["HOST_DMD"];
        if (!env["HOST_DMD"].exists)
        {
            writefln("Downloading DMD %s", hostDMDVer);
            auto curlFlags = "-fsSL --retry 5 --retry-max-time 120 --connect-timeout 5 --speed-time 30 --speed-limit 1024";
            hostDMDRoot.mkdirRecurse;
            ("curl " ~ curlFlags ~ " " ~ hostDMDURL~".tar.xz | tar -C "~hostDMDRoot~" -Jxf - || rm -rf "~hostDMDRoot).spawnShell.wait;
        }
    }
    else
    {
        env["HOST_DMD_PATH"] = getHostDMDPath(env["HOST_DMD"]).strip.absolutePath;
        env["HOST_DMD_RUN"] = env["HOST_DMD_PATH"];
    }

    if (!env["HOST_DMD_PATH"].exists)
    {
        abortBuild("No DMD compiler is installed. Try AUTO_BOOTSTRAP=1 or manually set the D host compiler with HOST_DMD");
    }
}

/// Checks the environment variables and flags
void processEnvironment()
{
    import std.meta : AliasSeq;

    const os = env["OS"];

    // Detect the host compiler kind and version
    const hostDmdInfo = [env["HOST_DMD_RUN"], `-Xi=compilerInfo`, `-Xf=-`].execute();

    if (hostDmdInfo.status) // Failed, JSON output currently not supported for GDC
    {
        env["HOST_DMD_KIND"] = "gdc";
        env["HOST_DMD_VERSION"] = "v2.076";
    }
    else
    {
        /// Reads the content of a single field without parsing the entire JSON
        alias get = field => hostDmdInfo.output
            .findSplitAfter(field ~ `" : "`)[1]
            .findSplitBefore(`"`)[0];

        const ver = env["HOST_DMD_VERSION"] = get(`version`)[1 .. "vX.XXX.X".length];

        // Vendor was introduced in 2.080
        if (ver < "2.080.1")
        {
            auto name = get("binary").baseName().stripExtension();
            if (name == "ldmd2")
                name = "ldc";
            else if (name == "gdmd")
                name = "gdc";
            else
                enforce(name == "dmd", "Unknown compiler: " ~ name);

            env["HOST_DMD_KIND"] = name;
        }
        else
        {
            env["HOST_DMD_KIND"] = [
                "Digital Mars D": "dmd",
                "LDC": "ldc",
                "GNU D": "gdc"
            ][get(`vendor`)];
        }
    }

    env["DMD_PATH"] = env["G"].buildPath("dmd").exeName;
    env.setDefault("DETAB", "detab");
    env.setDefault("TOLF", "tolf");
    version (Windows)
        env.setDefault("ZIP", "zip32");
    else
        env.setDefault("ZIP", "zip");

    string[] dflags = ["-w", "-de", env["PIC_FLAG"], env["MODEL_FLAG"], "-J"~env["G"], "-I" ~ srcDir];

    // TODO: add support for dObjc
    auto dObjc = false;
    version(OSX) version(X86_64)
        dObjc = true;

    if (env.getNumberedBool("ENABLE_DEBUG"))
    {
        dflags ~= ["-g", "-debug"];
    }
    if (env.getNumberedBool("ENABLE_RELEASE"))
    {
        dflags ~= ["-O", "-inline"];
        if (!env.getNumberedBool("ENABLE_ASSERTS"))
            dflags ~= ["-release"];
    }
    else
    {
        // add debug symbols for all non-release builds
        if (!dflags.canFind("-g"))
            dflags ~= ["-g"];
    }
    if (env.getNumberedBool("ENABLE_LTO"))
    {
        switch (env["HOST_DMD_KIND"])
        {
            case "dmd":
                stderr.writeln(`DMD does not support LTO! Ignoring ENABLE_LTO flag...`);
                break;
            case "ldc":
                dflags ~= "-flto=full";
                // workaround missing druntime-ldc-lto on 32-bit releases
                // https://github.com/dlang/dmd/pull/14083#issuecomment-1125832084
                if (env["MODEL"] != "32")
                    dflags ~= "-defaultlib=druntime-ldc-lto";
                break;
            case "gdc":
                dflags ~= "-flto";
                break;
            default:
                assert(false, "Unknown host compiler kind: " ~ env["HOST_DMD_KIND"]);
        }
    }
    if (env.getNumberedBool("ENABLE_UNITTEST"))
    {
        dflags ~= ["-unittest"];
    }
    if (env.getNumberedBool("ENABLE_PROFILE"))
    {
        dflags ~= ["-profile"];
    }

    // Enable CTFE coverage for recent host compilers
    const cov = env["HOST_DMD_VERSION"] >= "2.094.0" ? "-cov=ctfe" : "-cov";
    env["COVERAGE_FLAG"] = cov;

    if (env.getNumberedBool("ENABLE_COVERAGE"))
    {
        dflags ~= [ cov ];
    }
    const sanitizers = env.getDefault("ENABLE_SANITIZERS", "");
    if (!sanitizers.empty)
    {
        dflags ~= ["-fsanitize="~sanitizers];
    }

    // Determine the version of FreeBSD that we're building on if the target OS
    // version has not already been set.
    version (FreeBSD)
    {
        import std.ascii : isDigit;

        if (flags.get("DFLAGS", []).find!(a => a.startsWith("-version=TARGET_FREEBSD"))().empty)
        {
            // uname -K gives the kernel version, e.g. 1400097. The first two
            // digits correspond to the major version of the OS.
            immutable result = executeShell("uname -K");
            if (result.status != 0 || !result.output.take(2).all!isDigit())
                throw abortBuild("Failed to get the kernel version");
            dflags ~= ["-version=TARGET_FREEBSD" ~ result.output[0 .. 2]];
        }
    }

    // Retain user-defined flags
    flags["DFLAGS"] = dflags ~= flags.get("DFLAGS", []);
}

/// Setup environment for a C++ compiler
void processEnvironmentCxx()
{
    // Windows requires additional work to handle e.g. Cygwin on Azure
    version (Windows) return;

    env.setDefault("CXX", "c++");
    // env["CXX_KIND"] = detectHostCxx();

    string[] warnings  = [
        "-Wall", "-Werror", "-Wno-narrowing", "-Wwrite-strings", "-Wcast-qual", "-Wno-format",
        "-Wmissing-format-attribute", "-Woverloaded-virtual", "-pedantic", "-Wno-long-long",
        "-Wno-variadic-macros", "-Wno-overlength-strings",
    ];

    auto cxxFlags = warnings ~ [
        "-g", "-fno-exceptions", "-fno-rtti", "-fno-common", "-fasynchronous-unwind-tables", "-DMARS=1",
        env["MODEL_FLAG"], env["PIC_FLAG"],
    ];

    if (env.getNumberedBool("ENABLE_COVERAGE"))
        cxxFlags ~= "--coverage";

    const sanitizers = env.getDefault("ENABLE_SANITIZERS", "");
    if (!sanitizers.empty)
        cxxFlags ~= "-fsanitize=" ~ sanitizers;

    // Enable a temporary workaround in globals.h and rmem.h concerning
    // wrong name mangling using DMD.
    // Remove when the minimally required D version becomes 2.082 or later
    if (env["HOST_DMD_KIND"] == "dmd")
    {
        const output = run([ env["HOST_DMD_RUN"], "--version" ]);

        if (output.canFind("v2.079", "v2.080", "v2.081"))
            cxxFlags ~= "-DDMD_VERSION=2080";
    }

    // Retain user-defined flags
    flags["CXXFLAGS"] = cxxFlags ~= flags.get("CXXFLAGS", []);
}

/// Returns: the host C++ compiler, either "g++" or "clang++"
version (none) // Currently unused but will be needed at some point
string detectHostCxx()
{
    import std.meta: AliasSeq;

    const cxxVersion = [env["CXX"], "--version"].execute.output;

    alias GCC = AliasSeq!("g++", "gcc", "Free Software");
    alias CLANG = AliasSeq!("clang");

    const cxxKindIdx = cxxVersion.canFind(GCC, CLANG);
    enforce(cxxKindIdx, "Invalid CXX found: " ~ cxxVersion);

    return cxxKindIdx <= GCC.length ? "g++" : "clang++";
}

////////////////////////////////////////////////////////////////////////////////
// D source files
////////////////////////////////////////////////////////////////////////////////

/// Returns: all source files in the repository
alias allRepoSources = memoize!(() => srcDir.dirEntries("*.{d,h,di}", SpanMode.depth).map!(e => e.name).array);

/// Returns: all make/build files
alias buildFiles = memoize!(() => "osmodel.mak build.d".split().map!(e => srcDir.buildPath(e)).array);

/// Returns: all sources used in the build
alias allBuildSources = memoize!(() => buildFiles
    ~ sources.dmd.all
    ~ sources.lexer
    ~ sources.common
    ~ sources.backend
    ~ sources.root
    ~ sources.commonHeaders
    ~ sources.frontendHeaders
    ~ sources.rootHeaders
);

/// Returns: all source files for the compiler
auto sourceFiles()
{
    static struct DmdSources
    {
        string[] all, driver, frontend, glue, backendHeaders;
    }
    static struct Sources
    {
        DmdSources dmd;
        string[] lexer, common, root, backend, commonHeaders, frontendHeaders, rootHeaders;
    }
    static string[] fileArray(string dir, string files)
    {
        return files.split.map!(e => dir.buildPath(e)).array;
    }
    DmdSources dmd = {
        glue: fileArray(env["D"], "
            dmsc.d e2ir.d iasmdmd.d glue.d objc_glue.d
            s2ir.d tocsym.d toctype.d tocvdebug.d todt.d toir.d toobj.d
        "),
        driver: fileArray(env["D"], "dinifile.d dmdparams.d gluelayer.d lib/package.d lib/elf.d lib/mach.d lib/mscoff.d
            link.d mars.d main.d sarif.d lib/scanelf.d lib/scanmach.d lib/scanmscoff.d timetrace.d vsoptions.d
        "),
        frontend: fileArray(env["D"], "
            access.d aggregate.d aliasthis.d argtypes_x86.d argtypes_sysv_x64.d argtypes_aarch64.d arrayop.d
            arraytypes.d astenums.d ast_node.d astcodegen.d asttypename.d attrib.d attribsem.d blockexit.d builtin.d canthrow.d chkformat.d
            cli.d clone.d compiler.d cond.d constfold.d  cpreprocess.d ctfeexpr.d
            ctorflow.d dcast.d dclass.d declaration.d delegatize.d denum.d deps.d dimport.d
            dinterpret.d dmacro.d dmodule.d doc.d dscope.d dstruct.d dsymbol.d dsymbolsem.d
            dtemplate.d dtoh.d dversion.d enumsem.d escape.d expression.d expressionsem.d func.d funcsem.d hdrgen.d iasm.d iasmgcc.d
            impcnvtab.d imphint.d importc.d init.d initsem.d inline.d inlinecost.d intrange.d json.d lambdacomp.d
            mtype.d mustuse.d nogc.d nspace.d ob.d objc.d opover.d optimize.d
            parse.d pragmasem.d printast.d rootobject.d safe.d
            semantic2.d semantic3.d sideeffect.d statement.d
            statementsem.d staticassert.d staticcond.d stmtstate.d target.d templatesem.d templateparamsem.d traits.d
            typesem.d typinf.d utils.d
            mangle/package.d mangle/basic.d mangle/cpp.d mangle/cppwin.d
            visitor/package.d visitor/foreachvar.d visitor/parsetime.d visitor/permissive.d visitor/postorder.d visitor/statement_rewrite_walker.d
            visitor/strict.d visitor/transitive.d
            cparse.d
        "),
        backendHeaders: fileArray(env["C"], "
            cc.d cdef.d cgcv.d code.d dt.d el.d global.d
            obj.d oper.d rtlsym.d iasm.d codebuilder.d
            ty.d type.d dlist.d
            dwarf.d dwarf2.d cv4.d
            melf.d mscoff.d mach.d
            x86/code_x86.d x86/xmm.d
        "),
    };
    foreach (member; __traits(allMembers, DmdSources))
    {
        if (member != "all") dmd.all ~= __traits(getMember, dmd, member);
    }
    Sources sources = {
        dmd: dmd,
        frontendHeaders: fileArray(env["D"], "
            aggregate.h aliasthis.h arraytypes.h attrib.h compiler.h cond.h
            ctfe.h declaration.h dsymbol.h doc.h enum.h errors.h expression.h globals.h hdrgen.h
            identifier.h id.h import.h init.h json.h mangle.h module.h mtype.h nspace.h objc.h rootobject.h
            scope.h statement.h staticassert.h target.h template.h tokens.h version.h visitor.h
        "),
        lexer: fileArray(env["D"], "
            console.d entity.d errors.d errorsink.d file_manager.d globals.d id.d identifier.d lexer.d location.d tokens.d
        ") ~ fileArray(env["ROOT"], "
            array.d bitarray.d ctfloat.d file.d filename.d hash.d port.d region.d rmem.d
            stringtable.d utf.d
        "),
        common: fileArray(env["COMMON"], "
            bitfields.d file.d int128.d blake3.d outbuffer.d smallbuffer.d charactertables.d identifiertables.d
        "),
        commonHeaders: fileArray(env["COMMON"], "
            outbuffer.h
        "),
        root: fileArray(env["ROOT"], "
            aav.d complex.d env.d longdouble.d man.d optional.d response.d speller.d string.d strtold.d
        "),
        rootHeaders: fileArray(env["ROOT"], "
            array.h bitarray.h complex_t.h ctfloat.h dcompat.h dsystem.h filename.h longdouble.h
            optional.h port.h rmem.h root.h
        "),
        backend: fileArray(env["C"], "
            bcomplex.d evalu8.d divcoeff.d dvec.d go.d gsroa.d glocal.d gdag.d gother.d gflow.d
            dout.d inliner.d eh.d aarray.d
            gloop.d cgelem.d cgcs.d ee.d blockopt.d mem.d cg.d
            dtype.d debugprint.d fp.d symbol.d symtab.d elem.d dcode.d cgsched.d
            pdata.d util2.d var.d backconfig.d drtlsym.d ptrntab.d
            dvarstats.d cgen.d goh.d barray.d cgcse.d elpicpie.d
            dwarfeh.d dwarfdbginf.d cv8.d dcgcv.d
            machobj.d elfobj.d mscoffobj.d
            x86/nteh.d x86/cgreg.d x86/cg87.d x86/cgxmm.d x86/disasm86.d
            x86/cgcod.d x86/cod1.d x86/cod2.d x86/cod3.d x86/cod4.d x86/cod5.d
            arm/disasmarm.d arm/instr.d arm/cod1.d arm/cod2.d arm/cod3.d arm/cod4.d
            "
        ),
    };

    return sources;
}

/**
Downloads a file from a given URL

Params:
    to    = Location to store the file downloaded
    from  = The URL to the file to download
    tries = The number of times to try if an attempt to download fails
Returns: `true` if download succeeded
*/
bool download(string to, string from, uint tries = 3)
{
    import std.net.curl : download, HTTP, HTTPStatusException;

    foreach(i; 0..tries)
    {
        try
        {
            log("Downloading %s ...", from);
            auto con = HTTP(from);
            download(from, to, con);

            if (con.statusLine.code == 200)
                return true;
        }
        catch(HTTPStatusException e)
        {
            if (e.status == 404) throw e;
        }

        log("Failed to download %s (Attempt %s of %s)", from, i + 1, tries);
    }

    return false;
}

/**
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
    else
        static assert(0, "Unrecognized or unsupported OS.");
}

/**
Detects the host model

Returns: 32, 64 or throws an Exception
*/
string detectModel()
{
    string uname;
    if (detectOS == "solaris")
        uname = ["isainfo", "-n"].execute.output;
    else if (detectOS == "windows")
    {
        version (D_LP64)
            return "64"; // host must be 64-bit if this compiles
        else version (Windows)
        {
            import core.sys.windows.winbase;
            int is64;
            if (IsWow64Process(GetCurrentProcess(), &is64))
                return is64 ? "64" : "32";
        }
    }
    else
        uname = ["uname", "-m"].execute.output;

    if (uname.canFind("x86_64", "amd64", "aarch64", "arm64", "64-bit", "64-Bit", "64 bit"))
        return "64";
    if (uname.canFind("i386", "i586", "i686", "32-bit", "32-Bit", "32 bit"))
        return "32";

    throw new Exception(`Cannot figure 32/64 model from "` ~ uname ~ `"`);
}

/**
Gets the absolute path of the host's dmd executable

Params:
    hostDmd = the command used to launch the host's dmd executable
Returns: a string that is the absolute path of the host's dmd executable
*/
string getHostDMDPath(const string hostDmd)
{
    version(Posix)
        return ["which", hostDmd].execute.output;
    else version(Windows)
    {
        if (hostDmd.canFind("/", "\\"))
            return hostDmd;
        return ["where", hostDmd].execute.output
            .lineSplitter.filter!(file => file != srcDir.buildPath("dmd.exe")).front;
    }
    else
        static assert(false, "Unrecognized or unsupported OS.");
}

/**
Add the executable filename extension to the given `name` for the current OS.

Params:
    name = the name to append the file extention to
*/
string exeName(const string name)
{
    version(Windows)
        return name ~ ".exe";
    return name;
}

/**
Add the object file extension to the given `name` for the current OS.

Params:
    name = the name to append the file extention to
*/
string objName(const string name)
{
    version(Windows)
        return name ~ ".obj";
    return name ~ ".o";
}

/**
Add the library file extension to the given `name` for the current OS.

Params:
    name = the name to append the file extention to
*/
string libName(const string name)
{
    version(Windows)
        return name ~ ".lib";
    return name ~ ".a";
}

/**
Filter additional make-like assignments from args and add them to the environment
e.g. ./build.d ARGS=foo sets env["ARGS"] = environment["ARGS"] = "foo".

The variables DLFAGS and CXXFLAGS may contain flags intended for the
respective compiler and set flags instead, e.g. ./build.d DFLAGS="-w -version=foo"
results in flags["DFLAGS"] = ["-w", "-version=foo"].

Params:
    args = the command-line arguments from which the assignments will be removed
*/
void args2Environment(ref string[] args)
{
    bool tryToAdd(string arg)
    {
        auto parts = arg.findSplit("=");

        if (!parts)
            return false;

        const key = parts[0];
        const value = parts[2];

        if (key.among("DFLAGS", "CXXFLAGS"))
        {
            flags[key] = value.split();
        }
        else
        {
            environment[key] = value;
            env[key] = value;
        }
        return true;
    }
    args = args.filter!(a => !tryToAdd(a)).array;
}

/**
Ensures that `env` contains a mapping for `key` and returns the associated value.
Searches the process environment if it is missing and uses `default_` as a
last fallback.

Params:
    env = environment to check for `key`
    key = key to check for existence
    default_ = fallback value if `key` doesn't exist in the global environment

Returns: the value associated to key
*/
string getDefault(ref string[string] env, string key, string default_)
{
    if (auto ex = key in env)
        return *ex;

    if (key in environment)
        return environment[key];
    else
        return default_;
}

/**
Ensures that `env` contains a mapping for `key` and returns the associated value.
Searches the process environment if it is missing and creates an appropriate
entry in `env` using either the found value or `default_` as a fallback.

Params:
    env = environment to write the check to
    key = key to check for existence and write into the new env
    default_ = fallback value if `key` doesn't exist in the global environment

Returns: the value associated to key
*/
string setDefault(ref string[string] env, string key, string default_)
{
    auto v = getDefault(env, key, default_);
    env[key] = v;
    return v;
}

/**
Get the value of a build variable that should always be 0, 1 or empty.
*/
bool getNumberedBool(ref string[string] env, string varname)
{
    const value = env.getDefault(varname, null);
    if (value.length == 0 || value == "0")
        return false;
    if (value == "1")
        return true;
    throw abortBuild(format("Variable '%s' should be '0', '1' or <empty> but got '%s'", varname, value));
}

////////////////////////////////////////////////////////////////////////////////
// Mini build system
////////////////////////////////////////////////////////////////////////////////
/**
Checks whether any of the targets are older than the sources

Params:
    targets = the targets to check
    sources = the source files to check against
Returns:
    `true` if the target is up to date
*/
bool isUpToDate(R, S)(R targets, S sources)
{
    if (force)
        return false;
    auto oldestTargetTime = SysTime.max;
    foreach (target; targets)
    {
        const time = target.timeLastModified.ifThrown(SysTime.init);
        if (time == SysTime.init)
            return false;
        oldestTargetTime = min(time, oldestTargetTime);
    }
    return sources.all!(s => s.timeLastModified.ifThrown(SysTime.init) <= oldestTargetTime);
}

/**
Writes given the content to the given file.

The content will only be written to the file specified in `path` if that file
doesn't exist, or the content of the existing file is different from the given
content.

This makes sure the timestamp of the file is only updated when the
content has changed. This will avoid rebuilding when the content hasn't changed.

Params:
    path = the path to the file to write the content to
    content = the content to write to the file
*/
void updateIfChanged(const string path, const string content)
{
    const existingContent = path.exists ? path.readText : "";

    if (content != existingContent)
        writeText(path, content);
}

/**
A rule has one or more sources and yields one or more targets.
It knows how to build these target by invoking either the external command or
the commandFunction.

If a run fails, the entire build stops.
*/
class BuildRule
{
    string target; // path to the resulting target file (if target is used, it will set targets)
    string[] targets; // list of all target files
    string[] sources; // list of all source files
    BuildRule[] deps; // dependencies to build before this one
    bool delegate() condition; // Optional condition to determine whether or not to run this rule
    string[] command; // the rule command
    void delegate() commandFunction; // a custom rule command which gets called instead of command
    string msg; // msg of the rule that is e.g. written to the CLI when it's executed
    string name; /// optional string that can be used to identify this rule
    string description; /// optional string to describe this rule rather than printing the target files

    /// Finish creating the rule by checking that it is configured properly
    void finalize()
    {
        if (target)
        {
            assert(!targets, "target and targets cannot both be set");
            targets = [target];
        }
    }

    /**
    Executes the rule

    Params:
        depUpdated = whether any dependency was built (skips isUpToDate)

    Returns: Whether the targets of this rule were (re)built
    **/
    bool run(bool depUpdated = false)
    {
        if (condition !is null && !condition())
        {
            log("Skipping build of %-(%s%) as its condition returned false", targets);
            return false;
        }

        if (!depUpdated && targets && targets.isUpToDate(this.sources.chain([thisBuildScript])))
        {
            if (this.sources !is null)
                log("Skipping build of %-('%s' %)' because %s is newer than each of %-('%s' %)'",
                    targets, targets.length > 1 ? "each of them" : "it", this.sources);
            return false;
        }

        // Display the execution of the rule
        if (msg)
            msg.writeln;

        if(dryRun)
        {
            scope writer = stdout.lockingTextWriter;

            if(commandFunction)
            {
                writer.put("\n => Executing commandFunction()");

                if(name)
                    writer.formattedWrite!" of %s"(name);

                if(targets.length)
                    writer.formattedWrite!" to generate:\n%(    - %s\n%)"(targets);

                writer.put('\n');
            }
            if(command)
                writer.formattedWrite!"\n => %(%s %)\n\n"(command);
        }
        else
        {
            scope (failure) if (!verbose) dump();

            if (commandFunction !is null)
            {
                commandFunction();
            }
            else if (command.length)
            {
                command.run;
            }
            else
                // Do not automatically return true if the target has neither
                // command nor command function (e.g. dmdDefault) to avoid
                // unecessary rebuilds
                return depUpdated;
        }

        return true;
    }

    /// Writes relevant informations about this rule to stdout
    private void dump()
    {
        scope writer = stdout.lockingTextWriter;
        void write(T)(string fmt, T what)
        {
            static if (is(T : bool))
                bool print = what;
            else
                bool print = what.length != 0;

            if (print)
                writer.formattedWrite(fmt, what);
        }

        writer.put("\nThe following operation failed:\n");
        write("Name: %s\n", name);
        write("Description: %s\n", description);
        write("Dependencies: %-(\n -> %s%)\n\n", deps.map!(d => d.name ? d.name : d.target));
        write("Sources: %-(\n -> %s%)\n\n", sources);
        write("Targets: %-(\n -> %s%)\n\n", targets);
        write("Command: %-(%s %)\n\n", command);
        write("CommandFunction: %-s\n\n", commandFunction ? "Yes" : null);
        writer.put("-----------------------------------------------------------\n");
    }
}

/// Fake namespace containing all utilities to execute many rules in parallel
abstract final class Scheduler
{
    /**
    Builds the supplied targets in parallel using the global taskPool.

    Params:
        targets = rules to build
    **/
    static void build(BuildRule[] targets)
    {
        // Create an execution plan to build all targets
        Context[BuildRule] contexts;
        Context[] topSorted, leaves;

        foreach(target; targets)
            findLeafs(target, contexts, topSorted, leaves);

        // Start all leaves in parallel, they will submit the remaining tasks recursively
        foreach (leaf; leaves)
            taskPool.put(leaf.task);

        // Await execution of all targets while executing pending tasks. The
        // topological order of tasks guarantees that every tasks was already
        // submitted to taskPool before we call workForce.
        foreach (context; topSorted)
            context.task.workForce();
    }

    /**
    Recursively creates contexts instances for rule and all of its dependencies and stores
    them in contexts, tasks and leaves for further usage.

    Params:
        rule = current rule
        contexts = already created context instances
        tasks = context instances in topological order implied by Dependency.deps
        leaves = contexts of rules without dependencies

    Returns: the context belonging to rule
    **/
    private static Context findLeafs(BuildRule rule, ref Context[BuildRule] contexts, ref Context[] all, ref Context[] leaves)
    {
        // This implementation is based on Tarjan's algorithm for topological sorting.

        auto context = contexts.get(rule, null);

        // Check whether the current node wasn't already visited
        if (context is null)
        {
            context = contexts[rule] = new Context(rule);

            // Leafs are rules without further dependencies
            if (rule.deps.empty)
            {
                leaves ~= context;
            }
            else
            {
                // Recursively visit all dependencies
                foreach (dep; rule.deps)
                {
                    auto depContext = findLeafs(dep, contexts, all, leaves);
                    depContext.requiredBy ~= context;
                }
            }

            // Append the current rule AFTER all dependencies
            all ~= context;
        }

        return context;
    }

    /// Metadata required for parallel execution
    private static class Context
    {
        import std.parallelism: createTask = task;
        alias Task = typeof(createTask(&Context.init.buildRecursive)); /// Task type

        BuildRule target; /// the rule to execute
        Context[] requiredBy; /// rules relying on this one
        shared size_t pendingDeps; /// amount of rules to be built
        shared bool depUpdated; /// whether any dependency of target was updated
        Task task; /// corresponding task

        /// Creates a new context for rule
        this(BuildRule rule)
        {
            this.target = rule;
            this.pendingDeps = rule.deps.length;
            this.task = createTask(&buildRecursive);
        }

        /**
        Builds the rule given by this context and schedules other rules
        requiring it (if the current was the last missing dependency)
        **/
        private void buildRecursive()
        {
            import core.atomic: atomicLoad, atomicOp, atomicStore;

            /// Stores whether the current build is stopping because some step failed
            static shared bool aborting;
            if (atomicLoad(aborting))
                return; // Abort but let other jobs finish

            scope (failure) atomicStore(aborting, true);

            // Build the current rule
            if (target.run(depUpdated))
            {
                // Propagate that this rule's targets were (re)built
                foreach (parent; requiredBy)
                    atomicStore(parent.depUpdated, true);
            }

            // Mark this rule as finished for all parent rules
            foreach (parent; requiredBy)
            {
                if (parent.pendingDeps.atomicOp!"-="(1) == 0)
                    taskPool.put(parent.task);
            }
        }
    }
}

/** Initializes an object using a chain of method calls */
struct MethodInitializer(T) if (is(T == class)) // currenly only works with classes
{
    private T obj;

    ref MethodInitializer opDispatch(string name)(typeof(__traits(getMember, T, name)) arg)
    {
        __traits(getMember, obj, name) = arg;
        return this;
    }
}

/** Create an object using a chain of method calls for each field. */
T methodInit(T, alias Func, Args...)(Args args) if (is(T == class)) // currently only works with classes
{
    auto initializer = MethodInitializer!T(new T());
    Func(initializer, initializer.obj, args);
    initializer.obj.finalize();
    return initializer.obj;
}

/**
Takes a lambda and returns a memoized function to build a rule object.
The lambda takes a builder and a rule object.
This differs from makeRuleWithArgs in that the function literal does not need explicit
parameter types.
*/
alias makeRule(alias Func) = memoize!(methodInit!(BuildRule, Func));

/**
Takes a lambda and returns a memoized function to build a rule object.
The lambda takes a builder, rule object and any extra arguments needed
to create the rule.
This differs from makeRule in that the function literal must contain explicit parameter types.
*/
alias makeRuleWithArgs(alias Func) = memoize!(methodInit!(BuildRule, Func, Parameters!Func[2..$]));

/**
Logging primitive

Params:
    spec = a format specifier
    args = the data to format to the log
*/
void log(T...)(string spec, T args)
{
    if (verbose)
        writefln(spec, args);
}

/**
Aborts the current build

Params:
    msg = error message to display
    details = extra error details to display (e.g. a error diff)

Throws: BuildException with the supplied message

Returns: nothing but enables `throw abortBuild` to convey the resulting behavior
*/
BuildException abortBuild(string msg = "Build failed!", string details = "")
{
    throw new BuildException(msg, details);
}

class BuildException : Exception
{
    string details = "";
    this(string msg, string details) { super(msg); this.details = details; }
}

/**
The directory where all run commands are executed from.  All relative file paths
in a `run` command must be relative to `runDir`.
*/
alias runDir = compilerDir;

/**
Run a command which may not succeed and optionally log the invocation.

Params:
    args = the command and command arguments to execute
    workDir = the commands working directory

Returns: a tuple (status, output)
*/
auto tryRun(const(string)[] args, string workDir = runDir)
{
    args = args.filter!(a => !a.empty).array;
    log("Run: %-(%s %)", args);

    try
    {
        return execute(args, null, Config.none, size_t.max, workDir);
    }
    catch (Exception e) // e.g. exececutable does not exist
    {
        return typeof(return)(-1, e.msg);
    }
}

/**
Wrapper around execute that logs the execution
and throws an exception for a non-zero exit code.

Params:
    args = the command and command arguments to execute
    workDir = the commands working directory

Returns: any output of the executed command
*/
string run(const string[] args, const string workDir = runDir)
{
    auto res = tryRun(args, workDir);
    if (res.status)
    {
        string details;

        // Rerun with GDB if e.g. a segfault occurred
        // Limit this to executables within `generated` to not debug e.g. Git
        version (linux)
        if (res.status < 0 && args[0].startsWith(env["G"]))
        {
            // This should use --args to pass the command line parameters, but that
            // flag is only available since 7.1.1 and hence missing on some CI machines
            auto gdb = [
                "gdb", "-batch", // "-q","-n",
                args[0],
                "-ex", "set backtrace limit 100",
                "-ex", format("run %-(%s %)", args[1..$]),
                "-ex", "bt",
                "-ex", "info args",
                "-ex", "info locals",
            ];

            // Include gdb output as details (if GDB is available)
            const gdbRes = tryRun(gdb, workDir);
            if (gdbRes.status != -1)
                details = gdbRes.output;
            else
                log("Rerunning executable with GDB failed: %s", gdbRes.output);
        }

        abortBuild(res.output ? res.output : format("Last command failed with exit code %s", res.status), details);
    }
    return res.output;
}

/**
Install `files` to `targetDir`.  `files` in different directories but will be installed
to the same relative location as they exist in the `sourceBase` directory.

Params:
    targetDir = the directory to install files into
    sourceBase = the parent directory of all files.  all files will be installed to the same relative directory
                 in targetDir as they are from sourceBase
    files = the files to install.  must be in sourceBase
*/
void installRelativeFiles(T)(string targetDir, string sourceBase, T files, uint attributes = octal!644)
{
    struct FileToCopy
    {
        string name;
        string relativeName;
        string toString() const { return relativeName; }
    }
    FileToCopy[][string] filesByDir;
    foreach (file; files)
    {
        assert(file.startsWith(sourceBase), "expected all files to be installed to be in '%s', but got '%s'".format(sourceBase, file));
        const relativeFile = file.relativePath(sourceBase);
        filesByDir[relativeFile.dirName] ~= FileToCopy(file, relativeFile);
    }
    foreach (dirFilePair; filesByDir.byKeyValue)
    {
        const nextTargetDir = targetDir.buildPath(dirFilePair.key);
        writefln("copy these files %s from '%s' to '%s'", dirFilePair.value, sourceBase, nextTargetDir);
        mkdirRecurse(nextTargetDir);
        foreach (fileToCopy; dirFilePair.value)
        {
            std.file.copy(fileToCopy.name, targetDir.buildPath(fileToCopy.relativeName));
            std.file.setAttributes(targetDir.buildPath(fileToCopy.relativeName), attributes);
        }
    }
}

/** Wrapper around std.file.copy that also updates the target timestamp. */
void copyAndTouch(const string from, const string to)
{
    std.file.copy(from, to);
    const now = Clock.currTime;
    to.setTimes(now, now);
}

// Wrap standard library functions
alias writeText = std.file.write;
