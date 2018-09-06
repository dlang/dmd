/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * This module contains high-level interfaces for interacting
  with DMD as a library.
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/id.d, _id.d)
 * Documentation:  https://dlang.org/phobos/dmd_frontend.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/frontend.d
 */
module dmd.frontend;

import dmd.dmodule : Module;
import std.range.primitives : isInputRange, ElementType;
import std.traits : isNarrowString;

version (Windows) private enum sep = ";", exe = ".exe";
version (Posix) private enum sep = ":", exe = "";

/*
Initializes the global variables of the DMD compiler.
This needs to be done $(I before) calling any function.
*/
void initDMD()
{
    import dmd.builtin : builtin_init;
    import dmd.dmodule : Module;
    import dmd.expression : Expression;
    import dmd.globals : global;
    import dmd.id : Id;
    import dmd.mars : setTarget, addDefaultVersionIdentifiers;
    import dmd.mtype : Type;
    import dmd.objc : Objc;
    import dmd.target : Target;

    global._init();
    setTarget(global.params);
    addDefaultVersionIdentifiers(global.params);

    Type._init();
    Id.initialize();
    Module._init();
    Target._init();
    Expression._init();
    Objc._init();
    builtin_init();
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
Searches for a `dmd.conf`.

Params:
    dmdFilePath = path to the current DMD executable

Returns: full path to the found `dmd.conf`, `null` otherwise.
*/
string findDMDConfig(const(char)[] dmdFilePath)
{
    import dmd.dinifile : findConfFile;
    import std.string : fromStringz, toStringz;

    return findConfFile(dmdFilePath, "dmd.conf").idup;
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
Module parseModule(const(char)[] fileName, const(char)[] code = null)
{
    import dmd.astcodegen : ASTCodegen;
    import dmd.globals : Loc;
    import dmd.parse : Parser;
    import dmd.identifier : Identifier;
    import dmd.tokens : TOK;
    import std.string : toStringz;

    static auto parse(Module m, const(char)[] code)
    {
        scope p = new Parser!ASTCodegen(m, code, false);
        p.nextToken; // skip the initial token
        auto members = p.parseModule;
        assert(!p.errors, "Parsing error occurred.");
        assert(p.token.value == TOK.endOfFile, "Didn't reach the end token. Did an error occur?");
        return members;
    }

    Identifier id = Identifier.idPool(fileName);
    auto m = new Module(fileName.toStringz, id, 0, 0);
    if (code !is null)
        m.members = parse(m, code);
    else
    {
        m.read(Loc.initial);
        m.parse();
    }

    return m;
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
    m.semantic2(null);
    m.semantic3(null);
}

/**
Pretty print a module.

Returns:
    Pretty printed module as string.
*/
string prettyPrint(Module m)
{
    import dmd.root.outbuffer: OutBuffer;
    import dmd.hdrgen : HdrGenState, PrettyPrintVisitor;

    OutBuffer buf = { doindent: 1 };
    HdrGenState hgs = { fullDump: 1 };
    scope PrettyPrintVisitor ppv = new PrettyPrintVisitor(&buf, &hgs);
    m.accept(ppv);

    import std.string : replace, fromStringz;
    import std.exception : assumeUnique;

    auto generated = buf.extractData.fromStringz.replace("\t", "    ");
    return generated.assumeUnique;
}
