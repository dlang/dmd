module dmd.trace_file;

enum bitmask_lower_48 = 0xFFFF_FFFF_FFFFUL;
enum bitmask_lower_32 = 0xFFFF_FFFFUL;
enum bitmask_lower_16 = 0xFFFFUL;
enum bitmask_upper_16 = 0xFFFFUL << 32UL;
enum bitmask_upper_32 = 0xFFFF_FFFFUL << 16UL;
enum bitmask_upper_48 = 0xFFFF_FFFF_FFFFUL << 16UL;

extern(C) struct SymbolProfileRecord ///
{
    ulong begin_ticks;
    ulong end_ticks;
    
    ulong begin_mem;
    ulong end_mem;
    
    uint symbol_id;
    ushort kind_id;
    ushort phase_id;
}

extern(C) struct SymbolProfileRecordV2
{
    ulong[3] begin_ticks_48_end_ticks_48_begin_memomry_48_end_memory_48; /// represents 4 48 bit values


    uint symbol_id;
    ushort kind_id_9_phase_id_7;
}


extern (C) struct TraceFileHeader
{
    ulong magic_number;

    uint FileVersion;

    uint n_records;
    uint n_phases;
    uint n_kinds;
    uint n_symbols;
    
    uint offset_records;
    uint offset_phases;
    uint offset_kinds;
    uint offset_symbol_info_descriptors;
}

extern (C) struct TraceFileHeaderV4
{
    ulong magic_number;
    
    uint FileVersion;
    
    uint n_records;
    uint n_phases;
    uint n_kinds;
    uint n_symbols;
    
    uint offset_records;
    uint offset_phases;
    uint offset_kinds;
    uint offset_symbol_info_descriptors;

    ulong hash;
}

align(1) struct SymbolInfoPointers
{
align(1):
    uint symbol_name_start;
    uint symobol_location_start;
    uint one_past_symbol_location_end;
}

align(1) struct StringPointer
{
align(1):
    uint string_start;
    uint one_past_string_end;
}

static TraceFileHeader readHeader()(void[] file)
{
    TraceFileHeader header;

    if (file.length < header.sizeof)
    {
        import std.stdio;
        writeln(stderr, "Tracefile truncated.");
    }
    else
    {
        (cast(void*)&header)[0 .. header.sizeof] = file[0 .. header.sizeof];
    }

    return header;
}

static string[] readStrings()(const void[] file, uint offset_strings, uint n_strings)
{
    const (char)[][] result;
    result.length = n_strings;

    StringPointer* stringPointers = cast(StringPointer*)(file.ptr + offset_strings);
    foreach(i; 0 .. n_strings)
    {
        StringPointer p = *stringPointers++;
        result[i] = (cast(char*)file.ptr)[p.string_start .. p.one_past_string_end];
    }

    return (cast(string*)result.ptr)[0 .. result.length];
}

// the only reason this is a template is becuase d does not allow one to
// specify inline linkage ... sigh
static SymbolProfileRecord[] readRecords()(const void[] file, const void[][] additionalFiles = null)
{
    SymbolProfileRecord[] result;

    TraceFileHeader header;
    (cast(void*)&header)[0 .. header.sizeof] = file[0 ..header.sizeof];

    if (header.FileVersion == 1)
    {
        result = (cast(SymbolProfileRecord*)(file.ptr + header.offset_records))[0 .. header.n_records];
    }
    else if (header.FileVersion == 2 || header.FileVersion == 3 || header.FileVersion == 4)
    {
        import core.stdc.stdlib;
        auto source = (cast(SymbolProfileRecordV2*)(file.ptr + header.offset_records))[0 .. header.n_records];
        result = (cast(SymbolProfileRecord*)calloc(result[0].sizeof, header.n_records))[0 .. header.n_records];

        foreach(i;0 .. header.n_records)
        {
            ulong[3] byteField = source[i].begin_ticks_48_end_ticks_48_begin_memomry_48_end_memory_48;

            result[i].begin_ticks = (byteField[0] & bitmask_lower_48);
            result[i].end_ticks = (byteField[0] >> 48UL) | ((byteField[1] & bitmask_lower_32) << 16UL);
            result[i].begin_mem = (byteField[1] >> 32UL) | ((byteField[2] & bitmask_lower_16) << 32UL);
            result[i].end_mem = (byteField[2] >> 16);

            result[i].symbol_id = source[i].symbol_id;

            result[i].kind_id = source[i].kind_id_9_phase_id_7 & ((1 << 9) -1);
            result[i].phase_id = source[i].kind_id_9_phase_id_7 >> 9;
        }
    }

    return result;
}

static string getSymbolName()(const void[] file, uint id)
{
    if (id == uint.max)
        return "NullSymbol";
    
    TraceFileHeader* header = cast(TraceFileHeader*)file.ptr;
    SymbolInfoPointers* symbolInfoPointers = cast(SymbolInfoPointers*) (file.ptr + header.offset_symbol_info_descriptors);
    
    auto symp = symbolInfoPointers[id - 1];
    auto name = (cast(char*)file.ptr)[symp.symbol_name_start .. symp.symobol_location_start];
    if (symp.symbol_name_start == symp.symobol_location_start)
    {
        name = null;
    }
    
    return cast(string) name;
}

static string getSymbolName()(const void[] file, SymbolProfileRecord r)
{
    if (r.symbol_id == uint.max)
        return "NullSymbol";

    TraceFileHeader* header = cast(TraceFileHeader*)file.ptr;
    SymbolInfoPointers* symbolInfoPointers = cast(SymbolInfoPointers*) (file.ptr + header.offset_symbol_info_descriptors);

    auto symp = symbolInfoPointers[r.symbol_id - 1];
    auto name = (cast(char*)file.ptr)[symp.symbol_name_start .. symp.symobol_location_start];
    if (symp.symbol_name_start == symp.symobol_location_start)
    {
        name = null;
    }

    return cast(string) name;
}

static string getSymbolLocation()(const void[] file, uint id)
{
    if (id == uint.max)
        return "NullSymbol";
    
    TraceFileHeader* header = cast(TraceFileHeader*)file.ptr;
    SymbolInfoPointers* symbolInfoPointers = cast(SymbolInfoPointers*) (file.ptr + header.offset_symbol_info_descriptors);
    
    auto symp = symbolInfoPointers[id - 1];
    auto loc = (cast(char*)file.ptr)[symp.symobol_location_start .. symp.one_past_symbol_location_end];
    if (symp.symobol_location_start == symp.one_past_symbol_location_end)
    {
        loc = null;
    }
    
    return cast(string) loc;
}

static string getSymbolLocation()(const void[] file, SymbolProfileRecord r)
{
    if (r.symbol_id == uint.max)
        return "NullSymbol";

    TraceFileHeader* header = cast(TraceFileHeader*)file.ptr;
    SymbolInfoPointers* symbolInfoPointers = cast(SymbolInfoPointers*) (file.ptr + header.offset_symbol_info_descriptors);

    auto symp = symbolInfoPointers[r.symbol_id - 1];
    auto loc = (cast(char*)file.ptr)[symp.symobol_location_start .. symp.one_past_symbol_location_end];
    if (symp.symobol_location_start == symp.one_past_symbol_location_end)
    {
        loc = null;
    }
    
    return cast(string) loc;
}
