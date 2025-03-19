/**
 * Contains high-level interfaces for interacting with DMD as a library.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/id.d, _id.d)
 * Documentation:  https://dlang.org/phobos/dmd_frontend.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/frontend.d
 */
module dmd.frontend;

import dmd.astcodegen : ASTCodegen;
import dmd.astenums : CHECKENABLE;
import dmd.dmodule : Module;
import dmd.globals : DiagnosticReporting;
import dmd.errors;
import dmd.location;

import std.range.primitives : isInputRange, ElementType;
import std.traits : isNarrowString;
import std.typecons : Tuple;
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
    contractChecks = indicates which contracts should be enabled or not
    versionIdentifiers = a list of version identifiers that should be enabled
*/
void initDMD(
    DiagnosticHandler diagnosticHandler = null,
    FatalErrorHandler fatalErrorHandler = null,
    const string[] versionIdentifiers = [],
    ContractChecks contractChecks = ContractChecks()
)
{
    import std.algorithm : each;

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

    versionIdentifiers.each!(VersionCondition.addGlobalIdent);

    target.os = defaultTargetOS();
    target.isX86_64 = (size_t.sizeof == 8);
    target.isX86 = !target.isX86_64;
    target._init(global.params);
    Type._init();
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
    import dmd.errors : diagnostics;

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

    diagnostics.length = 0;
}

/**
Add import path to the `global.path`.
Params:
    path = import to add
*/
void addImport(const(char)[] path)
{
    import dmd.globals : global, ImportPathInfo;
    import std.string : toStringz;

    global.path.push(ImportPathInfo(path.toStringz));
}

/**
Add string import path to `global.filePath`.
Params:
    path = string import to add
*/
void addStringImport(const(char)[] path)
{
    import std.string : toStringz;

    import dmd.globals : global;
    import dmd.arraytypes : Strings;

    global.filePath.push(path.toStringz);
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
    import std.file : getcwd;
    import std.path : buildPath, dirName;
    import std.algorithm.iteration : filter;
    import std.file : exists;

    auto execDir = ldcFilePath.dirName;

    immutable ldcConfig = "ldc2.conf";
    // https://wiki.dlang.org/Using_LDC
    auto ldcConfigs = [
        getcwd.buildPath(ldcConfig),
        execDir.buildPath(ldcConfig),
        execDir.dirName.buildPath("etc", ldcConfig),
        "~/.ldc".buildPath(ldcConfig),
        execDir.buildPath("etc", ldcConfig),
        execDir.buildPath("etc", "ldc", ldcConfig),
        "/etc".buildPath(ldcConfig),
        "/etc/ldc".buildPath(ldcConfig),
    ].filter!exists;
    if (ldcConfigs.empty)
        return null;

    return ldcConfigs.front;
}

/**
Detect the currently active compiler.
Returns: full path to the executable of the found compiler, `null` otherwise.
*/
string determineDefaultCompiler()
{
    import std.algorithm.iteration : filter, joiner, map, splitter;
    import std.file : exists;
    import std.path : buildPath;
    import std.process : environment;
    import std.range : front, empty, transposed;
    // adapted from DUB: https://github.com/dlang/dub/blob/350a0315c38fab9d3d0c4c9d30ff6bb90efb54d6/source/dub/dub.d#L1183

    auto compilers = ["dmd", "gdc", "gdmd", "ldc2", "ldmd2"];

    // Search the user's PATH for the compiler binary
    if ("DMD" in environment)
        compilers = environment.get("DMD") ~ compilers;
    auto paths = environment.get("PATH", "").splitter(sep);
    auto res = compilers.map!(c => paths.map!(p => p.buildPath(c~exe))).joiner.filter!exists;
    return !res.empty ? res.front : null;
}

/**
Parses a `dmd.conf` or `ldc2.conf` config file and returns defined import paths.

Params:
    iniFile = iniFile to parse imports from
    execDir = directory of the compiler binary

Returns: forward range of import paths found in `iniFile`
*/
auto parseImportPathsFromConfig(const(char)[] iniFile, const(char)[] execDir)
{
    import std.algorithm, std.range, std.regex;
    import std.stdio : File;
    import std.path : buildNormalizedPath;

    alias expandConfigVariables = a => a.drop(2) // -I
                                // "set" common config variables
                                .replace("%@P%", execDir)
                                .replace("%%ldcbinarypath%%", execDir);

    // search for all -I imports in this file
    alias searchForImports = l => l.matchAll(`-I[^ "]+`.regex).joiner.map!expandConfigVariables;

    return File(iniFile, "r")
        .byLineCopy
        .map!searchForImports
        .joiner
        // remove duplicated imports paths
        .array
        .sort
        .uniq
        .map!buildNormalizedPath;
}

/**
Finds a `dmd.conf` and parses it for import paths.
This depends on the `$DMD` environment variable.
If `$DMD` is set to `ldmd`, it will try to detect and parse a `ldc2.conf` instead.

Returns:
    A forward range of normalized import paths.

See_Also: $(LREF determineDefaultCompiler), $(LREF parseImportPathsFromConfig)
*/
auto findImportPaths()
{
    import std.algorithm.searching : endsWith;
    import std.file : exists;
    import std.path : dirName;

    string execFilePath = determineDefaultCompiler();
    assert(execFilePath !is null, "No D compiler found. `Use parseImportsFromConfig` manually.");

    immutable execDir = execFilePath.dirName;

    string iniFile;
    if (execFilePath.endsWith("ldc"~exe, "ldc2"~exe, "ldmd"~exe, "ldmd2"~exe))
        iniFile = findLDCConfig(execFilePath);
    else
        iniFile = findDMDConfig(execFilePath);

    assert(iniFile !is null && iniFile.exists, "No valid config found.");
    return iniFile.parseImportPathsFromConfig(execDir);
}

/**
Parse a module from a string.

Params:
    fileName = file to parse
    code = text to use instead of opening the file

Returns: the parsed module object
*/
Tuple!(Module, "module_", Diagnostics, "diagnostics") parseModule(AST = ASTCodegen)(
    const(char)[] fileName,
    const(char)[] code = null)
{
    import dmd.root.file : File, Buffer;

    import dmd.globals : global;
    import dmd.location;
    import dmd.parse : Parser;
    import dmd.identifier : Identifier;
    import dmd.tokens : TOK;

    import std.path : baseName, stripExtension;
    import std.string : toStringz;
    import std.typecons : tuple;

    auto id = Identifier.idPool(fileName.baseName.stripExtension);
    auto m = new Module(fileName, id, 1, 0);

    if (code is null)
        m.read(Loc.initial);
    else
    {
        import dmd.root.filename : FileName;

        auto fb = cast(ubyte[]) code.dup ~ '\0';
        global.fileManager.add(FileName(fileName), fb);
        m.src = fb;
    }

    m.importedFrom = m;
    m = m.parseModule!AST();

    Diagnostics diagnostics = {
        errors: global.errors,
        warnings: global.warnings
    };

    return typeof(return)(m, diagnostics);
}

/**
Run full semantic analysis on a module.
*/
void fullSemantic(Module m)
{
    import dmd.dsymbolsem : dsymbolSemantic, importAll;
    import dmd.semantic2 : semantic2;
    import dmd.semantic3 : semantic3;

    m.importedFrom = m;
    m.importAll(null);

    m.dsymbolSemantic(null);
    Module.runDeferredSemantic();

    m.semantic2(null);
    Module.runDeferredSemantic2();

    m.semantic3(null);
    Module.runDeferredSemantic3();
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

    import std.string : replace, fromStringz;
    import std.exception : assumeUnique;

    auto generated = buf.extractSlice.replace("\t", "    ");
    return generated.assumeUnique;
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
