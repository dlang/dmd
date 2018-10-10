/**
 * This code reads ELF files and sections using memory mapped IO.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain
 * Source: $(DRUNTIMESRC core/elf.d)
 */

module core.elf;

version (linux) version = linux_or_bsd;
else version (FreeBSD) version = linux_or_bsd;
else version (DragonFlyBSD) version = linux_or_bsd;

version (linux_or_bsd):

import core.sys.posix.fcntl;
import core.sys.posix.unistd;

version (linux) import core.sys.linux.elf;
version (FreeBSD) import core.sys.freebsd.sys.elf;
version (DragonFlyBSD) import core.sys.dragonflybsd.sys.elf;

struct ElfFile
{
    static bool open(const(char)* path, out ElfFile file) @nogc nothrow
    {
        file.fd = .open(path, O_RDONLY);
        if (file.fd < 0)
            return false;

        // memory map header
        file.ehdr = MMapRegion!Elf_Ehdr(file.fd, 0, Elf_Ehdr.sizeof);
        return isValidElfHeader(*file.ehdr);
    }

    @disable this(this);

    ~this() @nogc nothrow
    {
        if (fd != -1) close(fd);
    }

    int fd = -1;
    MMapRegion!Elf_Ehdr ehdr;

    bool findSectionHeaderByName(const(char)[] sectionName, out ElfSectionHeader header) const @nogc nothrow
    {
        const index = findSectionIndexByName(sectionName);
        if (index == -1)
            return false;
        header = ElfSectionHeader(this, index);
        return true;
    }

    size_t findSectionIndexByName(const(char)[] sectionName) const @nogc nothrow
    {
        const stringSectionHeader = ElfSectionHeader(this, ehdr.e_shstrndx);
        const stringSection = ElfSection(this, stringSectionHeader);

        foreach (i; 0 .. ehdr.e_shnum)
        {
            auto sectionHeader = ElfSectionHeader(this, i);
            auto currentName = getSectionName(stringSection, sectionHeader.sh_name);
            if (sectionName == currentName)
                return i;
        }

        // not found
        return -1;
    }
}

struct ElfSectionHeader
{
    this(ref const ElfFile file, size_t index) @nogc nothrow
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
    this(ref const ElfFile file, ref const ElfSectionHeader shdr) @nogc nothrow
    {
        data = MMapRegion!void(
            file.fd,
            shdr.sh_offset,
            shdr.sh_size,
        );

        length = shdr.sh_size;
    }

    @disable this(this);

    const(void)[] get() const @nogc nothrow
    {
        return data.get()[0 .. length];
    }

    alias get this;

    MMapRegion!void data;
    size_t length;
}

private:

const(char)[] getSectionName(ref const ElfSection stringSection, size_t nameIndex) @nogc nothrow
{
    const data = cast(const(ubyte[])) stringSection.get();

    foreach (i; nameIndex .. data.length)
    {
        if (data[i] == 0)
            return cast(const(char)[]) data[nameIndex .. i];
    }

    return null;
}

bool isValidElfHeader(ref const Elf_Ehdr ehdr) @nogc nothrow
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
