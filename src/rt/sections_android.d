/**
 * Written in the D programming language.
 * This module provides bionic-specific support for sections.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC rt/_sections_android.d)
 */

module rt.sections_android;

version (CRuntime_Bionic):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.internal.elf.dl : SharedObject;
import core.sys.posix.pthread;
import core.stdc.stdlib : calloc, malloc, free;
import core.stdc.string : memcpy;
import rt.deh;
import rt.minfo;
import rt.util.utility : safeAssert;

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

    @property ref inout(ModuleGroup) moduleGroup() inout nothrow @nogc
    {
        return _moduleGroup;
    }

    @property immutable(FuncTable)[] ehTables() const nothrow @nogc
    {
        auto pbeg = cast(immutable(FuncTable)*)&__start_deh;
        auto pend = cast(immutable(FuncTable)*)&__stop_deh;
        return pbeg[0 .. pend - pbeg];
    }

    @property inout(void[])[] gcRanges() inout nothrow @nogc
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][1] _gcRanges;
}

void initSections() nothrow @nogc
{
    pthread_key_create(&_tlsKey, null);

    SharedObject object;
    const success = SharedObject.findForAddress(&_sections, object);
    safeAssert(success, "cannot find ELF object");

    _staticTLSRange = getStaticTLSRange(object);

    version (LDC)
    {
        auto mbeg = cast(immutable ModuleInfo**)&__start___minfo;
        auto mend = cast(immutable ModuleInfo**)&__stop___minfo;
    }
    else
    {
        auto mbeg = cast(immutable ModuleInfo**)&__start_minfo;
        auto mend = cast(immutable ModuleInfo**)&__stop_minfo;
    }
    _sections.moduleGroup = ModuleGroup(mbeg[0 .. mend - mbeg]);

    // iterate over ELF segments to determine data segment range
    import core.sys.linux.elf;
    foreach (ref phdr; object)
    {
        if (phdr.p_type == PT_LOAD && (phdr.p_flags & PF_W)) // writeable data segment
        {
            safeAssert(_sections._gcRanges[0] is null, "expected a single data segment");

            void* start = object.baseAddress + phdr.p_vaddr;
            void* end = start + phdr.p_memsz;
            debug(PRINTF) printf("data segment: %p - %p\n", start, end);

            // exclude static TLS range
            if (_staticTLSRange.length)
            {
                safeAssert(start == _staticTLSRange.ptr,
                    "static TLS range expected to be at start of data segment");
                start += _staticTLSRange.length;
            }

            // pointer-align up
            enum mask = size_t.sizeof - 1;
            start = cast(void*) ((cast(size_t)start + mask) & ~mask);

            _sections._gcRanges[0] = start[0 .. end-start];
        }
    }
}

void finiSections() nothrow @nogc
{
    pthread_key_delete(_tlsKey);
}

void[]* initTLSRanges() nothrow @nogc
{
    return &getTLSBlock();
}

void finiTLSRanges(void[]* rng) nothrow @nogc
{
    free(rng.ptr);
    free(rng);
}

void scanTLSRanges(void[]* rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    dg(rng.ptr, rng.ptr + rng.length);
}

/* NOTE: The Bionic C library ignores thread-local data stored in the normal
 *       .tbss/.tdata ELF sections, which are marked with the SHF_TLS/STT_TLS
 *       flags.  So instead we roll our own by keeping TLS data in the
 *       .tdata/.tbss sections but removing the SHF_TLS/STT_TLS flags, and
 *       access the TLS data using this function.
 *
 *       This function is called by the code emitted by the compiler.  It
 *       is expected to translate an address in the TLS static data to
 *       the corresponding address in the TLS dynamic per-thread data.
 */
extern(C) void* __tls_get_addr(void* p) nothrow @nogc
{
    debug(PRINTF) printf("  __tls_get_addr input - %p\n", p);
    const offset = cast(size_t) (p - _staticTLSRange.ptr);
    assert(offset < _staticTLSRange.length,
        "invalid TLS address or initSections() not called yet");
    // The following would only be safe if no TLS variables are accessed
    // before calling initTLSRanges():
    //return (cast(void[]*) pthread_getspecific(_tlsKey)).ptr + offset;
    return getTLSBlock().ptr + offset;
}

private:

__gshared pthread_key_t _tlsKey;
__gshared void[] _staticTLSRange;
__gshared SectionGroup _sections;

ref void[] getTLSBlock() nothrow @nogc
{
    auto pary = cast(void[]*) pthread_getspecific(_tlsKey);

    version (LDC)
    {
        import ldc.intrinsics;
        const isUninitialized = llvm_expect(pary is null, false);
    }
    else
        const isUninitialized = pary is null;

    if (isUninitialized)
    {
        pary = cast(void[]*) calloc(1, (void[]).sizeof);
        safeAssert(pary !is null, "cannot allocate TLS block slice");

        if (pthread_setspecific(_tlsKey, pary) != 0)
        {
            import core.stdc.stdio;
            perror("pthread_setspecific failed with");
            assert(0);
        }

        safeAssert(_staticTLSRange.ptr !is null, "initSections() not called yet");
        if (const size = _staticTLSRange.length)
        {
            auto p = malloc(size);
            safeAssert(p !is null, "cannot allocate TLS block");
            memcpy(p, _staticTLSRange.ptr, size);
            *pary = p[0 .. size];
        }
    }

    return *pary;
}

void[] getStaticTLSRange(const ref SharedObject object) nothrow @nogc
{
    import core.internal.elf.io;

    const(char)[] path = object.name();
    char[512] pathBuffer = void;
    if (path[0] != '/')
    {
        path = object.getPath(pathBuffer);
        safeAssert(path !is null, "cannot get path of ELF object");
    }
    debug(PRINTF) printf("ELF file path: %s\n", path.ptr);

    ElfFile file;
    const success = ElfFile.open(path.ptr, file);
    safeAssert(success, "cannot open ELF file");

    void* start, end;
    foreach (index, name, sectionHeader; file.namedSections)
    {
        if (name == ".tdata" || name == ".tbss")
        {
            void* sectionStart = object.baseAddress + sectionHeader.sh_addr;
            void* sectionEnd = sectionStart + sectionHeader.sh_size;
            debug(PRINTF) printf("section %s: %p - %p\n", name.ptr, sectionStart, sectionEnd);

            if (!start)
            {
                start = sectionStart;
                end = sectionEnd;
            }
            else
            {
                safeAssert(sectionStart == end, "expected .tdata and .tbss sections to be contiguous");
                end = sectionEnd;
                break; // we've found both sections
            }
        }
    }

    // return an empty but non-null slice if there's no TLS data
    return start ? start[0 .. end-start] : object.baseAddress[0..0];
}

extern(C)
{
    /* Symbols created by the linker and inserted into the object file that
     * 'bracket' sections.
     */
    extern __gshared
    {
        version (LDC)
        {
            void* __start___minfo;
            void* __stop___minfo;
        }
        else
        {
            void* __start_deh;
            void* __stop_deh;
            void* __start_minfo;
            void* __stop_minfo;
        }
    }
}
