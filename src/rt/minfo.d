/**
 * Written in the D programming language.
 * Module initialization routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2013.
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

/*****
 * A ModuleGroup is an unordered collection of modules.
 * There is exactly one for:
 *  1. all statically linked in D modules, either directely or as shared libraries
 *  2. each call to rt_loadLibrary()
 */

struct ModuleGroup
{
    this(immutable(ModuleInfo*)[] modules)
    {
        _modules = modules;
    }

    @property immutable(ModuleInfo*)[] modules() const
    {
        return _modules;
    }

    /******************************
     * Allocate and fill in _ctors[] and _tlsctors[].
     * Modules are inserted into the arrays in the order in which the constructors
     * need to be run.
     * Throws:
     *  Exception if it fails.
     */
    void sortCtors()
    {
        immutable len = _modules.length;
        if (!len)
            return;

        static struct StackRec
        {
            @property immutable(ModuleInfo)* mod()
            {
                return _mods[_idx];
            }

            immutable(ModuleInfo*)[] _mods;
            size_t         _idx;
        }

        auto stack = (cast(StackRec*).calloc(len, StackRec.sizeof))[0 .. len];
        // TODO: reuse GCBits by moving it to rt.util.container or core.internal
        immutable nwords = (len + 8 * size_t.sizeof - 1) / (8 * size_t.sizeof);
        auto ctorstart = cast(size_t*).malloc(nwords * size_t.sizeof);
        auto ctordone = cast(size_t*).malloc(nwords * size_t.sizeof);
        if (!stack.ptr || ctorstart is null || ctordone is null)
            assert(0);
        scope (exit) { .free(stack.ptr); .free(ctorstart); .free(ctordone); }

        int findModule(in ModuleInfo* mi)
        {
            foreach (i, m; _modules)
                if (m is mi) return cast(int)i;
            return -1;
        }

        void sort(ref immutable(ModuleInfo)*[] ctors, uint mask)
        {
            import core.bitop;

            ctors = (cast(immutable(ModuleInfo)**).malloc(len * size_t.sizeof))[0 .. len];
            if (!ctors.ptr)
                assert(0);

            // clean flags
            memset(ctorstart, 0, nwords * size_t.sizeof);
            memset(ctordone, 0, nwords * size_t.sizeof);
            size_t stackidx = 0;
            size_t cidx;

            immutable(ModuleInfo*)[] mods = _modules;
            size_t idx;
            while (true)
            {
                while (idx < mods.length)
                {
                    auto m = mods[idx];

                    immutable bitnum = findModule(m);

                    if (bitnum < 0 || bt(ctordone, bitnum))
                    {
                        /* If the module can't be found among the ones to be
                         * sorted it's an imported module from another DSO.
                         * Those don't need to be considered during sorting as
                         * the OS is responsible for the DSO load order and
                         * module construction is done during DSO loading.
                         */
                        ++idx;
                        continue;
                    }
                    else if (bt(ctorstart, bitnum))
                    {
                        /* Trace back to the begin of the cycle.
                         */
                        bool ctorInCycle;
                        size_t start = stackidx;
                        while (start--)
                        {
                            auto sm = stack[start].mod;
                            if (sm == m)
                                break;
                            immutable sbitnum = findModule(sm);
                            assert(sbitnum >= 0);
                            if (bt(ctorstart, sbitnum))
                                ctorInCycle = true;
                        }
                        assert(stack[start].mod == m);
                        if (ctorInCycle)
                        {
                            /* This is an illegal cycle, no partial order can be established
                             * because the import chain have contradicting ctor/dtor
                             * constraints.
                             */
                            string msg = "Aborting: Cycle detected between modules with ";
                            if (mask & (MIctor | MIdtor))
                                msg ~= "shared ";
                            msg ~= "ctors/dtors:\n";
                            foreach (e; stack[start .. stackidx])
                            {
                                msg ~= e.mod.name;
                                if (e.mod.flags & mask)
                                    msg ~= '*';
                                msg ~= " ->\n";
                            }
                            msg ~= stack[start].mod.name;
                            free();
                            throw new Exception(msg);
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
                    else
                    {
                        if (m.flags & mask)
                        {
                            if (m.flags & MIstandalone || !m.importedModules.length)
                            {   // trivial ctor => sort in
                                ctors[cidx++] = m;
                                bts(ctordone, bitnum);
                            }
                            else
                            {   // non-trivial ctor => defer
                                bts(ctorstart, bitnum);
                            }
                        }
                        else    // no ctor => mark as visited
                        {
                            bts(ctordone, bitnum);
                        }

                        if (m.importedModules.length)
                        {
                            /* Internal runtime error, recursion exceeds number of modules.
                             */
                            (stackidx < _modules.length) || assert(0);

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
                    immutable bitnum = findModule(m);
                    assert(bitnum >= 0);
                    if (m.flags & mask && !bts(ctordone, bitnum))
                        ctors[cidx++] = m;
                }
                else // done
                    break;
            }
            // store final number and shrink array
            ctors = (cast(immutable(ModuleInfo)**).realloc(ctors.ptr, cidx * size_t.sizeof))[0 .. cidx];
        }

        /* Do two passes: ctor/dtor, tlsctor/tlsdtor
         */
        sort(_ctors, MIctor | MIdtor);
        sort(_tlsctors, MItlsctor | MItlsdtor);
    }

    void runCtors()
    {
        // run independent ctors
        runModuleFuncs!(m => m.ictor)(_modules);
        // sorted module ctors
        runModuleFuncs!(m => m.ctor)(_ctors);
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
    }

    void free()
    {
        if (_ctors.ptr)
            .free(_ctors.ptr);
        _ctors = null;
        if (_tlsctors.ptr)
            .free(_tlsctors.ptr);
        _tlsctors = null;
        // _modules = null; // let the owner free it
    }

private:
    immutable(ModuleInfo*)[]  _modules;
    immutable(ModuleInfo)*[]    _ctors;
    immutable(ModuleInfo)*[] _tlsctors;
}


/********************************************
 * Iterate over all module infos.
 */

int moduleinfos_apply(scope int delegate(immutable(ModuleInfo*)) dg)
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

void runModuleFuncs(alias getfp)(const(immutable(ModuleInfo)*)[] modules)
{
    foreach (m; modules)
    {
        if (auto fp = getfp(m))
            (*fp)();
    }
}

void runModuleFuncsRev(alias getfp)(const(immutable(ModuleInfo)*)[] modules)
{
    foreach_reverse (m; modules)
    {
        if (auto fp = getfp(m))
            (*fp)();
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

    static struct UTModuleInfo
    {
        this(uint flags)
        {
            mi._flags = flags;
        }

        void setImports(immutable(ModuleInfo)*[] imports...)
        {
            import core.bitop;
            assert(flags & MIimportedModules);

            immutable nfuncs = popcnt(flags & (MItlsctor|MItlsdtor|MIctor|MIdtor|MIictor));
            immutable size = nfuncs * (void function()).sizeof +
                size_t.sizeof + imports.length * (ModuleInfo*).sizeof;
            assert(size <= pad.sizeof);

            pad[nfuncs] = imports.length;
            .memcpy(&pad[nfuncs+1], imports.ptr, imports.length * imports[0].sizeof);
        }

        immutable ModuleInfo mi;
        size_t[8] pad;
        alias mi this;
    }

    static UTModuleInfo mockMI(uint flags)
    {
        auto mi = UTModuleInfo(flags | MIimportedModules);
        auto p = cast(void function()*)&mi.pad;
        if (flags & MItlsctor) *p++ = &stub;
        if (flags & MItlsdtor) *p++ = &stub;
        if (flags & MIctor) *p++ = &stub;
        if (flags & MIdtor) *p++ = &stub;
        if (flags & MIictor) *p++ = &stub;
        *cast(size_t*)p++ = 0; // number of imported modules
        assert(cast(void*)p <= &mi + 1);
        return mi;
    }

    static void checkExp(
        immutable(ModuleInfo*)[] modules,
        immutable(ModuleInfo*)[] dtors=null,
        immutable(ModuleInfo*)[] tlsdtors=null)
    {
        auto mgroup = ModuleGroup(modules);
        mgroup.sortCtors();
        foreach (m; mgroup._modules)
            assert(!(m.flags & (MIctorstart | MIctordone)));
        assert(mgroup._ctors    == dtors);
        assert(mgroup._tlsctors == tlsdtors);
    }

    // no ctors
    {
        auto m0 = mockMI(0);
        auto m1 = mockMI(0);
        auto m2 = mockMI(0);
        checkExp([&m0.mi, &m1.mi, &m2.mi]);
    }

    // independent ctors
    {
        auto m0 = mockMI(MIictor);
        auto m1 = mockMI(0);
        auto m2 = mockMI(MIictor);
        auto mgroup = ModuleGroup([&m0.mi, &m1.mi, &m2.mi]);
        checkExp([&m0.mi, &m1.mi, &m2.mi]);
    }

    // standalone ctor
    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(0);
        auto m2 = mockMI(0);
        auto mgroup = ModuleGroup([&m0.mi, &m1.mi, &m2.mi]);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m0.mi]);
    }

    // imported standalone => no dependency
    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(0);
        m1.setImports(&m0.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi]);
    }

    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi]);
    }

    // standalone may have cycle
    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        m1.setImports(&m0.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi]);
    }

    // imported ctor => ordered ctors
    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m1.setImports(&m0.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi], []);
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        assert(m0.importedModules == [&m1.mi]);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], []);
    }

    // detects ctors cycles
    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        m1.setImports(&m0.mi);
        assertThrown!Throwable(checkExp([&m0.mi, &m1.mi, &m2.mi]));
    }

    // imported ctor/tlsctor => ordered ctors/tlsctors
    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi, &m2.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], [&m2.mi]);
    }

    {
        auto m0 = mockMI(MIctor | MItlsctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi, &m2.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], [&m2.mi, &m0.mi]);
    }

    // no cycle between ctors/tlsctors
    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi, &m2.mi);
        m2.setImports(&m0.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], [&m2.mi]);
    }

    // detects tlsctors cycle
    {
        auto m0 = mockMI(MItlsctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m2.mi);
        m2.setImports(&m0.mi);
        assertThrown!Throwable(checkExp([&m0.mi, &m1.mi, &m2.mi]));
    }

    // closed ctors cycle
    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(MIstandalone | MIctor);
        m0.setImports(&m1.mi);
        m1.setImports(&m2.mi);
        m2.setImports(&m0.mi);
        checkExp([&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m2.mi, &m0.mi]);
    }
}

version (CRuntime_Microsoft)
{
    // Dummy so Win32 code can still call it
    extern(C) void _minit() { }
}
