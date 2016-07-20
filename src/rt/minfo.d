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
        import core.bitop: bts, btr, bt;
        debug(printModuleDependencies)
        {
            import core.stdc.stdio : printf;
            foreach(_m; _modules)
            {
                printf("%s%s%s:", _m.name.ptr, (_m.flags & MIstandalone) ? "+".ptr : "".ptr, (_m.flags & (MIctor | MIdtor)) ? "*".ptr : "".ptr);
                foreach(_i; _m.importedModules)
                    printf(" %s", _i.name.ptr);
                printf("\n");
            }
        }

        immutable uint len = cast(uint)_modules.length;
        if(!len)
            return; // nothing to do.

        immutable(ModuleInfo)* minMod = _modules[0];
        immutable(ModuleInfo)* maxMod = _modules[0];
        foreach(m; _modules)
        {
            if(m < minMod)
                minMod = m;
            if(m > maxMod)
                maxMod = m;
        }

        int findModule(in ModuleInfo* mi)
        {
            // short circuit linear search if possible.
            if(mi < minMod || mi > maxMod)
                return -1;
            // binary search would be nice...
            foreach (i, m; _modules)
                if (m is mi) return cast(int)i;
            return -1;
        }


        // allocate some stack arrays that will be used throughout the process.
        immutable nwords = (len + 8 * size_t.sizeof - 1) / (8 * size_t.sizeof);
        immutable flagbytes = nwords * size_t.sizeof;
        auto ctorstart = cast(size_t*)alloca(flagbytes);// ctor/dtor seen
        auto ctordone = cast(size_t*)alloca(flagbytes);// ctor/dtor processed
        auto relevant = cast(size_t*)alloca(flagbytes);// has ctors/dtors
        auto reachable = cast(size_t*)alloca(flagbytes);// used for reachability check

        void clearFlags(size_t *flags)
        {
            memset(flags, 0, flagbytes);
        }

        // use this to hold the error message.
        string errmsg = null;

        void print(string[] msgs...)
        {
            foreach (m; msgs)
            {
                // save to the error message. Note that if we are throwing an
                // exception, we don't care about being careful with using
                // stack memory. Just use the GC/runtime.
                errmsg ~= m;
            }
        }

        void println(string[] msgs...)
        {
            print(msgs);
            version(Windows)
                print("\r\n");
            else
                print("\n");
        }

        // this set of functions helps create a valid path between two
        // interdependent modules. This is only used if a cycle is found, to
        // print the cycle to the user. Therefore, we don't initialize the data
        // until we have to.
        int[] cyclePath;
        int[] distance;
        int[][] edges;

        // determine the shortest path between two modules. Uses dijkstra
        // without a priority queue. (we can be a bit slow here, in order to
        // get a better printout).
        void shortest(int start, int target)
        {
            // initial setup
            distance[] = int.max;
            int curdist = 0;
            distance[start] = 0;
            while(true)
            {
                bool done = true;
                foreach(i, x; distance)
                {
                    if(x == curdist)
                    {
                        if(i == target)
                        {
                            done = true;
                            break;
                        }
                        foreach(n; edges[i])
                        {
                            if(distance[n] == int.max)
                            {
                                distance[n] = curdist + 1;
                                done = false;
                            }
                        }
                    }
                }
                if(done)
                    break;
                ++curdist;
            }
            // it should be impossible to not get to target, this is just a
            // sanity check. Not an assert, because druntime is compiled in
            // release mode.
            if(distance[target] != curdist)
            {
                throw new Error("internal error printing module cycle");
            }

            // determine the path. This is tricky, because we have to
            // follow the edges in reverse to get back to the original. We
            // don't have a reverse mapping, so it takes a bit of looping.
            cyclePath.length += curdist;
            auto subpath = cyclePath[$-curdist .. $];
            while(true)
            {
                --curdist;
                subpath[curdist] = target;
                if(curdist == 0)
                    break;
distloop:
                // search for next (previous) module in cycle.
                foreach(int m, d; distance)
                {
                    if(d == curdist)
                    {
                        // determine if m can reach target
                        foreach(e; edges[m])
                        {
                            if(e == target)
                            {
                                // recurse
                                target = m;
                                break distloop;
                            }
                        }
                    }
                }
            }
        }

        // this function initializes the bookeeping necessary to create the
        // cycle path, and then creates it. It is a precondition that src and
        // target modules are involved in a cycle
        void genPath(int srcidx, int targetidx)
        {
            assert(srcidx != -1);
            assert(targetidx != -1);

            // set up all the arrays. Use the GC, we are going to exit anyway.
            distance.length = len;
            edges.length = len;
            foreach(i, m; _modules)
            {
                // use reachable, because an import can appear more than once.
                // https://issues.dlang.org/show_bug.cgi?id=16208
                clearFlags(reachable);
                foreach(e; m.importedModules)
                {
                    auto impidx = findModule(e);
                    if(impidx != -1 && impidx != i)
                        if(!bts(reachable, impidx))
                            edges[i] ~= impidx;
                }
            }

            // a cycle starts with the source.
            cyclePath ~= srcidx;
            // first get to the target
            shortest(srcidx, targetidx);
            // now get back.
            shortest(targetidx, srcidx);
        }

        // find all the non-trivial dependencies (that is, dependencies that have a
        // ctor or dtor) of a given module.  Doing this, we can 'skip over' the
        // trivial modules to get at the non-trivial ones.
        size_t _findDependencies(int idx)
        {
            static struct stackFrame
            {
                int curMod;
                int curDep;
            }

            // initialize "stack"
            auto stack = cast(stackFrame *)alloca(stackFrame.sizeof * len);
            auto stacktop = stack + len;
            auto sp = stack;
            sp.curMod = idx;
            sp.curDep = 0;
            size_t result = 0;

            for(;;)
            {
                auto m = _modules[sp.curMod];
                if(sp.curDep >= m.importedModules.length)
                {
                    // return
                    if(sp == stack)
                        // finished the algorithm
                        break;
                    --sp;
                    ++sp.curDep;
                    continue;
                }
                auto midx = findModule(m.importedModules[sp.curDep]);
                // if midx is -1, then this isn't part of this DSO.
                if(midx != -1 && !bts(reachable, midx))
                {
                    if(bt(relevant, midx))
                    {
                        // non-trivial, stop here
                        result += 1;
                    }
                    else if(!bt(ctordone, midx))
                    {
                        // non-relevant, and hasn't been exhaustively processed, recurse.
                        if(!bt(ctorstart, midx))
                            ++result;
                        // recurse
                        if(++sp >= stacktop)
                        {
                            // stack overflow, this shouldn't happen.
                            import core.internal.abort : abort;
                            abort("stack overflow on dependency search");
                        }
                        sp.curMod = midx;
                        sp.curDep = 0;
                        continue;
                    }
                }

                // next dependency
                ++sp.curDep;
            }
            return result;
        }

        // The list of constructors that will be returned by the sorting.
        immutable(ModuleInfo)*[] ctors;
        // current element being inserted into ctors list.
        size_t ctoridx = 0;


        // This function will determine the order of construction/destruction and
        // check for cycles. If a cycle is found, the cycle path is transformed
        // into a string and thrown as an error.
        //
        // Each call into this function is given a module that has static
        // ctor/dtors that must be dealt with. It recurses only when it finds
        // dependencies that also have static ctor/dtors.
        void _checkModCtors2(int curidx)
        {
            assert(curidx != -1);
            immutable ModuleInfo* current = _modules[curidx];

            // First, determine what non-trivial elements are reachable.
            clearFlags(reachable);
            bts(reachable, curidx);
            auto nmodules = _findDependencies(curidx);

            // allocate the dependencies on the stack, because reachable will
            // be reused as we recurse.
            auto p = cast(int *)alloca(nmodules * int.sizeof);
            auto dependencies = p[0 .. nmodules];
            uint depidx = 0;
            // fill in the dependencies
            foreach (int i; 0 .. len)
            {
                if(i != curidx && bt(reachable, i))
                {
                   if(bt(relevant, i))
                   {
                       if(bt(ctorstart, i))
                       {
                           // found a cycle
                           println("Cyclic dependency between module ", _modules[i].name, " and ", current.name);
                           genPath(i, curidx);

                           foreach(midx; cyclePath[0 .. $-1])
                           {
                               println(_modules[midx].name, bt(relevant, midx) ? "* ->" : " ->");
                           }
                           println(_modules[i].name, "*");
                           throw new Error(errmsg);
                       }
                       dependencies[depidx++] = i;
                   }
                   else if(!bts(ctorstart, i))
                   {
                       // this is a non-relevant module, but it has never been
                       // imported by any other relevant module in our search.
                       // Once we have processed the current relevant module,
                       // we can mark this non-relevant module as done, so it's
                       // not ever looked at again.
                       dependencies[depidx++] = i;
                   }
                }
            }
            assert(depidx == nmodules);

            // process all the dependencies
            bts(ctorstart, curidx);
            foreach (m; dependencies)
            {
                if(bt(relevant, m) && !bt(ctordone, m))
                    _checkModCtors2(m);
            }
            bts(ctordone, curidx);
            btr(ctorstart, curidx);

            // mark all non-relevant dependencies as done
            foreach(m; dependencies)
            {
                if(!bt(relevant, m))
                {
                    bts(ctordone, m);
                    // no need to clear ctorstart, as we don't care about
                    // irrelevant modules for detecting cycles.
                }
            }
            // add this module to the construction order list
            ctors[ctoridx++] = current;
        }

        immutable(ModuleInfo)*[]
            _checkModCtors3(int function(immutable ModuleInfo *) getf)
        {
            clearFlags(relevant);
            clearFlags(ctorstart);
            clearFlags(ctordone);

            // pre-allocate enough space to hold all modules.
            ctors = (cast(immutable(ModuleInfo)**).malloc(len * (void*).sizeof))[0 .. len];
            ctoridx = 0;
            foreach (int idx, m; _modules)
            {
                // TODO: Should null ModuleInfo be allowed?
                if (m is null) continue;
                auto flag = getf(m);
                if(flag & MIctor)
                {
                    if(flag & MIstandalone)
                    {
                        // can run at any time. Just run it first.
                        ctors[ctoridx++] = m;
                    }
                    else
                    {
                        bts(relevant, idx);
                    }
                }
            }

            // now run the search in the relevant ones
            foreach (int idx, m; _modules)
            {
                if(bt(relevant, idx))
                {
                    if(!bt(ctordone, idx))
                        _checkModCtors2(idx);
                }
            }

            return ctors[0 .. ctoridx];
        }

        // finally, do the sorting for both shared and tls ctors.
        _ctors = _checkModCtors3((immutable ModuleInfo * m) => (m.flags & MIstandalone) | ((m.dtor || m.ctor)? MIctor : 0));
        _tlsctors = _checkModCtors3((immutable ModuleInfo * m) => (m.flags & MIstandalone) | ((m.tlsdtor || m.tlsctor)? MIctor : 0));
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
    static void assertThrown(T : Throwable, E)(lazy E expr, string msg)
    {
        try
            expr;
        catch (T)
            return;
        assert(0, msg);
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

    static void checkExp(string testname, bool shouldThrow,
        immutable(ModuleInfo*)[] modules,
        immutable(ModuleInfo*)[] dtors=null,
        immutable(ModuleInfo*)[] tlsdtors=null)
    {
        auto mgroup = ModuleGroup(modules);
        mgroup.sortCtors();

        // if we are expecting sort to throw, don't throw because of unexpected
        // success!
        if(!shouldThrow)
        {
            foreach (m; mgroup._modules)
                assert(!(m.flags & (MIctorstart | MIctordone)), testname);
            assert(mgroup._ctors    == dtors, testname);
            assert(mgroup._tlsctors == tlsdtors, testname);
        }
    }

    {
        auto m0 = mockMI(0);
        auto m1 = mockMI(0);
        auto m2 = mockMI(0);
        checkExp("no ctors", false, [&m0.mi, &m1.mi, &m2.mi]);
    }

    {
        auto m0 = mockMI(MIictor);
        auto m1 = mockMI(0);
        auto m2 = mockMI(MIictor);
        auto mgroup = ModuleGroup([&m0.mi, &m1.mi, &m2.mi]);
        checkExp("independent ctors", false, [&m0.mi, &m1.mi, &m2.mi]);
    }

    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(0);
        auto m2 = mockMI(0);
        auto mgroup = ModuleGroup([&m0.mi, &m1.mi, &m2.mi]);
        checkExp("standalone ctor", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi]);
    }

    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(0);
        m1.setImports(&m0.mi);
        checkExp("imported standalone => no dependency", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi]);
    }

    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        checkExp("imported standalone => no dependency (2)", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi]);
    }

    {
        auto m0 = mockMI(MIstandalone | MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        m1.setImports(&m0.mi);
        checkExp("standalone may have cycle", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi]);
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m1.setImports(&m0.mi);
        checkExp("imported ctor => ordered ctors", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi], []);
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        checkExp("imported ctor => ordered ctors (2)", false, [&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], []);
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m1.mi);
        m1.setImports(&m0.mi);
        assertThrown!Throwable(checkExp("", true, [&m0.mi, &m1.mi, &m2.mi]), "detects ctors cycles");
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(0);
        m0.setImports(&m2.mi);
        m1.setImports(&m2.mi);
        m2.setImports(&m0.mi, &m1.mi);
        assertThrown!Throwable(checkExp("", true, [&m0.mi, &m1.mi, &m2.mi]), "detects cycle with repeats");
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi, &m2.mi);
        checkExp("imported ctor/tlsctor => ordered ctors/tlsctors", false, [&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], [&m2.mi]);
    }

    {
        auto m0 = mockMI(MIctor | MItlsctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi, &m2.mi);
        checkExp("imported ctor/tlsctor => ordered ctors/tlsctors (2)", false, [&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], [&m2.mi, &m0.mi]);
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi, &m2.mi);
        m2.setImports(&m0.mi);
        checkExp("no cycle between ctors/tlsctors", false, [&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m0.mi], [&m2.mi]);
    }

    {
        auto m0 = mockMI(MItlsctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m2.mi);
        m2.setImports(&m0.mi);
        assertThrown!Throwable(checkExp("", true, [&m0.mi, &m1.mi, &m2.mi]), "detects tlsctors cycle");
    }

    {
        auto m0 = mockMI(MItlsctor);
        auto m1 = mockMI(MIctor);
        auto m2 = mockMI(MItlsctor);
        m0.setImports(&m1.mi);
        m1.setImports(&m0.mi, &m2.mi);
        m2.setImports(&m1.mi);
        assertThrown!Throwable(checkExp("", true, [&m0.mi, &m1.mi, &m2.mi]), "detects tlsctors cycle with repeats");
    }

    {
        auto m0 = mockMI(MIctor);
        auto m1 = mockMI(MIstandalone | MIctor);
        auto m2 = mockMI(MIstandalone | MIctor);
        m0.setImports(&m1.mi);
        m1.setImports(&m2.mi);
        m2.setImports(&m0.mi);
        // NOTE: this is implementation dependent, sorted order shouldn't be tested.
        checkExp("closed ctors cycle", false, [&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m2.mi, &m0.mi]);
        //checkExp("closed ctors cycle", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi, &m2.mi]);
    }
}

version (CRuntime_Microsoft)
{
    // Dummy so Win32 code can still call it
    extern(C) void _minit() { }
}
