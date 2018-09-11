/**
 * This code handles backtrace generation using DWARF debug_line section
 * in ELF and Mach-O files for Posix.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain, Sean Kelly
 * Source: $(DRUNTIMESRC rt/backtrace/dwarf.d)
 */

module rt.backtrace.dwarf;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version(CRuntime_Glibc) version = has_backtrace;
else version(FreeBSD) version = has_backtrace;
else version(DragonFlyBSD) version = has_backtrace;
else version(CRuntime_UClibc) version = has_backtrace;
else version(Darwin) version = has_backtrace;

version(has_backtrace):

version (Darwin)
    import rt.backtrace.macho;
else
    import rt.backtrace.elf;

import rt.util.container.array;
import core.stdc.string : strlen, memchr;

//debug = DwarfDebugMachine;

struct Location
{
    const(char)[] file = null; // file is missing directory, but DMD emits directory directly into file
    int line = -1;
    size_t address;
}

int traceHandlerOpApplyImpl(const void*[] callstack, scope int delegate(ref size_t, ref const(char[])) dg)
{
    import core.stdc.stdio : snprintf;
    version(linux) import core.sys.linux.execinfo : backtrace_symbols;
    else version(FreeBSD) import core.sys.freebsd.execinfo : backtrace_symbols;
    else version(DragonFlyBSD) import core.sys.dragonflybsd.execinfo : backtrace_symbols;
    else version(Darwin) import core.sys.darwin.execinfo : backtrace_symbols;
    import core.sys.posix.stdlib : free;

    const char** frameList = backtrace_symbols(callstack.ptr, cast(int) callstack.length);
    scope(exit) free(cast(void*) frameList);

    // find address -> file, line mapping using dwarf debug_line
    Array!Location locations;
    auto image = Image.openSelf();
    if (image.isValid)
    {
        auto debugLineSectionData = image.getDebugLineSectionData();

        if (debugLineSectionData)
        {
            // resolve addresses
            locations.length = callstack.length;
            foreach(size_t i; 0 .. callstack.length)
                locations[i].address = cast(size_t) callstack[i];

            resolveAddresses(debugLineSectionData, locations[], image.baseAddress);
        }
    }

    int ret = 0;
    foreach (size_t i; 0 .. callstack.length)
    {
        char[1536] buffer = void; buffer[0] = 0;
        char[256] addressBuffer = void; addressBuffer[0] = 0;

        if (locations.length > 0 && locations[i].line != -1)
            snprintf(addressBuffer.ptr, addressBuffer.length, "%.*s:%d ", cast(int) locations[i].file.length, locations[i].file.ptr, locations[i].line);
        else
            addressBuffer[] = "??:? \0";

        char[1024] symbolBuffer = void;
        int bufferLength;
        auto symbol = getDemangledSymbol(frameList[i][0 .. strlen(frameList[i])], symbolBuffer);
        if (symbol.length > 0)
            bufferLength = snprintf(buffer.ptr, buffer.length, "%s%.*s ", addressBuffer.ptr, cast(int) symbol.length, symbol.ptr);
        else
            bufferLength = snprintf(buffer.ptr, buffer.length, "%s", addressBuffer.ptr);

        assert(bufferLength >= 0);
        const addressLength = 20;
        const maxBufferLength = buffer.length - addressLength;
        if (bufferLength > maxBufferLength)
        {
            bufferLength = maxBufferLength;
            buffer[$-4-addressLength..$-addressLength] = "... ";
        }
        bufferLength += snprintf(buffer.ptr + bufferLength, buffer.length, "[0x%x]", callstack[i]);

        auto output = buffer[0 .. bufferLength];
        auto pos = i;
        ret = dg(pos, output);
        if (ret || symbol == "_Dmain") break;
    }
    return ret;
}

private:

// the lifetime of the Location data is the lifetime of the mmapped ElfSection
void resolveAddresses(const(ubyte)[] debugLineSectionData, Location[] locations, size_t baseAddress) @nogc nothrow
{
    debug(DwarfDebugMachine) import core.stdc.stdio;

    size_t numberOfLocationsFound = 0;

    const(ubyte)[] dbg = debugLineSectionData;
    while (dbg.length > 0)
    {
        debug(DwarfDebugMachine) printf("new debug program\n");
        const(LPHeader)* lph = cast(const(LPHeader)*) dbg.ptr;

        if (lph.unitLength == 0xffff_ffff) // is 64-bit dwarf?
            return; // unable to read 64-bit dwarf

        const(ubyte)[] program = dbg[
            lph.headerLength + LPHeader.minimumInstructionLength.offsetof ..
            lph.unitLength + LPHeader.dwarfVersion.offsetof
        ];

        const(ubyte)[] standardOpcodeLengths = dbg[
            LPHeader.sizeof .. LPHeader.sizeof + lph.opcodeBase - 1
        ];

        const(ubyte)[] pathData = dbg[
            LPHeader.sizeof + lph.opcodeBase - 1 .. $
        ];

        Array!(const(char)[]) directories;
        directories.length = (const(ubyte)[] bytes) {
            // count number of directories
            int count = 0;
            foreach (i; 0 .. bytes.length - 1)
            {
                if (bytes[i] == 0)
                {
                    count++;
                    if (bytes[i + 1] == 0) return count;
                }
            }
            return count;
        }(pathData);

        // fill directories array from dwarf section
        int currentDirectoryIndex = 0;
        while (pathData[0] != 0)
        {
            directories[currentDirectoryIndex] = cast(const(char)[]) pathData[0 .. strlen(cast(char*) (pathData.ptr))];
            debug(DwarfDebugMachine) printf("dir: %s\n", pathData.ptr);
            pathData = pathData[directories[currentDirectoryIndex].length + 1 .. $];
            currentDirectoryIndex++;
        }

        pathData = pathData[1 .. $];

        Array!(const(char)[]) filenames;
        filenames.length = (const(ubyte)[] bytes)
        {
            // count number of files
            int count = 0;
            while (bytes[0] != 0)
            {
                auto filename = cast(const(char)[]) bytes[0 .. strlen(cast(char*) (bytes.ptr))];
                bytes = bytes[filename.length + 1 .. $];
                bytes.readULEB128(); // dir index
                bytes.readULEB128(); // last mod
                bytes.readULEB128(); // file len
                count++;
            }
            return count;
        }(pathData);

        // fill filenames array from dwarf section
        int currentFileIndex = 0;
        while (pathData[0] != 0)
        {
            filenames[currentFileIndex] = cast(const(char)[]) pathData[0 .. strlen(cast(char*) (pathData.ptr))];
            debug(DwarfDebugMachine) printf("file: %s\n", pathData.ptr);
            pathData = pathData[filenames[currentFileIndex].length + 1 .. $];

            auto dirIndex = pathData.readULEB128(); // unused
            auto lastMod = pathData.readULEB128();  // unused
            auto fileLen = pathData.readULEB128();  // unused

            currentFileIndex++;
        }

        LocationInfo lastLoc = LocationInfo(-1, -1);
        size_t lastAddress = 0x0;

        debug(DwarfDebugMachine) printf("program:\n");
        runStateMachine(lph, program, standardOpcodeLengths,
            (size_t address, LocationInfo locInfo, bool isEndSequence)
            {
                // adjust to ASLR offset
                address += baseAddress;
                debug(DwarfDebugMachine) printf("-- offsetting 0x%x to 0x%x\n", address - baseAddress, address);
                // If loc.line != -1, then it has been set previously.
                // Some implementations (eg. dmd) write an address to
                // the debug data multiple times, but so far I have found
                // that the first occurrence to be the correct one.
                foreach (ref loc; locations) if (loc.line == -1)
                {
                    if (loc.address == address)
                    {
                        debug(DwarfDebugMachine) printf("-- found for [0x%x]:\n", loc.address);
                        debug(DwarfDebugMachine) printf("--   file: %.*s\n", filenames[locInfo.file - 1].length, filenames[locInfo.file - 1].ptr);
                        debug(DwarfDebugMachine) printf("--   line: %d\n", locInfo.line);
                        loc.file = filenames[locInfo.file - 1];
                        loc.line = locInfo.line;
                        numberOfLocationsFound++;
                    }
                    else if (loc.address < address && lastAddress < loc.address && lastAddress != 0)
                    {
                        debug(DwarfDebugMachine) printf("-- found for [0x%x]:\n", loc.address);
                        debug(DwarfDebugMachine) printf("--   file: %.*s\n", filenames[lastLoc.file - 1].length, filenames[lastLoc.file - 1].ptr);
                        debug(DwarfDebugMachine) printf("--   line: %d\n", lastLoc.line);
                        loc.file = filenames[lastLoc.file - 1];
                        loc.line = lastLoc.line;
                        numberOfLocationsFound++;
                    }
                }

                if (isEndSequence)
                {
                    lastAddress = 0;
                }
                else
                {
                    lastAddress = address;
                    lastLoc = locInfo;
                }

                return numberOfLocationsFound < locations.length;
            }
        );

        if (numberOfLocationsFound == locations.length) return;
        dbg = dbg[lph.unitLength + LPHeader.dwarfVersion.offsetof .. $];
    }
}

alias RunStateMachineCallback = bool delegate(size_t, LocationInfo, bool) @nogc nothrow;
bool runStateMachine(const(LPHeader)* lpHeader, const(ubyte)[] program, const(ubyte)[] standardOpcodeLengths, scope RunStateMachineCallback callback) @nogc nothrow
{
    debug(DwarfDebugMachine) import core.stdc.stdio;

    StateMachine machine;
    machine.isStatement = lpHeader.defaultIsStatement;

    while (program.length > 0)
    {
        ubyte opcode = program.read!ubyte();
        if (opcode < lpHeader.opcodeBase)
        {
            switch (opcode) with (StandardOpcode)
            {
                case extendedOp:
                    size_t len = cast(size_t) program.readULEB128();
                    ubyte eopcode = program.read!ubyte();

                    switch (eopcode) with (ExtendedOpcode)
                    {
                        case endSequence:
                            machine.isEndSequence = true;
                            debug(DwarfDebugMachine) printf("endSequence 0x%x\n", machine.address);
                            if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line), true)) return true;
                            machine = StateMachine.init;
                            machine.isStatement = lpHeader.defaultIsStatement;
                            break;

                        case setAddress:
                            size_t address = program.read!size_t();
                            debug(DwarfDebugMachine) printf("setAddress 0x%x\n", address);
                            machine.address = address;
                            break;

                        case defineFile: // TODO: add proper implementation
                            debug(DwarfDebugMachine) printf("defineFile\n");
                            program = program[len - 1 .. $];
                            break;

                        default:
                            // unknown opcode
                            debug(DwarfDebugMachine) printf("unknown extended opcode %d\n", cast(int) eopcode);
                            program = program[len - 1 .. $];
                            break;
                    }

                    break;

                case copy:
                    debug(DwarfDebugMachine) printf("copy 0x%x\n", machine.address);
                    if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line), false)) return true;
                    machine.isBasicBlock = false;
                    machine.isPrologueEnd = false;
                    machine.isEpilogueBegin = false;
                    break;

                case advancePC:
                    ulong op = readULEB128(program);
                    machine.address += op * lpHeader.minimumInstructionLength;
                    debug(DwarfDebugMachine) printf("advancePC %d to 0x%x\n", cast(int) (op * lpHeader.minimumInstructionLength), machine.address);
                    break;

                case advanceLine:
                    long ad = readSLEB128(program);
                    machine.line += ad;
                    debug(DwarfDebugMachine) printf("advanceLine %d to %d\n", cast(int) ad, cast(int) machine.line);
                    break;

                case setFile:
                    uint index = cast(uint) readULEB128(program);
                    debug(DwarfDebugMachine) printf("setFile to %d\n", cast(int) index);
                    machine.fileIndex = index;
                    break;

                case setColumn:
                    uint col = cast(uint) readULEB128(program);
                    debug(DwarfDebugMachine) printf("setColumn %d\n", cast(int) col);
                    machine.column = col;
                    break;

                case negateStatement:
                    debug(DwarfDebugMachine) printf("negateStatement\n");
                    machine.isStatement = !machine.isStatement;
                    break;

                case setBasicBlock:
                    debug(DwarfDebugMachine) printf("setBasicBlock\n");
                    machine.isBasicBlock = true;
                    break;

                case constAddPC:
                    machine.address += (255 - lpHeader.opcodeBase) / lpHeader.lineRange * lpHeader.minimumInstructionLength;
                    debug(DwarfDebugMachine) printf("constAddPC 0x%x\n", machine.address);
                    break;

                case fixedAdvancePC:
                    uint add = program.read!uint();
                    machine.address += add;
                    debug(DwarfDebugMachine) printf("fixedAdvancePC %d to 0x%x\n", cast(int) add, machine.address);
                    break;

                case setPrologueEnd:
                    machine.isPrologueEnd = true;
                    debug(DwarfDebugMachine) printf("setPrologueEnd\n");
                    break;

                case setEpilogueBegin:
                    machine.isEpilogueBegin = true;
                    debug(DwarfDebugMachine) printf("setEpilogueBegin\n");
                    break;

                case setISA:
                    machine.isa = cast(uint) readULEB128(program);
                    debug(DwarfDebugMachine) printf("setISA %d\n", cast(int) machine.isa);
                    break;

                default:
                    // unimplemented/invalid opcode
                    return false;
            }
        }
        else
        {
            opcode -= lpHeader.opcodeBase;
            auto ainc = (opcode / lpHeader.lineRange) * lpHeader.minimumInstructionLength;
            machine.address += ainc;
            auto linc = lpHeader.lineBase + (opcode % lpHeader.lineRange);
            machine.line += linc;

            debug(DwarfDebugMachine) printf("special %d %d to 0x%x line %d\n", cast(int) ainc, cast(int) linc, machine.address, cast(int) machine.line);
            if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line), false)) return true;
        }
    }

    return true;
}

const(char)[] getDemangledSymbol(const(char)[] btSymbol, ref char[1024] buffer)
{
    import core.demangle;

    version(linux)
    {
        // format is:  module(_D6module4funcAFZv) [0x00000000]
        // or:         module(_D6module4funcAFZv+0x78) [0x00000000]
        auto bptr = cast(char*) memchr(btSymbol.ptr, '(', btSymbol.length);
        auto eptr = cast(char*) memchr(btSymbol.ptr, ')', btSymbol.length);
        auto pptr = cast(char*) memchr(btSymbol.ptr, '+', btSymbol.length);
    }
    else version(FreeBSD)
    {
        // format is: 0x00000000 <_D6module4funcAFZv+0x78> at module
        auto bptr = cast(char*) memchr(btSymbol.ptr, '<', btSymbol.length);
        auto eptr = cast(char*) memchr(btSymbol.ptr, '>', btSymbol.length);
        auto pptr = cast(char*) memchr(btSymbol.ptr, '+', btSymbol.length);
    }
    else version(DragonFlyBSD)
    {
        // format is: 0x00000000 <_D6module4funcAFZv+0x78> at module
        auto bptr = cast(char*) memchr(btSymbol.ptr, '<', btSymbol.length);
        auto eptr = cast(char*) memchr(btSymbol.ptr, '>', btSymbol.length);
        auto pptr = cast(char*) memchr(btSymbol.ptr, '+', btSymbol.length);
    }
    else version(Darwin)
        return demangle(extractSymbol(btSymbol), buffer[]);

    version (Darwin) {}
    else
    {
        if (pptr && pptr < eptr)
            eptr = pptr;

        size_t symBeg, symEnd;
        if (bptr++ && eptr)
        {
            symBeg = bptr - btSymbol.ptr;
            symEnd = eptr - btSymbol.ptr;
        }

        assert(symBeg <= symEnd);
        assert(symEnd < btSymbol.length);

        return demangle(btSymbol[symBeg .. symEnd], buffer[]);
    }
}

/**
 * Extracts a D mangled symbol from the given string for macOS.
 *
 * The format of the string is:
 * `0   main         0x000000010b054ddb _D6module4funcAFZv + 87`
 *
 * Params:
 *  btSymbol = the string to extract the symbol from, in the format mentioned
 *             above
 *
 * Returns: the extracted symbol or null if the given string did not match the
 *          above format
 */
const(char)[] extractSymbol(const(char)[] btSymbol) @nogc nothrow
{
    auto symbolStart = size_t.max;
    auto symbolEnd = size_t.max;
    bool plus;

    foreach_reverse (i, e ; btSymbol)
    {
        if (e == '+')
        {
            plus = true;
            continue;
        }

        if (plus)
        {
            if (e != ' ')
            {
                if (symbolEnd == size_t.max)
                    symbolEnd = i + 1;

                symbolStart = i;
            }
            else if (symbolEnd != size_t.max)
                break;
        }
    }

    if (symbolStart == size_t.max || symbolEnd == size_t.max)
        return null;

    return btSymbol[symbolStart .. symbolEnd];
}

T read(T)(ref const(ubyte)[] buffer) @nogc nothrow
{
    T result = *(cast(T*) buffer[0 .. T.sizeof].ptr);
    buffer = buffer[T.sizeof .. $];
    return result;
}

ulong readULEB128(ref const(ubyte)[] buffer) @nogc nothrow
{
    ulong val = 0;
    uint shift = 0;

    while (true)
    {
        ubyte b = buffer.read!ubyte();

        val |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
    }

    return val;
}

unittest
{
    const(ubyte)[] data = [0xe5, 0x8e, 0x26, 0xDE, 0xAD, 0xBE, 0xEF];
    assert(readULEB128(data) == 624_485);
    assert(data[] == [0xDE, 0xAD, 0xBE, 0xEF]);
}

long readSLEB128(ref const(ubyte)[] buffer) @nogc nothrow
{
    long val = 0;
    uint shift = 0;
    int size = 8 << 3;
    ubyte b;

    while (true)
    {
        b = buffer.read!ubyte();
        val |= (b & 0x7f) << shift;
        shift += 7;
        if ((b & 0x80) == 0)
            break;
    }

    if (shift < size && (b & 0x40) != 0)
        val |= -(1 << shift);

    return val;
}

enum StandardOpcode : ubyte
{
    extendedOp = 0,
    copy = 1,
    advancePC = 2,
    advanceLine = 3,
    setFile = 4,
    setColumn = 5,
    negateStatement = 6,
    setBasicBlock = 7,
    constAddPC = 8,
    fixedAdvancePC = 9,
    setPrologueEnd = 10,
    setEpilogueBegin = 11,
    setISA = 12,
}

enum ExtendedOpcode : ubyte
{
    endSequence = 1,
    setAddress = 2,
    defineFile = 3,
}

struct StateMachine
{
    size_t address = 0;
    uint operationIndex = 0;
    uint fileIndex = 1;
    uint line = 1;
    uint column = 0;
    bool isStatement;
    bool isBasicBlock = false;
    bool isEndSequence = false;
    bool isPrologueEnd = false;
    bool isEpilogueBegin = false;
    uint isa = 0;
    uint discriminator = 0;
}

struct LocationInfo
{
    int file;
    int line;
}

// 32-bit DWARF
align(1)
struct LPHeader
{
align(1):
    uint unitLength;
    ushort dwarfVersion;
    uint headerLength;
    ubyte minimumInstructionLength;
    bool defaultIsStatement;
    byte lineBase;
    ubyte lineRange;
    ubyte opcodeBase;
}
