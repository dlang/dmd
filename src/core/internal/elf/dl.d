/**
 * Simplifies working with shared ELF objects of the current process.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2018.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Kinkelin
 * Source: $(DRUNTIMESRC core/internal/elf/dl.d)
 */

module core.internal.elf.dl;

version (linux)
{
    import core.sys.linux.link;
    version = LinuxOrBSD;
}
else version (FreeBSD)
{
    import core.sys.freebsd.sys.link_elf;
    version = LinuxOrBSD;
}
else version (DragonFlyBSD)
{
    import core.sys.dragonflybsd.sys.link_elf;
    version = LinuxOrBSD;
}
else version (NetBSD)
{
    import core.sys.netbsd.sys.link_elf;
    version = LinuxOrBSD;
}
else version (OpenBSD)
{
    import core.sys.openbsd.sys.link_elf;
    version = LinuxOrBSD;
}
else version (Solaris)
{
    import core.sys.solaris.link;
    version = LinuxOrBSD;
}

version (LinuxOrBSD):

alias Elf_Ehdr = ElfW!"Ehdr";
alias Elf_Phdr = ElfW!"Phdr";

/**
 * Enables iterating over the process' currently loaded shared objects.
 */
struct SharedObjects
{
@nogc nothrow:
    ///
    alias Callback = int delegate(SharedObject);

    ///
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

/**
 * A loaded shared ELF object/binary, i.e., executable or shared library.
 */
struct SharedObject
{
@nogc nothrow:
    /// Returns the executable of the current process.
    static SharedObject thisExecutable()
    {
        foreach (object; SharedObjects)
            return object; // first object
        assert(0);
    }

    /**
     * Tries to find the shared object containing the specified address in one of its segments.
     * Returns: True on success.
     */
    static bool findForAddress(const scope void* address, out SharedObject result)
    {
        version (linux)        enum IterateManually = true;
        else version (NetBSD)  enum IterateManually = true;
        else version (OpenBSD) enum IterateManually = true;
        else version (Solaris) enum IterateManually = true;
        else                   enum IterateManually = false;

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

    /// OS-dependent info structure.
    dl_phdr_info info;

    /// Returns the base address of the object.
    @property void* baseAddress() const
    {
        return cast(void*) info.dlpi_addr;
    }

    /// Returns the name of (usually: path to) the object. Null-terminated.
    const(char)[] name() const
    {
        import core.stdc.string : strlen;

        const(char)* cstr = info.dlpi_name;

        // the main executable has an empty name
        if (cstr[0] == 0)
            cstr = getprogname();

        return cstr[0 .. strlen(cstr)];
    }

    /**
     * Tries to fill the specified buffer with the path to the ELF file,
     * according to the /proc/<PID>/maps file.
     *
     * Returns: The filled slice (null-terminated), or null if an error occurs.
     */
    char[] getPath(size_t N)(ref char[N] buffer) const
    if (N > 1)
    {
        import core.stdc.stdio, core.stdc.string, core.sys.posix.unistd;

        char[N + 128] lineBuffer = void;

        snprintf(lineBuffer.ptr, lineBuffer.length, "/proc/%d/maps", getpid());
        auto file = fopen(lineBuffer.ptr, "r");
        if (!file)
            return null;
        scope(exit) fclose(file);

        const thisBase = cast(ulong) baseAddress();
        ulong startAddress;

        // prevent overflowing `buffer` by specifying the max length in the scanf format string
        enum int maxPathLength = N - 1;
        enum scanFormat = "%llx-%*llx %*s %*s %*s %*s %" ~ maxPathLength.stringof ~ "s";

        while (fgets(lineBuffer.ptr, lineBuffer.length, file))
        {
            if (sscanf(lineBuffer.ptr, scanFormat.ptr, &startAddress, buffer.ptr) == 2 &&
                startAddress == thisBase)
                return buffer[0 .. strlen(buffer.ptr)];
        }

        return null;
    }

    /// Iterates over this object's segments.
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

    /**
     * Tries to find the segment containing the specified address.
     * Returns: True on success.
     */
    bool findSegmentForAddress(const scope void* address, out const(Elf_Phdr)* result) const
    {
        if (address < baseAddress)
            return false;

        foreach (ref phdr; this)
        {
            const begin = baseAddress + phdr.p_vaddr;
            if (cast(size_t)(address - begin) < phdr.p_memsz)
            {
                result = &phdr;
                return true;
            }
        }
        return false;
    }
}

private @nogc nothrow:

version (linux)
{
    // TODO: replace with a fixed core.sys.linux.config._GNU_SOURCE
    version (CRuntime_Bionic) {} else version = Linux_Use_GNU;
}

version (Linux_Use_GNU)
{
    const(char)* getprogname()
    {
        import core.sys.linux.errno;
        return program_invocation_name;
    }
}
else // Bionic, BSDs
{
    extern(C) const(char)* getprogname();
}

unittest
{
    import core.stdc.stdio;

    char[512] buffer = void;
    foreach (object; SharedObjects)
    {
        const name = object.name();
        assert(name.length);
        const path = object.getPath(buffer);

        printf("DSO name: %s\n", name.ptr);
        printf("    path: %s\n", path ? path.ptr : "");
        printf("    base: %p\n", object.baseAddress);
    }
}
