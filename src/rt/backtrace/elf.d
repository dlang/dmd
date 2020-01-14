/**
 * This code reads ELF files and sections using memory mapped IO.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain
 * Source: $(DRUNTIMESRC rt/backtrace/elf.d)
 */

module rt.backtrace.elf;

version (linux) version = linux_or_bsd;
else version (FreeBSD) version = linux_or_bsd;
else version (DragonFlyBSD) version = linux_or_bsd;

version (linux_or_bsd):

import core.sys.posix.fcntl;
import core.sys.posix.unistd;

version (linux) import core.sys.linux.elf;
version (FreeBSD) import core.sys.freebsd.sys.elf;
version (DragonFlyBSD) import core.sys.dragonflybsd.sys.elf;

struct Image
{
    private ElfFile file;

    static Image openSelf()
    {
        Image image;

        if (!ElfFile.openSelf(&image.file))
            image.file = ElfFile.init;

        return image;
    }

    @property bool isValid()
    {
        return file != ElfFile.init;
    }

    const(ubyte)[] getDebugLineSectionData()
    {
        auto stringSectionHeader = ElfSectionHeader(&file, file.ehdr.e_shstrndx);
        auto stringSection = ElfSection(&file, &stringSectionHeader);

        auto dbgSectionIndex = findSectionByName(&file, &stringSection, ".debug_line");
        if (dbgSectionIndex != -1)
        {
            auto dbgSectionHeader = ElfSectionHeader(&file, dbgSectionIndex);
            // we don't support compressed debug sections
            if ((dbgSectionHeader.shdr.sh_flags & SHF_COMPRESSED) != 0)
                return null;
            // debug_line section found and loaded
            return ElfSection(&file, &dbgSectionHeader);
        }

        return null;
    }

    @property size_t baseAddress()
    {
        version (linux)
        {
            import core.sys.linux.link;
            import core.sys.linux.elf;
        }
        else version (FreeBSD)
        {
            import core.sys.freebsd.sys.link_elf;
            import core.sys.freebsd.sys.elf;
        }
        else version (DragonFlyBSD)
        {
            import core.sys.dragonflybsd.sys.link_elf;
            import core.sys.dragonflybsd.sys.elf;
        }

        static struct ElfAddress
        {
            size_t begin;
            bool set;
        }
        ElfAddress elfAddress;

        // the DWARF addresses for DSOs are relative
        const isDynamicSharedObject = (file.ehdr.e_type == ET_DYN);
        if (!isDynamicSharedObject)
            return 0;

        extern(C) int dl_iterate_phdr_cb_ngc_tracehandler(dl_phdr_info* info, size_t, void* elfObj) @nogc
        {
            auto obj = cast(ElfAddress*) elfObj;
            // only take the first address as this will be the main binary
            if (obj.set)
                return 0;

            obj.set = true;

            // use the base address of the object file
            obj.begin = info.dlpi_addr;
            return 0;
        }
        dl_iterate_phdr(&dl_iterate_phdr_cb_ngc_tracehandler, &elfAddress);
        return elfAddress.begin;
    }
}

private:

struct ElfFile
{
    static bool openSelf(ElfFile* file) @nogc nothrow
    {
        version (linux)
        {
            auto selfPath = "/proc/self/exe".ptr;
        }
        else version (FreeBSD)
        {
            char[1024] selfPathBuffer = void;
            auto selfPath = getFreeBSDExePath(selfPathBuffer[]);
            if (selfPath is null) return false;
        }
        else version (DragonFlyBSD)
        {
            auto selfPath = "/proc/curproc/file".ptr;
        }

        file.fd = open(selfPath, O_RDONLY);
        if (file.fd >= 0)
        {
            // memory map header
            file.ehdr = MMapRegion!Elf_Ehdr(file.fd, 0, Elf_Ehdr.sizeof);
            if (file.ehdr.isValidElfHeader())
                return true;
            else
                return false;
        }
        else
            return false;
    }

    @disable this(this);

    ~this() @nogc nothrow
    {
        if (fd != -1) close(fd);
    }

    int fd = -1;
    MMapRegion!Elf_Ehdr ehdr;
}

struct ElfSectionHeader
{
    this(const(ElfFile)* file, size_t index) @nogc nothrow
    {
        assert(Elf_Shdr.sizeof == file.ehdr.e_shentsize);
        shdr = MMapRegion!Elf_Shdr(
            file.fd,
            file.ehdr.e_shoff + index * file.ehdr.e_shentsize,
            file.ehdr.e_shentsize
        );
    }

    @disable this(this);

    alias shdr this;
    MMapRegion!Elf_Shdr shdr;
}

struct ElfSection
{
    this(ElfFile* file, ElfSectionHeader* shdr) @nogc nothrow
    {
        data = MMapRegion!ubyte(
            file.fd,
            shdr.sh_offset,
            shdr.sh_size,
        );

        length = shdr.sh_size;
    }

    @disable this(this);

    const(ubyte)[] get() @nogc nothrow
    {
        return data.get()[0 .. length];
    }

    alias get this;

    MMapRegion!ubyte data;
    size_t length;
}

const(char)[] getSectionName(const(ElfFile)* file, ElfSection* stringSection, size_t nameIndex) @nogc nothrow
{
    const(ubyte)[] data = stringSection.get();

    foreach (i; nameIndex .. data.length)
    {
        if (data[i] == 0)
            return cast(const(char)[])data[nameIndex .. i];
    }

    return null;
}

size_t findSectionByName(const(ElfFile)* file, ElfSection* stringSection, const(char)[] sectionName) @nogc nothrow
{
    foreach (s; 0 .. file.ehdr.e_shnum)
    {
        auto sectionHeader = ElfSectionHeader(file, s);
        auto currentName = getSectionName(file, stringSection, sectionHeader.sh_name);
        if (sectionName == currentName)
            return s; // TODO: attempt to move ElfSectionHeader instead of returning index
    }

    // not found
    return -1;
}

private:

version (FreeBSD)
{
    extern (C) int sysctl(const int* name, uint namelen, void* oldp, size_t* oldlenp, const void* newp, size_t newlen) @nogc nothrow;
    const(char)* getFreeBSDExePath(char[] buffer) @nogc nothrow
    {
        enum
        {
            CTL_KERN = 1,
            KERN_PROC = 14,
            KERN_PROC_PATHNAME = 12
        }

        int[4] mib = [CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, -1];
        size_t len = buffer.length;

        auto result = sysctl(mib.ptr, mib.length, buffer.ptr, &len, null, 0); // get the length of the path
        if (result != 0) return null;
        if (len + 1 > buffer.length) return null;
        buffer[len] = 0;
        return buffer.ptr;
    }
}

bool isValidElfHeader(const(Elf_Ehdr)* ehdr) @nogc nothrow
{
    if (ehdr.e_ident[EI_MAG0] != ELFMAG0) return false;
    if (ehdr.e_ident[EI_MAG1] != ELFMAG1) return false;
    if (ehdr.e_ident[EI_MAG2] != ELFMAG2) return false;
    if (ehdr.e_ident[EI_MAG3] != ELFMAG3) return false;

    // elf class and data encoding should match target's config
    if (ehdr.e_ident[EI_CLASS] != ELFCLASS) return false;
    if (ehdr.e_ident[EI_DATA]  != ELFDATA ) return false;

    return true;
}

struct MMapRegion(T)
{
    import core.sys.posix.sys.mman;
    import core.sys.posix.unistd;

    this(int fd, size_t offset, size_t length) @nogc nothrow
    {
        auto pagesize = sysconf(_SC_PAGESIZE);

        auto realOffset = (offset / pagesize) * pagesize;
        offsetDiff = offset - realOffset;
        realLength = length + offsetDiff;

        mptr = mmap(null, realLength, PROT_READ, MAP_PRIVATE, fd, realOffset);
    }

    @disable this(this);

    ~this() @nogc nothrow
    {
        if (mptr) munmap(mptr, realLength);
    }

    const(T)* get() const @nogc nothrow
    {
        return cast(T*)(mptr + offsetDiff);
    }

    alias get this;

    size_t realLength;
    size_t offsetDiff;
    void* mptr;
}

version (X86)
{
    alias Elf_Ehdr = Elf32_Ehdr;
    alias Elf_Shdr = Elf32_Shdr;
    enum ELFCLASS = ELFCLASS32;
}
else version (X86_64)
{
    version (D_X32)
    {
        alias Elf_Ehdr = Elf32_Ehdr;
        alias Elf_Shdr = Elf32_Shdr;
        enum ELFCLASS = ELFCLASS32;
    }
    else
    {
        alias Elf_Ehdr = Elf64_Ehdr;
        alias Elf_Shdr = Elf64_Shdr;
        enum ELFCLASS = ELFCLASS64;
    }
}
else version (ARM)
{
    alias Elf_Ehdr = Elf32_Ehdr;
    alias Elf_Shdr = Elf32_Shdr;
    enum ELFCLASS = ELFCLASS32;
}
else version (AArch64)
{
    alias Elf_Ehdr = Elf64_Ehdr;
    alias Elf_Shdr = Elf64_Shdr;
    enum ELFCLASS = ELFCLASS64;
}
else version (PPC)
{
    alias Elf_Ehdr = Elf32_Ehdr;
    alias Elf_Shdr = Elf32_Shdr;
    enum ELFCLASS = ELFCLASS32;
}
else version (PPC64)
{
    alias Elf_Ehdr = Elf64_Ehdr;
    alias Elf_Shdr = Elf64_Shdr;
    enum ELFCLASS = ELFCLASS64;
}
else version (MIPS)
{
    alias Elf_Ehdr = Elf32_Ehdr;
    alias Elf_Shdr = Elf32_Shdr;
    enum ELFCLASS = ELFCLASS32;
}
else version (MIPS64)
{
    alias Elf_Ehdr = Elf64_Ehdr;
    alias Elf_Shdr = Elf64_Shdr;
    enum ELFCLASS = ELFCLASS64;
}
else version (SystemZ)
{
    alias Elf_Ehdr = Elf64_Ehdr;
    alias Elf_Shdr = Elf64_Shdr;
    enum ELFCLASS = ELFCLASS64;
}
else
{
    static assert(0, "unsupported architecture");
}

version (LittleEndian)
{
    alias ELFDATA = ELFDATA2LSB;
}
else version (BigEndian)
{
    alias ELFDATA = ELFDATA2MSB;
}
else
{
    static assert(0, "unsupported byte order");
}
