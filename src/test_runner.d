import core.runtime, core.time : TickDuration;
import core.stdc.stdio;

ModuleInfo* getModuleInfo(string name)
{
    foreach (m; ModuleInfo)
        if (m.name == name) return m;
    assert(0, "module '"~name~"' not found");
}

bool tester()
{
    assert(Runtime.args.length == 2);
    auto name = Runtime.args[1];

    if (auto fp = getModuleInfo(name).unitTest)
    {
        printf("Testing %.*s", cast(int)name.length, name.ptr);

        try
        {
            immutable t0 = TickDuration.currSystemTick;
            fp();
            immutable t1 = TickDuration.currSystemTick;
            printf(" OK (took %dms)\n", (t1 - t0).msecs);
        }
        catch (Throwable e)
        {
            auto msg = e.toString();
            printf(" FAIL\n%.*s", cast(int)msg.length, msg.ptr);
            return false;
        }
    }
    return true;
}

shared static this()
{
    Runtime.moduleUnitTester = &tester;
}

void main()
{
}
