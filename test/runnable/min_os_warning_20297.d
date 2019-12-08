// PERMUTE_ARGS:
// DISABLED: win linux freebsd dragonflybsd netbsd

import core.stdc.stdlib : getenv;
import core.stdc.string : strlen;
import core.sys.darwin.mach.loader : build_version_command, version_min_command,
    mach_header_64, load_command, LC_BUILD_VERSION, LC_VERSION_MIN_MACOSX, PLATFORM_MACOS;
import core.sys.darwin.sys.mman : mmap, munmap, PROT_READ, MAP_FILE, MAP_PRIVATE, MAP_FAILED;
import core.sys.posix.fcntl : open, O_RDONLY, stat_t, fstat;
import core.sys.posix.unistd : close;

// Reads the object file at the given path and returns the contents of the build
// version load command.
load_command*[2] loadCommands(ref MachHeader header)
{
    load_command*[2] commands;
    size_t cmdIndex;
    auto command = cast(load_command*)(cast(ubyte*) header + mach_header_64.sizeof);

    foreach (_; 0 .. header.ncmds)
    {
        if (command.cmd == LC_BUILD_VERSION || command.cmd == LC_VERSION_MIN_MACOSX)
            commands[cmdIndex++] = command;

        command = cast(load_command*)(cast(ubyte*) command + command.cmdsize);
    }

    return commands;
}

struct MachHeader
{
    mach_header_64* header;
    alias header this;

    private int fd;
    private stat_t buffer;

    @disable this(this);

    this(const char* path)
    {
        const fd = open(path, O_RDONLY);
        assert(fd != -1);
        scope (failure)
            fd.close();

        assert(fd.fstat(&buffer) != -1);

        header = cast(mach_header_64*) mmap(null, buffer.st_size, PROT_READ,
            MAP_FILE | MAP_PRIVATE, fd, 0);
        assert(header != MAP_FAILED);
    }

    ~this()
    {
        header.munmap(buffer.st_size);
        fd.close();
    }
}

// Returns the mach_header_64 of the given path.
MachHeader machHeader(const char* path)
{
    return MachHeader(path);
}

// Returns the path to the object file that was generated when this file was
// compiled. It's assumed to be the same path as the currently running
// executable + `.o`.
const(char)* pathToObjectFile()
{
    const result = getenv("_");
    assert(result);

    return (result[0 .. result.strlen] ~ ".o\0").ptr;
}

void main()
{
    bool foundBuildVersion = false;
    bool foundVersionMin = false;
    auto header = machHeader(pathToObjectFile);
    auto loadCommands = header.loadCommands;

    foreach (cmd; loadCommands)
    {
        if (!cmd)
            continue;

        if (cmd.cmd == LC_BUILD_VERSION)
        {
            foundBuildVersion = true;

            with (cast(build_version_command*) cmd)
            {
                assert(cmdsize == build_version_command.sizeof);
                assert(platform == PLATFORM_MACOS);
                assert(minos > 0);
                assert(ntools == 0);
            }
        }

        else if (cmd.cmd == LC_VERSION_MIN_MACOSX)
        {
            foundVersionMin = true;

            with (cast(version_min_command*) cmd)
            {
                assert(cmdsize == version_min_command.sizeof);
                assert(version_ > 0);
            }
        }
    }

    assert(!(foundBuildVersion == foundVersionMin && !foundVersionMin),
        "Failed to find the LC_BUILD_VERSION or the LC_VERSION_MIN_MACOSX " ~
        "load commands");

    assert(!(foundBuildVersion && foundVersionMin), "Found both the " ~
        "LC_BUILD_VERSION and the LC_VERSION_MIN_MACOSX load commands. " ~
        "Only one should be present");
}
