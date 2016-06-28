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
    version(all)
    {
    void sortCtors()
    {
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

        immutable len = _modules.length;

        // This is ugly to say the least. Would be nice to use a binary
        // search at least instead of linear...
        int findModule(in ModuleInfo* mi)
        {
            foreach (i, m; _modules)
                if (m is mi) return cast(int)i;
            return -1;
        }

        // allocate the two constructor lists. These will be stored for life of
        // the program, so use malloc.
        _ctors = (cast(immutable(ModuleInfo)**).malloc(len * (void*).sizeof))[0 .. len];
        _tlsctors = (cast(immutable(ModuleInfo)**).malloc(len * (void*).sizeof))[0 .. len];

        // Start out doing the shared ctors. The destruction is done in reverse.
        auto ctors = _ctors;
        // current element being inserted into ctors list.
        size_t ctoridx = 0;

        // allocate some stack arrays that will be used throughout the process.
        ubyte* p = cast(ubyte *)alloca(len * ubyte.sizeof);
        auto reachable = p[0 .. len];

        p = cast(ubyte *)alloca(len * ubyte.sizeof);
        auto flags = p[0 .. len];


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
                reachable[] = 0;
                foreach(e; m.importedModules)
                {
                    auto impidx = findModule(e);
                    if(impidx != -1 && impidx != i)
                        reachable[impidx] = 1;
                }

                foreach(int j, r; reachable)
                {
                    if(r)
                        edges[i] ~= j;
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
        size_t _findDependencies(int idx, bool orig = true)
        {
            if(reachable[idx])
                return 0;
            auto current = _modules[idx];
            size_t result = 0;
            reachable[idx] = 1;
            if(!orig && (flags[idx] & (MIctor | MIdtor)) && !(flags[idx] & MIstandalone))
                // non-trivial, stop here
                return result + 1;
            foreach (m; current.importedModules)
            {
                auto midx = findModule(m);
                if(midx != -1)
                    // not part of this DSO, don't consider it.
                    result += _findDependencies(midx, false);
            }
            return result;
        }

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

            // we only get called if current has a dtor or a ctor, so no need to
            // check that.  First, determine what non-trivial elements are
            // reachable.
            reachable[] = 0;
            auto nmodules = _findDependencies(curidx);

            // allocate the dependencies on the stack
            auto p = cast(int *)alloca(nmodules * int.sizeof);
            auto dependencies = p[0 .. nmodules];
            uint depidx = 0;
            // fill in the dependencies
            foreach (int i, r; reachable)
            {
                if(r && i != curidx)
                {
                    if((flags[i] & (MIctor | MIdtor)) && !(flags[i] & MIstandalone))
                    {
                        dependencies[depidx++] = i;
                    }
                }
            }
            assert(depidx == nmodules);

            // ok, now perform cycle detection
            flags[curidx] |= MIctorstart;
            foreach (m; dependencies)
            {
                auto mflags = flags[m];
                if(mflags & MIctorstart)
                {
                    // found a cycle
                    println("Cyclic dependency between module ", _modules[m].name, " and ", current.name);
                    genPath(m, curidx);

                    foreach(midx; cyclePath[0 .. $-1])
                    {
                        println(_modules[midx].name, (flags[midx] & (MIctor | MIdtor)) ? "* ->" : " ->");
                    }
                    println(_modules[m].name, "*");
                    throw new Error(errmsg);
                }
                else if(!(mflags & MIctordone))
                {
                    _checkModCtors2(m);
                }
            }
            flags[curidx] = (flags[curidx] & ~MIctorstart) | MIctordone;
            // add this module to the construction order list
            ctors[ctoridx++] = current;
        }

        void _checkModCtors3()
        {
            foreach (int idx, m; _modules)
            {
                // TODO: Should null ModuleInfo be allowed?
                if (m is null) continue;
                auto flag = flags[idx];
                if((flag & (MIctor | MIdtor)) && !(flag & MIctordone))
                {
                    if(flag & MIstandalone)
                    {
                        // no need to run a check on this one, but we do need to call its ctor/dtor
                        ctors[ctoridx++] = m;
                    }
                    else
                        _checkModCtors2(idx);
                }
            }
        }

        // initialize the flags for the first run (shared ctors).
        foreach (uint i, m; _modules)
        {
            // TODO: Should null ModuleInfo be allowed?
            if (m is null) continue;
            ubyte flag = m.flags & MIstandalone;
            if(m.dtor)
                flag |= MIdtor;
            if(m.ctor)
                flag |= MIctor;
            flags[i] = flag;
        }

        _checkModCtors3();

        // _ctors is now valid up to ctoridx
        _ctors = _ctors[0 .. ctoridx];

        // tls ctors/dtors
        ctors = _tlsctors;
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
        _checkModCtors3();
        _tlsctors = _tlsctors[0 .. ctoridx];
    }
    }
    else
    {
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
                            (stackidx < stack.length) || assert(0);

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
        //checkExp("closed ctors cycle", false, [&m0.mi, &m1.mi, &m2.mi], [&m1.mi, &m2.mi, &m0.mi]);
        checkExp("closed ctors cycle", false, [&m0.mi, &m1.mi, &m2.mi], [&m0.mi, &m1.mi, &m2.mi]);
    }
}

version (CRuntime_Microsoft)
{
    // Dummy so Win32 code can still call it
    extern(C) void _minit() { }
}
