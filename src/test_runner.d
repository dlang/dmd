import core.runtime, core.time : TickDuration;
import core.stdc.stdio;

immutable(ModuleInfo*) getModuleInfo(string name)
{
    foreach (m; ModuleInfo)
        if (m.name == name) return m;
    assert(0, "module '"~name~"' not found");
}

bool tester()
{
    assert(Runtime.args.length == 2);
    auto name = Runtime.args[1];
    immutable pkg = ".package";
    immutable pkgLen = pkg.length;

    if (name.length > pkgLen && name[$ - pkgLen .. $] == pkg)
        name = name[0 .. $ - pkgLen];

    bool result = true;

    void testFailed(Throwable t)
    {
        auto msg = t.toString();
        printf("****** FAIL %.*s\n%.*s\n", cast(int)name.length, name.ptr,
               cast(int)msg.length, msg.ptr);
        result = false;
    }

    auto mi = getModuleInfo(name);
    immutable t0 = TickDuration.currSystemTick;
    if (auto tests = mi.unitTests)
    {
        foreach (test; tests)
        {
            if (test.disabled)
                continue;
            try
                test.func();
            catch (Throwable t)
                testFailed(t);
        }
    }
    else if (auto test = mi.unitTest) // old single test per module
    {
        try
            test();
        catch (Throwable t)
            testFailed(t);
    }
    immutable t1 = TickDuration.currSystemTick;
    if (result)
        printf("%.3fs PASS %.*s\n", (t1 - t0).msecs / 1000.,
               cast(int)name.length, name.ptr);
    return result;
}

shared static this()
{
    Runtime.moduleUnitTester = &tester;
}

void main()
{
}
