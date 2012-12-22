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

enum
{
    MIctorstart  = 1,   // we've started constructing it
    MIctordone   = 2,   // finished construction
    MIstandalone = 4,   // module ctor does not depend on other module
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
    MInew        = 0x80000000        // it's the "new" layout
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

        free();
    }

    void free()
    {
        .free(_ctors.ptr);
        _ctors = null;
        .free(_tlsctors.ptr);
        _tlsctors = null;
        _modules = null;
    }

private:
    ModuleInfo*[]  _modules;
    ModuleInfo*[]    _ctors;
    ModuleInfo*[] _tlsctors;
}

__gshared ModuleGroup _moduleGroup;

/********************************************
 * Iterate over all module infos.
 */

int moduleinfos_apply(scope int delegate(ref ModuleInfo*) dg)
{
    int ret = 0;

    foreach (m; _moduleGroup._modules)
    {
        // TODO: Should null ModuleInfo be allowed?
        if (m !is null)
        {
            ret = dg(m);
            if (ret)
                break;
        }
    }
    return ret;
}

/********************************************
 * Module constructor and destructor routines.
 */

extern (C) void rt_moduleCtor()
{
    _moduleGroup = ModuleGroup(getModuleInfos());
    _moduleGroup.sortCtors();
    _moduleGroup.runCtors();
}

extern (C) void rt_moduleTlsCtor()
{
    _moduleGroup.runTlsCtors();
}

extern (C) void rt_moduleTlsDtor()
{
    _moduleGroup.runTlsDtors();
}

extern (C) void rt_moduleDtor()
{
    _moduleGroup.runDtors();
    version (Posix)
        .free(_moduleGroup._modules.ptr);
    _moduleGroup.free();
}

/********************************************
 * Access compiler generated list of modules.
 */

version (Win32)
{
    // Windows: this gets initialized by minit.asm
    // Posix: this gets initialized in _moduleCtor()
    extern(C) __gshared ModuleInfo*[] _moduleinfo_array;
    extern(C) void _minit();
}
else version (Win64)
{
    extern (C)
    {
        extern __gshared void* _minfo_beg;
        extern __gshared void* _minfo_end;

        // Dummy so Win32 code can still call it
        extern(C) void _minit() { }
    }
}
else version (OSX)
{
    extern (C) __gshared ModuleInfo*[] _moduleinfo_array;
}
else version (Posix)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
        ModuleReference* next;
        ModuleInfo*      mod;
    }

    extern (C) __gshared ModuleReference* _Dmodule_ref;   // start of linked list
}
else
{
    static assert(0);
}

ModuleInfo*[] getModuleInfos()
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    typeof(return) result = void;

    version (OSX)
    {
        // _moduleinfo_array is set by src.rt.memory_osx.onAddImage()
        // but we need to throw out any null pointers
        auto p = _moduleinfo_array.ptr;
        auto pend = _moduleinfo_array.ptr + _moduleinfo_array.length;

        // count non-null pointers
        size_t cnt;
        for (; p < pend; ++p)
            if (*p !is null) ++cnt;

        result = (cast(ModuleInfo**).malloc(cnt * size_t.sizeof))[0 .. cnt];

        p = _moduleinfo_array.ptr;
        cnt = 0;
        for (; p < pend; ++p)
            if (*p !is null) result[cnt++] = *p;
    }
    // all other Posix variants (FreeBSD, Solaris, Linux)
    else version (Posix)
    {
        size_t len;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        result = (cast(ModuleInfo**).malloc(len * size_t.sizeof))[0 .. len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   result[len] = mr.mod;
            len++;
        }
    }
    else version (Win32)
    {
        // _minit directly alters the global _moduleinfo_array
        _minit();
        result = _moduleinfo_array;
    }
    else version (Win64)
    {
        auto m = (cast(ModuleInfo**)&_minfo_beg)[1 .. &_minfo_end - &_minfo_beg];
        /* Because of alignment inserted by the linker, various null pointers
         * are there. We need to filter them out.
         */
        auto p = m.ptr;
        auto pend = m.ptr + m.length;

        // count non-null pointers
        size_t cnt;
        for (; p < pend; ++p)
        {
            if (*p !is null) ++cnt;
        }

        result = (cast(ModuleInfo**).malloc(cnt * size_t.sizeof))[0 .. cnt];

        p = m.ptr;
        cnt = 0;
        for (; p < pend; ++p)
            if (*p !is null) result[cnt++] = *p;
    }
    else
    {
        static assert(0);
    }
    return result;
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

    static ModuleInfo mockMI(uint flags, ModuleInfo*[] imports...)
    {
        ModuleInfo mi;
        mi.n.flags |= flags | MInew;
        size_t fcnt;
        auto p = cast(ubyte*)&mi + ModuleInfo.New.sizeof;
        foreach (fl; [MItlsctor, MItlsdtor, MIctor, MIdtor, MIictor])
        {
            if (flags & fl)
            {
                *cast(void function()*)p = &stub;
                p += (&stub).sizeof;
            }
        }
        if (imports.length)
        {
            mi.n.flags |= MIimportedModules;
            *cast(size_t*)p = imports.length;
            p += size_t.sizeof;
            immutable nb = imports.length * (ModuleInfo*).sizeof;
            .memcpy(p, imports.ptr, nb);
            p += nb;
        }
        assert(p - cast(ubyte*)&mi <= ModuleInfo.sizeof);
        return mi;
    }

    ModuleInfo m0, m1, m2;

    void checkExp(ModuleInfo*[] dtors=null, ModuleInfo*[] tlsdtors=null)
    {
        auto mgroup = ModuleGroup([&m0, &m1, &m2]);
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
    checkExp([&m0]);

    // imported standalone => no dependency
    m0 = mockMI(MIstandalone | MIctor);
    m1 = mockMI(MIstandalone | MIctor, &m0);
    m2 = mockMI(0);
    checkExp([&m0, &m1]);

    m0 = mockMI(MIstandalone | MIctor, &m1);
    m1 = mockMI(MIstandalone | MIctor);
    m2 = mockMI(0);
    checkExp([&m0, &m1]);

    // standalone may have cycle
    m0 = mockMI(MIstandalone | MIctor, &m1);
    m1 = mockMI(MIstandalone | MIctor, &m0);
    m2 = mockMI(0);
    checkExp([&m0, &m1]);

    // imported ctor => ordered ctors
    m0 = mockMI(MIctor);
    m1 = mockMI(MIctor, &m0);
    m2 = mockMI(0);
    checkExp([&m0, &m1], []);

    m0 = mockMI(MIctor, &m1);
    m1 = mockMI(MIctor);
    m2 = mockMI(0);
    checkExp([&m1, &m0], []);

    // detects ctors cycles
    m0 = mockMI(MIctor, &m1);
    m1 = mockMI(MIctor, &m0);
    m2 = mockMI(0);
    assertThrown!Throwable(checkExp());

    // imported ctor/tlsctor => ordered ctors/tlsctors
    m0 = mockMI(MIctor, &m1, &m2);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor);
    checkExp([&m1, &m0], [&m2]);

    m0 = mockMI(MIctor | MItlsctor, &m1, &m2);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor);
    checkExp([&m1, &m0], [&m2, &m0]);

    // no cycle between ctors/tlsctors
    m0 = mockMI(MIctor, &m1, &m2);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor, &m0);
    checkExp([&m1, &m0], [&m2]);

    // detects tlsctors cycle
    m0 = mockMI(MItlsctor, &m2);
    m1 = mockMI(MIctor);
    m2 = mockMI(MItlsctor, &m0);
    assertThrown!Throwable(checkExp());

    // closed ctors cycle
    m0 = mockMI(MIctor, &m1);
    m1 = mockMI(MIstandalone | MIctor, &m2);
    m2 = mockMI(MIstandalone | MIctor, &m0);
    checkExp([&m1, &m2, &m0], []);
}
