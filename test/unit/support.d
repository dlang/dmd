module support;

import dmd.lexer : DiagnosticReporter;

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

class NoopDiagnosticReporter : DiagnosticReporter
{
    import core.stdc.stdarg : va_list;
    import dmd.globals : Loc;

    override int errorCount() { return 0; }
    override int warningCount() { return 0; }
    override int deprecationCount() { return 0; }
    override void error(const ref Loc loc, const(char)* format, va_list) {}
    override void errorSupplemental(const ref Loc loc, const(char)* format, va_list) {}
    override void warning(const ref Loc loc, const(char)* format, va_list) {}
    override void warningSupplemental(const ref Loc loc, const(char)* format, va_list) {}
    override void deprecation(const ref Loc loc, const(char)* format, va_list) {}
    override void deprecationSupplemental(const ref Loc loc, const(char)* format, va_list) {}
}
