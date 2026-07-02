module rt.sections_wasm;

version (WebAssembly):

import rt.minfo;

struct SectionGroup
{
    static int opApply(scope int delegate(ref SectionGroup) dg)
    {
        return dg(_sections);
    }

    static int opApplyReverse(scope int delegate(ref SectionGroup) dg)
    {
        return dg(_sections);
    }

    @property immutable(ModuleInfo*)[] modules() const nothrow @nogc
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout return nothrow @nogc
    {
        return _moduleGroup;
    }

    @property inout(void[])[] gcRanges() inout return nothrow @nogc
    {
        return null;
    }

private:
    ModuleGroup _moduleGroup;
}

void initSections() nothrow @nogc
{
    auto mbeg = cast(immutable ModuleInfo**)&__start___minfo;
    auto mend = cast(immutable ModuleInfo**)&__stop___minfo;
    _sections.moduleGroup = ModuleGroup(mbeg[0 .. mend - mbeg]);
}

void finiSections() nothrow @nogc
{
}

void[] initTLSRanges() nothrow @nogc
{
    return null;
}

void finiTLSRanges(void[] rng) nothrow @nogc
{
}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    dg(rng.ptr, rng.ptr + rng.length);
}

private:

__gshared SectionGroup _sections;

extern(C)
{
    extern __gshared
    {
        void* __start___minfo;
        void* __stop___minfo;
    }
}
