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

import core.elf;
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

        Image image;
        if (!ElfFile.open(selfPath, image.file))
            image.file = ElfFile.init;

        return image;
    }

    @property bool isValid()
    {
        return file != ElfFile.init;
    }

    const(ubyte)[] getDebugLineSectionData()
    {
        ElfSectionHeader dbgSectionHeader;
        if (!file.findSectionHeaderByName(".debug_line", dbgSectionHeader))
            return null;

        // we don't support compressed debug sections
        if ((dbgSectionHeader.shdr.sh_flags & SHF_COMPRESSED) != 0)
            return null;

        // debug_line section found and loaded
        return cast(const(ubyte)[]) ElfSection(file, dbgSectionHeader).get();
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
