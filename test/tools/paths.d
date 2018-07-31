module tools.paths;

import std.file : exists;
import std.path : buildNormalizedPath, buildPath, dirName, setExtension;
import std.process : environment;

version (Posix)
    enum exeExtension = "";
else version (Windows)
    enum exeExtension = ".exe";

version (Windows)
    enum os = "windows";
else version (OSX)
    enum os = "osx";
else version (linux)
    enum os = "linux";
else version (FreeBSD)
    enum os = "freebsd";
else version (OpenBSD)
    enum os = "openbsd";
else version (NetBSD)
    enum os = "netbsd";
else version (DragonFlyBSD)
    enum os = "dragonflybsd";
else version (Solaris)
    enum os = "solaris";
else version (SunOS)
    enum os = "solaris";
else
    static assert(0, "Unrecognized or unsupported OS.");

enum projectRootDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..", "..");
enum generatedDir = projectRootDir.buildPath("generated");
enum resultsDir = testPath("test_results");

enum dmdFilename = "dmd".setExtension(exeExtension);

alias testPath = path => projectRootDir.buildPath("test", path);

string build()
{
    static string build;
    return build = build ? build : environment.get("BUILD", "release");
}

string buildOutputPath()
{
    static string buildOutputPath;
    return buildOutputPath ? buildOutputPath : (buildOutputPath = generatedDir.buildPath(os, build, dmdModel));
}

// auto-tester might run the test suite with a different $(MODEL) than DMD
// has been compiled with. Hence we manually check which binary exists.
string dmdModel()
{
    static string dmdModel;

    if (dmdModel)
        return dmdModel;

    const prefix = generatedDir.buildPath(os, build);
    return dmdModel = prefix.buildPath("64", dmdFilename).exists ? "64" : "32";
}

string model()
{
    static string model;
    return model ? model : (model = environment.get("MODEL", dmdModel));
}

string dmdPath()
{
    static string dmdPath;
    return  dmdPath ? dmdPath : (dmdPath = buildOutputPath.buildPath(dmdFilename));
}
