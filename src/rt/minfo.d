/**
 * Written in the D programming language.
 * Module initialization routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE_1_0.txt)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_minfo.d)
 */

module rt.minfo;

import core.stdc.stdio;   // printf
import core.stdc.stdlib;  // alloca
import core.stdc.string;  // memcpy
import rt.util.console;   // console

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

// Windows: this gets initialized by minit.asm
// Posix: this gets initialized in rt_moduleCtor()
extern (C) __gshared ModuleInfo*[] _moduleinfo_array;
extern(C) void _minit();

struct SortedCtors
{
    void alloc(size_t n)
    {
        // don't bother to initialize, as they are getting overwritten anyhow
        _ctors = (cast(ModuleInfo**).malloc(n * size_t.sizeof))[0 .. n];
        _tlsctors = (cast(ModuleInfo**).malloc(n * size_t.sizeof))[0 .. n];
    }

    void free()
    {
        .free(_ctors.ptr);
        _ctors = null;
        .free(_tlsctors.ptr);
        _tlsctors = null;
    }

    ModuleInfo*[] _ctors;
    ModuleInfo*[] _tlsctors;
}

__gshared SortedCtors _sortedCtors;

/********************************************
 * Iterate over all module infos.
 */

int moduleinfos_apply(scope int delegate(ref ModuleInfo*) dg)
{
    int ret = 0;

    foreach (m; _moduleinfo_array)
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
    _moduleinfo_array = getModuleInfos();
    _sortedCtors = sortCtors(_moduleinfo_array);

    // run independent ctors
    runModuleFuncs!((a) { return a.ictor; })(_moduleinfo_array);
    // sorted module ctors
    runModuleFuncs!((a) { return a.ctor; })(_sortedCtors._ctors);
    // flag all modules as initialized
    foreach (m; _moduleinfo_array)
        m.flags = m.flags | MIctordone;
}

extern (C) void rt_moduleTlsCtor()
{
    runModuleFuncs!((a) { return a.tlsctor; })(_sortedCtors._tlsctors);
}

extern (C) void rt_moduleTlsDtor()
{
    runModuleFuncsRev!((a) { return a.tlsdtor; })(_sortedCtors._tlsctors);
}

extern (C) void rt_moduleDtor()
{
    runModuleFuncsRev!((a) { return a.dtor; })(_sortedCtors._ctors);

    // clean all initialized flags
    foreach (m; _moduleinfo_array)
        m.flags = m.flags & ~MIctordone;

    _sortedCtors.free();
    version (Posix)
        .free(_moduleinfo_array.ptr);
    _moduleinfo_array = null;
}

/********************************************
 * Access compiler generated list of modules.
 */

version (none)
{
    extern (C)
    {
        extern __gshared void* _minfo_beg;
        extern __gshared void* _minfo_end;
    }
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
        // set by src.rt.memory_osx.onAddImage()
        result = _moduleinfo_array;

        // But we need to throw out any null pointers
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
    else version (none)
    {
        //printf("getModuleInfos()\n");
        /* The ModuleInfo references are stored in the special segment
         * __minfodata, which is bracketed by the segments __minfo_beg
         * and __minfo_end. The variables _minfo_beg and _minfo_end
         * are of zero size and are in the two bracketing segments,
         * respectively.
         */

        auto p = cast(ModuleInfo**)&_minfo_beg;
        auto pend = cast(ModuleInfo**)&_minfo_end;

        // Throw out null pointers
        size_t cnt;
        for (; p < pend; ++p)
            if (*p !is null) ++cnt;

        result = (cast(ModuleInfo**).malloc(cnt * size_t.sizeof))[0 .. cnt];

        p = cast(ModuleInfo**)&_minfo_beg;
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
    else version (Windows)
    {
        // _minit directly alters the global _moduleinfo_array
        _minit();
        result = _moduleinfo_array;
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

SortedCtors sortCtors(ModuleInfo*[] modules)
{
    enum AllocaLimit = 100 * 1024; // 100KB

    immutable size = modules.length * StackRec.sizeof;

    if (!size)
    {
        return SortedCtors.init;
    }
    else if (size <= AllocaLimit)
    {
        auto p = cast(ubyte*).alloca(size);
        p[0 .. size] = 0;
        return sortCtorsImpl(modules, (cast(StackRec*)p)[0 .. modules.length]);
    }
    else
    {
        auto p = cast(ubyte*).malloc(size);
        p[0 .. size] = 0;
        auto result = sortCtorsImpl(modules, (cast(StackRec*)p)[0 .. modules.length]);
        .free(p);
        return result;
    }
}

private:

void print(string m)
{
    // write message to stderr
    console(m);
}

void println(string m)
{
    print(m);
    version (Windows)
        print("\r\n");
    else
        print("\n");
}

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
    version (unittest)
    {
        if (_inUnitTest)
            goto Lerror;
    }

    println("Cycle detected between modules with ctors/dtors:");
    foreach (e; stack)
    {
        print(e.mod.name);
        print(" -> ");
    }
    println(stack[0].mod.name);
 Lerror:
    throw new Exception("Aborting!");
}

private SortedCtors sortCtorsImpl(ModuleInfo*[] modules, StackRec[] stack)
{
    SortedCtors result;
    result.alloc(modules.length);

    size_t stackidx;
    bool tlsPass;

 Lagain:

    const mask = tlsPass ? (MItlsctor | MItlsdtor) : (MIctor | MIdtor);
    auto ctors = tlsPass ? result._tlsctors : result._ctors;
    size_t cidx;

    ModuleInfo*[] mods = modules;
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
                    (stackidx < modules.length) || assert(0);

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
    tlsPass ? result._tlsctors : result._ctors = ctors[0 .. cidx];

    // clean flags
    for (size_t i = 0; i < modules.length; ++i)
    {   auto m = modules[i];
        m.flags = m.flags & ~(MIctorstart | MIctordone);
    }

    // rerun for TLS constructors
    if (!tlsPass)
    {
        tlsPass = true;
        goto Lagain;
    }

    return result;
}

version (unittest)
  bool _inUnitTest;

unittest
{
    _inUnitTest = true;
    scope (exit) _inUnitTest = false;

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
        auto ptrs = [&m0, &m1, &m2];
        auto sorted = sortCtors(ptrs);
        foreach (m; ptrs)
            assert(!(m.flags & (MIctorstart | MIctordone)));
        assert(sorted._ctors    == dtors);
        assert(sorted._tlsctors == tlsdtors);
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
