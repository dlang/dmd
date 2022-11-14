/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/trace.d, _trace.d)
 * Documentation:  https://dlang.org/phobos/dmd_trace.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/trace.d
 */

module dmd.trace;
import dmd.dsymbol;
import dmd.expression;
import dmd.mtype;
import dmd.statement;
import dmd.root.rootobject;
import dmd.arraytypes : Strings;
import dmd.trace_file;

version (NO_TRACE)
    enum SYMBOL_TRACE = false;
else
    enum SYMBOL_TRACE = true;
enum COMPRESSED_TRACE = true;

struct ProbeEntry
{
    enum NodeType
    {
        invalid,
        nullSymbol,
        dsymbol,
        expression,
        statement,
        type,
    }

    ProbeEntry.NodeType nodeType;

    ulong begin_ticks;
    ulong end_ticks;

    ulong begin_mem;
    ulong end_mem;

    string kind; // asttypename
    string fn; // which function is being traced

    union
    {
        // RootObject ro;
        Dsymbol sym;
        Expression exp;
        Statement stmt;
        Type type;
        void* vp;
    }
}

extern (C) __gshared uint dsymbol_profile_array_count;
extern (C) __gshared ProbeEntry* dsymbol_profile_array;

enum dsymbol_profile_array_capacity = 128 * 1024 * 1024; // 128 million entries should do, no ?

void enableTracing() nothrow @nogc
{
    static if (SYMBOL_TRACE)
    {
        import core.stdc.stdlib : malloc;
        if (!dsymbol_profile_array)
            dsymbol_profile_array = cast(typeof(dsymbol_profile_array))malloc(dsymbol_profile_array_capacity * ProbeEntry.sizeof);
        assert(dsymbol_profile_array, "Failed to allocate trace data");
    }
}

string traceIdentifierStringInScope(string vname, string phaseName = null)
{
    static if (SYMBOL_TRACE)
    {
    return (`
    import dmd.dsymbol;
    import dmd.expression;
    import dmd.mtype;
    import dmd.statement;
    import dmd.globals : global;

    import dmd.queryperf : QueryPerformanceCounter;
    import dmd.root.rmem;
    ulong begin_sema_ticks;
    ulong end_sema_ticks;
    ulong begin_sema_mem = Mem.allocated;
    auto v_ = ` ~ vname ~ `;
    alias v_type = typeof(v_);
    auto insert_pos = dsymbol_profile_array_count++;

    enum asttypename_build = true;
    static if (asttypename_build && __traits(compiles, () { import dmd.asttypename; astTypeName(Dsymbol.init); }))
    {
        import dmd.asttypename;
        string asttypename_v = (global.params.traceFile !is null && v_ !is null ? astTypeName(v_) : "");
    }
    else
    {
        string asttypename_v = v_type.stringof;
    }

    if (global.params.traceFile !is null)
    {
        assert(dsymbol_profile_array_count < dsymbol_profile_array_capacity,
            "Trying to push more then" ~ dsymbol_profile_array_capacity.stringof ~ " symbols");
        QueryPerformanceCounter(&begin_sema_ticks);
    }

    scope(exit) if (global.params.traceFile !is null)
    {
        QueryPerformanceCounter(&end_sema_ticks);
        if (v_ !is null)
        {
            static if (is(v_type : Dsymbol))
            {
                dsymbol_profile_array[insert_pos] =
                    ProbeEntry(ProbeEntry.NodeType.dsymbol,
                    begin_sema_ticks, end_sema_ticks,
                    begin_sema_mem, Mem.allocated,
                    asttypename_v, ` ~ (phaseName
                        ? `"` ~ phaseName ~ `"` : `__FUNCTION__`) ~ `);
                dsymbol_profile_array[insert_pos].sym = v_;
            } else static if (is(v_type : Expression))
            {
                dsymbol_profile_array[insert_pos] =
                    ProbeEntry(ProbeEntry.NodeType.expression,
                    begin_sema_ticks, end_sema_ticks,
                    begin_sema_mem, Mem.allocated,
                    asttypename_v, ` ~ (phaseName
                        ? `"` ~ phaseName ~ `"` : `__FUNCTION__`) ~ `);
                dsymbol_profile_array[insert_pos].exp = v_;
            } else static if (is(v_type : Statement))
            {
                dsymbol_profile_array[insert_pos] =
                    ProbeEntry(ProbeEntry.NodeType.statement,
                    begin_sema_ticks, end_sema_ticks,
                    begin_sema_mem, Mem.allocated,
                    asttypename_v, ` ~ (phaseName
                        ? `"` ~ phaseName ~ `"` : `__FUNCTION__`) ~ `);
                dsymbol_profile_array[insert_pos].stmt = v_;
            } else static if (is(v_type : Type))
            {
                dsymbol_profile_array[insert_pos] =
                    ProbeEntry(ProbeEntry.NodeType.type,
                    begin_sema_ticks, end_sema_ticks,
                    begin_sema_mem, Mem.allocated,
                    asttypename_v, ` ~ (phaseName
                        ? `"` ~ phaseName ~ `"` : `__FUNCTION__`) ~ `);
                dsymbol_profile_array[insert_pos].type = v_;
            }
            else
                static assert(0, "we dont know how to deal with: " ~ v_type.stringof);
        }
        else
        {
            dsymbol_profile_array[insert_pos] =
                    ProbeEntry(ProbeEntry.NodeType.nullSymbol,
                    begin_sema_ticks, end_sema_ticks,
                    begin_sema_mem, Mem.allocated,
                    "Dsymbol(Null)", ` ~ (phaseName
                        ? `"` ~ phaseName ~ `"` : `__FUNCTION__`) ~ `);
        }
    }`);
}  else
        return "";
}

__gshared ulong numInvalidProfileNodes = 0;

static if (COMPRESSED_TRACE)
{
    static struct SymInfo
    {
        void* sym;
        uint id;
        uint pad;

        const (char)* name;
        const (char)* loc;
        const (char)* typename;
    }

    string[] phases;
    string[] kinds;

    ushort[string] kindArray;
    ushort kindArrayNextId = 1;
    ushort[string] phaseArray;
    ushort phaseArrayNextId = 1;

    SymInfo*[void*/*Expression*/] expMap;
    SymInfo*[void*/*Dsymbol*/] symMap;
    SymInfo*[void*/*Statement*/] stmtMap;
    SymInfo*[void*/*Type*/] typeMap;

    SymInfo[] symInfos;
    uint n_symInfos;
}

const(size_t) align4(const size_t val) @safe pure @nogc
{
    return ((val + 3) & ~3);
}

ulong timeBase = 0;

void writeRecord(ProbeEntry dp, ref char* bufferPos, uint FileVersion = 1)
{
    import core.stdc.stdio;
    import dmd.globals : Loc;

    static if (COMPRESSED_TRACE)
    {
        ushort getKindId(string kind, bool justLookup = true)
        {
            ushort result;
            //TODO: don't use AA's here
            if (auto id = kind in kindArray)
            {
                result = *id;
            }
            else
            {
                assert(!justLookup);
                auto id = kindArrayNextId++;
                kinds ~= kind;
                kindArray[kind] = id;
                result = id;
            }

            return result;
        }

        ushort getPhaseId(string phase, bool justLookup = true)
        {
            ushort result;
            //TODO: don't use AAs here
            if (auto id = phase in phaseArray)
            {
                result = *id;
            }
            else
            {
                assert(!justLookup);
                auto id = phaseArrayNextId++;
                phases ~= phase;
                phaseArray[phase] = id;
                result = id;
            }

            return result;
        }

        ushort kindId = getKindId(dp.kind, false);
        ushort phaseId = getPhaseId(dp.fn, false);

        if (kindId > 500)
            assert(0);

        if (phaseId > 500)
            assert(0);

        static uint running_id = 1;

        uint id;
        SymInfo info;

        final switch(dp.nodeType)
        {
            case ProbeEntry.NodeType.nullSymbol :
                id = uint.max;
            break;
            case ProbeEntry.NodeType.dsymbol :
                if (auto symInfo = (cast(void*)dp.sym) in symMap)
                {
                    id = (**symInfo).id;
                }
                break;
            case ProbeEntry.NodeType.expression :
                if (auto symInfo = (cast(void*)dp.exp) in expMap)
                {
                    id = (**symInfo).id;
                }
                break;
            case ProbeEntry.NodeType.statement :
                if (auto symInfo = (cast(void*)dp.stmt) in stmtMap)
                {
                    id = (**symInfo).id;
                }
                break;
            case ProbeEntry.NodeType.type :
                if (auto symInfo = (cast(void*)dp.type) in typeMap)
                {
                    id = (**symInfo).id;
                }
                break;
                // we should probably assert here.
            case ProbeEntry.NodeType.invalid:
                numInvalidProfileNodes++;
                return ;
        }

        if (!id) // we haven't haven't seen this symbol before
        {
            id = running_id++;
            // TODO ~= is too slow ... replace by manual memory allocation;

            symInfos ~= SymInfo(dp.vp, id);

            SymInfo *symInfo = &symInfos[n_symInfos++];

            if (isLikelyOnStack(dp.vp))
            {
                //running_id--;
                goto Lend;
            }

            final switch(dp.nodeType)
            {
                case ProbeEntry.NodeType.nullSymbol :
                    running_id--;
                break;
                case ProbeEntry.NodeType.dsymbol :
                    symInfo.name = dp.sym.toChars();
                    symInfo.loc = dp.sym.loc.toChars();

                    symMap[cast(void*)dp.sym] = symInfo;
                break;
                case ProbeEntry.NodeType.expression :
                    symInfo.name = dp.exp.toChars();
                    symInfo.loc = dp.exp.loc.toChars();

                    expMap[cast(void*)dp.exp] = symInfo;
                break;
                case ProbeEntry.NodeType.statement:
                    symInfo.loc = dp.stmt.loc.toChars();

                    stmtMap[cast(void*)dp.stmt] = symInfo;
                break;
                case ProbeEntry.NodeType.type :
                    symInfo.name = dp.type.toChars();

                    typeMap[cast(void*)dp.type] = symInfo;
                break;

                 case ProbeEntry.NodeType.invalid:
                     assert(0); // this cannot happen
            }
        Lend:
        }
    }
    else
    {
        Loc loc;
        const (char)* name;

        final switch(dp.nodeType)
        {
            case ProbeEntry.NodeType.Dsymbol :
                loc = dp.sym.loc;
                name = dp.sym.toChars();
            break;
            case ProbeEntry.NodeType.Expression :
                loc = dp.exp.loc;
                name = dp.exp.toChars();
            break;
            case ProbeEntry.NodeType.Statement :
                loc = dp.stmt.loc;
            break;
            case ProbeEntry.NodeType.Type :
                name = dp.type.toChars();
                loc = dp.type.toDsymbol().loc;
            break;
            // we should probably assert here.
            case ProbeEntry.NodeType.invalid:
                return ;
            case ProbeEntry.NodeType.nullSymbol: break;

        }
    }
    // Identifier ident = dp.sym.ident ? dp.sym.ident : dp.sym.getIdent();
    static if (COMPRESSED_TRACE)
    {
        if (FileVersion == 2 || FileVersion == 3)
        {
            ProbeRecordV2* rp = cast(ProbeRecordV2*) bufferPos;
            bufferPos += ProbeRecordV2.sizeof;
            //TODO test this works

            ulong[3] byteField;

            byteField[0] = ((dp.begin_ticks - timeBase) & bitmask_lower_48);
            byteField[0] |= (((dp.end_ticks - timeBase) & bitmask_lower_16) << 48UL);
            byteField[1] = (((dp.end_ticks -  timeBase) & bitmask_upper_32) >> 16UL);
            byteField[1] |= (((dp.begin_mem           ) & bitmask_lower_32) << 32UL);
            byteField[2] = (((dp.begin_mem            ) & bitmask_upper_16) >> 32UL);
            byteField[2] |= (((dp.end_mem             ) & bitmask_lower_48) << 16UL);

            ProbeRecordV2 r = {
                begin_ticks_48_end_ticks_48_begin_memomry_48_end_memory_48 :
                    byteField,
                kind_id_9_phase_id_7 : kindId | cast(ushort)(phaseId << 9),
                symbol_id : id,
            };
            *rp = r;
        }
        else if (FileVersion == 1)
        {
            ProbeRecord* rp = cast(ProbeRecord*) bufferPos;
            bufferPos += ProbeRecord.sizeof;

            ProbeRecord r = {
                begin_ticks : dp.begin_ticks,
                end_ticks : dp.end_ticks,
                begin_mem : dp.begin_mem,
                end_mem : dp.end_mem,
                symbol_id : id,
                kind_id : kindId,
                phase_id : phaseId
                    };
            (*rp) = r;
        }
    }
    else
    {
        bufferPos += sprintf(cast(char*) bufferPos,
            "%lld|%s|%s|%s|%s|%lld|%lld|%lld|%lld|\n",
            dp.end_ticks - dp.begin_ticks,
            name, &dp.kind[0], &dp.fn[0],
            loc.toChars(), dp.begin_ticks, dp.end_ticks,
            dp.begin_mem, dp.end_mem
        );
    }

}

/// Copies a string from src to dst
/// Params:
///     dst = destination memory
///     src = source string
/// Returns:
///     a pointer to the end of dst;
char* copyAndPointPastEnd(char* dst, const char * src) // TODO: remove
{
    if (!src)
        return dst;
    import core.stdc.string : strlen, memcpy;
    auto n = strlen(src); // len including the zero terminator
    return cast(char*)memcpy(dst, src, n) + n;
}

char* copyAndPointPastEnd(scope return char* dst, scope const(char)[] src) @trusted // TODO: make @safe use slices
{
    // TODO: untested:
    if (src.length == 0)
        return dst;
    auto n = src.length;
    dst[0..src.length] = src;
    return dst+src.length;
}

static if (COMPRESSED_TRACE)
void writeSymInfos(ref char* bufferPos, const char* fileBuffer)
{
    // first we write 3 pointers each
    // start of name_string
    // start of location_string
    // one past the end of location string

    /// Returns:
    ///     Current offset from the beginning of the file
    uint currentOffset32()
    {
        return cast(uint)(bufferPos - fileBuffer);
    }

    SymbolInfoPointers* symInfoPtrs = cast(SymbolInfoPointers*)bufferPos;
    bufferPos += SymbolInfoPointers.sizeof * n_symInfos;

    foreach(symInfo; symInfos[0 .. n_symInfos])
    {
        auto p = symInfoPtrs++;
        p.symbol_name_start = currentOffset32();
        bufferPos = copyAndPointPastEnd(bufferPos, symInfo.name);
        p.symobol_location_start = currentOffset32();
        bufferPos = copyAndPointPastEnd(bufferPos, symInfo.loc);
        p.one_past_symbol_location_end = currentOffset32();
    }
}

extern (D) void writeStrings(ref char* bufferPos, const char* fileBuffer, string[] strings)
{
    /// Returns:
    ///     Current offset from the beginning of the file
    uint currentOffset32() // should be inlined but dmd's inliner can't do it yet
    {
        return cast(uint)(bufferPos - fileBuffer);
    }

    StringPointer* stringPointers = cast(StringPointer*)bufferPos;
    bufferPos += align4(StringPointer.sizeof * strings.length);
    foreach(s;strings)
    {
        auto p = stringPointers++;

        p.string_start = currentOffset32();
        bufferPos = copyAndPointPastEnd(bufferPos, s.ptr);
        p.one_past_string_end = currentOffset32();
    }
    // align after writing the strings
    (*(cast(size_t*)&bufferPos)) = align4(cast(size_t)bufferPos);
}

struct TraceFileTail
{
    ProbeRecord[] records;

    string[] phases;
    string[] kinds;
    string[] symbol_names;
    string[] symbol_locations;
}

private bool isLikelyOnStack(in void* v) @safe pure nothrow @nogc
{
    pragma(inline, true);
    size_t vs = cast(size_t)v;
    size_t sp;
    version(D_InlineAsm_X86_64)
        asm @trusted pure nothrow @nogc { mov sp, RSP; }
    else version(D_InlineAsm_X86)
        asm @trusted pure nothrow @nogc { mov sp, ESP; }
    else
        static assert(0, "Inline asm not supported");
    // ignoring the first 24 bits of the adress
    // are they the same?
    return (sp & ~0x7FFFFF) == (vs & ~0x7FFFFF);
}

pragma(inline, false)
void writeTrace(Strings* arguments, const (char)[] traceFile = null, uint fVersion = 3)
{
    static if (SYMBOL_TRACE)
    {
        import core.stdc.stdlib;
        import core.stdc.string;
        import core.stdc.stdio;
        import dmd.root.file;
        import dmd.globals : global;

        // this is debug code we simply hope that we will not need more
        // then 2G of log-buffer;
        char* fileBuffer = cast(char*)malloc(int.max);
        char* bufferPos = fileBuffer;

        char[255] fileNameBuffer;
        import core.stdc.time : ctime, time;
        auto now = time(null);

        auto timeString = ctime(&now);
        uint timeStringLength = 0;
        // replace the ' ' by _ and '\n' or '\r' by '\0'
        {
            char c = void;
            for(;;)
            {
                c = timeString[timeStringLength++];
                // break on null, just to be safe;
                if (!c)
                    break;

                if (c == ' ')
                    timeString[timeStringLength - 1] = '_';

                if (c == '\r' || c == '\n')
                {
                    timeString[timeStringLength - 1] = '\0';
                    break;
                }
            }
        }

        auto nameStringLength = (global.params.traceFile !is null ? global.params.traceFile.length : timeStringLength);
        auto nameStringPointer = (global.params.traceFile !is null ? global.params.traceFile.ptr : timeString);
        enum split_file = false;

        static if (COMPRESSED_TRACE)
        {
            auto fileNameLength = snprintf(&fileNameBuffer[0], fileNameBuffer.sizeof, "%.*s.dmd_trace".ptr, cast(int)nameStringLength, nameStringPointer);

            int currentOffset32()
            {
                return cast(uint)(bufferPos - fileBuffer);
            }

            // reserve space for the header
            TraceFileHeader* header = cast(TraceFileHeader*)bufferPos;
            bufferPos += TraceFileHeader.sizeof;
            copyAndPointPastEnd(cast(char*)&header.magic_number, "DMDTRACE".ptr);
            header.FileVersion = fVersion;

            header.n_records = dsymbol_profile_array_count;
            // write arg string behind the header
            if (arguments)
            {
                foreach(arg;*arguments)
                {
                    bufferPos = copyAndPointPastEnd(cast(char*)bufferPos, arg);
                    *cast(char*)bufferPos++ = ' ';
                }
            }
            // realign
            if (auto unaligned = currentOffset32() % 4)
            {
                bufferPos += 4 - unaligned;
            }

            // the records follow
            header.offset_records = currentOffset32();

            foreach(dp;dsymbol_profile_array[0 .. dsymbol_profile_array_count])
            {
                writeRecord(dp, bufferPos, header.FileVersion);
            }

            assert(align4(currentOffset32()) == currentOffset32());

            // after writing the records we know how many symbols infos we have

            // write phases
            header.offset_phases = currentOffset32();
            assert(align4(currentOffset32()) == currentOffset32());
            writeStrings(bufferPos, fileBuffer, phases);
            header.n_phases = cast(uint) phases.length;

            // write kinds
            header.offset_kinds = currentOffset32();
            assert(align4(currentOffset32()) == currentOffset32());
            writeStrings(bufferPos, fileBuffer, kinds);
            header.n_kinds = cast(uint) kinds.length;

            char[] data;
            size_t errorcode_write;

            if (split_file)
            {
                data = fileBuffer[0 .. bufferPos - fileBuffer];
                errorcode_write = File.write(fileNameBuffer[0 .. fileNameLength], data);

                fileNameLength = snprintf(&fileNameBuffer[0], fileNameBuffer.sizeof, "%.*s.dmd_symbol".ptr, cast(int)nameStringLength, nameStringPointer);

                // reset buffer
                bufferPos = fileBuffer;
                auto symHeader = cast(TraceFileHeader*)bufferPos;
                bufferPos += TraceFileHeader.sizeof;

                copyAndPointPastEnd(cast(char*)&symHeader.magic_number, "DMDTRACE".ptr);
                symHeader.FileVersion = fVersion;

                // we write a symbolInfo file only
                // therefore no records
                symHeader.n_records = 0;
                symHeader.n_kinds = 0;
                symHeader.n_phases = 0;
                symHeader.n_symbols = n_symInfos;

                // now attach the metadata
                symHeader.offset_symbol_info_descriptors = currentOffset32();
            }
            else
            {
                header.n_symbols = n_symInfos;
                header.offset_symbol_info_descriptors = currentOffset32();
            }

            writeSymInfos(bufferPos, fileBuffer);
            data = fileBuffer[0 .. bufferPos - fileBuffer];
            errorcode_write = File.write(fileNameBuffer[0 .. fileNameLength], data);
        }
        else
        {
            auto fileNameLength =
                sprintf(&fileNameBuffer[0], "symbol-%s.1.csv".ptr, global.params.traceFile ? global.params.traceFile : timeString);

                        bufferPos += sprintf(cast(char*) bufferPos, "//");
                        if (arguments)
                        {
                            foreach(arg;arguments)
                            {
                                bufferPos += sprintf(bufferPos, "%s ", arg);
                            }
                        }
                        bufferPos += sprintf(cast(char*) bufferPos, "\n");

            bufferPos += sprintf(cast(char*) bufferPos,
                "%s|%s|%s|%s|%s|%s|%s|%s|%s|\n",
                "inclusive ticks".ptr,
                "name".ptr, "kind".ptr, "phase".ptr,
                "location".ptr, "begin_ticks".ptr, "end_ticks".ptr,
                "begin_mem".ptr, "end_mem".ptr
            );

            foreach(dp;dsymbol_profile_array[0 .. dsymbol_profile_array_count / 2])
            {
                writeRecord(dp, bufferPos);
            }

            printf("trace_file_size: %dk\n ", (bufferPos - fileBuffer) / 1024);
            auto data = fileBuffer[0 .. bufferPos - fileBuffer];
            auto errorcode_write = File.write(fileNameBuffer[0 .. fileNameLength], data);

            fileNameLength = sprintf(&fileNameBuffer[0], "symbol-%s.2.csv".ptr, global.params.traceFile ? global.params.traceFile : timeString);

            auto f2 = File();
            bufferPos = fileBuffer;

            foreach(dp;dsymbol_profile_array[dsymbol_profile_array_count / 2
                .. dsymbol_profile_array_count])
            {
                writeRecord(dp, bufferPos);
            }

            data = fileBuffer[0 .. bufferPos - fileBuffer];
            errorcode_write = File.write(fileNameBuffer[0 .. fileNameLength], data);
        }
        free(fileBuffer);
    }
}
