// EXTRA_SOURCES: imports/testptrref_tmpl.d imports/testptrref_usetmpl.d
// COMPILE_SEPARATELY

module testptrref;
import imports.testptrref_tmpl : TStruct;
import imports.testptrref_usetmpl;

version (CRuntime_Glibc) version = UseELF;
else version (FreeBSD) version = UseELF;
else version (NetBSD) version = UseELF;

version(CRuntime_Microsoft)
{
    extern(C)
    {
        extern __gshared uint _DP_beg;
        extern __gshared uint _DP_end;
        extern __gshared uint _TP_beg;
        extern __gshared uint _TP_end;
        extern int _tls_start;
        extern int _tls_end;
    }
    alias _DPbegin = _DP_beg;
    alias _DPend = _DP_end;
    alias _TPbegin = _TP_beg;
    alias _TPend = _TP_end;
    alias _tlsstart = _tls_start;
    alias _tlsend = _tls_end;

    __gshared void[] dataSection;
    shared static this()
    {
        import core.internal.traits : externDFunc;
        alias findImageSection = externDFunc!("rt.sections_win64.findImageSection",
                                              void[] function(string name) nothrow @nogc);
        dataSection = findImageSection(".data");
    }

    version = ptrref_supported;
}
else version(Win32)
{
    extern(C)
    {
        extern __gshared void* _DPbegin;
        extern __gshared void* _DPend;
        extern __gshared uint _TPbegin;
        extern __gshared uint _TPend;
        extern int _tlsstart;
        extern int _tlsend;
    }
    version = ptrref_supported;
}
else version(UseELF)
{
    version(linux)
    {
        import core.sys.linux.elf;
        import core.sys.linux.link;
    }
    else version (FreeBSD)
    {
        import core.sys.freebsd.sys.elf;
        import core.sys.freebsd.sys.link_elf;
    }
    else version (NetBSD)
    {
        import core.sys.netbsd.sys.elf;
        import core.sys.netbsd.sys.link_elf;
    }
    else
    {
        static assert(0, "unimplemented");
    }

    extern extern(C) __gshared int __start_dat_ptr;
    extern extern(C) __gshared int __stop_dat_ptr;
    extern extern(C) __gshared int __start_tls_ptr;
    extern extern(C) __gshared int __stop_tls_ptr;

    alias _DPbegin = __start_dat_ptr;
    alias _DPend = __stop_dat_ptr;
    alias _TPbegin = __start_tls_ptr;
    alias _TPend = __stop_tls_ptr;

    extern extern(C) int _tlsstart;
    extern extern(C) int _tlsend;

    __gshared void[] imgTlsRange;
    __gshared size_t dlpi_tls_modid;

    import core.internal.traits : externDFunc;
    alias getTLSRange = externDFunc!("rt.sections_elf_shared.getTLSRange",
                                     void[] function(size_t mod, size_t sz) nothrow @nogc);

    shared static this()
    {
        alias fnFindDSOInfoForAddr = bool function(in void* addr, dl_phdr_info* result=null) nothrow @nogc;
        alias findDSOInfoForAddr = externDFunc!("rt.sections_elf_shared.findDSOInfoForAddr",
                                                fnFindDSOInfoForAddr);

        size_t tlsSize;
        dl_phdr_info info = void;
        findDSOInfoForAddr(&imgTlsRange, &info) || assert(0);
        debug(PRINT) printf("dlpi_tls_modid=%p\n", info.dlpi_tls_modid);
        dlpi_tls_modid = info.dlpi_tls_modid;

        foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
            if (phdr.p_type == PT_TLS)
                imgTlsRange = (cast(void*)(info.dlpi_addr + phdr.p_vaddr))[0..phdr.p_memsz];
    }

    version = ptrref_supported;
}

struct Struct
{
    int x;
    Struct* next;
}

class Class
{
    void* ptr;
}

struct Struc(T)
{
	static T vtls;
	static __gshared T vgshared;
}

__gshared Struct* gsharedStrctPtr2 = new Struct(7, new Struct(8, null));

int tlsInt;
void* tlsVar;

shared int sharedInt;
shared void* sharedVar;
__gshared void* gsharedVar;
__gshared void* gsharedVar2;
immutable int[] arr = [1, 2, 3];
string tlsStr;

__gshared Struct gsharedStrct;
Struct[3] tlsStrcArr;
Class tlsClss;

// expression initializers
string[] strArr = [ "a", "b" ];
__gshared Class gsharedClss = new Class;
__gshared Struct* gsharedStrctPtr = new Struct(7, new Struct(8, null));

debug(PRINT) import core.stdc.stdio;

void main()
{
    version(ptrref_supported)
        testRefPtr();
}

version(ptrref_supported):

bool findTlsPtr(const(void)* ptr)
{
    version(UseELF) auto tlsRange = getTLSRange(dlpi_tls_modid, imgTlsRange.length);

    debug(PRINT) printf("findTlsPtr %p\n", ptr);
    for (auto p = &_TPbegin; p < &_TPend; p++)
    {
        version(UseELF)
            void* addr = cast(void*) p + *p + (tlsRange.ptr - imgTlsRange.ptr);
        else
            void* addr = cast(void*) &_tlsstart + *p;
        debug(PRINTTRY) printf("  try %p -> %p\n", cast(void*) cast(size_t) *p, addr);

        // for ELF, _tlsstart doesn't point at the actual start of TLS, and there's
        //  even a variable before it (strArr in this file)
        version(UseELF) assert(tlsRange.ptr <= addr && addr < tlsRange.ptr + tlsRange.length);
        else            assert(&_tlsstart <= addr && addr < &_tlsend);

        if (addr == ptr)
            return true;
    }
    return false;
}

bool findDataPtr(const(void)* ptr)
{
    debug(PRINT) printf("findDataPtr %p\n", ptr);
    for (auto p = &_DPbegin; p < &_DPend; p++)
    {
        version(UseELF)
            void* addr = cast(void*)p + *p;
        else version(CRuntime_Microsoft)
            void* addr = dataSection.ptr + *p;
        else
            void* addr = *p;

        debug(PRINTTRY) printf("  try %p -> %p\n", cast(void*) cast(size_t) *p, addr);
        if (addr == ptr)
            return true;
    }
    return false;
}

void testRefPtr()
{
    debug(PRINT) printf("&_DPbegin %p\n", &_DPbegin);
    debug(PRINT) printf("&_DPend   %p\n", &_DPend);
    debug(PRINT) printf("&_tlsstart %p\n", &_tlsstart);
    debug(PRINT) printf("&_tlsend   %p\n", &_tlsend);
    version(UseELF)
        debug(PRINT) printf("_tlsRange  [%p,%p]\n", imgTlsRange.ptr, imgTlsRange.ptr + imgTlsRange.length);

    assert(!findDataPtr(cast(void*)&sharedInt));

    assert(findDataPtr(cast(void*)&sharedVar));
    assert(findDataPtr(&gsharedVar));
    assert(findDataPtr(&gsharedStrct.next));
    assert(findDataPtr(&(gsharedClss)));
    assert(findDataPtr(&(gsharedClss.ptr)));
    assert(findDataPtr(&(TStruct!Class.gsharedInstance)));
    assert(findDataPtr(&(TStruct!(int*).gsharedInstance)));
    assert(!findDataPtr(&(TStruct!long.gsharedInstance)));
    assert(&(TStruct!(int*).gsharedInstance) is intPtrInstance());

    assert(!findTlsPtr(&tlsInt));
    assert(findTlsPtr(&tlsVar));
    assert(findTlsPtr(&tlsClss));
    assert(findTlsPtr(&tlsStrcArr[0].next));
    assert(findTlsPtr(&tlsStrcArr[1].next));
    assert(findTlsPtr(&tlsStrcArr[2].next));
    assert(findTlsPtr(&(TStruct!Class.tlsInstance)));
    assert(findTlsPtr(&(TStruct!(int*).tlsInstance)));
    assert(!findTlsPtr(&(TStruct!long.tlsInstance)));

    assert(!findTlsPtr(cast(size_t*)&tlsStr)); // length
    assert(findTlsPtr(cast(size_t*)&tlsStr + 1)); // ptr

    // monitor is manually managed
    assert(!findDataPtr(cast(size_t*)cast(void*)Class.classinfo + 1));
    assert(!findDataPtr(cast(size_t*)cast(void*)Class.classinfo + 1));

    assert(!findDataPtr(&arr));
    assert(!findTlsPtr(&arr));
    assert(!findDataPtr(cast(size_t*)&arr + 1));
    assert(!findTlsPtr(cast(size_t*)&arr + 1));

    assert(findTlsPtr(cast(size_t*)&strArr + 1));
    assert(findDataPtr(cast(size_t*)&strArr[0] + 1)); // ptr in _DATA!
    assert(findDataPtr(cast(size_t*)&strArr[1] + 1)); // ptr in _DATA!
    strArr[1] = "c";

    assert(findDataPtr(&gsharedStrctPtr));
    assert(findDataPtr(&gsharedStrctPtr.next));
    assert(findDataPtr(&gsharedStrctPtr.next.next));

    assert(findDataPtr(&(Struc!(int*).vgshared)));
    assert(!findDataPtr(&(Struc!(int).vgshared)));
    assert(findTlsPtr(&(Struc!(int*).vtls)));
    assert(!findTlsPtr(&(Struc!(int).vtls)));
}
