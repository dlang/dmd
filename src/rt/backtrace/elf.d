/**
 * This code reads ELF files and sections using memory mapped IO.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2018.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain
 * Source: $(DRUNTIMESRC rt/backtrace/elf.d)
 */

module rt.backtrace.elf;

version (linux)
{
    import core.sys.linux.elf;
    version = LinuxOrBSD;
}
else version (FreeBSD)
{
    import core.sys.freebsd.sys.elf;
    version = LinuxOrBSD;
}
else version (DragonFlyBSD)
{
    import core.sys.dragonflybsd.sys.elf;
    version = LinuxOrBSD;
}

version (LinuxOrBSD):

import core.elf.dl;
import core.elf.io;

struct Image
{
    private ElfFile file;

    static Image openSelf()
    {
        const(char)* selfPath;
        foreach (object; SharedObjects)
        {
            // the first object is the main binary
            selfPath = object.name().ptr;
            break;
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

    T processDebugLineSectionData(T)(scope T delegate(const(ubyte)[]) processor)
    {
        ElfSectionHeader dbgSectionHeader;
        ElfSection dbgSection;

        if (file.findSectionHeaderByName(".debug_line", dbgSectionHeader))
        {
            // we don't support compressed debug sections
            if (!(dbgSectionHeader.shdr.sh_flags & SHF_COMPRESSED))
                dbgSection = ElfSection(file, dbgSectionHeader);
        }

        return processor(cast(const(ubyte)[]) dbgSection.data());
    }

    @property size_t baseAddress()
    {
        // the DWARF addresses for DSOs are relative
        const isDynamicSharedObject = (file.ehdr.e_type == ET_DYN);
        if (!isDynamicSharedObject)
            return 0;

        size_t base = 0;
        foreach (object; SharedObjects)
        {
            // only take the first address as this will be the main binary
            base = cast(size_t) object.baseAddress;
            break;
        }

        return base;
    }
}
