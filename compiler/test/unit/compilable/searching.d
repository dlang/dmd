// See ../../README.md for information about DMD unit tests.
//
// Verify that searches using Dsymbol.search inside of templates respect
// the IgnoreErrors flag (instead of raising an error)

module compilable.searching;

import support : afterEach, beforeEach, compiles;

import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dclass : ClassDeclaration;
import dmd.declaration : VarDeclaration;
import dmd.dtemplate : TemplateDeclaration;
import dmd.globals : global;
import dmd.identifier : Identifier;
import dmd.location;

@beforeEach initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("Test searching templated class members")
unittest
{
    doTest(q{

class Clazz(T)
{
    T member;
}

    }, "Clazz");
}

@("Test searching templated struct members")
unittest
{
    doTest(q{

class Structure(T)
{
    T member;
}

    }, "Structure");
}

@("Test searching templated namespace members")
unittest
{
    doTest(q{

template Namespace(T)
{
    extern(C++, Namespace)
    {
        T member;
    }
}

    }, "Namespace");
}

@("Test searching templated enum members")
unittest
{
    doTest(q{

template Enumeration(T)
{
    enum Enumeration : T
    {
        member
    }
}

    }, "Enumeration");
}

@("Test searching templated alias")
unittest
{
    doTest(q{

    alias Alias(T) = int;

    }, "Alias");
}

@("Test searching templated import")
unittest
{
    doTest(q{

template Import(T)
{
    import object;
}

    }, "Import");
}

@("Test searching templated renamed import")
unittest
{
    doTest(q{

template Import(T)
{
    import core.stdc.stdint : member = int32_t;
}

    }, "Import");
}

private:

/**
 * Compiles `code` and searches for `symbol` as well as it's member `member`.
 *
 * `symbol` must be found and the fronted may never raise errors because this
 * method uses the `IgnoreErrors` flag.
 */
void doTest(const string code, const string symbol, const string member = "member")
{
    auto res = compiles(code);
    assert(res, res.toString());

    auto mod = cast() res.module_;

    auto td = find!TemplateDeclaration(mod, symbol);

    // Search doesn't work on uninstantiated templates
    assert(td.members);
    assert(td.members.length == 1);
    auto cl = (*td.members)[0];

    find!VarDeclaration(cl, member, true);
}

/**
 * Wrapper for `Dsymbol.search` that finds an AST node.
 *
 * Params:
 *   T            = expected type of the node
 *   name         = name of the symbol
 *   allowMissing = search is allowed yield no results
 *
 * Returns: the symbol or `null` if `allowMissing` is true
*           (otherwise triggers an assertion failure)
 */
T find(T)(Dsymbol sym, string name, bool allowMissing = false)
{
    Dsymbol found = findSymbol(sym, name, allowMissing);
    if (allowMissing && !found)
        return null;
    T res = mixin("found.is" ~ T.stringof);
    assert(res, found.toString() ~ " is not a " ~ T.stringof);
    return res;
}

/// ditto
Dsymbol findSymbol(Dsymbol sym, string name, bool allowMissing = false)
{
    assert(sym, "Missing symbol while searching for: " ~ name);

    const oldErrors = global.errors;
    Identifier id = Identifier.idPool(name);
    Dsymbol found = sym.search(Loc.initial, id, SearchOpt.ignoreErrors);

    assert(global.errors == oldErrors, "Searching " ~ name ~ " caused errors!");
    assert(allowMissing || found, name ~ " not found!");
    return found;
}
