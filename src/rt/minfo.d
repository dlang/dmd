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

__gshared ModuleInfo*[] _moduleinfo_dtors;
__gshared size_t        _moduleinfo_dtors_i;

__gshared ModuleInfo*[] _moduleinfo_tlsdtors;
__gshared size_t        _moduleinfo_tlsdtors_i;

// Register termination function pointers
extern (C) int _fatexit(void*);

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
    _checkModCtors();

    _moduleIndependentCtors();
    // now, call the module constructors in the designated order
    foreach(i; 0.._moduleinfo_dtors_i)
    {
        ModuleInfo *mi = _moduleinfo_dtors[i];
        if(mi.ctor)
            (*mi.ctor)();
    }

    //_moduleCtor2(_moduleinfo_array, 0);
    // NOTE: _moduleTlsCtor is now called manually by dmain2
    //_moduleTlsCtor();
}

extern (C) void _moduleIndependentCtors()
{
    debug(PRINTF) printf("_moduleIndependentCtors()\n");
    foreach (m; _moduleinfo_array)
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
extern(C) void _checkModCtors()
{
    // Create an array of modules that will determine the order of construction
    // (and destruction in reverse).
    auto dtors = _moduleinfo_dtors = new ModuleInfo*[_moduleinfo_array.length];
    size_t dtoridx = 0;

    // this pointer will identify the module where the cycle was detected.
    ModuleInfo *cycleModule;

    // allocate some stack arrays that will be used throughout the process.
    ubyte* p = cast(ubyte *)alloca(_moduleinfo_array.length * ubyte.sizeof);
    auto reachable = p[0.._moduleinfo_array.length];

    p = cast(ubyte *)alloca(_moduleinfo_array.length * ubyte.sizeof);
    auto flags = p[0.._moduleinfo_array.length];


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
        foreach(ModuleInfo *m; current.importedModules)
        {
            result += _findDependencies(m, false);
        }
        return result;
    }

    void println(string msg[]...)
    {
        version(Windows)
            immutable ret = "\r\n";
        else
            immutable ret = "\n";
        foreach(m; msg)
        {
            // write message to stderr
            console(m);
        }
        console(ret);
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
        foreach(m; current.importedModules)
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
        foreach(i, r; reachable)
        {
            if(r)
            {
                ModuleInfo *m = _moduleinfo_array[i];
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
        foreach(m; dependencies)
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
                dtoridx = dtors.length;
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
                dtors[--dtoridx] = current;
                if(current is cycleModule)
                {
                    // print the cycle
                    println("Cycle detected between modules with ctors/dtors:");
                    foreach(cm; dtors[dtoridx..$])
                    {
                        console(cm.name)(" -> ");
                    }
                    println(cycleModule.name);
                    throw new Exception("Aborting!");
                }
                return false;
            }
        }
        flags[curidx] = (flags[curidx] & ~MIctorstart) | MIctordone;
        // add this module to the construction order list
        dtors[dtoridx++] = current;
        return true;
    }

    void _checkModCtors3()
    {
        foreach(m; _moduleinfo_array)
        {
            // TODO: Should null ModuleInfo be allowed?
            if (m is null) continue;
            auto flag = flags[m.index];
            if((flag & (MIctor | MIdtor)) && !(flag & MIctordone))
            {
                if(flag & MIstandalone)
                {
                    // no need to run a check on this one, but we do need to call its ctor/dtor
                    dtors[dtoridx++] = m;
                }
                else
                    _checkModCtors2(m);
            }
        }
    }

    // ok, now we need to assign indexes, and also initialize the flags
    foreach(uint i, m; _moduleinfo_array)
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
    _moduleinfo_dtors_i = dtoridx;

    // set up everything for tls ctors
    dtors = _moduleinfo_tlsdtors = new ModuleInfo*[_moduleinfo_array.length];
    dtoridx = 0;
    foreach(i, m; _moduleinfo_array)
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
    _moduleinfo_tlsdtors_i = dtoridx;
}

/********************************************
 * Run static constructors for thread local global data.
 */

extern (C) void _moduleTlsCtor()
{
    // call the module constructors in the correct order as determined by the
    // check routine.
    foreach(i; 0.._moduleinfo_tlsdtors_i)
    {
        ModuleInfo *mi = _moduleinfo_tlsdtors[i];
        if(mi.tlsctor)
            (*mi.tlsctor)();
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
    for (auto i = _moduleinfo_dtors_i; i-- != 0;)
    {
        ModuleInfo* m = _moduleinfo_dtors[i];

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
        foreach (i,m; _moduleinfo_tlsdtors[0..11])
            printf("[%d] = %p\n", i, m);
    }

    for (auto i = _moduleinfo_tlsdtors_i; i-- != 0;)
    {
        ModuleInfo* m = _moduleinfo_tlsdtors[i];

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
