import core.runtime;
import core.stdc.stdio;

ModuleInfo* getModuleInfo(string name)
{
    foreach (m; ModuleInfo)
        if (m.name == name) return m;
    assert(0, "module '"~name~"' not found");
}

bool tester()
{
    assert(Runtime.args().length == 2);
    auto name = Runtime.args()[1];

    auto m = getModuleInfo(name);
    if (auto fp = m.unitTest)
    {
        printf("Testing %.*s\n", cast(int)name.length, name.ptr);
        fp();
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
