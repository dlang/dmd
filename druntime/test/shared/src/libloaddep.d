import core.runtime;

extern(C) alias RunTests = int function();

extern(C) int runDepTests(const char* name)
{
    import utils : loadSym;

    auto h = rt_loadLibrary(name);
    if (h is null) return false;
    RunTests runTests;
    loadSym(h, runTests, "runTests");
    assert(runTests !is null);
    if (!runTests()) return false;
    return rt_unloadLibrary(h);
}
