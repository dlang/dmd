module semantic.nogc;

import std.algorithm : each;

import dmd.dsymbol : PASS;
import dmd.dsymbolsem : dsymbolSemantic, importAll;
import dmd.frontend;
import dmd.func : FuncDeclaration;
import dmd.globals : global;
import dmd.nogc : isNogc;

import support : afterEach, beforeEach, defaultImportPaths;

@beforeEach void initializeFrontend()
{
    initDMD();
}

@afterEach void deinitializeFrontend()
{
    deinitializeDMD();
}

@("a nogc query can finish pending body analysis without recording incomplete inference")
unittest
{
    defaultImportPaths.each!addImport;
    auto result = parseModule("lazy_nogc.d", q{
        auto leaf() { return 1; }
    });
    assert(!result.diagnostics.hasErrors);

    // Stop before semantic3 so the attribute query itself must analyze the body.
    auto m = result.module_;
    m.importedFrom = m;
    m.importAll(null);
    m.dsymbolSemantic(null);

    FuncDeclaration leaf;
    foreach (member; *m.members)
        if (member.ident && member.ident.toString() == "leaf")
            leaf = member.isFuncDeclaration();

    assert(leaf !is null);
    assert(leaf.semanticRun < PASS.semantic3);
    assert(leaf._scope !is null);
    assert(leaf.nogcInprocess);
    assert(!leaf.nogcInferenceIncomplete);
    assert(global.errors == 0);

    assert(leaf.isNogc());

    assert(leaf.semanticRun == PASS.semantic3done);
    assert(!leaf.nogcInprocess);
    assert(!leaf.nogcInferenceIncomplete);
    assert(leaf.nogcViolation is null);
    assert(global.errors == 0);
}
