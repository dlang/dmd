// REQUIRED_ARGS: -g

void main()
{
    version(OSX) testDebugLineMacOS();
}

version (OSX):

struct mach_header;
struct mach_header_64;
struct section;
struct section_64;

version (D_LP64)
{
    alias MachHeader = mach_header_64;
    alias Section = section_64;
}

else
{
    alias MachHeader = mach_header;
    alias Section = section;
}

extern (C)
{
    MachHeader* _dyld_get_image_header(uint image_index);
    const(section)* getsectbynamefromheader(in mach_header* mhp, in char* segname, in char* sectname);
    const(section_64)* getsectbynamefromheader_64(in mach_header_64* mhp, in char* segname, in char* sectname);
}

const(Section)* getSectByNameFromHeader(MachHeader* mhp, in char* segname, in char* sectname)
{
    version (D_LP64)
        return getsectbynamefromheader_64(mhp, segname, sectname);
    else
        return getsectbynamefromheader(mhp, segname, sectname);
}

void testDebugLineMacOS()
{
    auto header = _dyld_get_image_header(0);
    assert(header);

    auto section = getSectByNameFromHeader(header, "__DWARF", "__debug_line");
    // verify that the __debug_line section is present in the final executable
    assert(section);
}
