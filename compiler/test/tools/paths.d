module tools.paths;

import std.file : exists;
import std.path : buildNormalizedPath, buildPath, dirName, setExtension;
import std.process : environment;

version (Posix)
    enum exeExtension = "";
else version (Windows)
    enum exeExtension = ".exe";

version (Windows)
    enum hostOs = "windows";
else version (OSX)
    enum hostOs = "osx";
else version (linux)
    enum hostOs = "linux";
else version (FreeBSD)
    enum hostOs = "freebsd";
else version (OpenBSD)
    enum hostOs = "openbsd";
else version (NetBSD)
    enum hostOs = "netbsd";
else version (DragonFlyBSD)
    enum hostOs = "dragonflybsd";
else version (Solaris)
    enum hostOs = "solaris";
else version (SunOS)
    enum hostOs = "solaris";
else version (Hurd)
    enum hostOs = "hurd";
else
    static assert(0, "Unrecognized or unsupported OS.");

/// Target OS, e.g. `OS=wasm ./run.d runnable`
string os()
{
    static string cached;
    return cached ? cached : (cached = environment.get("OS", hostOs));
}

enum projectRootDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..", "..", "..");
enum generatedDir = projectRootDir.buildPath("generated");

enum dmdFilename = "dmd".setExtension(exeExtension);

enum compilerRootDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..", "..");
alias testPath = path => compilerRootDir.buildPath("test", path);

string build()
{
    return environment.get("BUILD", "release");
}

/// The DMD binary is always built for the host OS, even when cross compiling
string dmdOs()
{
    return os == "wasm" ? hostOs : os;
}

string buildOutputPath()
{
    return generatedDir.buildPath(dmdOs, build, dmdModel);
}

// auto-tester might run the test suite with a different $(MODEL) than DMD
// has been compiled with. Hence we manually check which binary exists.
string dmdModel()
{
    const prefix = generatedDir.buildPath(dmdOs, build);
    return environment.get("DMD_MODEL",
        prefix.buildPath("64", dmdFilename).exists ? "64" : "32");
}

string model()
{
    const defaultModel = os == "wasm" ? "32" : dmdModel;
    return environment.get("MODEL", defaultModel);
}

string dmdPath()
{
    return buildOutputPath.buildPath(dmdFilename);
}

string resultsDir()
{
    return environment.get("RESULTS_DIR", testPath("test_results"));
}

/// Returns: a path to 'target' relative to `base` using POSIX file separators
version (Windows)
string relativePosixPath(const string target, const string base) pure @safe
{
    import std.array : join;
    import std.path : relativePath, pathSplitter;

    return target.relativePath(base)
                .pathSplitter()
                .join('/');
}
