/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * This module contains high-level interfaces for interacting
  with DMD as a library.
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/id.d, _id.d)
 * Documentation:  https://dlang.org/phobos/dmd_frontend.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/frontend.d
 */
module dmd.frontend;

import dmd.astcodegen : ASTCodegen;
import dmd.dmodule : Module;
import dmd.errors : DiagnosticReporter;
import dmd.globals : CHECKENABLE;

import std.range.primitives : isInputRange, ElementType;
import std.traits : isNarrowString;
import std.typecons : Tuple;

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

unittest
{
    static assert(
        __traits(allMembers, ContractChecking).length ==
        __traits(allMembers, CHECKENABLE).length
    );
}

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
    contractChecks = indicates which contracts should be enabled or not
    versionIdentifiers = a list of version identifiers that should be enabled
*/
void initDMD(
    const string[] versionIdentifiers = [],
    ContractChecks contractChecks = ContractChecks()
)
{
    import std.algorithm : each;

    import dmd.root.ctfloat : CTFloat;

    version (CRuntime_Microsoft)
        import dmd.root.longdouble : initFPU;

    import dmd.builtin : builtin_init;
    import dmd.cond : VersionCondition;
    import dmd.dmodule : Module;
    import dmd.expression : Expression;
    import dmd.filecache : FileCache;
    import dmd.globals : CHECKENABLE, global;
    import dmd.id : Id;
    import dmd.identifier : Identifier;
    import dmd.mars : setTarget, addDefaultVersionIdentifiers;
    import dmd.mtype : Type;
    import dmd.objc : Objc;
    import dmd.target : target;

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
    setTarget(global.params);
    addDefaultVersionIdentifiers(global.params);

    Type._init();
    Id.initialize();
    Module._init();
    target._init(global.params);
    Expression._init();
    Objc._init();
    builtin_init();
    FileCache._init();

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
    import dmd.builtin : builtinDeinitialize;
    import dmd.dmodule : Module;
    import dmd.expression : Expression;
    import dmd.globals : global;
    import dmd.id : Id;
    import dmd.mtype : Type;
    import dmd.objc : Objc;
    import dmd.target : target;

    global.deinitialize();

    Type.deinitialize();
    Id.deinitialize();
    Module.deinitialize();
    target.deinitialize();
    Expression.deinitialize();
    Objc.deinitialize();
    builtinDeinitialize();
}

/**
Add import path to the `global.path`.
Params:
    path = import to add
*/
void addImport(const(char)[] path)
{
    import dmd.globals : global;
    import dmd.arraytypes : Strings;
    import std.string : toStringz;

    if (global.path is null)
        global.path = new Strings();

    global.path.push(path.toStringz);
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

    if (global.filePath is null)
        global.filePath = new Strings();

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
    diagnosticReporter = the diagnostic reporter to use. By default a
        diagnostic reporter which prints to stderr will be used

Returns: the parsed module object
*/
Tuple!(Module, "module_", Diagnostics, "diagnostics") parseModule(AST = ASTCodegen)(
    const(char)[] fileName,
    const(char)[] code = null,
    DiagnosticReporter diagnosticReporter = defaultDiagnosticReporter
)
in
{
    assert(diagnosticReporter !is null);
}
body
{
    import dmd.root.file : File, FileBuffer;

    import dmd.globals : Loc, global;
    import dmd.parse : Parser;
    import dmd.identifier : Identifier;
    import dmd.tokens : TOK;

    import std.path : baseName, stripExtension;
    import std.string : toStringz;
    import std.typecons : tuple;

    auto id = Identifier.idPool(fileName.baseName.stripExtension);
    auto m = new Module(fileName, id, 0, 0);

    if (code is null)
        m.read(Loc.initial);
    else
    {
        File.ReadResult readResult = {
            success: true,
            buffer: FileBuffer(cast(ubyte[]) code.dup ~ '\0')
        };

        m.loadSourceBuffer(Loc.initial, readResult);
    }

    m.parse!AST(diagnosticReporter);

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
    import dmd.dsymbolsem : dsymbolSemantic;
    import dmd.semantic2 : semantic2;
    import dmd.semantic3 : semantic3;

    m.importedFrom = m;
    m.importAll(null);

    m.dsymbolSemantic(null);
    Module.dprogress = 1;
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
    import dmd.root.outbuffer: OutBuffer;
    import dmd.hdrgen : HdrGenState, moduleToBuffer2;

    OutBuffer buf = { doindent: 1 };
    HdrGenState hgs = { fullDump: 1 };
    moduleToBuffer2(m, &buf, &hgs);

    import std.string : replace, fromStringz;
    import std.exception : assumeUnique;

    auto generated = buf.extractData.fromStringz.replace("\t", "    ");
    return generated.assumeUnique;
}

private DiagnosticReporter defaultDiagnosticReporter()
{
    import dmd.globals : global;
    import dmd.errors : StderrDiagnosticReporter;

    return new StderrDiagnosticReporter(global.params.useDeprecated);
}
