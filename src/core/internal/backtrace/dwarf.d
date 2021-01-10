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
 * This module only supports DWARF 3, 4 and 5.
 *
 * Reference: http://www.dwarfstd.org/
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain, Sean Kelly
 * Source: $(DRUNTIMESRC rt/backtrace/dwarf.d)
 */

module core.internal.backtrace.dwarf;

import core.internal.execinfo;
import core.internal.string;

version (Posix):

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin)
    import core.internal.backtrace.macho;
else
    import core.internal.backtrace.elf;

import core.internal.container.array;
import core.stdc.string : strlen, memcpy;

//debug = DwarfDebugMachine;
debug(DwarfDebugMachine) import core.stdc.stdio : printf;

struct Location
{
    /**
     * Address of the instruction for which this location is for.
     */
    const(void)* address;

    /**
     * The name of the procedure, or function, this address is in.
     */
    const(char)[] procedure;

    /**
     * Path to the file this location references, relative to `directory`
     *
     * Note that depending on implementation, this could be just a name,
     * a relative path, or an absolute path.
     *
     * If no debug info is present, this may be `null`.
     */
    const(char)[] file;

    /**
     * Directory where `file` resides
     *
     * This may be `null`, either if there is no debug info,
     * or if the compiler implementation doesn't use this feature (e.g. DMD).
     */
    const(char)[] directory;

    /**
     * Line within the file that correspond to this `location`.
     *
     * Note that in addition to a positive value, the values `0` and `-1`
     * are to be expected by consumers. A value of `0` means that the code
     * is not attributable to a specific line in the file, e.g. module-specific
     * generated code, and `-1` means that no debug info could be found.
     */
    int line = -1;

    /// Format this location into a human-readable string
    void toString (scope void delegate(scope const char[]) sink) const
    {
        import core.demangle;

        // If there's no file information, there shouldn't be any directory
        // information. If there is we will simply ignore it.
        if (this.file.length)
        {
            // Note: Sink needs to handle empty data
            sink(this.directory);
            // Only POSIX path because this module is not used on Windows
            if (this.directory.length && this.directory[$ - 1] != '/')
                sink("/");
            sink(this.file);
        }
        else
            // Most likely, no debug information
            sink("??");

        // Also no debug infos
        if (this.line < 0)
            sink(":?");
        // Line can be 0, e.g. if the frame is in generated code
        else if (this.line)
        {
            sink(":");
            sink(signedToTempString(this.line));
        }

        char[1024] symbolBuffer = void;
        // When execinfo style is used, procedure can be null if the format
        // of the line cannot be read, but it generally should not happen
        if (this.procedure.length)
        {
            sink(" ");
            sink(demangle(this.procedure, symbolBuffer));
        }

        sink(" [0x");
        sink(unsignedToTempString!16(cast(size_t) this.address));
        sink("]");
    }
}

static if (hasExecinfo)
{
    int traceHandlerOpApplyImpl(const(void*)[] callstack,
                                scope int delegate(ref size_t, ref const(char[])) dg)
    {
        import core.stdc.stdio : snprintf;
        import core.sys.posix.stdlib : free;

        const char** frameList = backtrace_symbols(callstack.ptr, cast(int) callstack.length);
        scope(exit) free(cast(void*) frameList);

        auto image = Image.openSelf();

        // find address -> file, line mapping using dwarf debug_line
        Array!Location locations;
        locations.length = callstack.length;
        size_t startIdx;
        foreach (size_t i; 0 .. callstack.length)
        {
            locations[i].address = callstack[i];
            locations[i].procedure = getMangledSymbolName(frameList[i][0 .. strlen(frameList[i])]);

            // NOTE: The first few frames with the current implementation are
            //       inside core.runtime and the object code, so eliminate
            //       these for readability.
            // They also might depend on build parameters, which would make
            // using a fixed number of frames otherwise brittle.
            version (LDC) enum BaseExceptionFunctionName = "_d_throw_exception";
            else          enum BaseExceptionFunctionName = "_d_throwdwarf";
            if (!startIdx && locations[i].procedure == BaseExceptionFunctionName)
                startIdx = i + 1;
        }

        if (!image.isValid())
            return locations[startIdx .. $].processCallstack(null, image.baseAddress, dg);

        return image.processDebugLineSectionData(
            (line) => locations[startIdx .. $].processCallstack(line, image.baseAddress, dg));
    }
}

int traceHandlerOpApplyImpl2(T)(const T[] input, scope int delegate(ref size_t, ref const(char[])) dg)
{
    auto image = Image.openSelf();

    // find address -> file, line mapping using dwarf debug_line
    Array!Location locations;
    locations.length = input.length;
    foreach (idx, const ref inp; input)
    {
        locations[idx].address = inp.address;
        locations[idx].procedure = inp.name;
        // Same code as `traceHandlerOpApplyImpl2`
        version (LDC) enum BaseExceptionFunctionName = "_d_throw_exception";
        else          enum BaseExceptionFunctionName = "_d_throwdwarf";
        if (!startIdx && inp.name == BaseExceptionFunctionName)
            startIdx = i + 1;
    }

    return image.isValid
        ? image.processDebugLineSectionData(
            (line) => locations[].processCallstack(line, image.baseAddress, dg))
        : locations[].processCallstack(null, image.baseAddress, dg);
}

struct TraceInfoBuffer
{
    private char[1536] buf = void;
    private size_t position;

    // BUG: https://issues.dlang.org/show_bug.cgi?id=21285
    @safe pure nothrow @nogc
    {
        ///
        inout(char)[] opSlice() inout return
        {
            return this.buf[0 .. this.position > $ ? $ : this.position];
        }

        ///
        void reset()
        {
            this.position = 0;
        }
    }

    /// Used as `sink` argument to `Location.toString`
    void put(scope const char[] data)
    {
        // We cannot write anymore
        if (this.position > this.buf.length)
            return;

        if (this.position + data.length > this.buf.length)
        {
            this.buf[this.position .. $] = data[0 .. this.buf.length - this.position];
            this.buf[$ - 3 .. $] = "...";
            // +1 is a marker for the '...', otherwise if the symbol
            // name was to exactly fill the buffer,
            // we'd discard anything else without printing the '...'.
            this.position = this.buf.length + 1;
            return;
        }

        this.buf[this.position .. this.position + data.length] = data;
        this.position += data.length;
    }
}

private:

int processCallstack(Location[] locations, const(ubyte)[] debugLineSectionData,
                     size_t baseAddress, scope int delegate(ref size_t, ref const(char[])) dg)
{
    if (debugLineSectionData)
        resolveAddresses(debugLineSectionData, locations, baseAddress);

    TraceInfoBuffer buffer;
    foreach (idx, const ref loc; locations)
    {
        buffer.reset();
        loc.toString(&buffer.put);

        auto lvalue = buffer[];
        if (auto ret = dg(idx, lvalue))
            return ret;

        if (loc.procedure == "_Dmain")
            break;
    }

    return 0;
}

/**
 * Resolve the addresses of `locations` using `debugLineSectionData`
 *
 * Runs the DWARF state machine on `debugLineSectionData`,
 * assuming it represents a debugging program describing the addresses
 * in a continous and increasing manner.
 *
 * After this function successfully completes, `locations` will contains
 * file / lines informations.
 *
 * Note that the lifetime of the `Location` data is bound to the lifetime
 * of `debugLineSectionData`.
 *
 * Params:
 *   debugLineSectionData = A DWARF program to feed the state machine
 *   locations = The locations to resolve
 *   baseAddress = The offset to apply to every address
 */
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

/**
 * Reads an ULEB128 length and then reads the followings bytes specified by the
 * length.
 *
 * Params:
 *      buffer = buffer where the data is read from
 * Returns:
 *      Value contained in the block.
 */
ulong readBlock(ref const(ubyte)[] buffer) @nogc nothrow
{
    ulong length = buffer.readULEB128();
    assert(length <= ulong.sizeof);

    ulong block;
    foreach (i; 0 .. length)
    {
        ubyte b = buffer.read!ubyte;
        block <<= 8 * i;
        block |= b;
    }

    return block;
}

/**
 * Reads a MD5 hash from the `buffer`.
 *
 * Params:
 *      buffer = buffer where the data is read from
 * Returns:
 *      A MD5 hash
 */
char[16] readMD5(ref const(ubyte)[] buffer) @nogc nothrow
{
    assert(buffer.length >= 16);

    ubyte[16] bytes;
    foreach (h; 0 .. 16)
        bytes[h] = buffer.read!ubyte;

    return cast(char[16])bytes;
}

/**
 * Reads a null-terminated string from `buffer`.
 * The string is not removed from buffer and doesn't contain the last null byte.
 *
 * Params:
 *      buffer = buffer where the data is read from
 *
 * Returns:
 *      A string
 */
const(char)[] readString(ref const(ubyte)[] buffer) @nogc nothrow
{
    import core.sys.posix.string : strnlen;

    return cast(const(char)[])buffer[0 .. strnlen(cast(char*)buffer.ptr, buffer.length)];
}

unittest
{
    const(ubyte)[] data = [0x48, 0x61, 0x76, 0x65, 0x20, 0x61, 0x20, 0x67, 0x6f,
        0x6f, 0x64, 0x20, 0x64, 0x61, 0x79, 0x20, 0x21, 0x00];
    const(char)[] result = data.readString();
    assert(result == "Have a good day !");

    data = [0x00];
    assert(data.readString == null);
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

Array!EntryFormatData readEntryFormat(ref const(ubyte)[] buffer, ref Array!ulong entryFormat) @nogc nothrow
{
    // The count needs to be pair, as the specification says
    assert(entryFormat.length % 2 == 0);
    Array!EntryFormatData result;

    for (uint i = 0; i < entryFormat.length; i += 2)
    {
        EntryFormatData efdata;
        ulong form = entryFormat[i + 1];

        switch (entryFormat[i])
        {
            case StandardContentDescription.path:
                if (form == FormEncoding._string)
                    efdata.path = buffer.readString();
                else
                {
                    size_t offset = buffer.read!size_t;

                    // TODO: set filename.path to the string at offset
                    static if (0)
                    {
                        if (form == FormEncoding.line_strp) // Offset in debug_line_str
                        {

                        }
                        else if (form == FormEncoding.strp) // Offset in debug_str
                        {

                        }
                        else if (form == FormEncoding.strp_sup) // Offset of debug_str in debug_info
                        {

                        }
                        else
                            assert(0);
                    }
                    else
                        assert(0);
                }
                break;

            case StandardContentDescription.directoryIndex:
                if (form == FormEncoding.data1)
                    efdata.directoryIndex = cast(ulong)buffer.read!ubyte;
                else if (form == FormEncoding.data2)
                    efdata.directoryIndex = cast(ulong)buffer.read!ushort;
                else if (form == FormEncoding.udata)
                    efdata.directoryIndex = buffer.readULEB128();
                else
                    assert(0);
                break;

            case StandardContentDescription.timeStamp:
                if (form == FormEncoding.udata)
                    efdata.timeStamp = buffer.readULEB128();
                else if (form == FormEncoding.data4)
                    efdata.timeStamp = cast(ulong)buffer.read!uint;
                else if (form == FormEncoding.data8)
                    efdata.timeStamp = buffer.read!ulong;
                else if (form == FormEncoding.block)
                    efdata.timeStamp = buffer.readBlock();
                else
                    assert(0);
                break;

            case StandardContentDescription.size:
                if (form == FormEncoding.data1)
                    efdata.size = cast(ulong)buffer.read!ubyte;
                else if (form == FormEncoding.data2)
                    efdata.size = cast(ulong)buffer.read!ushort;
                else if (form == FormEncoding.data4)
                    efdata.size = cast(ulong)buffer.read!uint;
                else if (form == FormEncoding.data8)
                    efdata.size = buffer.read!ulong;
                else
                    assert(0);
                break;

            case StandardContentDescription.md5:
                if (form == FormEncoding.data16)
                    efdata.md5 = buffer.readMD5();
                else
                    assert(0);
                break;

            default:
                assert(0);
        }
        result.insertBack(efdata);
    }
    return result;
}

enum FormEncoding : ubyte
{
    addr = 1,
    block2 = 3,
    block4 = 4,
    data2 = 5,
    data4 = 6,
    data8 = 7,
    _string = 8,
    block = 9,
    block1 = 10,
    data1 = 11,
    flag = 12,
    sdata = 13,
    strp = 14,
    udata = 15,
    ref_addr = 16,
    ref1 = 17,
    ref2 = 18,
    ref4 = 19,
    ref8 = 20,
    ref_udata = 21,
    indirect = 22,
    sec_offset = 23,
    exprloc = 24,
    flag_present = 25,
    strx = 26,
    addrx = 27,
    ref_sup4 = 28,
    strp_sup = 29,
    data16 = 30,
    line_strp = 31,
    ref_sig8 = 32,
    implicit_const = 33,
    loclistx = 34,
    rnglistx = 35,
    ref_sup8 = 36,
    strx1 = 37,
    strx2 = 38,
    strx3 = 39,
    strx4 = 40,
    addrx1 = 41,
    addrx2 = 42,
    addrx3 = 43,
    addrx4 = 44,
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

enum StandardContentDescription : ubyte
{
    path = 1,
    directoryIndex = 2,
    timeStamp = 3,
    size = 4,
    md5 = 5,
}

struct EntryFormatData
{
    const(char)[] path;
    ulong directoryIndex;
    ulong timeStamp;
    ulong size;
    char[16] md5;
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
    ubyte addressSize;
    ubyte segmentSelectorSize;
    ulong headerLength;
    ubyte minimumInstructionLength;
    ubyte maximumOperationsPerInstruction;
    bool defaultIsStatement;
    byte lineBase;
    ubyte lineRange;
    ubyte opcodeBase;
    const(ubyte)[] standardOpcodeLengths;

    ubyte directoryEntryFormatCount;
    Array!ulong directoryEntryFormat;
    ulong directoriesCount;
    Array!EntryFormatData directories;

    ubyte fileNameEntryFormatCount;
    Array!ulong fileNameEntryFormat;
    ulong fileNamesCount;
    Array!EntryFormatData fileNames;

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
    assert(lp.dwarfVersion < 6, "DWARF v6+ not supported yet");

    if (lp.dwarfVersion >= 5)
    {
        lp.addressSize = data.read!ubyte();
        lp.segmentSelectorSize = data.read!ubyte();
    }

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

    if (lp.dwarfVersion >= 5)
    {
        lp.directoryEntryFormatCount = data.read!ubyte();
        foreach (c; 0 .. lp.directoryEntryFormatCount)
            lp.directoryEntryFormat.insertBack(data.readULEB128());

        lp.directoriesCount = data.readULEB128();
        lp.directories = data.readEntryFormat(lp.directoryEntryFormat);


        lp.fileNameEntryFormatCount = data.read!ubyte;
        foreach (c; 0 .. lp.fileNameEntryFormatCount)
            lp.fileNameEntryFormat.insertBack(data.readULEB128());

        lp.fileNamesCount = data.readULEB128();
        lp.fileNames = data.readEntryFormat(lp.fileNameEntryFormat);
    }

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
