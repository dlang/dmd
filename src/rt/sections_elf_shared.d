/**
 * Written in the D programming language.
 * This module provides ELF-specific support for sections with shared libraries.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_linux.d)
 */

module rt.sections_elf_shared;

version (linux) enum SharedELF = true;
else version (FreeBSD) enum SharedELF = true;
else enum SharedELF = false;
static if (SharedELF):

// debug = PRINTF;
import core.memory;
import core.stdc.stdio;
import core.stdc.stdlib : calloc, exit, free, malloc, EXIT_FAILURE;
import core.stdc.string : strlen;
version (linux)
{
    import core.sys.linux.dlfcn;
    import core.sys.linux.elf;
    import core.sys.linux.link;
}
else version (FreeBSD)
{
    import core.sys.freebsd.dlfcn;
    import core.sys.freebsd.sys.elf;
    import core.sys.freebsd.sys.link_elf;
}
else
{
    static assert(0, "unimplemented");
}
import core.sys.posix.pthread;
import rt.deh;
import rt.dmain2;
import rt.minfo;
import rt.util.container.array;
import rt.util.container.hashtab;

alias DSO SectionGroup;
struct DSO
{
    static int opApply(scope int delegate(ref DSO) dg)
    {
        foreach (dso; _loadedDSOs)
        {
            if (auto res = dg(*dso))
                return res;
        }
        return 0;
    }

    static int opApplyReverse(scope int delegate(ref DSO) dg)
    {
        foreach_reverse (dso; _loadedDSOs)
        {
            if (auto res = dg(*dso))
                return res;
        }
        return 0;
    }

    @property immutable(ModuleInfo*)[] modules() const
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout
    {
        return _moduleGroup;
    }

    @property immutable(FuncTable)[] ehTables() const
    {
        return _ehTables[];
    }

    @property inout(void[])[] gcRanges() inout
    {
        return _gcRanges[];
    }

private:

    invariant()
    {
        assert(_moduleGroup.modules.length);
        assert(_tlsMod || !_tlsSize);
    }

    immutable(FuncTable)[] _ehTables;
    ModuleGroup _moduleGroup;
    Array!(void[]) _gcRanges;
    size_t _tlsMod;
    size_t _tlsSize;

    version (Shared)
    {
        Array!(void[]) _codeSegments; // array of code segments
        Array!(DSO*) _deps; // D libraries needed by this DSO
        void* _handle; // corresponding handle
    }
}

/****
 * Boolean flag set to true while the runtime is initialized.
 */
__gshared bool _isRuntimeInitialized;


/****
 * Gets called on program startup just before GC is initialized.
 */
void initSections()
{
    _isRuntimeInitialized = true;
}


/***
 * Gets called on program shutdown just after GC is terminated.
 */
void finiSections()
{
    _isRuntimeInitialized = false;
}

alias ScanDG = void delegate(void* pbeg, void* pend) nothrow;

version (Shared)
{
    /***
     * Called once per thread; returns array of thread local storage ranges
     */
    Array!(ThreadDSO)* initTLSRanges()
    {
        return &_loadedDSOs;
    }

    void finiTLSRanges(Array!(ThreadDSO)* tdsos)
    {
        tdsos.reset();
    }

    void scanTLSRanges(Array!(ThreadDSO)* tdsos, scope ScanDG dg) nothrow
    {
        foreach (ref tdso; *tdsos)
            dg(tdso._tlsRange.ptr, tdso._tlsRange.ptr + tdso._tlsRange.length);
    }

    // interface for core.thread to inherit loaded libraries
    void* pinLoadedLibraries()
    {
        auto res = cast(Array!(ThreadDSO)*)calloc(1, Array!(ThreadDSO).sizeof);
        res.length = _loadedDSOs.length;
        foreach (i, ref tdso; _loadedDSOs)
        {
            (*res)[i] = tdso;
            if (tdso._addCnt)
            {
                // Increment the dlopen ref for explicitly loaded libraries to pin them.
                .dlopen(linkMapForHandle(tdso._pdso._handle).l_name, RTLD_LAZY) !is null || assert(0);
                (*res)[i]._addCnt = 1; // new array takes over the additional ref count
            }
        }
        return res;
    }

    void unpinLoadedLibraries(void* p)
    {
        auto pary = cast(Array!(ThreadDSO)*)p;
        // In case something failed we need to undo the pinning.
        foreach (ref tdso; *pary)
        {
            if (tdso._addCnt)
            {
                auto handle = tdso._pdso._handle;
                handle !is null || assert(0);
                .dlclose(handle);
            }
        }
        pary.reset();
        .free(pary);
    }

    // Called before TLS ctors are ran, copy over the loaded libraries
    // of the parent thread.
    void inheritLoadedLibraries(void* p)
    {
        assert(_loadedDSOs.empty);
        _loadedDSOs.swap(*cast(Array!(ThreadDSO)*)p);
        .free(p);
    }

    // Called after all TLS dtors ran, decrements all remaining dlopen refs.
    void cleanupLoadedLibraries()
    {
        foreach (ref tdso; _loadedDSOs)
        {
            if (tdso._addCnt == 0) continue;

            auto handle = tdso._pdso._handle;
            handle !is null || assert(0);
            for (; tdso._addCnt > 0; --tdso._addCnt)
                .dlclose(handle);
        }
        _loadedDSOs.reset();
    }
}
else
{
    /***
     * Called once per thread; returns array of thread local storage ranges
     */
    Array!(void[])* initTLSRanges()
    {
        return &_tlsRanges;
    }

    void finiTLSRanges(Array!(void[])* rngs)
    {
        rngs.reset();
    }

    void scanTLSRanges(Array!(void[])* rngs, scope ScanDG dg) nothrow
    {
        foreach (rng; *rngs)
            dg(rng.ptr, rng.ptr + rng.length);
    }
}

private:

// start of linked list for ModuleInfo references
version (FreeBSD) deprecated extern (C) __gshared void* _Dmodule_ref;

version (Shared)
{
    /*
     * Array of thread local DSO metadata for all libraries loaded and
     * initialized in this thread.
     *
     * Note:
     *     A newly spawned thread will inherit these libraries.
     * Note:
     *     We use an array here to preserve the order of
     *     initialization.  If that became a performance issue, we
     *     could use a hash table and enumerate the DSOs during
     *     loading so that the hash table values could be sorted when
     *     necessary.
     */
    struct ThreadDSO
    {
        DSO* _pdso;
        static if (_pdso.sizeof == 8) uint _refCnt, _addCnt;
        else static if (_pdso.sizeof == 4) ushort _refCnt, _addCnt;
        else static assert(0, "unimplemented");
        void[] _tlsRange;
        alias _pdso this;
    }
    Array!(ThreadDSO) _loadedDSOs;

    /*
     * Set to true during rt_loadLibrary/rt_unloadLibrary calls.
     */
    bool _rtLoading;

    /*
     * Hash table to map link_map* to corresponding DSO*.
     * The hash table is protected by a Mutex.
     */
    __gshared pthread_mutex_t _handleToDSOMutex;
    __gshared HashTab!(void*, DSO*) _handleToDSO;
}
else
{
    /*
     * Static DSOs loaded by the runtime linker. This includes the
     * executable. These can't be unloaded.
     */
    __gshared Array!(DSO*) _loadedDSOs;

    /*
     * Thread local array that contains TLS memory ranges for each
     * library initialized in this thread.
     */
    Array!(void[]) _tlsRanges;

    enum _rtLoading = false;
}

///////////////////////////////////////////////////////////////////////////////
// Compiler to runtime interface.
///////////////////////////////////////////////////////////////////////////////


/*
 * This data structure is generated by the compiler, and then passed to
 * _d_dso_registry().
 */
struct CompilerDSOData
{
    size_t _version;                                       // currently 1
    void** _slot;                                          // can be used to store runtime data
    immutable(object.ModuleInfo*)* _minfo_beg, _minfo_end; // array of modules in this object file
    immutable(rt.deh.FuncTable)* _deh_beg, _deh_end;       // array of exception handling data
}

T[] toRange(T)(T* beg, T* end) { return beg[0 .. end - beg]; }

/* For each shared library and executable, the compiler generates code that
 * sets up CompilerDSOData and calls _d_dso_registry().
 * A pointer to that code is inserted into both the .ctors and .dtors
 * segment so it gets called by the loader on startup and shutdown.
 */
extern(C) void _d_dso_registry(CompilerDSOData* data)
{
    // only one supported currently
    data._version >= 1 || assert(0, "corrupt DSO data version");

    // no backlink => register
    if (*data._slot is null)
    {
        if (_loadedDSOs.empty) initLocks(); // first DSO

        DSO* pdso = cast(DSO*).calloc(1, DSO.sizeof);
        assert(typeid(DSO).init().ptr is null);
        *data._slot = pdso; // store backlink in library record

        pdso._moduleGroup = ModuleGroup(toRange(data._minfo_beg, data._minfo_end));
        pdso._ehTables = toRange(data._deh_beg, data._deh_end);

        dl_phdr_info info = void;
        findDSOInfoForAddr(data._slot, &info) || assert(0);

        scanSegments(info, pdso);

        checkModuleCollisions(info, pdso._moduleGroup.modules);

        version (Shared)
        {
            // the first loaded DSO is druntime itself
            assert(!_loadedDSOs.empty ||
                   /* We need a local symbol (rt_get_bss_start) or the function
                    * pointer might be a PLT address in the executable.
                    * data._slot is already local in the shared library
                    */
                   handleForAddr(&rt_get_bss_start) == handleForAddr(data._slot));

            getDependencies(info, pdso._deps);
            pdso._handle = handleForAddr(data._slot);
            setDSOForHandle(pdso, pdso._handle);

            if (!_rtLoading)
            {
                /* This DSO was not loaded by rt_loadLibrary which
                 * happens for all dependencies of an executable or
                 * the first dlopen call from a C program.
                 * In this case we add the DSO to the _loadedDSOs of this
                 * thread with a refCnt of 1 and call the TlsCtors.
                 */
                immutable ushort refCnt = 1, addCnt = 0;
                auto tlsRng = getTLSRange(pdso._tlsMod, pdso._tlsSize);
                _loadedDSOs.insertBack(ThreadDSO(pdso, refCnt, addCnt, tlsRng));
            }
        }
        else
        {
            foreach (p; _loadedDSOs) assert(p !is pdso);
            _loadedDSOs.insertBack(pdso);
            _tlsRanges.insertBack(getTLSRange(pdso._tlsMod, pdso._tlsSize));
        }

        // don't initialize modules before rt_init was called (see Bugzilla 11378)
        if (_isRuntimeInitialized)
        {
            registerGCRanges(pdso);
            // rt_loadLibrary will run tls ctors, so do this only for dlopen
            immutable runTlsCtors = !_rtLoading;
            runModuleConstructors(pdso, runTlsCtors);
        }
    }
    // has backlink => unregister
    else
    {
        DSO* pdso = cast(DSO*)*data._slot;
        *data._slot = null;

        // don't finalizes modules after rt_term was called (see Bugzilla 11378)
        if (_isRuntimeInitialized)
        {
            // rt_unloadLibrary already ran tls dtors, so do this only for dlclose
            immutable runTlsDtors = !_rtLoading;
            runModuleDestructors(pdso, runTlsDtors);
            unregisterGCRanges(pdso);
            // run finalizers after module dtors (same order as in rt_term)
            version (Shared) runFinalizers(pdso);
        }

        version (Shared)
        {
            if (!_rtLoading)
            {
                /* This DSO was not unloaded by rt_unloadLibrary so we
                 * have to remove it from _loadedDSOs here.
                 */
                foreach (i, ref tdso; _loadedDSOs)
                {
                    if (tdso._pdso == pdso)
                    {
                        _loadedDSOs.remove(i);
                        break;
                    }
                }
            }

            assert(pdso._handle == handleForAddr(data._slot));
            unsetDSOForHandle(pdso, pdso._handle);
            pdso._handle = null;
        }
        else
        {
            // static DSOs are unloaded in reverse order
            assert(pdso._tlsSize == _tlsRanges.back.length);
            _tlsRanges.popBack();
            assert(pdso == _loadedDSOs.back);
            _loadedDSOs.popBack();
        }

        freeDSO(pdso);

        if (_loadedDSOs.empty) finiLocks(); // last DSO
    }
}

///////////////////////////////////////////////////////////////////////////////
// dynamic loading
///////////////////////////////////////////////////////////////////////////////

// Shared D libraries are only supported when linking against a shared druntime library.

version (Shared)
{
    ThreadDSO* findThreadDSO(DSO* pdso)
    {
        foreach (ref tdata; _loadedDSOs)
            if (tdata._pdso == pdso) return &tdata;
        return null;
    }

    void incThreadRef(DSO* pdso, bool incAdd)
    {
        if (auto tdata = findThreadDSO(pdso)) // already initialized
        {
            if (incAdd && ++tdata._addCnt > 1) return;
            ++tdata._refCnt;
        }
        else
        {
            foreach (dep; pdso._deps)
                incThreadRef(dep, false);
            immutable ushort refCnt = 1, addCnt = incAdd ? 1 : 0;
            auto tlsRng = getTLSRange(pdso._tlsMod, pdso._tlsSize);
            _loadedDSOs.insertBack(ThreadDSO(pdso, refCnt, addCnt, tlsRng));
            pdso._moduleGroup.runTlsCtors();
        }
    }

    void decThreadRef(DSO* pdso, bool decAdd)
    {
        auto tdata = findThreadDSO(pdso);
        tdata !is null || assert(0);
        !decAdd || tdata._addCnt > 0 || assert(0, "Mismatching rt_unloadLibrary call.");

        if (decAdd && --tdata._addCnt > 0) return;
        if (--tdata._refCnt > 0) return;

        pdso._moduleGroup.runTlsDtors();
        foreach (i, ref td; _loadedDSOs)
            if (td._pdso == pdso) _loadedDSOs.remove(i);
        foreach (dep; pdso._deps)
            decThreadRef(dep, false);
    }

    extern(C) void* rt_loadLibrary(const char* name)
    {
        immutable save = _rtLoading;
        _rtLoading = true;
        scope (exit) _rtLoading = save;

        auto handle = .dlopen(name, RTLD_LAZY);
        if (handle is null) return null;

        // if it's a D library
        if (auto pdso = dsoForHandle(handle))
            incThreadRef(pdso, true);
        return handle;
    }

    extern(C) int rt_unloadLibrary(void* handle)
    {
        if (handle is null) return false;

        immutable save = _rtLoading;
        _rtLoading = true;
        scope (exit) _rtLoading = save;

        // if it's a D library
        if (auto pdso = dsoForHandle(handle))
            decThreadRef(pdso, true);
        return .dlclose(handle) == 0;
    }
}

///////////////////////////////////////////////////////////////////////////////
// helper functions
///////////////////////////////////////////////////////////////////////////////

void initLocks()
{
    version (Shared)
        !pthread_mutex_init(&_handleToDSOMutex, null) || assert(0);
}

void finiLocks()
{
    version (Shared)
        !pthread_mutex_destroy(&_handleToDSOMutex) || assert(0);
}

void runModuleConstructors(DSO* pdso, bool runTlsCtors)
{
    pdso._moduleGroup.sortCtors();
    pdso._moduleGroup.runCtors();
    if (runTlsCtors) pdso._moduleGroup.runTlsCtors();
}

void runModuleDestructors(DSO* pdso, bool runTlsDtors)
{
    if (runTlsDtors) pdso._moduleGroup.runTlsDtors();
    pdso._moduleGroup.runDtors();
}

void registerGCRanges(DSO* pdso)
{
    foreach (rng; pdso._gcRanges)
        GC.addRange(rng.ptr, rng.length);
}

void unregisterGCRanges(DSO* pdso)
{
    foreach (rng; pdso._gcRanges)
        GC.removeRange(rng.ptr);
}

version (Shared) void runFinalizers(DSO* pdso)
{
    foreach (seg; pdso._codeSegments)
        GC.runFinalizers(seg);
}

void freeDSO(DSO* pdso)
{
    pdso._gcRanges.reset();
    version (Shared) pdso._codeSegments.reset();
    .free(pdso);
}

version (Shared)
{
    link_map* linkMapForHandle(void* handle)
    {
        link_map* map;
        dlinfo(handle, RTLD_DI_LINKMAP, &map) == 0 || assert(0);
        return map;
    }

    DSO* dsoForHandle(void* handle)
    {
        DSO* pdso;
        !pthread_mutex_lock(&_handleToDSOMutex) || assert(0);
        if (auto ppdso = handle in _handleToDSO)
            pdso = *ppdso;
        !pthread_mutex_unlock(&_handleToDSOMutex) || assert(0);
        return pdso;
    }

    void setDSOForHandle(DSO* pdso, void* handle)
    {
        !pthread_mutex_lock(&_handleToDSOMutex) || assert(0);
        assert(handle !in _handleToDSO);
        _handleToDSO[handle] = pdso;
        !pthread_mutex_unlock(&_handleToDSOMutex) || assert(0);
    }

    void unsetDSOForHandle(DSO* pdso, void* handle)
    {
        !pthread_mutex_lock(&_handleToDSOMutex) || assert(0);
        assert(_handleToDSO[handle] == pdso);
        _handleToDSO.remove(handle);
        !pthread_mutex_unlock(&_handleToDSOMutex) || assert(0);
    }

    void getDependencies(in ref dl_phdr_info info, ref Array!(DSO*) deps)
    {
        // get the entries of the .dynamic section
        ElfW!"Dyn"[] dyns;
        foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
        {
            if (phdr.p_type == PT_DYNAMIC)
            {
                auto p = cast(ElfW!"Dyn"*)(info.dlpi_addr + phdr.p_vaddr);
                dyns = p[0 .. phdr.p_memsz / ElfW!"Dyn".sizeof];
                break;
            }
        }
        // find the string table which contains the sonames
        const(char)* strtab;
        foreach (dyn; dyns)
        {
            if (dyn.d_tag == DT_STRTAB)
            {
                version (linux)
                    strtab = cast(const(char)*)dyn.d_un.d_ptr;
                else version (FreeBSD)
                    strtab = cast(const(char)*)(info.dlpi_addr + dyn.d_un.d_ptr); // relocate
                else
                    static assert(0, "unimplemented");
                break;
            }
        }
        foreach (dyn; dyns)
        {
            immutable tag = dyn.d_tag;
            if (!(tag == DT_NEEDED || tag == DT_AUXILIARY || tag == DT_FILTER))
                continue;

            // soname of the dependency
            auto name = strtab + dyn.d_un.d_val;
            // get handle without loading the library
            auto handle = handleForName(name);
            // the runtime linker has already loaded all dependencies
            if (handle is null) assert(0);
            // if it's a D library
            if (auto pdso = dsoForHandle(handle))
                deps.insertBack(pdso); // append it to the dependencies
        }
    }

    void* handleForName(const char* name)
    {
        auto handle = .dlopen(name, RTLD_NOLOAD | RTLD_LAZY);
        if (handle !is null) .dlclose(handle); // drop reference count
        return handle;
    }
}

///////////////////////////////////////////////////////////////////////////////
// Elf program header iteration
///////////////////////////////////////////////////////////////////////////////

/************
 * Scan segments in Linux dl_phdr_info struct and store
 * the TLS and writeable data segments in *pdso.
 */
void scanSegments(in ref dl_phdr_info info, DSO* pdso)
{
    foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
    {
        switch (phdr.p_type)
        {
        case PT_LOAD:
            if (phdr.p_flags & PF_W) // writeable data segment
            {
                auto beg = cast(void*)(info.dlpi_addr + phdr.p_vaddr);
                pdso._gcRanges.insertBack(beg[0 .. phdr.p_memsz]);
            }
            version (Shared) if (phdr.p_flags & PF_X) // code segment
            {
                auto beg = cast(void*)(info.dlpi_addr + phdr.p_vaddr);
                pdso._codeSegments.insertBack(beg[0 .. phdr.p_memsz]);
            }
            break;

        case PT_TLS: // TLS segment
            assert(!pdso._tlsSize); // is unique per DSO
            pdso._tlsMod = info.dlpi_tls_modid;
            pdso._tlsSize = phdr.p_memsz;
            break;

        default:
            break;
        }
    }
}

/**************************
 * Input:
 *      result  where the output is to be written; dl_phdr_info is a Linux struct
 * Returns:
 *      true if found, and *result is filled in
 * References:
 *      http://linux.die.net/man/3/dl_iterate_phdr
 */
nothrow
bool findDSOInfoForAddr(in void* addr, dl_phdr_info* result=null)
{
    static struct DG { const(void)* addr; dl_phdr_info* result; }

    extern(C) nothrow
    int callback(dl_phdr_info* info, size_t sz, void* arg)
    {
        auto p = cast(DG*)arg;
        if (findSegmentForAddr(*info, p.addr))
        {
            if (p.result !is null) *p.result = *info;
            return 1; // break;
        }
        return 0; // continue iteration
    }

    auto dg = DG(addr, result);

    /* Linux function that walks through the list of an application's shared objects and
     * calls 'callback' once for each object, until either all shared objects
     * have been processed or 'callback' returns a nonzero value.
     */
    return dl_iterate_phdr(&callback, &dg) != 0;
}

/*********************************
 * Determine if 'addr' lies within shared object 'info'.
 * If so, return true and fill in 'result' with the corresponding ELF program header.
 */
nothrow
bool findSegmentForAddr(in ref dl_phdr_info info, in void* addr, ElfW!"Phdr"* result=null)
{
    if (addr < cast(void*)info.dlpi_addr) // less than base address of object means quick reject
        return false;

    foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
    {
        auto beg = cast(void*)(info.dlpi_addr + phdr.p_vaddr);
        if (cast(size_t)(addr - beg) < phdr.p_memsz)
        {
            if (result !is null) *result = phdr;
            return true;
        }
    }
    return false;
}

version (linux) import core.sys.linux.errno : program_invocation_name;
// should be in core.sys.freebsd.stdlib
version (FreeBSD) extern(C) const(char)* getprogname() nothrow @nogc;

@property const(char)* progname() nothrow @nogc
{
    version (linux) return program_invocation_name;
    version (FreeBSD) return getprogname();
}

nothrow
const(char)[] dsoName(const char* dlpi_name)
{
    // the main executable doesn't have a name in its dlpi_name field
    const char* p = dlpi_name[0] != 0 ? dlpi_name : progname;
    return p[0 .. strlen(p)];
}

extern(C)
{
    void* rt_get_bss_start() @nogc nothrow;
    void* rt_get_end() @nogc nothrow;
}

nothrow
void checkModuleCollisions(in ref dl_phdr_info info, in immutable(ModuleInfo)*[] modules)
in { assert(modules.length); }
body
{
    immutable(ModuleInfo)* conflicting;

    auto bss_start = rt_get_bss_start();
    immutable bss_size = rt_get_end() - bss_start;
    assert(bss_size >= 0);

    foreach (m; modules)
    {
        auto addr = cast(const(void*))m;
        if (cast(size_t)(addr - bss_start) < cast(size_t)bss_size)
        {
            // Module is in .bss of the exe because it was copy relocated
        }
        else if (!findSegmentForAddr(info, addr))
        {
            // Module is in another DSO
            conflicting = m;
            break;
        }
    }

    if (conflicting !is null)
    {
        dl_phdr_info other=void;
        findDSOInfoForAddr(conflicting, &other) || assert(0);

        auto modname = conflicting.name;
        auto loading = dsoName(info.dlpi_name);
        auto existing = dsoName(other.dlpi_name);
        fprintf(stderr, "Fatal Error while loading '%.*s':\n\tThe module '%.*s' is already defined in '%.*s'.\n",
                cast(int)loading.length, loading.ptr,
                cast(int)modname.length, modname.ptr,
                cast(int)existing.length, existing.ptr);
        assert(0);
    }
}

/**************************
 * Input:
 *      addr  an internal address of a DSO
 * Returns:
 *      the dlopen handle for that DSO or null if addr is not within a loaded DSO
 */
version (Shared) void* handleForAddr(void* addr)
{
    Dl_info info = void;
    if (dladdr(addr, &info) != 0)
        return handleForName(info.dli_fname);
    return null;
}

///////////////////////////////////////////////////////////////////////////////
// TLS module helper
///////////////////////////////////////////////////////////////////////////////


/*
 * Returns: the TLS memory range for a given module and the calling
 * thread or null if that module has no TLS.
 *
 * Note: This will cause the TLS memory to be eagerly allocated.
 */
struct tls_index
{
    size_t ti_module;
    size_t ti_offset;
}

extern(C) void* __tls_get_addr(tls_index* ti);

/* The dynamic thread vector (DTV) pointers may point 0x8000 past the start of
 * each TLS block. This is at least true for PowerPC and Mips platforms.
 * See: https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/powerpc/dl-tls.h;h=f7cf6f96ebfb505abfd2f02be0ad0e833107c0cd;hb=HEAD#l34
 *      https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/mips/dl-tls.h;h=93a6dc050cb144b9f68b96fb3199c60f5b1fcd18;hb=HEAD#l32
 */
version(X86)
    enum TLS_DTV_OFFSET = 0x;
else version(X86_64)
    enum TLS_DTV_OFFSET = 0x;
else version(ARM)
    enum TLS_DTV_OFFSET = 0x;
else version(AArch64)
    enum TLS_DTV_OFFSET = 0x;
else version(SPARC)
    enum TLS_DTV_OFFSET = 0x;
else version(SPARC64)
    enum TLS_DTV_OFFSET = 0x;
else version(PPC)
    enum TLS_DTV_OFFSET = 0x8000;
else version(PPC64)
    enum TLS_DTV_OFFSET = 0x8000;
else version(MIPS)
    enum TLS_DTV_OFFSET = 0x8000;
else version(MIPS64)
    enum TLS_DTV_OFFSET = 0x8000;
else
    static assert( false, "Platform not supported." );

void[] getTLSRange(size_t mod, size_t sz)
{
    if (mod == 0)
        return null;

    // base offset
    auto ti = tls_index(mod, 0);
    return (__tls_get_addr(&ti)-TLS_DTV_OFFSET)[0 .. sz];
}
