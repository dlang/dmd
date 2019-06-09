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

/// The severity level of a diagnostic.
enum Severity
{
    /// An error occurred.
    error,

    /// A warning occurred.
    warning,

    /// A deprecation occurred.
    deprecation,
}

/// A single diagnostic message.
struct Diagnostic
{
    import dmd.globals : Loc;

    /// The severity of the diagnostic.
    const Severity severity;

    /// The location of where the diagnostic occurred.
    const Loc location;

    /// The message.
    const string message;

    /// The supplemental diagnostics belonging to this diagnostic.
    private const(Diagnostic)[] _supplementalDiagnostics;

    string toString() const pure
    {
        import std.format : format;
        import std.string : fromStringz;

        return format!"%s: %s:%s:%s: %s%s%(%s\n%)"(
            severity,
            location.filename.fromStringz,
            location.linnum,
            location.charnum,
            message,
            supplementalDiagnostics.length > 0 ? "\n" : "",
            supplementalDiagnostics
        );
    }

pure nothrow @safe:

    /// Returns: the supplemental diagnostics attached to this diagnostic.
    const(Diagnostic[]) supplementalDiagnostics() const @nogc
    {
        return _supplementalDiagnostics;
    }

    /**
     * Adds a supplemental diagnostic to this diagnostic.
     *
     * Params:
     *  diagnostic = the supplemental diagnostic to add
     */
    private void addSupplementalDiagnostic(Diagnostic diagnostic)
    in
    {
        assert(diagnostic.severity == severity);
    }
    body
    {
        _supplementalDiagnostics ~= diagnostic;
    }
}

/// Stores a set of diagnostics.
struct DiagnosticSet
{
    private Diagnostic[] _diagnostics;

    string toString() const pure
    {
        import std.format : format;

        return format!"%(%s\n%)"(_diagnostics);
    }

pure nothrow @safe:

    /**
     * Adds the given diagnostic to the set of diagnostics.
     *
     * Params:
     *  diagnostic = the diagnostic to add
     */
    DiagnosticSet opOpAssign(string op)(Diagnostic diagnostic)
    if (op == "~")
    {
        _diagnostics ~= diagnostic;
        return this;
    }

    /// ditto
    void add(Diagnostic diagnostic)
    {
        _diagnostics ~= diagnostic;
    }

    /**
     * Adds the given supplemental diagnostic to the last added diagnostic.
     *
     * Params:
     *  diagnostic = the supplemental diagnostic to add
     */
    void addSupplemental(Diagnostic diagnostic)
    {
        _diagnostics[$ - 1].addSupplementalDiagnostic(diagnostic);
    }

@nogc:

    /// Returns: the diagnostic at the front of the range.
    const(Diagnostic) front() const
    {
        return _diagnostics[0];
    }

    /// Advances the range forward.
    void popFront()
    {
        _diagnostics = _diagnostics[1 .. $];
    }

    /// Returns: `true` if no diagnostics are stored.
    bool empty() const
    {
        return _diagnostics.length == 0;
    }

    /// Returns: the number of diagnostics stored.
    size_t length() const
    {
        return _diagnostics.length;
    }

    /**
     * Returns the diagnostic stored at the given index.
     *
     * Params:
     *  index = the index of the diagnostic to return
     *
     * Returns: the diagnostic
     */
    const(Diagnostic) opIndex(size_t index) const
    {
        return _diagnostics[index];
    }
}

/**
 * Collects all reported diagnostics and stores them internally.
 *
 * Can later be retrieved for processing.
 */
class CollectingDiagnosticReporter : DiagnosticReporter
{
    import core.stdc.stdarg : va_list;
    import std.algorithm : count;

    import dmd.globals : Loc;
    import dmd.root.outbuffer;

    /// The stored diagnostics.
    private DiagnosticSet diagnostics_;

    DiagnosticSet diagnostics()
    {
        return diagnostics_;
    }

    override int errorCount()
    {
        return countDiagnostics(Severity.error);
    }

    override int warningCount()
    {
        return countDiagnostics(Severity.warning);
    }

    override int deprecationCount()
    {
        return countDiagnostics(Severity.deprecation);
    }

    override void error(const ref Loc loc, const(char)* format, va_list args)
    {
        appendDiagnostic(Severity.error, loc, format, args);
    }

    override void errorSupplemental(const ref Loc loc, const(char)* format,
        va_list args)
    {
        appendSupplementalDiagnostic(Severity.error, loc, format, args);
    }

    override void warning(const ref Loc loc, const(char)* format, va_list args)
    {
        appendDiagnostic(Severity.warning, loc, format, args);
    }

    override void warningSupplemental(const ref Loc loc, const(char)* format,
        va_list args)
    {
        appendSupplementalDiagnostic(Severity.warning, loc, format, args);
    }

    override void deprecation(const ref Loc loc, const(char)* format,
        va_list args)
    {
        appendDiagnostic(Severity.deprecation, loc, format, args);
    }

    override void deprecationSupplemental(
        const ref Loc loc,
        const(char)* format,
        va_list args
    )
    {
        appendSupplementalDiagnostic(Severity.deprecation, loc, format, args);
    }

nothrow:

    /**
     * Returns the number of diagnostics stored for the given severity.
     *
     * Params:
     *  severity = the severity to count
     *
     * Returns: the number of diagnostics
     */
    private int countDiagnostics(Severity severity) /*const*/
    {
        return cast(int) diagnostics_.count!(e => e.severity == severity);
    }

    /**
     * Creates and appends a diagnostic.
     *
     * Params:
     *  severity = the severity of the diagnostic
     *  loc = the location of the diagnostic
     *  format = the format string for the diagnostic message
     *  args = the args for the diagnostic message
     */
    private void appendDiagnostic(
        Severity severity,
        const ref Loc loc,
        const(char)* format,
        va_list args
    )
    {
        diagnostics_ ~= createDiagnostic(severity, loc, format, args);
    }

    /**
     * Creates and appends a supplemental diagnostic.
     *
     * Params:
     *  severity = the severity of the diagnostic
     *  loc = the location of the diagnostic
     *  format = the format string for the diagnostic message
     *  args = the args for the diagnostic message
     */
    private void appendSupplementalDiagnostic(
        Severity severity,
        const ref Loc loc,
        const(char)* format,
        va_list args
    )
    {
        const diagnostic = createDiagnostic(severity, loc, format, args);
        diagnostics_.addSupplemental(diagnostic);
    }

    /**
     * Creates a diagnostic.
     *
     * Params:
     *  severity = the severity of the diagnostic
     *  loc = the location of the diagnostic
     *  format = the format string for the diagnostic message
     *  args = the args for the diagnostic message
     *
     * Returns: the newly created diagnostic
     */
    private Diagnostic createDiagnostic(
        Severity severity,
        const ref Loc loc,
        const(char)* format,
        va_list args
    ) const
    {
        OutBuffer buffer;
        buffer.vprintf(format, args);

        Diagnostic diagnostic = {
            severity: Severity.error,
            location: loc,
            message: cast(string) buffer.extractSlice
        };

        return diagnostic;
    }
}
