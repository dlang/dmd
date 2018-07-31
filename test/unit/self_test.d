module self_test;

import support : afterEach, beforeEach, defaultImportPaths;

@beforeEach initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

@afterEach deinitializeFrontend()
{
    // import dmd.frontend : deinitializeDMD;
    // deinitializeDMD();
}

@("self test")
unittest
{
    import std.algorithm : each;
    import dmd.frontend;

    defaultImportPaths.each!addImport;

    auto t = parseModule("test.d", q{
        int a = 3;
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);
}
