/**
 * This code handles backtrace generation using dwarf .debug_line section
 * in ELF files for linux.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/backtrace/dwarf.d)
 */

module rt.backtrace.dwarf;

version(linux):

import rt.util.container.array;
import rt.backtrace.elf;

import core.stdc.string : strlen, memchr;

struct Location
{
    const(char)[] file = null; // file is missing directory, but DMD emits directory directly into file
    int line = -1;
    size_t address;
}

int traceHandlerOpApplyImpl(const void*[] callstack, scope int delegate(ref size_t, ref const(char[])) dg)
{
    import core.stdc.stdio : snprintf;
    import core.sys.linux.execinfo : backtrace_symbols;
    import core.sys.posix.stdlib : free;

    const char** frameList = backtrace_symbols(callstack.ptr, cast(int) callstack.length);
    scope(exit) free(cast(void*) frameList);

    // find address -> file, line mapping using dwarf debug_line
    ElfFile file;
    ElfSection dbgSection;
    Array!Location locations;
    if (ElfFile.openSelf(&file))
    {
        auto stringSectionHeader = ElfSectionHeader(&file, file.ehdr.e_shstrndx);
        auto stringSection = ElfSection(&file, &stringSectionHeader);

        auto dbgSectionIndex = findSectionByName(&file, &stringSection, ".debug_line");
        if (dbgSectionIndex != -1)
        {
            auto dbgSectionHeader = ElfSectionHeader(&file, dbgSectionIndex);
            dbgSection = ElfSection(&file, &dbgSectionHeader);
            // debug_line section found and loaded

            // resolve addresses
            locations.length = callstack.length;
            foreach(size_t i; 0 .. callstack.length)
                locations[i].address = cast(size_t) callstack[i];

            resolveAddresses(&dbgSection, locations[]);
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
            bufferLength = snprintf(buffer.ptr, buffer.length, "%s%.*s [0x%x]", addressBuffer.ptr, cast(int) symbol.length, symbol.ptr, callstack[i]);
        else
            bufferLength = snprintf(buffer.ptr, buffer.length, "%s[0x%x]", addressBuffer.ptr, callstack[i]);

        assert(bufferLength >= 0);

        auto output = buffer[0 .. bufferLength];
        auto pos = i;
        ret = dg(pos, output);
        if (ret) break;
    }
    return ret;
}

private:

// the lifetime of the Location data is the lifetime of the mmapped ElfSection
void resolveAddresses(ElfSection* debugLineSection, Location[] locations) @nogc nothrow
{
    size_t numberOfLocationsFound = 0;

    const(ubyte)[] dbg = debugLineSection.get();
    while (dbg.length > 0)
    {
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
            pathData = pathData[filenames[currentFileIndex].length + 1 .. $];

            auto dirIndex = pathData.readULEB128(); // unused
            auto lastMod = pathData.readULEB128();  // unused
            auto fileLen = pathData.readULEB128();  // unused

            currentFileIndex++;
        }

        LocationInfo lastLoc = LocationInfo(-1, -1);
        size_t lastAddress = 0x0;

        runStateMachine(lph, program, standardOpcodeLengths,
            (size_t address, LocationInfo locInfo)
            {
                foreach (ref loc; locations)
                {
                    if (loc.address == address)
                    {
                        loc.file = filenames[locInfo.file - 1];
                        loc.line = locInfo.line;
                        numberOfLocationsFound++;
                    }
                    else if (loc.address < address && lastAddress < loc.address && lastAddress != 0)
                    {
                        loc.file = filenames[lastLoc.file - 1];
                        loc.line = lastLoc.line;
                        numberOfLocationsFound++;
                    }
                }

                lastAddress = address;
                lastLoc = locInfo;
                return numberOfLocationsFound < locations.length;
            }
        );

        if (numberOfLocationsFound == locations.length) return;
        dbg = dbg[lph.unitLength + LPHeader.dwarfVersion.offsetof .. $];
    }
}

alias RunStateMachineCallback = bool delegate(size_t, LocationInfo) @nogc nothrow;
bool runStateMachine(const(LPHeader)* lpHeader, const(ubyte)[] program, const(ubyte)[] standardOpcodeLengths, scope RunStateMachineCallback callback) @nogc nothrow
{
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
                            // trace("endSequence ", "0x%x".format(m.address));
                            if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line))) return true;
                            machine = StateMachine.init;
                            machine.isStatement = lpHeader.defaultIsStatement;
                            break;

                        case setAddress:
                            size_t address = program.read!size_t();
                            // trace("setAddress ", "0x%x".format(address));
                            machine.address = address;
                            break;

                        case defineFile: // TODO: add proper implementation
                            // trace("defineFile");
                            program = program[len - 1 .. $];
                            break;

                        default:
                            // unknown opcode
                            // trace("unknown extended opcode ", eopcode);
                            program = program[len - 1 .. $];
                            break;
                    }

                    break;

                case copy:
                    // trace("copy");
                    if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line))) return true;
                    machine.isBasicBlock = false;
                    machine.isPrologueEnd = false;
                    machine.isEpilogueBegin = false;
                    break;

                case advancePC:
                    ulong op = readULEB128(program);
                    // trace("advancePC ", op * lpHeader.minimumInstructionLength);
                    machine.address += op * lpHeader.minimumInstructionLength;
                    break;

                case advanceLine:
                    long ad = readSLEB128(program);
                    // trace("advanceLine ", ad);
                    machine.line += ad;
                    break;

                case setFile:
                    uint index = cast(uint) readULEB128(program);
                    // trace("setFile to ", index);
                    machine.fileIndex = index;
                    break;

                case setColumn:
                    uint col = cast(uint) readULEB128(program);
                    // trace("setColumn ", col);
                    machine.column = col;
                    break;

                case negateStatement:
                    // trace("negateStatement");
                    machine.isStatement = !machine.isStatement;
                    break;

                case setBasicBlock:
                    // trace("setBasicBlock");
                    machine.isBasicBlock = true;
                    break;

                case constAddPC:
                    machine.address += (255 - lpHeader.opcodeBase) / lpHeader.lineRange * lpHeader.minimumInstructionLength;
                    // trace("constAddPC ", "0x%x".format(machine.address));
                    break;

                case fixedAdvancePC:
                    uint add = program.read!uint();
                    // trace("fixedAdvancePC ", add);
                    machine.address += add;
                    break;

                case setPrologueEnd:
                    machine.isPrologueEnd = true;
                    // trace("setPrologueEnd");
                    break;

                case setEpilogueBegin:
                    machine.isEpilogueBegin = true;
                    // trace("setEpilogueBegin");
                    break;

                case setISA:
                    machine.isa = cast(uint) readULEB128(program);
                    // trace("setISA ", m.isa);
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

            // trace("special ", ainc, " ", linc);
            if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line))) return true;
        }
    }

    return true;
}

const(char)[] getDemangledSymbol(const(char)[] btSymbol, ref char[1024] buffer)
{
    // format is:  module(_D6module4funcAFZv) [0x00000000]
    // or:         module(_D6module4funcAFZv+0x78) [0x00000000]
    auto bptr = cast(char*) memchr(btSymbol.ptr, '(', btSymbol.length);
    auto eptr = cast(char*) memchr(btSymbol.ptr, ')', btSymbol.length);
    auto pptr = cast(char*) memchr(btSymbol.ptr, '+', btSymbol.length);

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

    import core.demangle;
    return demangle(btSymbol[symBeg .. symEnd], buffer[]);
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
