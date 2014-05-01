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

    if(name.length > pkgLen && name[$ - pkgLen .. $] == pkg)
        name = name[0 .. $ - pkgLen];

    bool result = true;
    if (auto tests = getModuleInfo(name).unitTests)
    {
        immutable t0 = TickDuration.currSystemTick;

        foreach(test; tests)
        {
            if(test.disabled)
                continue;
            try
            {
                test.func();
            }
            catch (Throwable e)
            {
                auto msg = e.toString();
                printf("****** FAIL %.*s\n%.*s\n", cast(int)name.length, name.ptr,
                    cast(int)msg.length, msg.ptr);
                result = false;
            }
        }
        immutable t1 = TickDuration.currSystemTick;
        if (result)
        {
            printf("%.3fs PASS %.*s\n", (t1 - t0).msecs / 1000.,
                cast(int)name.length, name.ptr);
        }
    }
    return result;
}

shared static this()
{
    Runtime.moduleUnitTester = &tester;
}

void main()
{
}
