/**
 * This code simplifies working with ELF binaries, e.g., iterating
 * over loaded shared objects & their segments as well as reading
 * headers and sections from ELF files.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain, Martin Kinkelin
 * Source: $(DRUNTIMESRC core/elf.d)
 */

module core.elf;

version (linux)             version = linux_or_bsd;
else version (FreeBSD)      version = linux_or_bsd;
else version (DragonFlyBSD) version = linux_or_bsd;

version (linux_or_bsd):

import core.stdc.string : strlen;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;

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

alias Elf_Phdr = ElfW!"Phdr";
alias Elf_Ehdr = ElfW!"Ehdr";
alias Elf_Shdr = ElfW!"Shdr";

/****
 * Enables iterating over the process' currently loaded shared objects.
 */
struct SharedObjects
{
@nogc nothrow:
    alias Callback = int delegate(SharedObject);

    static int opApply(scope Callback dg)
    {
        extern(C) int nativeCallback(dl_phdr_info* info, size_t, void* data)
        {
            auto dg = *cast(Callback*) data;
            return dg(SharedObject(*info));
        }

        return dl_iterate_phdr(&nativeCallback, &dg);
    }
}

struct SharedObject
{
@nogc nothrow:
    /****
     * Finds the shared object containing the specified address in one of its segments.
     */
    static bool findForAddress(const scope void* address, out SharedObject result)
    {
        version (linux)       enum IterateManually = true;
        else version (NetBSD) enum IterateManually = true;
        else                  enum IterateManually = false;

        static if (IterateManually)
        {
            foreach (object; SharedObjects)
            {
                const(Elf_Phdr)* segment;
                if (object.findSegmentForAddress(address, segment))
                {
                    result = object;
                    return true;
                }
            }
            return false;
        }
        else
        {
            return !!_rtld_addr_phdr(address, &result.info);
        }
    }

    dl_phdr_info info;

    void* baseAddress() const
    {
        return cast(void*) info.dlpi_addr;
    }

    const(char)[] name() const
    {
        const(char)* cstr = info.dlpi_name;

        // the main executable has an empty name
        if (cstr[0] == 0)
            cstr = getprogname();

        return cstr[0 .. strlen(cstr)];
    }

    /****
     * Iterates over this object's segments.
     */
    int opApply(scope int delegate(ref const Elf_Phdr) @nogc nothrow dg) const
    {
        foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
        {
            const r = dg(phdr);
            if (r != 0)
                return r;
        }
        return 0;
    }

    bool findSegmentForAddress(const scope void* address, out const(Elf_Phdr)* result) const
    {
        if (address < baseAddress())
            return false;

        foreach (ref phdr; this)
        {
            const begin = baseAddress() + phdr.p_vaddr;
            if (cast(size_t)(address - begin) < phdr.p_memsz)
            {
                result = &phdr;
                return true;
            }
        }
        return false;
    }
}

// -------------------------------
//  File-based memory-mapped I/O:
// -------------------------------

struct ElfFile
{
@nogc nothrow:
    static bool open(const(char)* path, out ElfFile file)
    {
        file = ElfFile(.open(path, O_RDONLY));
        return file.isValid();
    }

    this(int fd)
    {
        this.fd = fd;
        if (fd != -1)
        {
            // memory map header
            this.ehdr = MMapRegion!Elf_Ehdr(fd, 0);
        }
    }

    @disable this(this);

    ~this()
    {
        if (fd != -1)
            close(fd);
    }

    private int fd = -1;
    MMapRegion!Elf_Ehdr ehdr;

    bool isValid() const
    {
        return fd != -1 && isValidElfHeader(*ehdr);
    }

    bool findSectionHeaderByName(const(char)[] sectionName, out ElfSectionHeader header) const
    {
        const index = findSectionIndexByName(sectionName);
        if (index == -1)
            return false;
        header = ElfSectionHeader(this, index);
        return true;
    }

    size_t findSectionIndexByName(const(char)[] sectionName) const
    {
        const stringSectionHeader = ElfSectionHeader(this, ehdr.e_shstrndx);
        const stringSection = ElfSection(this, stringSectionHeader);

        foreach (i; 0 .. ehdr.e_shnum)
        {
            auto sectionHeader = ElfSectionHeader(this, i);
            auto pCurrentName = cast(const(char)*) (stringSection.data.ptr + sectionHeader.sh_name);
            auto currentName = pCurrentName[0 .. strlen(pCurrentName)];
            if (sectionName == currentName)
                return i;
        }

        // not found
        return -1;
    }
}

struct ElfSectionHeader
{
@nogc nothrow:
    this(ref const ElfFile file, size_t index)
    {
        assert(Elf_Shdr.sizeof == file.ehdr.e_shentsize);
        shdr = MMapRegion!Elf_Shdr(
            file.fd,
            file.ehdr.e_shoff + index * Elf_Shdr.sizeof
        );
    }

    @disable this(this);

    alias shdr this;
    MMapRegion!Elf_Shdr shdr;
}

struct ElfSection
{
@nogc nothrow:
    this(ref const ElfFile file, ref const ElfSectionHeader shdr)
    {
        mappedRegion = MMapRegion!void(file.fd, shdr.sh_offset, shdr.sh_size);
        size = shdr.sh_size;
    }

    @disable this(this);

    const(void)[] data() const
    {
        return mappedRegion.data[0 .. size];
    }

    alias data this;

private:
    MMapRegion!void mappedRegion;
    size_t size;
}

private @nogc nothrow:

version (linux)
{
    const(char)* getprogname()
    {
        import core.sys.linux.errno;
        return program_invocation_name;
    }
}
else
{
    extern(C) const(char)* getprogname();
}

bool isValidElfHeader(ref const Elf_Ehdr ehdr)
{
    version (D_LP64) alias ELFCLASS = ELFCLASS64;
    else             alias ELFCLASS = ELFCLASS32;

    version (LittleEndian)   alias ELFDATA = ELFDATA2LSB;
    else version (BigEndian) alias ELFDATA = ELFDATA2MSB;
    else static assert(0, "unsupported byte order");

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
@nogc nothrow:
    import core.sys.posix.sys.mman;
    import core.sys.posix.unistd;

    this(int fd, size_t offset, size_t length = 1)
    {
        const pageSize = sysconf(_SC_PAGESIZE);
        const pagedOffset = (offset / pageSize) * pageSize;
        const offsetDiff = offset - pagedOffset;
        const mappedSize = length * T.sizeof + offsetDiff;

        auto ptr = cast(ubyte*) mmap(null, mappedSize, PROT_READ, MAP_PRIVATE, fd, pagedOffset);

        mappedRegion = ptr[0 .. mappedSize];
        data = cast(T*) (ptr + offsetDiff);
    }

    @disable this(this);

    ~this()
    {
        if (mappedRegion !is null)
            munmap(mappedRegion.ptr, mappedRegion.length);
    }

    alias data this;

    private ubyte[] mappedRegion;
    const(T)* data;
}
