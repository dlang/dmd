#!/usr/bin/env rdmd
/**
DMD builder

Usage:
  ./build.d dmd

TODO:
- add all posix.mak Makefile targets
- support 32-bit builds
- allow appending DFLAGS via the environment
- test the script with LDC or GDC as host compiler
*/

version(CoreDdoc) {} else:

import std.algorithm, std.conv, std.datetime, std.exception, std.file, std.format, std.functional,
       std.getopt, std.parallelism, std.path, std.process, std.range, std.stdio, std.string;
import core.stdc.stdlib : exit;

const thisBuildScript = __FILE_FULL_PATH__;
const srcDir = thisBuildScript.dirName.buildNormalizedPath;
const dmdRepo = srcDir.dirName;
shared bool verbose; // output verbose logging
shared bool force; // always build everything (ignores timestamp checking)
shared bool dryRun; /// dont execute targets, just print command to be executed

__gshared string[string] env;
__gshared string[][string] flags;
__gshared typeof(sourceFiles()) sources;

/// Array of dependencies through which all other dependencies can be reached
immutable rootDeps = [
    &dmdDefault,
    &runDmdUnittest,
    &clean,
    &checkwhitespace,
    &runCxxUnittest
];

void main(string[] args)
{
    int jobs = totalCPUs;
    bool calledFromMake = false;
    auto res = getopt(args,
        "j|jobs", "Specifies the number of jobs (commands) to run simultaneously (default: %d)".format(totalCPUs), &jobs,
        "v", "Verbose command output", (cast(bool*) &verbose),
        "f", "Force run (ignore timestamps and always run all tests)", (cast(bool*) &force),
        "d|dry-run", "Print commands instead of executing them", (cast(bool*) &dryRun),
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

Important variables:
--------------------

HOST_DMD:             Host D compiler to use for bootstrapping
AUTO_BOOTSTRAP:       Enable auto-boostrapping by downloading a stable DMD binary
MODEL:                Target architecture to build for (32,64) - defaults to the host architecture

Build modes:
------------
BUILD: release (default) | debug (enabled a build with debug instructions)

Opt-in build features:

ENABLE_RELEASE:       Optimized release built
ENABLE_DEBUG:         Add debug instructions and symbols (set if ENABLE_RELEASE isn't set)
ENABLE_LTO:           Enable link-time optimizations
ENABLE_UNITTEST:      Build dmd with unittests (sets ENABLE_COVERAGE=1)
ENABLE_PROFILE:       Build dmd with a profiling recorder (D)
ENABLE_COVERAGE       Build dmd with coverage counting
ENABLE_SANITIZERS     Build dmd with sanitizer (e.g. ENABLE_SANITIZERS=address,undefined)

Targets
-------
` ~ targetsHelp ~ `
The generated files will be in generated/$(OS)/$(BUILD)/$(MODEL)

Command-line parameters
-----------------------
`, res.options);
        return;
    }

    // parse arguments
    args.popFront;
    args2Environment(args);
    parseEnvironment;
    processEnvironment;
    version(Posix) processEnvironmentCxx;
    sources = sourceFiles;

    if (res.helpWanted)
        return showHelp;

    // default target
    if (!args.length)
        args = ["dmd"];

    auto targets = args
        .predefinedTargets // preprocess
        .array;

    if (targets.length == 0)
        return showHelp;

    if (verbose)
    {
        log("================================================================================");
        foreach (key, value; env)
            log("%s=%s", key, value);
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
        foreach (target; targets.parallel(1))
            target();
    }

    writeln("Success");
}

/// Generate list of targets for use in the help message
string targetsHelp()
{
    string result = "";
    foreach (dep; DependencyRange(rootDeps.map!(a => a()).array))
    {
        if (dep.name)
        {
            enum defaultPrefix = "\n                      ";
            result ~= dep.name;
            string prefix = defaultPrefix[1 + dep.name.length .. $];
            void add(string msg)
            {
                result ~= format("%s%s", prefix, msg);
                prefix = defaultPrefix;
            }
            if (dep.description)
                add(dep.description);
            else if (dep.targets)
            {
                foreach (target; dep.targets)
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
D build dependencies
====================

The strategy of this script is to emulate what the Makefile is doing.

Below all individual dependencies of DMD are defined.
They have a target path, sources paths and an optional name.
When a dependency is needed either its command or custom commandFunction is executed.
A dependency will be skipped if all targets are older than all sources.
This script is by default part of the sources and thus any change to the build script,
will trigger a full rebuild.

*/

/// Returns: the dependency that builds the lexer
alias lexer = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "lexer";
        target = env["G"].buildPath("lexer").libName;
        sources = .sources.lexer;
        deps = [versionFile, sysconfDirFile];
        msg = "(DC) D_LEXER_OBJ %-(%s, %)".format(sources.map!(e => e.baseName).array);
        command = [
            env["HOST_DMD_RUN"],
            "-of" ~ target,
            "-lib",
            "-vtls",
            "-J"~env["G"], "-J../res",
        ].chain(flags["DFLAGS"], sources).array;
    }
    return new DependencyRef(dep);
});

/// Returns: the dependency that generates the dmd.conf file in the output folder
alias dmdConf = memoize!(function()
{
    // TODO: add support for Windows
    string exportDynamic;
    version(OSX) {} else
        exportDynamic = " -L--export-dynamic";

    auto conf = `[Environment32]
DFLAGS=-I%@P%/../../../../../druntime/import -I%@P%/../../../../../phobos -L-L%@P%/../../../../../phobos/generated/{OS}/{BUILD}/32{exportDynamic}

[Environment64]
DFLAGS=-I%@P%/../../../../../druntime/import -I%@P%/../../../../../phobos -L-L%@P%/../../../../../phobos/generated/{OS}/{BUILD}/64{exportDynamic} -fPIC`
        .replace("{exportDynamic}", exportDynamic)
        .replace("{BUILD}", env["BUILD"])
        .replace("{OS}", env["OS"]);

    Dependency dep;
    with (dep)
    {
        name = "dmdconf";
        target = env["G"].buildPath("dmd.conf");
        msg = "(TX) DMD_CONF";
        commandFunction = ()
        {
            conf.toFile(target);
        };
    }
    return new DependencyRef(dep);
});

/// Returns: the dependencies that build the D backend
alias backendObj = memoize!(function ()
{
    Dependency dep;
    with (dep)
    {
        name = "backendObj";
        target = env["G"].buildPath("backend").objName;
        sources = .sources.backend;
        msg = "(DC) D_BACK_OBJS %-(%s, %)".format(sources.map!(e => e.baseName).array);
        command = [
            env["HOST_DMD_RUN"],
            "-c",
            "-of" ~ target,
            "-betterC",
        ].chain(flags["DFLAGS"], sources).array;
    }
    return new DependencyRef(dep);
});

/// Execute the sub-dependencies of the backend and pack everything into one object file
alias backend = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "backend";
        msg = "(LIB) %s".format("BACKEND".libName);
        sources = [ env["G"].buildPath("backend").objName ];
        target = env["G"].buildPath("backend").libName;
        deps = [backendObj];
        command = [env["HOST_DMD_RUN"], env["MODEL_FLAG"], "-lib", "-of" ~ target].chain(sources).array;
    }
    return new DependencyRef(dep);
});

/// Returns: the dependencies that generate required string files: VERSION and SYSCONFDIR.imp
alias versionFile = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        msg = "(TX) VERSION";
        target = env["G"].buildPath("VERSION");
        commandFunction = ()
        {
            string ver;
            if (dmdRepo.buildPath(".git").exists)
            {
                try
                {
                    auto gitResult = ["git", "describe", "--dirty"].run;
                    if (gitResult.status == 0)
                        ver = gitResult.output.strip;
                }
                catch (ProcessException)
                {
                    // git not installed
                }
            }
            // version fallback
            if (ver.length == 0)
                ver = dmdRepo.buildPath("VERSION").readText;
            updateIfChanged(target, ver);
        };
    }
    return new DependencyRef(dep);
});

alias sysconfDirFile = memoize!(function()
{
    Dependency dep;
    with(dep)
    {
        msg = "(TX) SYSCONFDIR";
        sources = [thisBuildScript];
        target = env["G"].buildPath("SYSCONFDIR.imp");
        commandFunction = ()
        {
            updateIfChanged(target, env["SYSCONFDIR"]);
        };
    }
    return new DependencyRef(dep);
});

/**
Dependency for the DMD executable.

Params:
  extra_flags = Flags to apply to the main build but not the dependencies
*/
alias dmdExe = memoize!(function(string targetSuffix, string[] extraFlags...)
{
    const dmdSources = sources.dmd.chain(sources.root).array;

    // Main DMD build dependency
    Dependency dep;
    with (dep)
    {
        // newdelete.o + lexer.a + backend.a
        sources = dmdSources.chain(lexer.targets, backend.targets).array;
        target = env["DMD_PATH"] ~ targetSuffix;
        msg = "(DC) DMD%s %-(%s, %)".format(targetSuffix, dmdSources.map!(e => e.baseName).array);
        deps = [versionFile, sysconfDirFile, lexer, backend];
        string[] platformArgs;
        version (Windows)
            platformArgs = ["-L/STACK:8388608"];
        command = [
            env["HOST_DMD_RUN"],
            "-of" ~ target,
            "-vtls",
            "-J"~env["G"],
            "-J../res",
        ].chain(extraFlags, platformArgs, flags["DFLAGS"], sources).array;
    }
    return new DependencyRef(dep);
});

alias dmdDefault = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "dmd";
        description = "Build dmd";
        deps = [dmdConf, dmdExe(null, null)];
    }
    return new DependencyRef(dep);
});

/// Dependency to run the DMD unittest executable.
alias runDmdUnittest = memoize!(function()
{
    auto dmdUnittestExe = dmdExe("-unittest", ["-version=NoMain", "-unittest", "-main"]);

    Dependency dep;
    with (dep)
    {
        name = "unittest";
        description = "Run the dmd unittests";
        msg = "(RUN) DMD-UNITTEST";
        deps = [dmdUnittestExe];
        commandFunction = ()
        {
            spawnProcess(dmdUnittestExe.targets[0]);
        };
    }
    return new DependencyRef(dep);
});

/// Compiles the C++ frontend test files
version(Posix) alias cxxFrontend = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "cxx-frontend";
        description = "Build the C++ frontend";
        msg = "(CXX) CXX-FRONTEND";
        sources = "tests/cxxfrontend.c" ~ .sources.sources ~ .sources.root; // Omitted $(SRC_MAKE);
        target = env["G"] ~ "/cxxfrontend".objName;
        command = [
            env["CXX"],
            "-c",
            sources[0],
            "-o" ~ target,

            // $(DMD_FLAGS)
            "-I" ~ env["D"],
            "-Wuninitialized",

            // $("MMD") == -MMD -MF $(basename $@).deps
            "-MMD",
            "-MF cxxfrontend.deps"
        ]
        ~ flags["CXXFLAGS"];
    }

    return new DependencyRef(dep);
});

/// Compiles the complete C++ unittests executable
version(Posix) alias cxxUnittestExe = memoize!(function()
{

    const stringImportFiles = [
        env["G"] ~ "/VERSION",
        env["G"] ~ "/SYSCONFDIR.imp",
        env["RES"] ~ "/default_ddoc_theme.ddoc"
    ];

    // $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH),$^)
    auto inputFiles = sources.dmd ~ sources.root;

    Dependency dep;
    with (dep)
    {
        name = "cxx-unittest";
        description = "Build the C++ unittests";
        msg = "(DMD) CXX-UNITTEST";
        deps = [cxxFrontend, lexer, backend];
        sources = inputFiles ~ stringImportFiles;
        target = env["G"] ~ "/cxx-unittest";
        command = [
            env["HOST_DMD_RUN"],
            "-of=" ~ target,
            env["MODEL_FLAG"],
            "-vtls",
            "-J" ~ env["G"],
            "-J" ~ env["RES"],
            "-L-lstdc++",
            "-version=NoMain",
        ].chain(
            flags["DFLAGS"],
            inputFiles,
            deps.map!(d => d.target)
        ).array;
    }

    return new DependencyRef(dep);
});

/// Runs the C++ unittests executable
version(Posix) alias runCxxUnittest = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "cxx-unittest";
        description = "Run the C++ unittests";
        msg = "(RUN) CXX-UNITTEST";
        deps = [cxxUnittestExe];
        command = [cxxUnittestExe.target];
    }
    return new DependencyRef(dep);
});

/// Dependency that removes all generated files
alias clean = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "clean";
        description = "Remove the generated directory";
        msg = "(RM) " ~ env["G"];
        commandFunction = ()
        {
            if (env["G"].exists)
                env["G"].rmdirRecurse;
        };
    }
    return new DependencyRef(dep);
});

alias toolsRepo = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        commandFunction = ()
        {
            if (!env["TOOLS_DIR"].exists)
            {
                writefln("cloning tools repo to '%s'...", env["TOOLS_DIR"]);
                run(["git", "clone", "--depth=1", env["GIT_HOME"] ~ "/tools", env["TOOLS_DIR"]]);
            }
        };
    }
    return new DependencyRef(dep);
});

alias checkwhitespace = memoize!(function()
{
    Dependency dep;
    with (dep)
    {
        name = "checkwhitespace";
        description = "Checks for trailing whitespace and tabs";
        deps = [toolsRepo];
        commandFunction = ()
        {
            const cmdPrefix = [env["HOST_DMD_RUN"], "-run", env["TOOLS_DIR"].buildPath("checkwhitespace.d")];
            const allSources = srcDir.dirEntries("*.{d,h,di}", SpanMode.depth).map!(e => e.name).array;
            writefln("Checking whitespace on %s files...", allSources.length);
            auto chunkLength = allSources.length;
            version (Win32)
                chunkLength = 80; // avoid command-line limit on win32
            foreach (nextSources; allSources.chunks(chunkLength).parallel(1))
            {
                const nextCommand = cmdPrefix ~ nextSources;
                writeln(nextCommand.join(" "));
                run(nextCommand);
            }
        };
    }
    return new DependencyRef(dep);
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
auto predefinedTargets(string[] targets)
{
    import std.functional : toDelegate;
    Appender!(void delegate()[]) newTargets;
LtargetsLoop:
    foreach (t; targets)
    {
        t = t.buildNormalizedPath; // remove trailing slashes

        // check if `t` matches any dependency names first
        foreach (dep; DependencyRange(rootDeps.map!(a => a()).array))
        {
            if (t == dep.name)
            {
                newTargets.put(&dep.run);
                continue LtargetsLoop;
            }
        }

        switch (t)
        {
            case "all":
                t = "dmd";
                goto default;

            case "auto-tester-build":
                "TODO: auto-tester-all".writeln; // TODO
                break;

            case "toolchain-info":
                "TODO: info".writeln; // TODO
                break;

            case "check-examples":
                "TODO: cxx-unittest".writeln; // TODO
                break;

            case "build-examples":
                "TODO: build-examples".writeln; // TODO
                break;

            case "html":
                "TODO: html".writeln; // TODO
                break;

            case "install":
                "TODO: install".writeln; // TODO
                break;

            case "man":
                "TODO: man".writeln; // TODO
                break;

            default:
                // check this last, target paths should be checked after predefined names
                const tAbsolute = t.absolutePath.buildNormalizedPath;
                foreach (dep; DependencyRange(rootDeps.map!(a => a()).array))
                {
                    foreach (depTarget; dep.targets)
                    {
                        if (depTarget.endsWith(t, tAbsolute))
                        {
                            newTargets.put(&dep.run);
                            continue LtargetsLoop;
                        }
                    }
                }
                writefln("ERROR: Target `%s` is unknown.", t);
                writeln;
                exit(1);
                break;
        }
    }
    return newTargets.data;
}

/// An input range for a recursive set of dependencies
struct DependencyRange
{
    private DependencyRef[] next;
    private bool[DependencyRef] added;
    this(DependencyRef[] deps) { addDeps(deps); }
    bool empty() const { return next.length == 0; }
    auto front() inout { return next[0]; }
    void popFront()
    {
        auto save = next[0];
        next = next[1 .. $];
        addDeps(save.deps);
    }
    void addDeps(DependencyRef[] deps)
    {
        foreach (dep; deps)
        {
            if (!added.get(dep, false))
            {
                next ~= dep;
                added[dep] = true;
            }
        }
    }
}

/// Sets the environment variables
void parseEnvironment()
{
    // This block is temporary until we can remove the windows make files
    {
        const ddebug = env.get("DDEBUG", null);
        if (ddebug.length)
        {
            writefln("WARNING: the DDEBUG variable is deprecated");
            if (ddebug == "-debug -g -unittest -cov")
            {
                environment["ENABLE_DEBUG"] = "1";
                environment["ENABLE_UNITTEST"] = "1";
                environment["ENABLE_COVERAGE"] = "1";
            }
            else if (ddebug == "-debug -g -unittest")
            {
                environment["ENABLE_DEBUG"] = "1";
                environment["ENABLE_UNITTEST"] = "1";
            }
            else
            {
                writefln("Error: DDEBUG is not an expected value '%s'", ddebug);
                exit(1);
            }
        }
    }

    env.getDefault("TARGET_CPU", "X86");
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
        const os = env.getDefault("OS", detectOS);
    auto build = env.getDefault("BUILD", "release");
    enforce(build.among("release", "debug"), "BUILD must be 'debug' or 'release'");

    // detect Model
    auto model = env.getDefault("MODEL", detectModel);
    env["MODEL_FLAG"] = "-m" ~ env["MODEL"];

    // detect PIC
    version(Posix)
    {
        // default to PIC on x86_64, use PIC=1/0 to en-/disable PIC.
        // Note that shared libraries and C files are always compiled with PIC.
        bool pic;
        version(X86_64)
            pic = true;
        else version(X86)
            pic = false;
        if (environment.get("PIC", "0") == "1")
            pic = true;

        env["PIC_FLAG"]  = pic ? "-fPIC" : "";
    }
    else
    {
        env["PIC_FLAG"] = "";
    }

    env.getDefault("GIT", "git");
    env.getDefault("GIT_HOME", "https://github.com/dlang");
    env.getDefault("SYSCONFDIR", "/etc");
    env.getDefault("TMP", tempDir);

    auto d = env["D"] = srcDir.buildPath("dmd");
    env["C"] = d.buildPath("backend");
    env["ROOT"] = d.buildPath("root");
    env["EX"] = srcDir.buildPath("examples");
    auto generated = env["GENERATED"] = dmdRepo.buildPath("generated");
    auto g = env["G"] = generated.buildPath(os, build, model);
    mkdirRecurse(g);
    env.getDefault("TOOLS_DIR", dmdRepo.dirName.buildPath("tools"));

    if (env.get("HOST_DMD", null).length == 0)
    {
        const hostDmd = env.get("HOST_DC", null);
        env["HOST_DMD"] = hostDmd.length ? hostDmd : "dmd";
    }

    // Auto-bootstrapping of a specific host compiler
    if (env.getDefault("AUTO_BOOTSTRAP", null) == "1")
    {
        auto hostDMDVer = env.getDefault("HOST_DMD_VER", "2.088.0");
        writefln("Using Bootstrap compiler: %s", hostDMDVer);
        auto hostDMDRoot = env["G"].buildPath("host_dmd-"~hostDMDVer);
        auto hostDMDBase = hostDMDVer~"."~os;
        auto hostDMDURL = "http://downloads.dlang.org/releases/2.x/"~hostDMDVer~"/dmd."~hostDMDBase;
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
        stderr.writefln("No DMD compiler is installed. Try AUTO_BOOTSTRAP=1 or manually set the D host compiler with HOST_DMD");
        exit(1);
    }
}

/// Checks the environment variables and flags
void processEnvironment()
{
    import std.meta : AliasSeq;

    const os = env["OS"];

    const hostDMDVersion = [env["HOST_DMD_RUN"], "--version"].execute.output;

    alias DMD = AliasSeq!("DMD");
    alias LDC = AliasSeq!("LDC");
    alias GDC = AliasSeq!("GDC", "gdmd", "gdc");
    const kindIdx = hostDMDVersion.canFind(DMD, LDC, GDC);

    enforce(kindIdx, "Invalid Host DMD found: " ~ hostDMDVersion);

    if (kindIdx <= DMD.length)
        env["HOST_DMD_KIND"] = "dmd";
    else if (kindIdx <= LDC.length + DMD.length)
        env["HOST_DMD_KIND"] = "ldc";
    else
        env["HOST_DMD_KIND"] = "gdc";

    env["DMD_PATH"] = env["G"].buildPath("dmd").exeName;

    env.getDefault("ENABLE_WARNINGS", "0");
    string[] warnings;

      // TODO: allow adding new flags from the environment
    string[] dflags = ["-version=MARS", "-w", "-de", env["PIC_FLAG"], env["MODEL_FLAG"], "-J"~env["G"]];
    if (env["HOST_DMD_KIND"] != "gdc")
        dflags ~= ["-dip25"]; // gdmd doesn't support -dip25

    // TODO: add support for dObjc
    auto dObjc = false;
    version(OSX) version(X86_64)
        dObjc = true;

    if (env.getDefault("ENABLE_DEBUG", "0") != "0")
    {
        dflags ~= ["-g", "-debug"];
    }
    if (env.getDefault("ENABLE_RELEASE", "0") != "0")
    {
        dflags ~= ["-O", "-release", "-inline"];
    }
    else
    {
        // add debug symbols for all non-release builds
        if (!dflags.canFind("-g"))
            dflags ~= ["-g"];
    }
    if (env.getDefault("ENABLE_LTO", "0") != "0")
    {
        dflags ~= ["-flto=full"];
    }
    if (env.getDefault("ENABLE_UNITTEST", "0") != "0")
    {
        dflags ~= ["-unittest", "-cov"];
    }
    if (env.getDefault("ENABLE_PROFILE", "0") != "0")
    {
        dflags ~= ["-profile"];
    }
    if (env.getDefault("ENABLE_COVERAGE", "0") != "0")
    {
        dflags ~= ["-cov", "-L-lgcov"];
    }
    if (env.getDefault("ENABLE_SANITIZERS", "0") != "0")
    {
        dflags ~= ["-fsanitize="~env["ENABLE_SANITIZERS"]];
    }
    flags["DFLAGS"] ~= dflags;
}

/// Setup environment for a C++ compiler
version(Posix) void processEnvironmentCxx()
{
    import std.meta: AliasSeq;

    env.getDefault("RES", srcDir ~ "/../res");

    const cxxVersion = [env.getDefault("CXX", "c++"), "--version"].execute.output;

    alias GCC = AliasSeq!("g++", "gcc", "Free Software");
    alias CLANG = AliasSeq!("clang");
    const kindIdx = cxxVersion.canFind(GCC, CLANG);

    enforce(kindIdx, "Invalid CXX found: " ~ cxxVersion);
    const kind = kindIdx <= GCC.length ? "g++" : "clang++";

    env["CXX_KIND"] = kind;

    string[] warnings;
    if(env.getDefault("ENABLE_WARNINGS", "0") != "0")
    {
        warnings = [
            "-Wall",
            "-Wextra",
            "-Werror",
            "-Wno-attributes",
            "-Wno-char-subscripts",
            "-Wno-deprecated",
            "-Wno-empty-body",
            "-Wno-format",
            "-Wno-missing-braces",
            "-Wno-missing-field-initializers",
            "-Wno-overloaded-virtual",
            "-Wno-parentheses",
            "-Wno-reorder",
            "-Wno-return-type",
            "-Wno-sign-compare",
            "-Wno-strict-aliasing",
            "-Wno-switch",
            "-Wno-type-limits",
            "-Wno-unknown-pragmas",
            "-Wno-unused-function",
            "-Wno-unused-label",
            "-Wno-unused-parameter",
            "-Wno-unused-value",
            "-Wno-unused-variable"
        ];

        if(kind == "g++") {
            warnings ~= [
                "-Wno-logical-op",
                "-Wno-narrowing",
                "-Wno-unused-but-set-variable",
                "-Wno-uninitialized",
                "-Wno-class-memaccess",
                "-Wno-implicit-fallthrough"
            ];
        }
    }
    else
    {
        warnings = [
            "-Wno-deprecated",
            "-Wstrict-aliasing",
            "-Werror"
        ];

        if(kind == "clang++")
            warnings ~= "-Wno-logical-op-parentheses";
    }

    string hostDmdVernum;
    if(env["HOST_DMD_KIND"] == "dmd") // Why limit this to dmd?
    {
        enum redirect = Redirect.stdin | Redirect.stdout | Redirect.stderrToStdout;
        auto pipes = pipeProcess([env["HOST_DMD_RUN"], "-o-", "-c", "-"], redirect);

        pipes.stdin.writeln("pragma(msg, cast(int)__VERSION__);");
        pipes.stdin.flush();
        pipes.stdin.close();
        //  wait(pipes.pid);

        hostDmdVernum = pipes.stdout.byLine.front.idup;
    }
    else {
        hostDmdVernum = "2";
    }

    auto cxxFlags = warnings ~ [
        "-fno-exceptions",
        "-fno-rtti",
        "-D__pascal=",
        "-DMARS=1",
        "-DTARGET_" ~ env["OS"].toUpper ~ "=1",
        "-DDM_TARGET_CPU_" ~ env["TARGET_CPU"] ~ "=1",
        env["MODEL_FLAG"],
        env["PIC_FLAG"],
        "-DDMD_VERSION=" ~ hostDmdVernum,

        // No explicit if since kind will always be either g++ or clang++
        kind == "g++" ? "-std=gnu++98" : "-xc++"
    ];

    const pgoDir = env.getDefault("PGO_DIR", srcDir ~ "/pgo");

    const extraFlags = [
        "ENABLE_DEBUG": ["-g", "-g3", "-DDEBUG=1", "-DUNITTEST"],
        "ENABLE_RELEASE": ["-O2"],
        "ENABLE_PROFILING": ["-pg", "-fprofile-arcs", "-ftest-coverage"],
        "ENABLE_PGO_GENERATE": ["-fprofile-generate=" ~ pgoDir],
        "ENABLE_PGO_USE": ["-fprofile-use=" ~ pgoDir, "-freorder-blocks-and-partition"],
        "ENABLE_LTO": ["-flto"],
        "ENABLE_UNITTEST": ["-unittest", "-cov"],
        "ENABLE_COVERAGE": ["--coverage"],
        "ENABLE_SANITIZERS": ["-fsanitize=" ~ env.getDefault("ENABLE_SANITIZERS", "")]
    ];

    foreach(const var, const flags; extraFlags) {
        if(env.getDefault(var, "0") != "0") {
            cxxFlags ~= flags;
        }
    }

    flags["CXXFLAGS"] = cxxFlags;
}

////////////////////////////////////////////////////////////////////////////////
// D source files
////////////////////////////////////////////////////////////////////////////////

/// Returns: all source files for the compiler
auto sourceFiles()
{
    struct Sources
    {
        string[] frontend, lexer, root, glue, dmd, backend, sources;
        string[] frontendHeaders, backendHeaders, backendObjects;
    }
    string targetCH;
    string[] targetObjs;
    if (env["TARGET_CPU"] == "X86")
    {
        targetCH = "code_x86.h";
    }
    else if (env["TARGET_CPU"] == "stub")
    {
        targetCH = "code_stub.h";
        targetObjs = ["platform_stub"];
    }
    else
    {
        assert(0, "Unknown TARGET_CPU: " ~ env["TARGET_CPU"]);
    }
    static string[] fileArray(string dir, string files)
    {
        return files.split.map!(e => dir.buildPath(e)).array;
    }
    Sources sources = {
        glue: fileArray(env["D"], "
            irstate.d toctype.d glue.d gluelayer.d todt.d tocsym.d toir.d dmsc.d
            tocvdebug.d s2ir.d toobj.d e2ir.d eh.d iasm.d iasmdmd.d iasmgcc.d objc_glue.d
        "),
        frontend: fileArray(env["D"], "
            access.d aggregate.d aliasthis.d apply.d argtypes.d argtypes_sysv_x64.d arrayop.d
            arraytypes.d ast_node.d astbase.d astcodegen.d attrib.d blockexit.d builtin.d canthrow.d
            cli.d clone.d compiler.d complex.d cond.d constfold.d cppmangle.d cppmanglewin.d ctfeexpr.d
            ctorflow.d dcast.d dclass.d declaration.d delegatize.d denum.d dimport.d dinifile.d
            dinterpret.d dmacro.d dmangle.d dmodule.d doc.d dscope.d dstruct.d dsymbol.d dsymbolsem.d
            dtemplate.d dversion.d env.d escape.d expression.d expressionsem.d func.d hdrgen.d impcnvtab.d
            imphint.d init.d initsem.d inline.d inlinecost.d intrange.d json.d lambdacomp.d lib.d libelf.d
            libmach.d libmscoff.d libomf.d link.d mars.d mtype.d nogc.d nspace.d objc.d opover.d optimize.d
            parse.d parsetimevisitor.d permissivevisitor.d printast.d safe.d sapply.d scanelf.d scanmach.d
            scanmscoff.d scanomf.d semantic2.d semantic3.d sideeffect.d statement.d statement_rewrite_walker.d
            statementsem.d staticassert.d staticcond.d strictvisitor.d target.d templateparamsem.d traits.d
            transitivevisitor.d typesem.d typinf.d utils.d visitor.d
        "),
        frontendHeaders: fileArray(env["D"], "
            aggregate.h aliasthis.h arraytypes.h attrib.h compiler.h complex_t.h cond.h
            ctfe.h declaration.h dsymbol.h doc.h enum.h errors.h expression.h globals.h hdrgen.h
            identifier.h id.h import.h init.h json.h module.h mtype.h nspace.h objc.h scope.h
            statement.h staticassert.h target.h template.h tokens.h version.h visitor.h
            " ~ (env["OS"] == "windows" ? "" : "libomf.d scanomf.d libmscoff.d scanmscoff.d")
        ),
        lexer: fileArray(env["D"], "
            console.d entity.d errors.d filecache.d globals.d id.d identifier.d lexer.d tokens.d utf.d
        ") ~ fileArray(env["ROOT"], "
            array.d bitarray.d ctfloat.d file.d filename.d hash.d outbuffer.d port.d region.d rmem.d
            rootobject.d stringtable.d
        "),
        root: fileArray(env["ROOT"], "
            aav.d longdouble.d man.d response.d speller.d string.d strtold.d
        "),
        backend: fileArray(env["C"], "
            backend.d bcomplex.d evalu8.d divcoeff.d dvec.d go.d gsroa.d glocal.d gdag.d gother.d gflow.d
            out.d
            gloop.d compress.d cgelem.d cgcs.d ee.d cod4.d cod5.d nteh.d blockopt.d mem.d cg.d cgreg.d
            dtype.d debugprint.d fp.d symbol.d elem.d dcode.d cgsched.d cg87.d cgxmm.d cgcod.d cod1.d cod2.d
            cod3.d cv8.d dcgcv.d pdata.d util2.d var.d md5.d backconfig.d ph2.d drtlsym.d dwarfeh.d ptrntab.d
            dvarstats.d dwarfdbginf.d cgen.d os.d goh.d barray.d cgcse.d elpicpie.d
            machobj.d elfobj.d
            " ~ ((env["OS"] == "windows") ? "cgobj.d filespec.d mscoffobj.d newman.d" : "aarray.d")
        ),
        backendHeaders: fileArray(env["C"], "
            cc.d cdef.d cgcv.d code.d cv4.d dt.d el.d global.d
            obj.d oper.d outbuf.d rtlsym.d code_x86.d iasm.d codebuilder.d
            ty.d type.d exh.d mach.d mscoff.d dwarf.d dwarf2.d xmm.d
            dlist.d melf.d varstats.di
        "),
    };
    sources.dmd = sources.frontend ~ sources.glue ~ sources.backendHeaders;
    sources.sources = sources.frontendHeaders ~ sources.dmd;

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
    import std.net.curl : download, HTTPStatusException;

    foreach(i; 0..tries)
    {
        try
        {
            log("Downloading %s ...", from);
            download(from, to);
            return true;
        }
        catch(HTTPStatusException e)
        {
            if (e.status == 404) throw e;
            else
            {
                log("Failed to download %s (Attempt %s of %s)", from, i + 1, tries);
                continue;
            }
        }
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
auto detectModel()
{
    string uname;
    if (detectOS == "solaris")
        uname = ["isainfo", "-n"].execute.output;
    else if (detectOS == "windows")
        uname = ["wmic", "OS", "get", "OSArchitecture"].execute.output;
    else
        uname = ["uname", "-m"].execute.output;

    if (uname.canFind("x86_64", "amd64", "64-bit", "64-Bit", "64 bit"))
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
auto getHostDMDPath(string hostDmd)
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
auto exeName(T)(T name)
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
auto objName(T)(T name)
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
auto libName(T)(T name)
{
    version(Windows)
        return name ~ ".lib";
    return name ~ ".a";
}

/**
Add additional make-like assignments to the environment
e.g. ./build.d ARGS=foo -> sets the "ARGS" internal environment variable to "foo"

Params:
    args = the command-line arguments from which the assignments will be parsed
*/
void args2Environment(ref string[] args)
{
    bool tryToAdd(string arg)
    {
        if (!arg.canFind("="))
            return false;

        auto sp = arg.splitter("=");
        auto key = sp.front;
        auto value = sp.dropOne.front;
        environment[key] = value;
        env[key] = value;
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
auto getDefault(ref string[string] env, string key, string default_)
{
    if (key in environment)
        env[key] = environment[key];
    else
        env[key] = default_;

    return env[key];
}

////////////////////////////////////////////////////////////////////////////////
// Mini build system
////////////////////////////////////////////////////////////////////////////////

/**
Determines if a target is up to date with respect to its source files

Params:
    target = the target to check
    source = the source file to check against
Returns: `true` if the target is up to date
*/
auto isUpToDate(string target, string source)
{
    return isUpToDate(target, [source]);
}

/**
Determines if a target is up to date with respect to its source files

Params:
    target = the target to check
    source = the source files to check against
Returns: `true` if the target is up to date
*/
auto isUpToDate(string target, string[][] sources...)
{
    return isUpToDate([target], sources);
}

/**
Checks whether any of the targets are older than the sources

Params:
    targets = the targets to check
    sources = the source files to check against
Returns:
    `true` if the target is up to date
*/
auto isUpToDate(string[] targets, string[][] sources...)
{
    if (force)
        return false;

    foreach (target; targets)
    {
        auto sourceTime = target.timeLastModified.ifThrown(SysTime.init);
        // if a target has no sources, it only needs to be built once
        if (sources.empty || sources.length == 1 && sources.front.empty)
            return sourceTime > SysTime.init;
        foreach (arg; sources)
            foreach (a; arg)
                if (sourceTime < a.timeLastModified.ifThrown(SysTime.init + 1.seconds))
                    return false;
    }

    return true;
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
    import std.file : exists, readText, write;

    const existingContent = path.exists ? path.readText : "";

    if (content != existingContent)
        write(path, content);
}

/**
A dependency has one or more sources and yields one or more targets.
It knows how to build these target by invoking either the external command or
the commandFunction.

If a run fails, the entire build stops.
*/
struct Dependency
{
    string target; // path to the resulting target file (if target is used, it will set targets)
    string[] targets; // list of all target files
    string[] sources; // list of all source files
    string[] rebuildSources; // Optional list of files that trigger a rebuild of this dependency
    DependencyRef[] deps; // dependencies to build before this one
    string[] command; // the dependency command
    void delegate() commandFunction; // a custom dependency command which gets called instead of command
    string msg; // msg of the dependency that is e.g. written to the CLI when it's executed
    string name; /// optional string that can be used to identify this dependency
    string description; /// optional string to describe this dependency rather than printing the target files
    string[] trackSources;
}

class DependencyRef
{
    Dependency dep;
    alias dep this;
    private bool executed;

    this(ref Dependency dep)
    {
        this.dep = dep;
        if (dep.target)
        {
            assert(!dep.targets, "target and targets cannot both be set");
            this.dep.targets = [dep.target];
        }
    }

    /// Executes the dependency
    void run()
    {
        synchronized (this)
            runSynchronized();
    }

    private void runSynchronized()
    {
        if (executed)
            return;
        scope (exit) executed = true;

        bool depUpdated = false;
        foreach (dep; deps.parallel(1))
        {
            dep.run();
        }

        if (targets && targets.isUpToDate(dep.sources, [thisBuildScript], rebuildSources))
        {
            if (dep.sources !is null)
                log("Skipping build of %-(%s%) as it's newer than %-(%s%)", targets, dep.sources);
            return;
        }

        // Display the execution of the dependency
        if (msg)
            msg.writeln;

        if(dryRun)
        {
            if(commandFunction)
            {
                write("\n => Executing commandFunction()");

                if(name)
                    writef!" of %s"(name);

                if(targets.length)
                    writef!" to generate:\n%(    - %s\n%)"(targets);

                writeln('\n');
            }
            if(command)
                writefln!"\n => %(%s %)\n"(command);
        }
        else
        {
            if (commandFunction !is null)

                return commandFunction();

            if (command)
            {
                command.runCanThrow;
            }
        }
    }
}

/**
Logging primitive

Params:
    args = the data to write to the log
*/
auto log(T...)(T args)
{
    if (verbose)
        writefln(args);
}

/**
Run a command and optionally log the invocation

Params:
    args = the command and command arguments to execute
*/
auto run(T)(T args)
{
    args = args.filter!(a => !a.empty).array;
    log("Run: %s", args.join(" "));
    return execute(args, null, Config.none, size_t.max, srcDir);
}

/**
Wrapper around execute that logs the execution
and throws an exception for a non-zero exit code.

Params:
    args = the command and command arguments to execute
*/
auto runCanThrow(T)(T args)
{
    auto res = run(args);
    if (res.status)
    {
        writeln(res.output ? res.output : format("last command failed with exit code %s", res.status));
        exit(1);
    }
    return res.output;
}

version (CRuntime_DigitalMars)
{
    // workaround issue https://issues.dlang.org/show_bug.cgi?id=13727
    auto parallel(R)(R range, size_t workUnitSize) { return range; }
}
