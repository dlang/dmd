/**
 * Written in the D programming language.
 * Module initialization routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_minfo.d)
 */

module rt.minfo;

import core.stdc.stdlib;  // alloca
import core.stdc.string;  // memcpy
import rt.sections;

enum
{
    MIctorstart  = 0x1,   // we've started constructing it
    MIctordone   = 0x2,   // finished construction
    MIstandalone = 0x4,   // module ctor does not depend on other module
                        // ctors being done first
    MItlsctor    = 8,
    MItlsdtor    = 0x10,
    MIctor       = 0x20,
    MIdtor       = 0x40,
    MIxgetMembers = 0x80,
    MIictor      = 0x100,
    MIunitTest   = 0x200,
    MIimportedModules = 0x400,
    MIlocalClasses = 0x800,
    MIname       = 0x1000,
}

struct ModuleGroup
{
    this(ModuleInfo*[] modules)
    {
        _modules = modules;
    }

    @property inout(ModuleInfo*)[] modules() inout
    {
        return _modules;
    }

    void sortCtors()
    {
        // don't bother to initialize, as they are getting overwritten anyhow
        immutable n = _modules.length;
        _ctors = (cast(ModuleInfo**).malloc(n * size_t.sizeof))[0 .. n];
        _tlsctors = (cast(ModuleInfo**).malloc(n * size_t.sizeof))[0 .. n];
        .sortCtors(this);
    }

    void runCtors()
    {
        // run independent ctors
        runModuleFuncs!(m => m.ictor)(_modules);
        // sorted module ctors
        runModuleFuncs!(m => m.ctor)(_ctors);
        // flag all modules as initialized
        foreach (m; _modules)
            m.flags = m.flags | MIctordone;
    }

    void runTlsCtors()
    {
        runModuleFuncs!(m => m.tlsctor)(_tlsctors);
    }

    void runTlsDtors()
    {
        runModuleFuncsRev!(m => m.tlsdtor)(_tlsctors);
    }

    void runDtors()
    {
        runModuleFuncsRev!(m => m.dtor)(_ctors);
        // clean all initialized flags
        foreach (m; _modules)
            m.flags = m.flags & ~MIctordone;
    }

    void free()
    {
        .free(_ctors.ptr);
        _ctors = null;
        .free(_tlsctors.ptr);
        _tlsctors = null;
        // _modules = null; // let the owner free it
    }

private:
    ModuleInfo*[]  _modules;
    ModuleInfo*[]    _ctors;
    ModuleInfo*[] _tlsctors;
}


/********************************************
 * Iterate over all module infos.
 */

int moduleinfos_apply(scope int delegate(ref ModuleInfo*) dg)
{
    foreach (ref sg; SectionGroup)
    {
        foreach (m; sg.modules)
        {
            // TODO: Should null ModuleInfo be allowed?
            if (m !is null)
            {
                if (auto res = dg(m))
                    return res;
            }
        }
    }
    return 0;
}

/********************************************
 * Module constructor and destructor routines.
 */

extern (C)
{
void rt_moduleCtor()
{
    foreach (ref sg; SectionGroup)
    {
        sg.moduleGroup.sortCtors();
        sg.moduleGroup.runCtors();
    }
}

void rt_moduleTlsCtor()
{
    foreach (ref sg; SectionGroup)
    {
        sg.moduleGroup.runTlsCtors();
    }
}

void rt_moduleTlsDtor()
{
    foreach_reverse (ref sg; SectionGroup)
    {
        sg.moduleGroup.runTlsDtors();
    }
}

void rt_moduleDtor()
{
    foreach_reverse (ref sg; SectionGroup)
    {
        sg.moduleGroup.runDtors();
        sg.moduleGroup.free();
    }
}

version (Win32)
{
    // Alternate names for backwards compatibility with older DLL code
    void _moduleCtor()
    {
        rt_moduleCtor();
    }

    void _moduleDtor()
    {
        rt_moduleDtor();
    }

    void _moduleTlsCtor()
    {
        rt_moduleTlsCtor();
    }

    void _moduleTlsDtor()
    {
        rt_moduleTlsDtor();
    }
}
}

/********************************************
 */

void runModuleFuncs(alias getfp)(ModuleInfo*[] modules)
{
    foreach (m; modules)
    {
        if (auto fp = getfp(m))
            (*fp)();
    }
}

void runModuleFuncsRev(alias getfp)(ModuleInfo*[] modules)
{
    foreach_reverse (m; modules)
    {
        if (auto fp = getfp(m))
            (*fp)();
    }
}

/********************************************
 * Check for cycles on module constructors, and establish an order for module
 * constructors.
 */

void sortCtors(ref ModuleGroup mgroup)
in
{
    assert(mgroup._modules.length == mgroup._ctors.length);
    assert(mgroup._modules.length == mgroup._tlsctors.length);
}
body
{
    enum AllocaLimit = 100 * 1024; // 100KB

    immutable len = mgroup._modules.length;
    immutable size = len * StackRec.sizeof;

    if (!len)
    {
        return;
    }
    else if (size <= AllocaLimit)
    {
        auto p = cast(ubyte*).alloca(size);
        p[0 .. size] = 0;
        sortCtorsImpl(mgroup, (cast(StackRec*)p)[0 .. len]);
    }
    else
    {
        auto p = cast(ubyte*).malloc(size);
        p[0 .. size] = 0;
        sortCtorsImpl(mgroup, (cast(StackRec*)p)[0 .. len]);
        .free(p);
    }
}

private:

struct StackRec
{
    @property ModuleInfo* mod()
    {
        return _mods[_idx];
    }

    ModuleInfo*[] _mods;
    size_t         _idx;
}

void onCycleError(StackRec[] stack)
{
    string msg = "Aborting: Cycle detected between modules with ctors/dtors:\n";
    foreach (e; stack)
    {
        msg ~= e.mod.name;
        msg ~= " -> ";
    }
    msg ~= stack[0].mod.name;
    throw new Exception(msg);
}

private void sortCtorsImpl(ref ModuleGroup mgroup, StackRec[] stack)
{
    size_t stackidx;
    bool tlsPass;

 Lagain:

    const mask = tlsPass ? (MItlsctor | MItlsdtor) : (MIctor | MIdtor);
    auto ctors = tlsPass ? mgroup._tlsctors : mgroup._ctors;
    size_t cidx;

    ModuleInfo*[] mods = mgroup._modules;
    size_t idx;
    while (true)
    {
        while (idx < mods.length)
        {
            auto m = mods[idx];
            auto fl = m.flags;
            if (fl & MIctorstart)
            {
                // trace back to cycle start
                fl &= ~MIctorstart;
                size_t start = stackidx;
                while (start--)
                {
                    auto sm = stack[start].mod;
                    if (sm == m)
                        break;
                    fl |= sm.flags & MIctorstart;
                }
                assert(stack[start].mod == m);
                if (fl & MIctorstart)
                {
                    /* This is an illegal cycle, no partial order can be established
                     * because the import chain have contradicting ctor/dtor
                     * constraints.
                     */
                    onCycleError(stack[start .. stackidx]);
                }
                else
                {
                    /* This is also a cycle, but the import chain does not constrain
                     * the order of initialization, either because the imported
                     * modules have no ctors or the ctors are standalone.
                     */
                    ++idx;
                }
            }
            else if (fl & MIctordone)
            {   // already visited => skip
                ++idx;
            }
            else
            {
                if (fl & mask)
                {
                    if (fl & MIstandalone || !m.importedModules.length)
                    {   // trivial ctor => sort in
                        ctors[cidx++] = m;
                        m.flags = fl | MIctordone;
                    }
                    else
                    {   // non-trivial ctor => defer
                        m.flags = fl | MIctorstart;
                    }
                }
                else    // no ctor => mark as visited
                    m.flags = fl | MIctordone;

                if (m.importedModules.length)
                {
                    /* Internal runtime error, dependency on an uninitialized
                     * module outside of the current module group.
                     */
                    (stackidx < mgroup._modules.length) || assert(0);

                    // recurse
                    stack[stackidx++] = StackRec(mods, idx);
                    idx  = 0;
                    mods = m.importedModules;
                }
            }
        }

        if (stackidx)
        {   // pop old value from stack
            --stackidx;
            mods    = stack[stackidx]._mods;
            idx     = stack[stackidx]._idx;
            auto m  = mods[idx++];
            auto fl = m.flags;
            if (fl & mask && !(fl & MIctordone))
                ctors[cidx++] = m;
            m.flags = (fl & ~MIctorstart) | MIctordone;
        }
        else // done
            break;
    }
    // store final number
    tlsPass ? mgroup._tlsctors : mgroup._ctors = ctors[0 .. cidx];

    // clean flags
    foreach(m; mgroup._modules)
        m.flags = m.flags & ~(MIctorstart | MIctordone);

    // rerun for TLS constructors
    if (!tlsPass)
    {
        tlsPass = true;
        goto Lagain;
    }
}

unittest
{
    static void assertThrown(T : Throwable, E)(lazy E expr)
    {
        try
            expr;
        catch (T)
            return;
        assert(0);
    }

    static void stub()
    {
    }

    struct UTModuleInfo
    {
        ModuleInfo mi;
        size_t pad[8];
        alias mi this;
    }

    static UTModuleInfo mockMI(uint flags, ModuleInfo*[] imports...)
    {
        import core.bitop;
        size_t size = ModuleInfo.sizeof;
        size += popcnt(flags & (MItlsctor|MItlsdtor|MIctor|MIdtor|MIictor)) * (void function()).sizeof;
        if (imports.length)
            size += size_t.sizeof + imports.length * (ModuleInfo*).sizeof;
        assert(size <= UTModuleInfo.sizeof);

        UTModuleInfo mi;
        mi._flags = flags;
        auto p = cast(void function()*)&mi.pad;
        if (flags & MItlsctor) *p++ = &stub;
        if (flags & MItlsdtor) *p++ = &stub;
        if (flags & MIctor) *p++ = &stub;
        if (flags & MIdtor) *p++ = &stub;
        if (flags & MIictor) *p++ = &stub;
        if (imports.length)
        {
            mi._flags |= MIimportedModules;
            *cast(size_t*)p++ = imports.length;
            .memcpy(p, imports.ptr, imports.length * (ModuleInfo*).sizeof);
            p += imports.length;
        }
        assert(cast(void*)p <= &mi + 1);
        return mi;
    }

    UTModuleInfo m0, m1, m2;

    void checkExp(ModuleInfo*[] dtors=null, ModuleInfo*[] tlsdtors=null)
    {
        auto mgroup = ModuleGroup([&m0.mi, &m1.mi, &m2.mi]);
        mgroup.sortCtors();
        foreach (m; mgroup._modules)
            assert(!(m.flags & (MIctorstart | MIctordone)));
        assert(mgroup._ctors    == dtors);
        assert(mgroup._tlsctors == tlsdtors);
    }

    // no ctors
    m0 = mockMI(0);
    m1 = mockMI(0);
    m2 = mockMI(0);
    checkExp();

    // independent ctors
    m0 = mockMI(MIictor);
    m1 = mockMI(0);
    m2 = mockMI(MIictor);
    checkExp();

    // standalone ctor
    m0 = mockMI(MIstandalone | MIctor);
    m1 = mockMI(0);
    m2 = mockMI(0);
    checkExp([&m0.mi]);

    // imported standalone => no dependency
    m0 = mockMI(MIstandalone | MIctor);
    m1 = mockMI(MIstandalone | MIctor, &m0.mi);
    m2 = mockMI(0);
    checkExp([&m0.mi, &m1.mi]);

    m0 = mockMI(MIstandalone | MIctor, &m1.mi);
    m1 = mockMI(MIstandalone | MIctor);
    m2 = mockMI(0);
    checkExp([&m0.mi, &m1.mi]);

    // standalone may have cycle
    m0 = mockMI(MIstandalone | MIctor, &m1.mi);
    m1 = mockMI(MIstandalone | MIctor, &m0.mi);
    m2 = mockMI(0);
    checkExp([&m0.mi, &m1.mi]);

    // imported ctor => ordered ctors
    m0 = mockMI(MIctor);
    m1 = mockMI(MIctor, &m0.mi);
    m2 = mockMI(0);
    checkExp([&m0.mi, &m1.mi], []);

    m0 = mockMI(MIctor, &m1.mi);
    m1 = mockMI(MIctor);
    m2 = mockMI(0);
    assert(m0.importedModules == [&m1.mi]);
    checkExp([&m1.mi, &m0.mi], []);

    // detects ctors cycles
    m0 = mockMI(MIctor, &m1.mi);
    m1 = mockMI(MIctor, &m0.mi);
    m2 = mockMI(0);
    assertThrown!Throwable(checkExp());

    // imported ctor/tlsctor => ordered ctors/tlsctors
    m0 = mockMI(MIctor, &m1.mi, &m2.mi);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor);
    checkExp([&m1.mi, &m0.mi], [&m2.mi]);

    m0 = mockMI(MIctor | MItlsctor, &m1.mi, &m2.mi);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor);
    checkExp([&m1.mi, &m0.mi], [&m2.mi, &m0.mi]);

    // no cycle between ctors/tlsctors
    m0 = mockMI(MIctor, &m1.mi, &m2.mi);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor, &m0.mi);
    checkExp([&m1.mi, &m0.mi], [&m2.mi]);

    // detects tlsctors cycle
    m0 = mockMI(MItlsctor, &m2.mi);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor, &m0.mi);
    assertThrown!Throwable(checkExp());

    // closed ctors cycle
    m0 = mockMI(MIctor, &m1.mi);
    m1 = mockMI(MIstandalone | MIctor, &m2.mi);
    m2 = mockMI(MIstandalone | MIctor, &m0.mi);
    checkExp([&m1.mi, &m2.mi, &m0.mi], []);
}

version (Win64)
{
    // Dummy so Win32 code can still call it
    extern(C) void _minit() { }
}
