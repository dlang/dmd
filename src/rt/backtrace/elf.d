/**
 * This code reads ELF files and sections using memory mapped IO.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain
 * Source: $(DRUNTIMESRC src/rt/backtrace/elf.d)
 */

module rt.backtrace.elf;

version(linux) version = linux_or_freebsd;
else version(FreeBSD) version = linux_or_freebsd;

version(linux_or_freebsd):

import core.sys.posix.fcntl;
import core.sys.posix.unistd;

version(linux) public import core.sys.linux.elf;
version(FreeBSD) public import core.sys.freebsd.sys.elf;

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

version(X86)
{
    alias Elf_Ehdr = Elf32_Ehdr;
    alias Elf_Shdr = Elf32_Shdr;
    enum ELFCLASS = ELFCLASS32;
}
else version(X86_64)
{
    alias Elf_Ehdr = Elf64_Ehdr;
    alias Elf_Shdr = Elf64_Shdr;
    enum ELFCLASS = ELFCLASS64;
}
else
{
    static assert(0, "unsupported architecture");
}

version(LittleEndian)
{
    alias ELFDATA = ELFDATA2LSB;
}
else version(BigEndian)
{
    alias ELFDATA = ELFDATA2MSB;
}
else
{
    static assert(0, "unsupported byte order");
}
