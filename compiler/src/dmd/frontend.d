/**
 * Contains high-level interfaces for interacting with DMD as a library.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/frontend.d, _id.d)
 * Documentation:  https://dlang.org/phobos/dmd_frontend.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/frontend.d
 */
module dmd.frontend;

import dmd.astcodegen : ASTCodegen;
import dmd.astenums : CHECKENABLE;
import dmd.dmodule : Module;
import dmd.errors : DiagnosticHandler, diagnosticHandler, FatalErrorHandler, fatalErrorHandler, Classification;
import dmd.globals : DiagnosticReporting;
import dmd.location;

import core.stdc.stdarg;

version (Windows) private enum sep = ";", exe = ".exe";
version (Posix) private enum sep = ":", exe = "";

/// Contains aggregated diagnostics information.
immutable struct Diagnostics
{
    /// Number of errors diagnosed
    uint errors;

    /// Number of warnings diagnosed
    uint warnings;

    /// Returns: `true` if errors have been diagnosed
    bool hasErrors()
    {
        return errors > 0;
    }

    /// Returns: `true` if warnings have been diagnosed
    bool hasWarnings()
    {
        return warnings > 0;
    }
}

/// Result of parseModule().
struct ParsedModule
{
    Module module_;
    Diagnostics diagnostics;
}

/// Indicates the checking state of various contracts.
enum ContractChecking : CHECKENABLE
{
    /// Initial value
    default_ = CHECKENABLE._default,

    /// Never do checking
    disabled = CHECKENABLE.off,

    /// Always do checking
    enabled = CHECKENABLE.on,

    /// Only do checking in `@safe` functions
    enabledInSafe = CHECKENABLE.safeonly
}

static assert(
    __traits(allMembers, ContractChecking).length ==
    __traits(allMembers, CHECKENABLE).length
);

/// Indicates which contracts should be checked or not.
struct ContractChecks
{
    /// Precondition checks (in contract).
    ContractChecking precondition = ContractChecking.enabled;

    /// Invariant checks.
    ContractChecking invariant_ = ContractChecking.enabled;

    /// Postcondition checks (out contract).
    ContractChecking postcondition = ContractChecking.enabled;

    /// Array bound checks.
    ContractChecking arrayBounds = ContractChecking.enabled;

    /// Assert checks.
    ContractChecking assert_ = ContractChecking.enabled;

    /// Switch error checks.
    ContractChecking switchError = ContractChecking.enabled;
}

/*
Initializes the global variables of the DMD compiler.
This needs to be done $(I before) calling any function.

Params:
    diagnosticHandler = a delegate to configure what to do with diagnostics (other than printing to console or stderr).
    fatalErrorHandler = a delegate to configure what to do with fatal errors (default is to call exit(EXIT_FAILURE)).
    versionIdentifiers = a list of version identifiers that should be enabled
    contractChecks = indicates which contracts should be enabled or not
*/
void initDMD(
    DiagnosticHandler diagnosticHandler = null,
    FatalErrorHandler fatalErrorHandler = null,
    const string[] versionIdentifiers = [],
    ContractChecks contractChecks = ContractChecks()
)
{
    import dmd.root.ctfloat : CTFloat;

    version (CRuntime_Microsoft)
        import dmd.root.longdouble : initFPU;

    import dmd.astenums : CHECKENABLE;
    import dmd.cond : VersionCondition;
    import dmd.dmodule : Module;
    import dmd.escape : EscapeState;
    import dmd.expression : Expression;
    import dmd.globals : global;
    import dmd.id : Id;
    import dmd.identifier : Identifier;
    import dmd.mtype : Type;
    import dmd.objc : Objc;
    import dmd.target : target, defaultTargetOS, addDefaultVersionIdentifiers;
    import dmd.typesem : Type_init;

    .diagnosticHandler = diagnosticHandler;
    .fatalErrorHandler = fatalErrorHandler;

    global._init();

    with (global.params)
    {
        useIn = contractChecks.precondition;
        useInvariants = contractChecks.invariant_;
        useOut = contractChecks.postcondition;
        useArrayBounds = contractChecks.arrayBounds;
        useAssert = contractChecks.assert_;
        useSwitchError = contractChecks.switchError;
    }

    foreach (id; versionIdentifiers)
        VersionCondition.addGlobalIdent(id);

    target.os = defaultTargetOS();
    target.isX86_64 = (size_t.sizeof == 8);
    target.isX86 = !target.isX86_64;
    target._init(global.params);
    Type_init();
    Id.initialize();
    Module._init();
    Expression._init();
    Objc._init();
    Loc._init();
    EscapeState.reset();

    addDefaultVersionIdentifiers(global.params, target);

    version (CRuntime_Microsoft)
        initFPU();

    CTFloat.initialize();
}

/**
Deinitializes the global variables of the DMD compiler.

This can be used to restore the state set by `initDMD` to its original state.
Useful if there's a need for multiple sessions of the DMD compiler in the same
application.
*/
void deinitializeDMD()
{
    import dmd.dmodule : Module;
    import dmd.dsymbol : Dsymbol;
    import dmd.escape : EscapeState;
    import dmd.expression : Expression;
    import dmd.func : FuncDeclaration;
    import dmd.globals : global;
    import dmd.id : Id;
    import dmd.mtype : Type;
    import dmd.objc : Objc;
    import dmd.target : target;
    import dmd.dfa.fast.structure : DFAAllocator;

    diagnosticHandler = null;
    fatalErrorHandler = null;
    FuncDeclaration.lastMain = null;

    global.deinitialize();

    Type.deinitialize();
    Id.deinitialize();
    Module.deinitialize();
    target.deinitialize();
    Expression.deinitialize();
    Objc.deinitialize();
    Dsymbol.deinitialize();
    EscapeState.reset();
    DFAAllocator.deinitialize();

    // Drop module-scoped caches that would otherwise retain the old universe.
    {
        import funcsem = dmd.funcsem;
        import dsymbolsem = dmd.dsymbolsem;
        import typesem = dmd.typesem;
        import semantic3 = dmd.semantic3;
        import templatesem = dmd.templatesem;
        import dtemplate = dmd.dtemplate;
        import dmd.dscope : Scope;
        import clone = dmd.clone;
        import arrayop = dmd.arrayop;
        import dinterpret = dmd.dinterpret;
        import dmd.location : Loc;

        funcsem.deinitialize();
        dsymbolsem.deinitialize();
        typesem.deinitialize();
        semantic3.deinitialize();
        templatesem.deinitialize();
        dtemplate.deinitialize();
        clone.deinitialize();
        arrayop.deinitialize();
        dinterpret.deinitialize();
        Scope.freelist = null;
        Loc._init();
    }
}

/**
Add import path to the `global.path`.
Params:
    path = import to add
*/
void addImport(const(char)[] path)
{
    import dmd.globals : global, ImportPathInfo;
    import dmd.root.string : toCString;

    global.path.push(ImportPathInfo(path.toCString.ptr));
}

/**
Add string import path to `global.filePath`.
Params:
    path = string import to add
*/
void addStringImport(const(char)[] path)
{
    import dmd.root.string : toCString;

    import dmd.globals : global;
    import dmd.arraytypes : Strings;

    global.filePath.push(path.toCString.ptr);
}

/**
Searches for a `dmd.conf`.

Params:
    dmdFilePath = path to the current DMD executable

Returns: full path to the found `dmd.conf`, `null` otherwise.
*/
string findDMDConfig(const(char)[] dmdFilePath)
{
    import dmd.dinifile : findConfFile;

    version (Windows)
        enum configFile = "sc.ini";
    else
        enum configFile = "dmd.conf";

    return findConfFile(dmdFilePath, configFile).idup;
}

/**
Searches for a `ldc2.conf`.

Params:
    ldcFilePath = path to the current LDC executable

Returns: full path to the found `ldc2.conf`, `null` otherwise.
*/
string findLDCConfig(const(char)[] ldcFilePath)
{
    import dmd.root.filename : FileName;

    string execDir = dirNameOf(ldcFilePath);

    immutable ldcConfig = "ldc2.conf";
    // https://wiki.dlang.org/Using_LDC
    string[8] candidates = [
        FileName.combine(currentDir(), ldcConfig).idup,
        FileName.combine(execDir, ldcConfig).idup,
        FileName.combine(FileName.combine(dirNameOf(execDir), "etc"), ldcConfig).idup,
        FileName.combine("~/.ldc", ldcConfig).idup,
        FileName.combine(FileName.combine(execDir, "etc"), ldcConfig).idup,
        FileName.combine(FileName.combine(FileName.combine(execDir, "etc"), "ldc"), ldcConfig).idup,
        FileName.combine("/etc", ldcConfig).idup,
        FileName.combine("/etc/ldc", ldcConfig).idup,
    ];
    foreach (c; candidates)
    {
        if (FileName.exists(c))
            return c;
    }
    return null;
}

/**
Detect the currently active compiler.
Returns: full path to the executable of the found compiler, `null` otherwise.
*/
string determineDefaultCompiler()
{
    import dmd.root.filename : FileName;

    // adapted from DUB: https://github.com/dlang/dub/blob/350a0315c38fab9d3d0c4c9d30ff6bb90efb54d6/source/dub/dub.d#L1183

    string[5] compilers = ["dmd", "gdc", "gdmd", "ldc2", "ldmd2"];

    // Search the user's PATH for the compiler binary.
    // Outer loop over compilers, inner over PATH entries.
    const(char)[] dmdEnv = getenvOr("DMD", null);
    const(char)[] pathEnv = getenvOr("PATH", "");

    string[] names;
    if (dmdEnv.length)
        names ~= dmdEnv.idup;
    names ~= compilers[];

    // split PATH on the platform separator (quotes are not special here)
    string[] dirs;
    size_t start = 0;
    for (size_t i = 0; i <= pathEnv.length; i++)
    {
        if (i == pathEnv.length || pathEnv[i] == sep[0])
        {
            dirs ~= pathEnv[start .. i].idup;
            start = i + 1;
        }
    }

    foreach (c; names)
    {
        string binary = c ~ exe;
        foreach (p; dirs)
        {
            string candidate = FileName.combine(p, binary).idup;
            if (FileName.exists(candidate))
                return candidate;
        }
    }
    return null;
}

/**
Parses a `dmd.conf` or `ldc2.conf` config file and returns defined import paths.

Params:
    iniFile = iniFile to parse imports from
    execDir = directory of the compiler binary

Returns: array of normalized import paths found in `iniFile`
*/
auto parseImportPathsFromConfig(const(char)[] iniFile, const(char)[] execDir)
{
    string text = readFileBytes(iniFile);
    string[] found;
    if (text is null)
        return found;

    // search for all `-I` imports in this file: `-I` followed by a run
    // of non-space, non-quote characters, possibly several per line
    size_t i = 0;
    while (i + 1 < text.length)
    {
        if (text[i] == '-' && text[i + 1] == 'I')
        {
            size_t j = i + 2;
            while (j < text.length && text[j] != ' ' && text[j] != '"')
                j++;
            if (j > i + 2)
                found ~= expandConfigVariables(text[i .. j], execDir);
            i = j;
        }
        else
            i++;
    }

    // dedup sorted import paths
    sortDedup(found);

    // normalize each path
    foreach (ref p; found)
        p = normalizeImportPath(p);
    return found;
}

/**
Finds a `dmd.conf` and parses it for import paths.
This depends on the `$DMD` environment variable.
If `$DMD` is set to `ldmd`, it will try to detect and parse a `ldc2.conf` instead.

Returns:
    Array of normalized import paths.

See_Also: $(LREF determineDefaultCompiler), $(LREF parseImportPathsFromConfig)
*/
auto findImportPaths()
{
    import dmd.root.filename : FileName;

    string execFilePath = determineDefaultCompiler();
    assert(execFilePath !is null, "No D compiler found. `Use parseImportsFromConfig` manually.");

    immutable execDir = dirNameOf(execFilePath);

    string iniFile;
    if (endsWithAny(execFilePath, ["ldc" ~ exe, "ldc2" ~ exe, "ldmd" ~ exe, "ldmd2" ~ exe]))
        iniFile = findLDCConfig(execFilePath);
    else
        iniFile = findDMDConfig(execFilePath);

    assert(iniFile !is null && FileName.exists(iniFile), "No valid config found.");
    return iniFile.parseImportPathsFromConfig(execDir);
}

/**
Parse a module from a string.

Params:
    fileName = file to parse
    code = text to use instead of opening the file

Returns: the parsed module object
*/
ParsedModule parseModule(AST = ASTCodegen)(
    const(char)[] fileName,
    const(char)[] code = null)
{
    import dmd.root.file : File, Buffer;

    import dmd.globals : global;
    import dmd.location;
    import dmd.parse : Parser;
    import dmd.identifier : Identifier;
    import dmd.tokens : TOK;

    import dmd.root.filename : FileName;

    auto id = Identifier.idPool(FileName.removeExt(FileName.name(fileName)));
    auto m = new Module(fileName, id, 1, 0);

    if (code is null)
        m.read(Loc.initial);
    else
    {
        auto fb = cast(ubyte[]) code.dup ~ '\0';
        global.fileManager.add(FileName(fileName), fb);
        m.src = fb;
    }

    m.importedFrom = m;
    m = m.parseModule!AST();

    return ParsedModule(m, Diagnostics(global.errors, global.warnings));
}

/**
Run full semantic analysis on a module.
*/
void fullSemantic(Module m)
{
    import dmd.dsymbolsem : dsymbolSemantic, importAll, runDeferredSemantic, runDeferredSemantic2, runDeferredSemantic3;
    import dmd.semantic2 : semantic2;
    import dmd.semantic3 : semantic3;

    m.importedFrom = m;
    m.importAll(null);

    m.dsymbolSemantic(null);
    runDeferredSemantic();

    m.semantic2(null);
    runDeferredSemantic2();

    m.semantic3(null);
    runDeferredSemantic3();
}

/**
Pretty print a module.

Returns:
    Pretty printed module as string.
*/
string prettyPrint(Module m)
{
    import dmd.common.outbuffer: OutBuffer;
    import dmd.hdrgen : HdrGenState, moduleToBuffer2;

    auto buf = OutBuffer();
    buf.doindent = 1;
    HdrGenState hgs = { fullDump: 1 };
    moduleToBuffer2(m, buf, hgs);

    auto generated = buf.extractSlice;
    size_t tabs = 0;
    foreach (c; generated)
    {
        if (c == '\t')
            tabs++;
    }
    if (!tabs)
        return cast(string)generated;
    char[] out_ = new char[generated.length + 3 * tabs];
    size_t k = 0;
    foreach (c; generated)
    {
        if (c == '\t')
        {
            out_[k .. k + 4] = "    ";
            k += 4;
        }
        else
            out_[k++] = c;
    }
    return cast(string)out_;
}

/// Interface for diagnostic reporting.
abstract class DiagnosticReporter
{
    import dmd.console : Color;

nothrow:
    DiagnosticHandler prevHandler;

    this()
    {
        prevHandler = diagnosticHandler;
        diagnosticHandler = &diagHandler;
    }

    ~this()
    {
        // assumed to be used scoped
        diagnosticHandler = prevHandler;
    }

    bool diagHandler(const ref SourceLoc loc, Color headerColor, const(char)* header,
                     const(char)* format, va_list ap, const(char)* p1, const(char)* p2)
    {
        import core.stdc.string;

        // recover type from header and color
        if (strncmp (header, "Error:", 6) == 0)
            return error(loc, format, ap, p1, p2);
        if (strncmp (header, "Warning:", 8) == 0)
            return warning(loc, format, ap, p1, p2);
        if (strncmp (header, "Deprecation:", 12) == 0)
            return deprecation(loc, format, ap, p1, p2);

        if (cast(Classification)headerColor == Classification.warning)
            return warningSupplemental(loc, format, ap, p1, p2);
        if (cast(Classification)headerColor == Classification.deprecation)
            return deprecationSupplemental(loc, format, ap, p1, p2);

        return errorSupplemental(loc, format, ap, p1, p2);
    }

    /// Returns: the number of errors that occurred during lexing or parsing.
    abstract int errorCount();

    /// Returns: the number of warnings that occurred during lexing or parsing.
    abstract int warningCount();

    /// Returns: the number of deprecations that occurred during lexing or parsing.
    abstract int deprecationCount();

    /**
    Reports an error message.

    Params:
        loc = Location of error
        format = format string for error
        args = printf-style variadic arguments
        p1 = additional message prefix
        p2 = additional message prefix

    Returns: false if the message should also be printed to stderr, true otherwise
    */
    abstract bool error(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2);

    /**
    Reports additional details about an error message.

    Params:
        loc = Location of error
        format = format string for supplemental message
        args = printf-style variadic arguments
        p1 = additional message prefix
        p2 = additional message prefix

    Returns: false if the message should also be printed to stderr, true otherwise
    */
    abstract bool errorSupplemental(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2);

    /**
    Reports a warning message.

    Params:
        loc = Location of warning
        format = format string for warning
        args = printf-style variadic arguments
        p1 = additional message prefix
        p2 = additional message prefix

    Returns: false if the message should also be printed to stderr, true otherwise
    */
    abstract bool warning(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2);

    /**
    Reports additional details about a warning message.

    Params:
        loc = Location of warning
        format = format string for supplemental message
        args = printf-style variadic arguments
        p1 = additional message prefix
        p2 = additional message prefix

    Returns: false if the message should also be printed to stderr, true otherwise
    */
    abstract bool warningSupplemental(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2);

    /**
    Reports a deprecation message.

    Params:
        loc = Location of the deprecation
        format = format string for the deprecation
        args = printf-style variadic arguments
        p1 = additional message prefix
        p2 = additional message prefix

    Returns: false if the message should also be printed to stderr, true otherwise
    */
    abstract bool deprecation(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2);

    /**
    Reports additional details about a deprecation message.

    Params:
        loc = Location of deprecation
        format = format string for supplemental message
        args = printf-style variadic arguments
        p1 = additional message prefix
        p2 = additional message prefix

    Returns: false if the message should also be printed to stderr, true otherwise
    */
    abstract bool deprecationSupplemental(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2);
}

/**
Diagnostic reporter which prints the diagnostic messages to stderr.

This is usually the default diagnostic reporter.
*/
final class StderrDiagnosticReporter : DiagnosticReporter
{
    private const DiagnosticReporting useDeprecated;

    private int errorCount_;
    private int warningCount_;
    private int deprecationCount_;

nothrow:

    /**
    Initializes this object.

    Params:
        useDeprecated = indicates how deprecation diagnostics should be
                        handled
    */
    this(DiagnosticReporting useDeprecated)
    {
        this.useDeprecated = useDeprecated;
    }

    override int errorCount()
    {
        return errorCount_;
    }

    override int warningCount()
    {
        return warningCount_;
    }

    override int deprecationCount()
    {
        return deprecationCount_;
    }

    override bool error(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2)
    {
        errorCount_++;
        return false;
    }

    override bool errorSupplemental(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2)
    {
        return false;
    }

    override bool warning(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2)
    {
        warningCount_++;
        return false;
    }

    override bool warningSupplemental(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2)
    {
        return false;
    }

    override bool deprecation(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2)
    {
        if (useDeprecated == DiagnosticReporting.error)
            errorCount_++;
        else
            deprecationCount_++;
        return false;
    }

    override bool deprecationSupplemental(const ref SourceLoc loc, const(char)* format, va_list args, const(char)* p1, const(char)* p2)
    {
        return false;
    }
}

// Private path/config helpers.

private bool isPathSep(char c) nothrow @nogc @safe pure
{
    import dmd.root.filename : isDirSeparator;
    return isDirSeparator(c);
}

// Directory portion of a path, "." when there is none.
private string dirNameOf(const(char)[] path)
{
    if (!path.length)
        return ".";
    // strip trailing separators, keeping a lone root
    size_t end = path.length;
    while (end > 1 && isPathSep(path[end - 1]))
    {
        // keep Windows drive roots like `C:\` intact
        if (end == 2 && path[1] == ':')
            break;
        end--;
    }
    // find last separator in path[0 .. end]
    size_t i = end;
    while (i > 0 && !isPathSep(path[i - 1]))
        i--;
    if (i == 0)
        return ".";
    if (i == 1)
        return path[0 .. 1].idup; // root "/"
    size_t dirEnd = i - 1;
    // keep `C:` style prefixes
    if (dirEnd == 2 && path[1] == ':')
        return path[0 .. 2].idup;
    while (dirEnd > 1 && isPathSep(path[dirEnd - 1]))
        dirEnd--;
    return path[0 .. dirEnd].idup;
}

///
unittest
{
    assert(dirNameOf("") == ".");
    assert(dirNameOf("foo") == ".");
    assert(dirNameOf("foo/bar") == "foo");
    assert(dirNameOf("foo/bar/") == "foo");
    assert(dirNameOf("/foo/bar") == "/foo");
    assert(dirNameOf("/foo") == "/");
    assert(dirNameOf("/") == "/");
    assert(dirNameOf("a/b/c") == "a/b");
}

// Replace all (non-overlapping).
private string replaceAll(const(char)[] s, const(char)[] from, const(char)[] to)
{
    if (!from.length)
        return s.idup;
    string r;
    size_t i = 0;
    while (i < s.length)
    {
        if (i + from.length <= s.length && s[i .. i + from.length] == from)
        {
            r ~= to;
            i += from.length;
        }
        else
        {
            r ~= s[i];
            i++;
        }
    }
    return r;
}

///
unittest
{
    assert(replaceAll("aaa", "aa", "b") == "ba");
    assert(replaceAll("%@P%/x/%@P%", "%@P%", "E") == "E/x/E");
    assert(replaceAll("abc", "", "x") == "abc");
    assert(replaceAll("", "a", "b") == "");
}

// normalize an import path.
private string normalizeImportPath(const(char)[] path)
{
    if (!path.length)
        return "";
    string prefix;
    size_t i = 0;
    version (Windows)
    {
        // drive letter prefix
        if (path.length >= 2 && path[1] == ':' &&
            ((path[0] >= 'a' && path[0] <= 'z') || (path[0] >= 'A' && path[0] <= 'Z')))
        {
            prefix = path[0 .. 2].idup;
            i = 2;
        }
    }
    bool rooted = false;
    if (i < path.length && isPathSep(path[i]))
    {
        rooted = true;
        prefix ~= '/';
        while (i < path.length && isPathSep(path[i]))
            i++;
    }
    string[] parts;
    while (i < path.length)
    {
        size_t j = i;
        while (j < path.length && !isPathSep(path[j]))
            j++;
        auto seg = path[i .. j];
        i = j;
        while (i < path.length && isPathSep(path[i]))
            i++;
        if (!seg.length || seg == ".")
            continue;
        if (seg == "..")
        {
            if (parts.length && parts[$ - 1] != "..")
            {
                parts = parts[0 .. $ - 1];
                continue;
            }
            if (rooted)
                continue; // `..` above root is dropped
        }
        parts ~= seg.idup;
    }
    if (!parts.length)
        return rooted ? prefix : ".";
    string r = prefix.idup;
    foreach (k, p; parts)
    {
        if (k > 0)
            r ~= '/';
        r ~= p;
    }
    return r;
}

///
unittest
{
    assert(normalizeImportPath("") == "");
    assert(normalizeImportPath("a/b/../c") == "a/c");
    assert(normalizeImportPath("a/b/../../c") == "c");
    assert(normalizeImportPath("../../x") == "../../x");
    assert(normalizeImportPath("a/./b") == "a/b");
    assert(normalizeImportPath("/a/b/../../c") == "/c");
    assert(normalizeImportPath("/../x") == "/x");
    assert(normalizeImportPath("a//b") == "a/b");
    assert(normalizeImportPath(".") == ".");
    version (Windows)
    {
        assert(normalizeImportPath("C:\\a\\..\\b") == "C:/b");
    }
    else
    {
        assert(normalizeImportPath("a/b/c") == "a/b/c");
    }
}

// Expand `-I` argument & drop the prefix
private string expandConfigVariables(const(char)[] arg, const(char)[] execDir)
{
    auto s = arg.length >= 2 ? arg[2 .. $] : arg[0 .. 0];
    string r = replaceAll(s, "%@P%", execDir);
    return replaceAll(r, "%%ldcbinarypath%%", execDir);
}

private void sortDedup(ref string[] paths)
{
    foreach (i; 1 .. paths.length)
    {
        auto key = paths[i];
        size_t j = i;
        while (j > 0 && paths[j - 1] > key)
        {
            paths[j] = paths[j - 1];
            j--;
        }
        paths[j] = key;
    }
    size_t w = 0;
    foreach (i; 0 .. paths.length)
    {
        if (w == 0 || paths[i] != paths[w - 1])
            paths[w++] = paths[i];
    }
    paths = paths[0 .. w];
}

///
unittest
{
    string[] p = ["b", "a", "b", "c", "a"];
    sortDedup(p);
    assert(p == ["a", "b", "c"]);
    assert(expandConfigVariables("-I%@P%/../src", "/bin") == "/bin/../src");
}

private bool endsWithAny(const(char)[] s, scope const(char)[][] suffixes)
{
    foreach (suf; suffixes)
    {
        if (suf.length <= s.length && s[$ - suf.length .. $] == suf)
            return true;
    }
    return false;
}

///
unittest
{
    assert(endsWithAny("foo/ldc2", ["ldc", "ldc2"]));
    assert(!endsWithAny("foo/ldc2x", ["ldc", "ldc2"]));
    assert(!endsWithAny("ld", ["ldc", "ldc2"]));
}

// Read a whole file, null on failure.
private string readFileBytes(const(char)[] path)
{
    import core.stdc.stdio : fopen, fread, fseek, ftell, rewind, fclose, SEEK_END;

    if (path.length + 1 >= 4096)
        return null;
    char[4096] zpath;
    zpath[0 .. path.length] = path[];
    zpath[path.length] = 0;
    auto f = fopen(zpath.ptr, "rb");
    if (!f)
        return null;
    scope (exit)
        fclose(f);
    if (fseek(f, 0, SEEK_END) != 0)
        return null;
    long n = ftell(f);
    if (n < 0)
        return null;
    rewind(f);
    char[] buf = new char[cast(size_t)n];
    size_t got = 0;
    while (got < buf.length)
    {
        auto k = fread(buf.ptr + got, 1, buf.length - got, f);
        if (k == 0)
            break;
        got += k;
    }
    return buf[0 .. got].idup;
}

// Current working directory, null on failure.
private string currentDir()
{
    version (Posix)
    {
        import core.sys.posix.unistd : getcwd;
        import dmd.root.string : toDString;

        return getcwd(null, 0).toDString().idup;
    }
    else version (Windows)
    {
        import core.sys.windows.winbase : GetCurrentDirectoryA;
        import core.sys.windows.windef : DWORD;

        char[4096] buf;
        auto len = GetCurrentDirectoryA(cast(DWORD)buf.length, buf.ptr);
        if (len == 0 || len >= buf.length)
            return null;
        return buf[0 .. len].idup;
    }
    else
        return null;
}

// getenv with a fallback default.
private const(char)[] getenvOr(const(char)* name, const(char)[] def)
{
    import core.stdc.stdlib : getenv;
    import dmd.root.string : toDString;

    const(char)* v = getenv(name);
    return v ? toDString(v) : def;
}
