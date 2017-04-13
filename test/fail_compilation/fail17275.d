// https://issues.dlang.org/show_bug.cgi?id=17275

struct DSO
{
    inout(ModuleGroup) moduleGroup() { }
}

struct ThreadDSO
{
    DSO* _pdso;
    void[] _tlsRange;
}
