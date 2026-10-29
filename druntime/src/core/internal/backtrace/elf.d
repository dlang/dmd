/**
 * This code reads ELF files and sections using memory mapped IO.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2018.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain
 * Source: $(DRUNTIMESRC core/internal/backtrace/elf.d)
 */

module core.internal.backtrace.elf;

version (linux)
{
    import core.sys.linux.elf : SHF_COMPRESSED, ET_DYN;
    version = LinuxOrBSD;
}
else version (FreeBSD)
{
    import core.sys.freebsd.sys.elf : SHF_COMPRESSED, ET_DYN;
    version = LinuxOrBSD;
}
else version (DragonFlyBSD)
{
    import core.sys.dragonflybsd.sys.elf : SHF_COMPRESSED, ET_DYN;
    version = LinuxOrBSD;
}
else version (OpenBSD)
{
    import core.sys.openbsd.sys.elf : SHF_COMPRESSED, ET_DYN;
    version = LinuxOrBSD;
}
else version (Solaris)
{
    import core.sys.solaris.sys.elf : SHF_COMPRESSED, ET_DYN;
    version = LinuxOrBSD;
}
else version (Hurd)
{
    import core.sys.hurd.elf : SHF_COMPRESSED, ET_DYN;
    version = LinuxOrBSD;
}

version (LinuxOrBSD):

import core.internal.backtrace.dwarf : DebugSections;
import core.internal.elf.io;

struct Image
{
    private ElfFile file;

    static Image openSelf()
    {
        import core.stdc.stdlib : free;

        Image image;

        char* selfPath = thisExePath();
        if (selfPath is null)
            return image;
        scope(exit) free(selfPath);

        if (!ElfFile.open(selfPath, image.file))
            image.file = ElfFile.init;

        return image;
    }

    @property bool isValid()
    {
        return file != ElfFile.init;
    }

    T processDebugSections(T)(scope T delegate(ref const DebugSections) processor)
    {
        ElfSection line;
        mapSection(".debug_line", line);

        const DebugSections sections = {
            line: cast(const(ubyte)[]) line.data(),
        };
        return processor(sections);
    }

    private void mapSection(const(char)[] name, out ElfSection section)
    {
        ElfSectionHeader header;

        if (file.findSectionHeaderByName(name, header))
        {
            // we don't support compressed debug sections
            if (!(header.shdr.sh_flags & SHF_COMPRESSED))
                section = ElfSection(file, header);
        }
    }

    @property size_t baseAddress()
    {
        import core.internal.elf.dl : SharedObject;

        // the DWARF addresses for DSOs are relative
        const isDynamicSharedObject = (file.ehdr.e_type == ET_DYN);
        if (!isDynamicSharedObject)
            return 0;

        return cast(size_t) SharedObject.thisExecutable().baseAddress;
    }
}
