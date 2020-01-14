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

private import core.internal.execinfo;

static if (hasExecinfo):

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin)
    import rt.backtrace.macho;
else
    import rt.backtrace.elf;

import rt.util.container.array;
import core.stdc.string : strlen, memcpy;

//debug = DwarfDebugMachine;
debug(DwarfDebugMachine) import core.stdc.stdio : printf;

struct Location
{
    const(char)[] file = null; // file is missing directory, but DMD emits directory directly into file
    int line = -1;
    size_t address;
}

int traceHandlerOpApplyImpl(const void*[] callstack, scope int delegate(ref size_t, ref const(char[])) dg)
{
    import core.stdc.stdio : snprintf;
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
            foreach (size_t i; 0 .. callstack.length)
                locations[i].address = cast(size_t) callstack[i];

            resolveAddresses(debugLineSectionData, locations[], image.baseAddress);
        }
    }

    int ret = 0;
    foreach (size_t i; 0 .. callstack.length)
    {
        char[1536] buffer = void;
        size_t bufferLength = 0;

        void appendToBuffer(Args...)(const(char)* format, Args args)
        {
            const count = snprintf(buffer.ptr + bufferLength, buffer.length - bufferLength, format, args);
            assert(count >= 0);
            bufferLength += count;
            if (bufferLength >= buffer.length)
                bufferLength = buffer.length - 1;
        }

        if (locations.length > 0 && locations[i].line != -1)
        {
            appendToBuffer("%.*s:%d ", cast(int) locations[i].file.length, locations[i].file.ptr, locations[i].line);
        }
        else
        {
            buffer[0 .. 5] = "??:? ";
            bufferLength = 5;
        }

        char[1024] symbolBuffer = void;
        auto symbol = getDemangledSymbol(frameList[i][0 .. strlen(frameList[i])], symbolBuffer);
        if (symbol.length > 0)
            appendToBuffer("%.*s ", cast(int) symbol.length, symbol.ptr);

        const addressLength = 20;
        const maxBufferLength = buffer.length - addressLength;
        if (bufferLength > maxBufferLength)
        {
            buffer[maxBufferLength-4 .. maxBufferLength] = "... ";
            bufferLength = maxBufferLength;
        }
        static if (size_t.sizeof == 8)
            appendToBuffer("[0x%llx]", callstack[i]);
        else
            appendToBuffer("[0x%x]", callstack[i]);

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
        const lp = readLineNumberProgram(dbg);

        LocationInfo lastLoc = LocationInfo(-1, -1);
        size_t lastAddress = 0x0;

        debug(DwarfDebugMachine) printf("program:\n");
        runStateMachine(lp,
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
                        debug(DwarfDebugMachine) printf("--   file: %.*s\n", cast(int) lp.fileNames[locInfo.file - 1].length, lp.fileNames[locInfo.file - 1].ptr);
                        debug(DwarfDebugMachine) printf("--   line: %d\n", locInfo.line);
                        loc.file = lp.fileNames[locInfo.file - 1];
                        loc.line = locInfo.line;
                        numberOfLocationsFound++;
                    }
                    else if (loc.address < address && lastAddress < loc.address && lastAddress != 0)
                    {
                        debug(DwarfDebugMachine) printf("-- found for [0x%x]:\n", loc.address);
                        debug(DwarfDebugMachine) printf("--   file: %.*s\n", cast(int) lp.fileNames[lastLoc.file - 1].length, lp.fileNames[lastLoc.file - 1].ptr);
                        debug(DwarfDebugMachine) printf("--   line: %d\n", lastLoc.line);
                        loc.file = lp.fileNames[lastLoc.file - 1];
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
    }
}

alias RunStateMachineCallback = bool delegate(size_t, LocationInfo, bool) @nogc nothrow;
bool runStateMachine(ref const(LineNumberProgram) lp, scope RunStateMachineCallback callback) @nogc nothrow
{
    StateMachine machine;
    machine.isStatement = lp.defaultIsStatement;

    const(ubyte)[] program = lp.program;
    while (program.length > 0)
    {
        size_t advanceAddressAndOpIndex(size_t operationAdvance)
        {
            const addressIncrement = lp.minimumInstructionLength * ((machine.operationIndex + operationAdvance) / lp.maximumOperationsPerInstruction);
            machine.address += addressIncrement;
            machine.operationIndex = (machine.operationIndex + operationAdvance) % lp.maximumOperationsPerInstruction;
            return addressIncrement;
        }

        ubyte opcode = program.read!ubyte();
        if (opcode < lp.opcodeBase)
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
                            machine.isStatement = lp.defaultIsStatement;
                            break;

                        case setAddress:
                            size_t address = program.read!size_t();
                            debug(DwarfDebugMachine) printf("setAddress 0x%x\n", address);
                            machine.address = address;
                            machine.operationIndex = 0;
                            break;

                        case defineFile: // TODO: add proper implementation
                            debug(DwarfDebugMachine) printf("defineFile\n");
                            program = program[len - 1 .. $];
                            break;

                        case setDiscriminator:
                            const discriminator = cast(uint) program.readULEB128();
                            debug(DwarfDebugMachine) printf("setDiscriminator %d\n", discriminator);
                            machine.discriminator = discriminator;
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
                    machine.discriminator = 0;
                    break;

                case advancePC:
                    const operationAdvance = cast(size_t) readULEB128(program);
                    advanceAddressAndOpIndex(operationAdvance);
                    debug(DwarfDebugMachine) printf("advancePC %d to 0x%x\n", cast(int) operationAdvance, machine.address);
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
                    const operationAdvance = (255 - lp.opcodeBase) / lp.lineRange;
                    advanceAddressAndOpIndex(operationAdvance);
                    debug(DwarfDebugMachine) printf("constAddPC 0x%x\n", machine.address);
                    break;

                case fixedAdvancePC:
                    const add = program.read!ushort();
                    machine.address += add;
                    machine.operationIndex = 0;
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
                    debug(DwarfDebugMachine) printf("unknown opcode %d\n", cast(int) opcode);
                    return false;
            }
        }
        else
        {
            opcode -= lp.opcodeBase;
            const operationAdvance = opcode / lp.lineRange;
            const addressIncrement = advanceAddressAndOpIndex(operationAdvance);
            const lineIncrement = lp.lineBase + (opcode % lp.lineRange);
            machine.line += lineIncrement;

            debug(DwarfDebugMachine) printf("special %d %d to 0x%x line %d\n", cast(int) addressIncrement, cast(int) lineIncrement, machine.address, machine.line);
            if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line), false)) return true;

            machine.isBasicBlock = false;
            machine.isPrologueEnd = false;
            machine.isEpilogueBegin = false;
            machine.discriminator = 0;
        }
    }

    return true;
}

const(char)[] getDemangledSymbol(const(char)[] btSymbol, return ref char[1024] buffer)
{
    import core.demangle;
    const mangledName = getMangledSymbolName(btSymbol);
    return !mangledName.length ? buffer[0..0] : demangle(mangledName, buffer[]);
}

T read(T)(ref const(ubyte)[] buffer) @nogc nothrow
{
    version (X86)         enum hasUnalignedLoads = true;
    else version (X86_64) enum hasUnalignedLoads = true;
    else                  enum hasUnalignedLoads = false;

    static if (hasUnalignedLoads || T.alignof == 1)
    {
        T result = *(cast(T*) buffer.ptr);
    }
    else
    {
        T result = void;
        memcpy(&result, buffer.ptr, T.sizeof);
    }

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
    setDiscriminator = 4,
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

struct LineNumberProgram
{
    ulong unitLength;
    ushort dwarfVersion;
    ulong headerLength;
    ubyte minimumInstructionLength;
    ubyte maximumOperationsPerInstruction;
    bool defaultIsStatement;
    byte lineBase;
    ubyte lineRange;
    ubyte opcodeBase;
    const(ubyte)[] standardOpcodeLengths;
    Array!(const(char)[]) includeDirectories;
    Array!(const(char)[]) fileNames;
    const(ubyte)[] program;
}

LineNumberProgram readLineNumberProgram(ref const(ubyte)[] data) @nogc nothrow
{
    const originalData = data;

    LineNumberProgram lp;

    bool is64bitDwarf = false;
    lp.unitLength = data.read!uint();
    if (lp.unitLength == uint.max)
    {
        is64bitDwarf = true;
        lp.unitLength = data.read!ulong();
    }

    const dwarfVersionFieldOffset = cast(size_t) (data.ptr - originalData.ptr);
    lp.dwarfVersion = data.read!ushort();
    assert(lp.dwarfVersion < 5, "DWARF v5+ not supported yet");

    lp.headerLength = (is64bitDwarf ? data.read!ulong() : data.read!uint());

    const minimumInstructionLengthFieldOffset = cast(size_t) (data.ptr - originalData.ptr);
    lp.minimumInstructionLength = data.read!ubyte();

    lp.maximumOperationsPerInstruction = (lp.dwarfVersion >= 4 ? data.read!ubyte() : 1);
    lp.defaultIsStatement = (data.read!ubyte() != 0);
    lp.lineBase = data.read!byte();
    lp.lineRange = data.read!ubyte();
    lp.opcodeBase = data.read!ubyte();

    lp.standardOpcodeLengths = data[0 .. lp.opcodeBase - 1];
    data = data[lp.opcodeBase - 1 .. $];

    // A sequence ends with a null-byte.
    static Array!(const(char)[]) readSequence(alias ReadEntry)(ref const(ubyte)[] data)
    {
        static size_t count(const(ubyte)[] data)
        {
            size_t count = 0;
            while (data.length && data[0] != 0)
            {
                ReadEntry(data);
                ++count;
            }
            return count;
        }

        const numEntries = count(data);

        Array!(const(char)[]) result;
        result.length = numEntries;

        foreach (i; 0 .. numEntries)
            result[i] = ReadEntry(data);

        data = data[1 .. $]; // skip over sequence-terminating null

        return result;
    }

    static const(char)[] readIncludeDirectoryEntry(ref const(ubyte)[] data)
    {
        const length = strlen(cast(char*) data.ptr);
        auto result = cast(const(char)[]) data[0 .. length];
        debug(DwarfDebugMachine) printf("dir: %.*s\n", cast(int) length, result.ptr);
        data = data[length + 1 .. $];
        return result;
    }
    lp.includeDirectories = readSequence!readIncludeDirectoryEntry(data);

    static const(char)[] readFileNameEntry(ref const(ubyte)[] data)
    {
        const length = strlen(cast(char*) data.ptr);
        auto result = cast(const(char)[]) data[0 .. length];
        debug(DwarfDebugMachine) printf("file: %.*s\n", cast(int) length, result.ptr);
        data = data[length + 1 .. $];
        data.readULEB128(); // dir index
        data.readULEB128(); // last mod
        data.readULEB128(); // file len
        return result;
    }
    lp.fileNames = readSequence!readFileNameEntry(data);

    const programStart = cast(size_t) (minimumInstructionLengthFieldOffset + lp.headerLength);
    const programEnd = cast(size_t) (dwarfVersionFieldOffset + lp.unitLength);
    lp.program = originalData[programStart .. programEnd];

    data = originalData[programEnd .. $];

    return lp;
}
