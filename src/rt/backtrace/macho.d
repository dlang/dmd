/**
 * This module extracts debug info from the currently running Mach-O executable.
 *
 * Copyright: Copyright Jacob Carlborg 2018.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Jacob Carlborg
 * Source:    $(DRUNTIMESRC rt/backtrace/macho.d)
 */
module rt.backtrace.macho;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin):

import core.stdc.config : c_ulong;

version (D_LP64)
{
    import core.sys.darwin.mach.loader :
        MachHeader = mach_header_64,
        Section = section_64;
}

else
{
    import core.sys.darwin.mach.loader :
        MachHeader = mach_header,
        Section = section;
}

private extern (C)
{
    MachHeader* _NSGetMachExecuteHeader();

    ubyte* getsectiondata(
        in MachHeader* mhp,
        in char* segname,
        in char* sectname,
        c_ulong* size
    );
}

struct Image
{
    private MachHeader* self;

    static Image openSelf()
    {
        return Image(_NSGetMachExecuteHeader());
    }

    @property bool isValid()
    {
        return self !is null;
    }

    T processDebugLineSectionData(T)(scope T delegate(const(ubyte)[]) processor)
    {
        c_ulong size;
        auto data = getsectiondata(self, "__DWARF", "__debug_line", &size);
        return processor(data[0 .. size]);
    }

    @property size_t baseAddress()
    {
        return 0;
    }
}
