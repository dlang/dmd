/**
 * Describes a back-end compiler and implements compiler-specific actions.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/compiler.d, _compiler.d)
 * Documentation:  https://dlang.org/phobos/dmd_compiler.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/compiler.d
 */

module dmd.compiler;

import dmd.astcodegen;
import dmd.astenums;
import dmd.arraytypes;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbolsem;
import dmd.errors;
import dmd.expression;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.parse;
import dmd.root.array;
import dmd.root.ctfloat;
import dmd.semantic2;
import dmd.semantic3;
import dmd.tokens;
import dmd.statement;

version (DMDLIB)
{
    version = CallbackAPI;
}

extern (C++) __gshared
{
    bool includeImports = false;
    // array of module patterns used to include/exclude imported modules
    Array!(const(char)*) includeModulePatterns;
    Modules compiledImports;
}


/**
 * A data structure that describes a back-end compiler and implements
 * compiler-specific actions.
 */
extern (C++) struct Compiler
{
    /******************************
     * Encode the given expression, which is assumed to be an rvalue literal
     * as another type for use in CTFE.
     * This corresponds roughly to the idiom *(Type *)&e.
     */
    extern (C++) static Expression paintAsType(UnionExp* pue, Expression e, Type type)
    {
        union U
        {
            d_int32 int32value;
            d_int64 int64value;
            float float32value;
            double float64value;
        }
        U u = void;

        assert(e.type.size() == type.size());

        switch (e.type.ty)
        {
        case Tint32:
        case Tuns32:
            u.int32value = cast(d_int32) e.toInteger();
            break;
        case Tint64:
        case Tuns64:
            u.int64value = cast(d_int64) e.toInteger();
            break;
        case Tfloat32:
            u.float32value = cast(float) e.toReal();
            break;
        case Tfloat64:
            u.float64value = cast(double) e.toReal();
            break;
        case Tfloat80:
            assert(e.type.size() == 8); // 64-bit target `real`
            goto case Tfloat64;
        default:
            assert(0, "Unsupported source type");
        }

        real_t r = void;
        switch (type.ty)
        {
        case Tint32:
        case Tuns32:
            emplaceExp!(IntegerExp)(pue, e.loc, u.int32value, type);
            break;

        case Tint64:
        case Tuns64:
            emplaceExp!(IntegerExp)(pue, e.loc, u.int64value, type);
            break;

        case Tfloat32:
            r = u.float32value;
            emplaceExp!(RealExp)(pue, e.loc, r, type);
            break;

        case Tfloat64:
            r = u.float64value;
            emplaceExp!(RealExp)(pue, e.loc, r, type);
            break;

        case Tfloat80:
            assert(type.size() == 8); // 64-bit target `real`
            goto case Tfloat64;

        default:
            assert(0, "Unsupported target type");
        }
        return pue.exp();
    }

    /******************************
     * For the given module, perform any post parsing analysis.
     * Certain compiler backends (ie: GDC) have special placeholder
     * modules whose source are empty, but code gets injected
     * immediately after loading.
     */
    extern (C++) static void onParseModule(Module m)
    {
    }

    /**
     * A callback function that is called once an imported module is
     * parsed. If the callback returns true, then it tells the
     * frontend that the driver intends on compiling the import.
     */
    extern(C++) static bool onImport(Module m)
    {
        if (includeImports)
        {
            if (includeImportedModuleCheck(ModuleComponentRange(
                m.md ? m.md.packages : [], m.ident, m.isPackageFile)))
            {
                if (global.params.verbose)
                    message("compileimport (%s)", m.srcfile.toChars);
                compiledImports.push(m);
                return true; // this import will be compiled
            }
        }
        return false; // this import will not be compiled
    }

    version (CallbackAPI)
    {
        alias OnStatementSemanticStart = void function(Statement, Scope*);
        alias OnStatementSemanticDone = void function(Statement, Scope*);

        /**
         * Used to insert functionality before the start of the
         * semantic analysis of a statement when importing DMD as a library
         */
        __gshared OnStatementSemanticStart onStatementSemanticStart
                    = function void(Statement s, Scope *sc) {};

        /**
         * Used to insert functionality after the end of the
         * semantic analysis of a statement when importing DMD as a library
         */
        __gshared OnStatementSemanticDone onStatementSemanticDone
                    = function void(Statement s, Scope *sc) {};
    }
}

/******************************
 * Private helpers for Compiler::onImport.
 */
// A range of component identifiers for a module
private struct ModuleComponentRange
{
    Identifier[] packages;
    Identifier name;
    bool isPackageFile;
    size_t index;
    @property auto totalLength() const { return packages.length + 1 + (isPackageFile ? 1 : 0); }

    @property auto empty() { return index >= totalLength(); }
    @property auto front() const
    {
        if (index < packages.length)
            return packages[index];
        if (index == packages.length)
            return name;
        else
            return Identifier.idPool("package");
    }
    void popFront() { index++; }
}

/*
 * Determines if the given module should be included in the compilation.
 * Returns:
 *  True if the given module should be included in the compilation.
 */
private bool includeImportedModuleCheck(ModuleComponentRange components)
    in { assert(includeImports); }
do
{
    createMatchNodes();
    size_t nodeIndex = 0;
    while (nodeIndex < matchNodes.dim)
    {
        //printf("matcher ");printMatcher(nodeIndex);printf("\n");
        auto info = matchNodes[nodeIndex++];
        if (info.depth <= components.totalLength())
        {
            size_t nodeOffset = 0;
            for (auto range = components;;range.popFront())
            {
                if (range.empty || nodeOffset >= info.depth)
                {
                    // MATCH
                    return !info.isExclude;
                }
                if (!(range.front is matchNodes[nodeIndex + nodeOffset].id))
                {
                    break;
                }
                nodeOffset++;
            }
        }
        nodeIndex += info.depth;
    }
    assert(nodeIndex == matchNodes.dim, "code bug");
    return includeByDefault;
}

// Matching module names is done with an array of matcher nodes.
// The nodes are sorted by "component depth" from largest to smallest
// so that the first match is always the longest (best) match.
private struct MatcherNode
{
    union
    {
        struct
        {
            ushort depth;
            bool isExclude;
        }
        Identifier id;
    }
    this(Identifier id) { this.id = id; }
    this(bool isExclude, ushort depth)
    {
        this.depth = depth;
        this.isExclude = isExclude;
    }
}

/*
 * $(D includeByDefault) determines whether to include/exclude modules when they don't
 * match any pattern. This setting changes depending on if the user provided any "inclusive" module
 * patterns. When a single "inclusive" module pattern is given, it likely means the user only
 * intends to include modules they've "included", however, if no module patterns are given or they
 * are all "exclusive", then it is likely they intend to include everything except modules
 * that have been excluded. i.e.
 * ---
 * -i=-foo // include everything except modules that match "foo*"
 * -i=foo  // only include modules that match "foo*" (exclude everything else)
 * ---
 * Note that this default behavior can be overriden using the '.' module pattern. i.e.
 * ---
 * -i=-foo,-.  // this excludes everything
 * -i=foo,.    // this includes everything except the default exclusions (-std,-core,-etc.-object)
 * ---
*/
private __gshared bool includeByDefault = true;
private __gshared Array!MatcherNode matchNodes;

/*
 * Creates the global list of match nodes used to match module names
 * given strings provided by the -i commmand line option.
 */
private void createMatchNodes()
{
    static size_t findSortedIndexToAddForDepth(size_t depth)
    {
        size_t index = 0;
        while (index < matchNodes.dim)
        {
            auto info = matchNodes[index];
            if (depth > info.depth)
                break;
            index += 1 + info.depth;
        }
        return index;
    }

    if (matchNodes.dim == 0)
    {
        foreach (modulePattern; includeModulePatterns)
        {
            auto depth = parseModulePatternDepth(modulePattern);
            auto entryIndex = findSortedIndexToAddForDepth(depth);
            matchNodes.split(entryIndex, depth + 1);
            parseModulePattern(modulePattern, &matchNodes[entryIndex], depth);
            // if at least 1 "include pattern" is given, then it is assumed the
            // user only wants to include modules that were explicitly given, which
            // changes the default behavior from inclusion to exclusion.
            if (includeByDefault && !matchNodes[entryIndex].isExclude)
            {
                //printf("Matcher: found 'include pattern', switching default behavior to exclusion\n");
                includeByDefault = false;
            }
        }

        // Add the default 1 depth matchers
        MatcherNode[8] defaultDepth1MatchNodes = [
            MatcherNode(true, 1), MatcherNode(Id.std),
            MatcherNode(true, 1), MatcherNode(Id.core),
            MatcherNode(true, 1), MatcherNode(Id.etc),
            MatcherNode(true, 1), MatcherNode(Id.object),
        ];
        {
            auto index = findSortedIndexToAddForDepth(1);
            matchNodes.split(index, defaultDepth1MatchNodes.length);
            auto slice = matchNodes[];
            slice[index .. index + defaultDepth1MatchNodes.length] = defaultDepth1MatchNodes[];
        }
    }
}

/*
 * Determines the depth of the given module pattern.
 * Params:
 *  modulePattern = The module pattern to determine the depth of.
 * Returns:
 *  The component depth of the given module pattern.
 */
private ushort parseModulePatternDepth(const(char)* modulePattern)
{
    if (modulePattern[0] == '-')
        modulePattern++;

    // handle special case
    if (modulePattern[0] == '.' && modulePattern[1] == '\0')
        return 0;

    ushort depth = 1;
    for (;; modulePattern++)
    {
        auto c = *modulePattern;
        if (c == '.')
            depth++;
        if (c == '\0')
            return depth;
    }
}
unittest
{
    assert(".".parseModulePatternDepth == 0);
    assert("-.".parseModulePatternDepth == 0);
    assert("abc".parseModulePatternDepth == 1);
    assert("-abc".parseModulePatternDepth == 1);
    assert("abc.foo".parseModulePatternDepth == 2);
    assert("-abc.foo".parseModulePatternDepth == 2);
}

/*
 * Parses a 'module pattern', which is the "include import" components
 * given on the command line, i.e. "-i=<module_pattern>,<module_pattern>,...".
 * Params:
 *  modulePattern = The module pattern to parse.
 *  dst = the data structure to save the parsed module pattern to.
 *  depth = the depth of the module pattern previously retrieved from $(D parseModulePatternDepth).
 */
private void parseModulePattern(const(char)* modulePattern, MatcherNode* dst, ushort depth)
{
    bool isExclude = false;
    if (modulePattern[0] == '-')
    {
        isExclude = true;
        modulePattern++;
    }

    *dst = MatcherNode(isExclude, depth);
    dst++;

    // Create and add identifiers for each component in the modulePattern
    if (depth > 0)
    {
        auto idStart = modulePattern;
        auto lastNode = dst + depth - 1;
        for (; dst < lastNode; dst++)
        {
            for (;; modulePattern++)
            {
                if (*modulePattern == '.')
                {
                    assert(modulePattern > idStart, "empty module pattern");
                    *dst = MatcherNode(Identifier.idPool(idStart, cast(uint)(modulePattern - idStart)));
                    modulePattern++;
                    idStart = modulePattern;
                    break;
                }
            }
        }
        for (;; modulePattern++)
        {
            if (*modulePattern == '\0')
            {
                assert(modulePattern > idStart, "empty module pattern");
                *lastNode = MatcherNode(Identifier.idPool(idStart, cast(uint)(modulePattern - idStart)));
                break;
            }
        }
    }
}
