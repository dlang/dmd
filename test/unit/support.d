module support;

/// UDA used to indicate a function should be run before each test.
enum beforeEach;

/// UDA used to indicate a function should be run after each test.
enum afterEach;

/// Returns: the default import paths, i.e. for Phobos and druntime.
string[] defaultImportPaths()
{
    import std.path : buildNormalizedPath, buildPath, dirName;
    import std.process : environment;

    enum dlangDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..", "..", "..");
    enum druntimeDir = dlangDir.buildPath("druntime", "import");
    enum phobosDir = dlangDir.buildPath("phobos");

    return [
        environment.get("DRUNTIME_PATH", druntimeDir),
        environment.get("PHOBOS_PATH", phobosDir)
    ];
}
