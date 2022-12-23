// See ../README.md for information about DMD unit tests.

module support;

import core.stdc.stdarg : va_list;

import dmd.console : Color;
import dmd.frontend : DiagnosticReporter;
import dmd.location;

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
    enum phobosDir = dlangDir.buildPath("..", "phobos");

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

const struct CompilationResult
{
    import dmd.dmodule : Module;

    Diagnostic[] diagnostics;
    Module module_;

    alias diagnostics this;

    bool opCast(T : bool)()
    {
        return diagnostics.length == 0;
    }

    string toString()
    {
        import std.format : format;

        return format!"%(%s\n%)"(diagnostics);
    }
}

/**
 * Compiles the given code.
 *
 * This will run the frontend up to, including, the semantic analysis.
 *
 * Params:
 *  code = the code to compile
 *  filename = the filename to use when compiling the code
 *
 * Returns: the diagnostics reported during the compilation
 */
CompilationResult compiles(string code, string filename = "test.d")
{
    import dmd.globals : global;
    import std.algorithm : each;

    import dmd.frontend : addImport, fullSemantic, parseModule;
    import dmd.errors : diagnosticHandler;

    defaultImportPaths.each!addImport;
    auto diagnosticCollector = DiagnosticCollector();
    diagnosticHandler = &diagnosticCollector.handleDiagnostic;

    auto t = parseModule(filename, code);

    if (t.diagnostics.hasErrors)
        return CompilationResult(diagnosticCollector.diagnostics);

    t.module_.fullSemantic();

    return CompilationResult(diagnosticCollector.diagnostics, t.module_);
}

class NoopDiagnosticReporter : DiagnosticReporter
{
    import core.stdc.stdarg : va_list;
    import dmd.location;

    override int errorCount() { return 0; }
    override int warningCount() { return 0; }
    override int deprecationCount() { return 0; }
    override bool error(const ref Loc loc, const(char)* format, va_list, const(char)* p1, const(char)* p2) { return true; }
    override bool errorSupplemental(const ref Loc loc, const(char)* format, va_list, const(char)* p1, const(char)* p2) { return true; }
    override bool warning(const ref Loc loc, const(char)* format, va_list, const(char)* p1, const(char)* p2) { return true; }
    override bool warningSupplemental(const ref Loc loc, const(char)* format, va_list, const(char)* p1, const(char)* p2) { return true; }
    override bool deprecation(const ref Loc loc, const(char)* format, va_list, const(char)* p1, const(char)* p2) { return true; }
    override bool deprecationSupplemental(const ref Loc loc, const(char)* format, va_list, const(char)* p1, const(char)* p2) { return true; }
}

/// A single diagnostic.
const struct Diagnostic
{
    /// The location of the diagnostic.
    Loc location;

    /// The diagnostic message.
    string message;

    string toString() nothrow
    {
        import dmd.common.outbuffer : OutBuffer;

        auto buffer = OutBuffer();
        buffer.printf("%s: %.*s", location.toChars(true),
            cast(int) message.length, message.ptr);

        return buffer.extractSlice.idup;
    }
}

/// Collects all diagnostics that are reported.
struct DiagnosticCollector
{
    private Diagnostic[] diagnostics_;

    /// Returns: the collected diagnostics
    const(Diagnostic[]) diagnostics() const pure nothrow @nogc @safe
    {
        return diagnostics_;
    }

    /// Handles a diagnostic.
    bool handleDiagnostic (
        const ref Loc location,
        Color headerColor,
        const(char)* header,
        const(char)* messageFormat,
        va_list args,
        const(char)* prefix1,
        const(char)* prefix2
    ) nothrow
    {
        import std.array : replace;
        import std.string : strip;
        import dmd.common.outbuffer : OutBuffer;

        auto buffer = OutBuffer();

        void appendPrefix(const(char)* prefix)
        {
            if (!prefix)
                return;

            buffer.writestring(prefix);
            buffer.writestring(" ");
        }

        buffer.writestring(header);
        appendPrefix(prefix1);
        appendPrefix(prefix2);

        buffer.vprintf(messageFormat, args);

        const string message = buffer
            .extractSlice.idup
            .replace("`", "")
            .strip;

        diagnostics_ ~= Diagnostic(location, message);

        return true;
    }
}
