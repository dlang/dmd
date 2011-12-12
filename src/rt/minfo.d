/**
 * Module initialization routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.minfo;

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
// Posix: this gets initialized in _moduleCtor()
extern (C) __gshared ModuleInfo*[] _moduleinfo_array;

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

version (linux)
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

version (FreeBSD)
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

version (Solaris)
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

version (OSX)
{
    extern (C)
    {
        extern __gshared void* _minfo_beg;
        extern __gshared void* _minfo_end;
    }
}

struct SortedCtors
{
    ModuleInfo*[] _ctors;
    ModuleInfo*[] _tlsctors;
}

__gshared SortedCtors _sortedCtors;

/**
 * Initialize the modules.
 */

extern (C) void _moduleCtor()
{
    debug(PRINTF) printf("_moduleCtor()\n");

    version (OSX)
    {
        /* The ModuleInfo references are stored in the special segment
         * __minfodata, which is bracketed by the segments __minfo_beg
         * and __minfo_end. The variables _minfo_beg and _minfo_end
         * are of zero size and are in the two bracketing segments,
         * respectively.
         */
         size_t length = cast(ModuleInfo**)&_minfo_end - cast(ModuleInfo**)&_minfo_beg;
         _moduleinfo_array = (cast(ModuleInfo**)&_minfo_beg)[0 .. length];
         debug printf("moduleinfo: ptr = %p, length = %d\n", _moduleinfo_array.ptr, _moduleinfo_array.length);

         debug foreach (m; _moduleinfo_array)
         {
             // TODO: Should null ModuleInfo be allowed?
             if (m !is null)
                //printf("\t%p\n", m);
                printf("\t%.*s\n", m.name);
         }
    }
    // all other Posix variants (FreeBSD, Solaris, Linux)
    else version (Posix)
    {
        int len = 0;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        _moduleinfo_array = new ModuleInfo*[len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   _moduleinfo_array[len] = mr.mod;
            len++;
        }
    }
    else version (Windows)
    {
        // Ensure module destructors also get called on program termination
        //_fatexit(&_STD_moduleDtor);
    }

    //_moduleinfo_dtors = new ModuleInfo*[_moduleinfo_array.length];
    //debug(PRINTF) printf("_moduleinfo_dtors = x%x\n", cast(void*)_moduleinfo_dtors);
    // this will determine the constructor/destructor order, and check for
    // cycles for both shared and TLS ctors
    _sortedCtors = _checkModCtors(_moduleinfo_array);

    _moduleIndependentCtors(_moduleinfo_array);
    // now, call the module constructors in the designated order
    foreach (m; _sortedCtors._ctors)
    {
        if(m.ctor)
            (*m.ctor)();
    }

    //_moduleCtor2(_moduleinfo_array, 0);
    // NOTE: _moduleTlsCtor is now called manually by dmain2
    //_moduleTlsCtor();
}

void _moduleIndependentCtors(ModuleInfo*[] modules)
{
    debug(PRINTF) printf("_moduleIndependentCtors()\n");
    foreach (m; modules)
    {
        // TODO: Should null ModuleInfo be allowed?
        if (m && m.ictor)
        {
            (*m.ictor)();
        }
    }
}

/********************************************
 * Check for cycles on module constructors, and establish an order for module
 * constructors.
 */
SortedCtors _checkModCtors(ModuleInfo*[] modules)
{
    SortedCtors result;
    // Create an array of modules that will determine the order of construction
    // (and destruction in reverse).
    auto ctors = result._ctors = new ModuleInfo*[modules.length];
    size_t ctoridx = 0;

    // this pointer will identify the module where the cycle was detected.
    ModuleInfo *cycleModule;

    // allocate some stack arrays that will be used throughout the process.
    ubyte* p = cast(ubyte *)alloca(modules.length * ubyte.sizeof);
    auto reachable = p[0..modules.length];

    p = cast(ubyte *)alloca(modules.length * ubyte.sizeof);
    auto flags = p[0..modules.length];


    // find all the non-trivial dependencies (that is, dependencies that have a
    // ctor or dtor) of a given module.  Doing this, we can 'skip over' the
    // trivial modules to get at the non-trivial ones.
    size_t _findDependencies(ModuleInfo *current, bool orig = true)
    {
        auto idx = current.index;
        if(reachable[idx])
            return 0;
        size_t result = 0;
        reachable[idx] = 1;
        if(!orig && (flags[idx] & (MIctor | MIdtor)) && !(flags[idx] & MIstandalone))
            // non-trivial, stop here
            return result + 1;
        foreach (ModuleInfo *m; current.importedModules)
        {
            result += _findDependencies(m, false);
        }
        return result;
    }

    void print(string msgs[]...)
    {
        version (unittest)
        {
            if (_inUnitTest)
                return;
        }

        foreach (m; msgs)
        {
            // write message to stderr
            console(m);
        }
    }

    void println(string msgs[]...)
    {
        print(msgs);
        version(Windows)
            print("\r\n");
        else
            print("\n");
    }

    bool printCycle(ModuleInfo *current, ModuleInfo *target, bool orig = true)
    {
        if(reachable[current.index])
            // already visited
            return false;
        if(current is target)
            // found path
            return true;
        reachable[current.index] = 1;
        if(!orig && (flags[current.index] & (MIctor | MIdtor)) && !(flags[current.index] & MIstandalone))
            // don't go through modules with ctors/dtors that aren't
            // standalone.
            return false;
        // search connections from current to see if we can get to target
        foreach (m; current.importedModules)
        {
            if(printCycle(m, target, false))
            {
                // found the path, print this module
                if(orig)
                    println("imported from ", current.name, " containing module ctor/dtor");
                else
                    println("   imported from (", current.name, ")");
                return true;
            }
        }
        return false;
    }

    // This function will determine the order of construction/destruction and
    // check for cycles.
    bool _checkModCtors2(ModuleInfo *current)
    {
        // we only get called if current has a dtor or a ctor, so no need to
        // check that.  First, determine what non-trivial elements are
        // reachable.
        reachable[] = 0;
        auto nmodules = _findDependencies(current);

        // allocate the dependencies on the stack
        ModuleInfo **p = cast(ModuleInfo **)alloca(nmodules * (ModuleInfo*).sizeof);
        auto dependencies = p[0..nmodules];
        uint depidx = 0;
        // fill in the dependencies
        foreach (i, r; reachable)
        {
            if(r)
            {
                ModuleInfo *m = modules[i];
                if(m !is current && (flags[i] & (MIctor | MIdtor)) && !(flags[i] & MIstandalone))
                {
                    dependencies[depidx++] = m;
                }
            }
        }
        assert(depidx == nmodules);

        // ok, now perform cycle detection
        auto curidx = current.index;
        flags[curidx] |= MIctorstart;
        bool valid = true;
        foreach (m; dependencies)
        {
            auto mflags = flags[m.index];
            if(mflags & MIctorstart)
            {
                // found a cycle, but we don't care if the MIstandalone flag is
                // set, this is a guarantee that there are no cycles in this
                // module (not sure what triggers it)
                println("Cyclic dependency in module ", m.name);
                cycleModule = m;
                valid = false;

                // use the currently allocated dtor path to record the loop
                // that contains module ctors/dtors only.
                ctoridx = ctors.length;
            }
            else if(!(mflags & MIctordone))
            {
                valid = _checkModCtors2(m);
            }


            if(!valid)
            {
                // cycle detected, now, we must print in reverse order the
                // module include cycle.  For this, we need to traverse the
                // graph of trivial modules again, this time printing them.
                reachable[] = 0;
                printCycle(current, m);

                // record this as a module that was used in the loop.
                ctors[--ctoridx] = current;
                if(current is cycleModule)
                {
                    // print the cycle
                    println("Cycle detected between modules with ctors/dtors:");
                    foreach (cm; ctors[ctoridx..$])
                    {
                        print(cm.name, " -> ");
                    }
                    println(cycleModule.name);
                    throw new Exception("Aborting!");
                }
                return false;
            }
        }
        flags[curidx] = (flags[curidx] & ~MIctorstart) | MIctordone;
        // add this module to the construction order list
        ctors[ctoridx++] = current;
        return true;
    }

    void _checkModCtors3()
    {
        foreach (m; modules)
        {
            // TODO: Should null ModuleInfo be allowed?
            if (m is null) continue;
            auto flag = flags[m.index];
            if((flag & (MIctor | MIdtor)) && !(flag & MIctordone))
            {
                if(flag & MIstandalone)
                {
                    // no need to run a check on this one, but we do need to call its ctor/dtor
                    ctors[ctoridx++] = m;
                }
                else
                    _checkModCtors2(m);
            }
        }
    }

    // ok, now we need to assign indexes, and also initialize the flags
    foreach (uint i, m; modules)
    {
        // TODO: Should null ModuleInfo be allowed?
        if (m is null) continue;
        m.index = i;
        ubyte flag = m.flags & MIstandalone;
        if(m.dtor)
            flag |= MIdtor;
        if(m.ctor)
            flag |= MIctor;
        flags[i] = flag;
    }

    // everything's all set up for shared ctors
    _checkModCtors3();

    // store the number of dtors/ctors
    result._ctors = result._ctors[0 .. ctoridx];

    // set up everything for tls ctors
    ctors = result._tlsctors = new ModuleInfo*[modules.length];
    ctoridx = 0;
    foreach (i, m; modules)
    {
        // TODO: Should null ModuleInfo be allowed?
        if (m is null) continue;
        ubyte flag = m.flags & MIstandalone;
        if(m.tlsdtor)
            flag |= MIdtor;
        if(m.tlsctor)
            flag |= MIctor;
        flags[i] = flag;
    }

    // ok, run it
    _checkModCtors3();

    // store the number of dtors/ctors
    result._tlsctors = result._tlsctors[0 .. ctoridx];

    return result;
}

/********************************************
 * Run static constructors for thread local global data.
 */

extern (C) void _moduleTlsCtor()
{
    // call the module constructors in the correct order as determined by the
    // check routine.
    foreach (m; _sortedCtors._tlsctors)
    {
        if(m.tlsctor)
            (*m.tlsctor)();
    }
}


/**
 * Destruct the modules.
 */

// Starting the name with "_STD" means under Posix a pointer to the
// function gets put in the .dtors segment.

extern (C) void _moduleDtor()
{
    debug(PRINTF) printf("_moduleDtor(): %d modules\n", _moduleinfo_dtors_i);

    // NOTE: _moduleTlsDtor is now called manually by dmain2
    //_moduleTlsDtor();
    foreach_reverse (i, m; _sortedCtors._ctors)
    {
        debug(PRINTF) printf("\tmodule[%d] = '%.*s', x%x\n", i, m.name.length, m.name.ptr, m);
        if (m.dtor)
        {
            (*m.dtor)();
        }
    }
    debug(PRINTF) printf("_moduleDtor() done\n");
}

extern (C) void _moduleTlsDtor()
{
    debug(PRINTF) printf("_moduleTlsDtor(): %d modules\n", _moduleinfo_tlsdtors_i);
    version(none)
    {
        printf("_moduleinfo_tlsdtors = %d,%p\n", _moduleinfo_tlsdtors);
        foreach (i,m; _sortedCtors._tlsctors[0..11])
            printf("[%d] = %p\n", i, m);
    }

    foreach_reverse (i, m; _sortedCtors._tlsctors)
    {
        debug(PRINTF) printf("\tmodule[%d] = '%.*s', x%x\n", i, m.name.length, m.name.ptr, m);
        if (m.tlsdtor)
        {
            (*m.tlsdtor)();
        }
    }
    debug(PRINTF) printf("_moduleTlsDtor() done\n");
}

// Alias the TLS ctor and dtor using "rt_" prefixes, since these routines
// must be called by core.thread.

extern (C) void rt_moduleTlsCtor()
{
    _moduleTlsCtor();
}

extern (C) void rt_moduleTlsDtor()
{
    _moduleTlsDtor();
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
        auto sorted = _checkModCtors(ptrs);
        foreach (i, m; ptrs)
        {
            assert(m.index == i);
            m.index = 0;
        }
        assert(sorted._ctors == dtors);
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
}
