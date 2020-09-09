/**
 * Generates a human-readable stack-trace on POSIX targets using DWARF
 *
 * The common use case for printing a stack trace is when `toString` is called
 * on a `Throwable` (see `object.d`). It will iterate on what is likely to be
 * the default trace handler (see `core.runtime : defaultTraceHandler`).
 * The class returned by `defaultTraceHandler` is what ends up calling into
 * this module, through the use of `core.internal.traits : externDFunc`.
 *
 * The entry point of this module is `traceHandlerOpApplyImpl`,
 * and the only really "public" symbol (since all `rt` symbols are private).
 * In the future, this implementation should probably be made idiomatic,
 * so that it can for example work with attributes.
 *
 * Resilience:
 * As this module is used for diagnostic, it should handle failures
 * as gracefully as possible. Having the runtime error out on printing
 * the stack trace one is trying to debug would be quite a terrible UX.
 * For this reason, this module works on a "best effort" basis and will
 * sometimes print mangled symbols, or "???" when it cannot do anything
 * more useful.
 *
 * Source_of_data:
 * This module uses two main sources for generating human-readable data.
 * First, it uses `backtrace_symbols` to obtain the name of the symbols
 * (functions or methods) associated with the addresses.
 * Since the names are mangled, it will also call into `core.demangle`,
 * and doesn't need to use any DWARF information for this,
 * however a future extension  could make use of the call frame information
 * (See DWARF4 "6.4 Call Frame Information", PDF page 126).
 *
 * The other piece of data used is the DWARF `.debug_line` section,
 * which contains the line informations of a program, necessary to associate
 * the instruction address with its (file, line) information.
 *
 * Since debug lines informations are quite large, they are encoded using a
 * program that is to be fed to a finite state machine.
 * See `runStateMachine` and `readLineNumberProgram` for more details.
 *
 * DWARF_Version:
 * This module only supports DWARF 3 and 4.
 *
 * Reference: http://www.dwarfstd.org/
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain, Sean Kelly
 * Source: $(DRUNTIMESRC rt/backtrace/dwarf.d)
 */

module rt.backtrace.dwarf;

import core.internal.execinfo;

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
    const(char)[] file = null;
    const(char)[] directory = null;
    int line = -1;
    const(void)* address;
}

int traceHandlerOpApplyImpl(const(void*)[] callstack, scope int delegate(ref size_t, ref const(char[])) dg)
{
    import core.stdc.stdio : snprintf;
    import core.sys.posix.stdlib : free;

    const char** frameList = backtrace_symbols(callstack.ptr, cast(int) callstack.length);
    scope(exit) free(cast(void*) frameList);

    auto image = Image.openSelf();

    int processCallstack(const(ubyte)[] debugLineSectionData)
    {
        // find address -> file, line mapping using dwarf debug_line
        Array!Location locations;
        if (debugLineSectionData)
        {
            locations.length = callstack.length;
            foreach (size_t i; 0 .. callstack.length)
                locations[i].address = callstack[i];

            resolveAddresses(debugLineSectionData, locations[], image.baseAddress);
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
                bool includeSlash = locations[i].directory.length > 0 && locations[i].directory[$ - 1] != '/';
                string printFormat = includeSlash ? "%.*s/%.*s:%d " : "%.*s%.*s:%d ";

                appendToBuffer(
                    printFormat.ptr,
                    cast(int) locations[i].directory.length, locations[i].directory.ptr,
                    cast(int) locations[i].file.length, locations[i].file.ptr,
                    locations[i].line,
                );
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
            appendToBuffer("[%p]", callstack[i]);

            auto output = buffer[0 .. bufferLength];
            auto pos = i;
            ret = dg(pos, output);
            if (ret || symbol == "_Dmain") break;
        }

        return ret;
    }

    return image.isValid
        ? image.processDebugLineSectionData(&processCallstack)
        : processCallstack(null);
}

private:

// the lifetime of the Location data is bound to the lifetime of debugLineSectionData
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
        const(void)* lastAddress;

        debug(DwarfDebugMachine) printf("program:\n");
        runStateMachine(lp,
            (const(void)* address, LocationInfo locInfo, bool isEndSequence)
            {
                // adjust to ASLR offset
                address += baseAddress;
                debug (DwarfDebugMachine)
                    printf("-- offsetting %p to %p\n", address - baseAddress, address);

                foreach (ref loc; locations)
                {
                    // If loc.line != -1, then it has been set previously.
                    // Some implementations (eg. dmd) write an address to
                    // the debug data multiple times, but so far I have found
                    // that the first occurrence to be the correct one.
                    if (loc.line != -1)
                        continue;

                    // Can be called with either `locInfo` or `lastLoc`
                    void update(const ref LocationInfo match)
                    {
                        const sourceFile = lp.sourceFiles[match.file - 1];
                        debug (DwarfDebugMachine)
                        {
                            printf("-- found for [%p]:\n", loc.address);
                            printf("--   file: %.*s\n",
                                   cast(int) sourceFile.file.length, sourceFile.file.ptr);
                            printf("--   line: %d\n", match.line);
                        }
                        // DMD emits entries with FQN, but other implmentations
                        // (e.g. LDC) make use of directories
                        // See https://github.com/dlang/druntime/pull/2945
                        if (sourceFile.dirIndex != 0)
                            loc.directory = lp.includeDirectories[sourceFile.dirIndex - 1];

                        loc.file = sourceFile.file;
                        loc.line = match.line;
                        numberOfLocationsFound++;
                    }

                    // The state machine will not contain an entry for each
                    // address, as consecutive addresses with the same file/line
                    // are merged together to save on space, so we need to
                    // check if our address is within two addresses we get
                    // called with.
                    //
                    // Specs (DWARF v4, Section 6.2, PDF p.109) says:
                    // "We shrink it with two techniques. First, we delete from
                    // the matrix each row whose file, line, source column and
                    // discriminator information is identical with that of its
                    // predecessors.
                    if (loc.address == address)
                        update(locInfo);
                    else if (lastAddress &&
                             loc.address > lastAddress && loc.address < address)
                        update(lastLoc);
                }

                if (isEndSequence)
                {
                    lastAddress = null;
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

/**
 * A callback type for `runStateMachine`
 *
 * The callback is called when certain specific opcode are encountered
 * (a.k.a when a complete `LocationInfo` is encountered).
 * See `runStateMachine` implementation and the DWARF specs for more detail.
 *
 * Params:
 *   address = The address that the `LocationInfo` describes
 *   info = The `LocationInfo` itself, describing `address`
 *   isEndSequence = Whether the end of a sequence has been reached
 */
alias RunStateMachineCallback =
    bool delegate(const(void)* address, LocationInfo info, bool isEndSequence)
    @nogc nothrow;

/**
 * Run the state machine to generate line number matrix
 *
 * Line number informations generated by the compiler are stored in the
 * `.debug_line` section. Conceptually, they can be seen as a large matrix,
 * with row such as "file", "line", "column", "is_statement", etc...
 * However such a matrix would be too big to store in an object file,
 * so DWARF instead generate this matrix using bytecode fed to a state machine.
 *
 * Note:
 * Each compilation unit can have its own line number program.
 *
 * See_Also:
 * - DWARF v4, Section 6.2: Line Number Information
 *
 * Params:
 *   lp = Program to execute
 *   callback = Delegate to call whenever a LocationInfo is completed
 *
 * Returns:
 *   `false` if an error happened (e.g. unknown opcode)
 */
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
                            debug(DwarfDebugMachine) printf("endSequence %p\n", machine.address);
                            if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line), true)) return true;
                            machine = StateMachine.init;
                            machine.isStatement = lp.defaultIsStatement;
                            break;

                        case setAddress:
                            const address = program.read!(void*)();
                            debug(DwarfDebugMachine) printf("setAddress %p\n", address);
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
                    debug(DwarfDebugMachine) printf("copy %p\n", machine.address);
                    if (!callback(machine.address, LocationInfo(machine.fileIndex, machine.line), false)) return true;
                    machine.isBasicBlock = false;
                    machine.isPrologueEnd = false;
                    machine.isEpilogueBegin = false;
                    machine.discriminator = 0;
                    break;

                case advancePC:
                    const operationAdvance = cast(size_t) readULEB128(program);
                    advanceAddressAndOpIndex(operationAdvance);
                    debug(DwarfDebugMachine) printf("advancePC %d to %p\n", cast(int) operationAdvance, machine.address);
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
                    debug(DwarfDebugMachine) printf("constAddPC %p\n", machine.address);
                    break;

                case fixedAdvancePC:
                    const add = program.read!ushort();
                    machine.address += add;
                    machine.operationIndex = 0;
                    debug(DwarfDebugMachine) printf("fixedAdvancePC %d to %p\n", cast(int) add, machine.address);
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

            debug (DwarfDebugMachine)
                printf("special %d %d to %p line %d\n", cast(int) addressIncrement,
                       cast(int) lineIncrement, machine.address, machine.line);

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
    const(void)* address;
    uint operationIndex = 0;
    uint fileIndex = 1;
    uint line = 1;
    uint column = 0;
    uint isa = 0;
    uint discriminator = 0;
    bool isStatement;
    bool isBasicBlock = false;
    bool isEndSequence = false;
    bool isPrologueEnd = false;
    bool isEpilogueBegin = false;
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
    Array!SourceFile sourceFiles;
    const(ubyte)[] program;
}

struct SourceFile
{
    const(char)[] file;
    size_t dirIndex;
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
    static auto readSequence(alias ReadEntry)(ref const(ubyte)[] data)
    {
        alias ResultType = typeof(ReadEntry(data));

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

        Array!ResultType result;
        result.length = numEntries;

        foreach (i; 0 .. numEntries)
            result[i] = ReadEntry(data);

        data = data[1 .. $]; // skip over sequence-terminating null

        return result;
    }

    /// Directories are simply a sequence of NUL-terminated strings
    static const(char)[] readIncludeDirectoryEntry(ref const(ubyte)[] data)
    {
        const ptr = cast(const(char)*) data.ptr;
        const dir = ptr[0 .. strlen(ptr)];
        data = data[dir.length + "\0".length .. $];
        return dir;
    }
    lp.includeDirectories = readSequence!readIncludeDirectoryEntry(data);

    static SourceFile readFileNameEntry(ref const(ubyte)[] data)
    {
        const ptr = cast(const(char)*) data.ptr;
        const file = ptr[0 .. strlen(ptr)];
        data = data[file.length + "\0".length .. $];

        auto dirIndex = cast(size_t) data.readULEB128();

        data.readULEB128(); // last mod
        data.readULEB128(); // file len

        return SourceFile(
            file,
            dirIndex,
        );
    }
    lp.sourceFiles = readSequence!readFileNameEntry(data);

    debug (DwarfDebugMachine)
    {
        printf("include_directories: (%d)\n", cast(int) lp.includeDirectories.length);
        foreach (dir; lp.includeDirectories)
            printf("\t- %.*s\n", cast(int) dir.length, dir.ptr);
        printf("source_files: (%d)\n", cast(int) lp.sourceFiles.length);
        foreach (ref sf; lp.sourceFiles)
        {
            if (sf.dirIndex > lp.includeDirectories.length)
                printf("\t- Out of bound directory! (%llu): %.*s\n",
                       sf.dirIndex, cast(int) sf.file.length, sf.file.ptr);
            else if (sf.dirIndex > 0)
            {
                const dir = lp.includeDirectories[sf.dirIndex - 1];
                printf("\t- (Dir:%llu:%.*s/)%.*s\n", sf.dirIndex,
                       cast(int) dir.length, dir.ptr,
                       cast(int) sf.file.length, sf.file.ptr);
            }
            else
                printf("\t- %.*s\n", cast(int) sf.file.length, sf.file.ptr);
        }
    }

    const programStart = cast(size_t) (minimumInstructionLengthFieldOffset + lp.headerLength);
    const programEnd = cast(size_t) (dwarfVersionFieldOffset + lp.unitLength);
    lp.program = originalData[programStart .. programEnd];

    data = originalData[programEnd .. $];

    return lp;
}
