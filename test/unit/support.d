module support;

import dmd.errors : DiagnosticReporter;

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

/**
 * Strips indentation and extra newlines in delimited strings.
 *
 * This is indented to be used on delimited string literals. It will strip the
 * indentation and remove the first and the last newlines.
 *
 * Params:
 *  str = the delimited string to strip
 *
 * Return: the stripped string
 */
string stripDelimited(string str)
{
    import std.string : chomp, outdent;
    import dmd.root.string : stripLeadingLineTerminator;

    return str
        .stripLeadingLineTerminator
        .outdent
        .chomp;
}

/**
 * Returns `true` if the given code compiles.
 *
 * This will run the frontend up to, including, the semantic analysis.
 *
 * Params:
 *  code = the code to compile
 *  filename = the filename to use when compiling the code
 *
 * Returns: `true` if the given code compiles
 */
bool compiles(string code, string filename = "test.d")
{
    import dmd.globals : global;
    import std.algorithm : each;

    import dmd.frontend : addImport, fullSemantic, parseModule;

    defaultImportPaths.each!addImport;

    auto t = parseModule(filename, code);

    if (t.diagnostics.hasErrors)
        return false;

    t.module_.fullSemantic();

    return global.errors == 0;
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
