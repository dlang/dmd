/**
 * This module extracts debug info from the currently running Mach-O executable.
 *
 * Copyright: Copyright Jacob Carlborg 2018.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Jacob Carlborg
 * Source:    $(DRUNTIMESRC rt/backtrace/macho.d)
 */
module core.internal.backtrace.macho;

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
import core.sys.darwin.crt_externs;
import core.sys.darwin.mach.getsect;
import core.sys.darwin.mach.loader;

struct Image
{
    private mach_header_64* self;

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
